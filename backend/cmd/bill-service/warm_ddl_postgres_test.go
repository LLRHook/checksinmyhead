//go:build integration

package main

import (
	"backend/internal/bill"
	"backend/internal/exchange"
	"backend/internal/tab"
	"backend/internal/testpostgres"
	"backend/internal/web"
	"backend/migrations"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"regexp"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// warmTrace observes the driver itself: every statement, every implicit
// statement-cache prepare, every failure SQLSTATE and the backend PID that ran
// it. A cache hit makes no prepare call, so zero prepares proves a warm reuse.
type warmTrace struct {
	mu         sync.Mutex
	recording  bool
	statements []string
	prepares   []string
	states     []string
	pids       map[uint32]bool
}

func (w *warmTrace) note(conn *pgx.Conn, record func()) {
	w.mu.Lock()
	defer w.mu.Unlock()
	if !w.recording {
		return
	}
	w.pids[conn.PgConn().PID()] = true
	record()
}
func (w *warmTrace) fail(err error) {
	if err == nil {
		return
	}
	state := "non-sqlstate"
	var pg *pgconn.PgError
	if errors.As(err, &pg) {
		state = pg.Code
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.recording {
		w.states = append(w.states, state)
	}
}
func (w *warmTrace) TraceQueryStart(ctx context.Context, conn *pgx.Conn, v pgx.TraceQueryStartData) context.Context {
	w.note(conn, func() { w.statements = append(w.statements, v.SQL) })
	return ctx
}
func (w *warmTrace) TraceQueryEnd(_ context.Context, _ *pgx.Conn, v pgx.TraceQueryEndData) {
	w.fail(v.Err)
}
func (w *warmTrace) TracePrepareStart(ctx context.Context, conn *pgx.Conn, v pgx.TracePrepareStartData) context.Context {
	w.note(conn, func() { w.prepares = append(w.prepares, v.SQL) })
	return ctx
}
func (w *warmTrace) TracePrepareEnd(_ context.Context, _ *pgx.Conn, v pgx.TracePrepareEndData) {
	w.fail(v.Err)
}

type warmPhase struct {
	statements, prepares, states []string
	pids                         []uint32
}

// phase records exactly the statements issued by run.
func (w *warmTrace) phase(run func()) warmPhase {
	w.mu.Lock()
	w.recording, w.statements, w.prepares, w.states, w.pids = true, nil, nil, nil, map[uint32]bool{}
	w.mu.Unlock()
	run()
	w.mu.Lock()
	defer w.mu.Unlock()
	w.recording = false
	result := warmPhase{statements: w.statements, prepares: w.prepares, states: w.states}
	for pid := range w.pids {
		result.pids = append(result.pids, pid)
	}
	sort.Slice(result.pids, func(i, j int) bool { return result.pids[i] < result.pids[j] })
	return result
}

// A result shape that follows the table, in any clause that returns rows.
var warmUnstableShape = regexp.MustCompile(`(?i)(?:^|[\s,])(?:"?\w+"?\.)?\*\s*(?:,|from\b|$)`)

type warmRead struct {
	name, path, token, member string
	version                   int
	html                      bool
}

type warmService struct {
	api, html http.Handler
}

func (s warmService) read(t *testing.T, r warmRead) string {
	t.Helper()
	if r.html {
		w := httptest.NewRecorder()
		s.html.ServeHTTP(w, httptest.NewRequest(http.MethodGet, r.path, nil))
		if w.Code != 200 {
			t.Fatalf("%s: status%d body%s", r.name, w.Code, w.Body)
		}
		return w.Body.String()
	}
	return identityRequest(t, s.api, http.MethodGet, r.path, "", r.token, r.member, "", r.version, 200).Body.String()
}

// warmGraph creates one complete owned graph through the production router and
// returns every authorized read of it. Each call also exercises the writers.
func warmGraph(t *testing.T, s warmService) []warmRead {
	t.Helper()
	r := s.api
	// IDs come from the production read: the shared GORM test helper is SELECT *.
	ids := func(b identityReceipt) (item, share uint) {
		var view struct {
			Items []struct {
				ID uint `json:"id"`
			} `json:"items"`
			Shares []struct {
				ID uint `json:"id"`
			} `json:"person_shares"`
		}
		body := identityRequest(t, r, http.MethodGet, fmt.Sprintf("/api/bills/%d", b.ID), "", b.Token, "", "", 2, 200).Body.Bytes()
		if err := json.Unmarshal(body, &view); err != nil || len(view.Items) == 0 || view.Items[0].ID == 0 {
			t.Fatal("created graph has no readable item")
		}
		if len(view.Shares) > 0 {
			share = view.Shares[0].ID
		}
		return view.Items[0].ID, share
	}
	lazy := identityCreate(t, r, []string{"Alex", "Bea"}, true, "")
	item, _ := ids(lazy)
	claim := fmt.Sprintf("/api/bills/%d/items/%d/assignments", lazy.ID, item)
	identityRequest(t, r, http.MethodPatch, claim, identityJSON(t, map[string]any{"expected_revision": 0, "assignments": []any{
		map[string]any{"participant_id": lazy.Map[0].ID, "percentage": 50}, map[string]any{"participant_id": lazy.Map[1].ID, "percentage": 50}}}), lazy.Token, "", "", 2, 200)
	identityRequest(t, r, http.MethodPost, fmt.Sprintf("/api/bills/%d/participants", lazy.ID), `{"client_ref":"late","name":"Cy","expected_revision":1}`, lazy.Token, "", "", 2, 200)

	split := identityCreate(t, r, []string{"Alex", "Bea"}, false, "")
	_, share := ids(split)
	if share == 0 {
		t.Fatal("split graph has no readable share")
	}
	identityRequest(t, r, http.MethodPatch, fmt.Sprintf("/api/bills/%d/shares/%d", split.ID, share), `{"paid":true}`, split.Token, "", "", 2, 200)

	open := identityNewTab(t, r, "Creator")
	_, joined := identityJoin(t, r, open, "Bea")
	_, leaver := identityJoin(t, r, open, "Cy")
	identityAttach(t, r, open, identityCreate(t, r, []string{"Alex", "Bea"}, false, ""), 0)
	identityRequest(t, r, http.MethodPatch, fmt.Sprintf("/api/tabs/%d", open.ID), `{"name":"Renamed trip"}`, open.Token, open.Member, "", 2, 200)
	identityRequest(t, r, http.MethodPatch, fmt.Sprintf("/api/tabs/%d/members/me", open.ID), `{"display_name":"Bea B"}`, open.Token, joined, "", 2, 200)
	identityRequest(t, r, http.MethodDelete, fmt.Sprintf("/api/tabs/%d/members/me", open.ID), "", open.Token, leaver, "", 2, 200)

	closed := identityNewTab(t, r, "Creator")
	identityAttach(t, r, closed, identityCreate(t, r, []string{"Alex", "Bea"}, false, ""), 0)
	identityRequest(t, r, http.MethodPost, fmt.Sprintf("/api/tabs/%d/finalize", closed.ID), "", closed.Token, closed.Member, "", 2, 200)
	var settlements []struct {
		ID uint `json:"id"`
	}
	history := identityRequest(t, r, http.MethodGet, fmt.Sprintf("/api/tabs/%d/settlements", closed.ID), "", closed.Token, closed.Member, "", 1, 200).Body.Bytes()
	if err := json.Unmarshal(history, &settlements); err != nil || len(settlements) == 0 {
		t.Fatal("finalized graph has no readable settlement")
	}
	identityRequest(t, r, http.MethodPatch, fmt.Sprintf("/api/tabs/%d/settlements/%d", closed.ID, settlements[0].ID), `{"paid":true}`, closed.Token, closed.Member, "", 2, 200)

	bills := func(id uint) string { return fmt.Sprintf("/api/bills/%d", id) }
	tabs := func(id uint, suffix string) string { return fmt.Sprintf("/api/tabs/%d%s", id, suffix) }
	return []warmRead{
		{name: "health", path: "/health"},
		{name: "lazy bill wire2", path: bills(lazy.ID), token: lazy.Token, version: 2},
		{name: "lazy bill wire1", path: bills(lazy.ID), token: lazy.Token, version: 1},
		{name: "split bill wire2", path: bills(split.ID), token: split.Token, version: 2},
		{name: "split bill unversioned", path: bills(split.ID), token: split.Token},
		{name: "split bill HTML", path: fmt.Sprintf("/b/%d?t=%s", split.ID, split.Token), html: true},
		{name: "open tab wire2", path: tabs(open.ID, ""), token: open.Token, member: open.Member, version: 2},
		{name: "open tab wire1", path: tabs(open.ID, ""), token: open.Token, member: joined, version: 1},
		{name: "open tab members", path: tabs(open.ID, "/members"), token: open.Token, member: open.Member, version: 2},
		{name: "open tab member self", path: tabs(open.ID, "/members/me"), token: open.Token, member: joined, version: 2},
		{name: "open tab settlements", path: tabs(open.ID, "/settlements"), token: open.Token, member: open.Member, version: 2},
		{name: "closed tab wire2", path: tabs(closed.ID, ""), token: closed.Token, member: closed.Member, version: 2},
		{name: "closed tab wire1", path: tabs(closed.ID, ""), token: closed.Token, member: closed.Member, version: 1},
		{name: "closed tab settlements wire2", path: tabs(closed.ID, "/settlements"), token: closed.Token, member: closed.Member, version: 2},
		{name: "closed tab settlements wire1", path: tabs(closed.ID, "/settlements"), token: closed.Token, member: closed.Member, version: 1},
	}
}

// One warm pool connection serves API and retained HTML before and after a
// separate session commits an owned additive column on every application table.
// Authorized bodies must be byte-identical from already cached statements, and
// the same warm writers must still commit; nothing is retried or reconnected.
func TestPostgresWarmServiceSurvivesAdditiveDDL(t *testing.T) {
	t.Setenv("TRUSTED_PROXY_CIDRS", "")
	trace := &warmTrace{}
	pool := testpostgres.Open(t, trace)
	pool.SetMaxOpenConns(2)
	pool.SetMaxIdleConns(2)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	state, err := migrations.Run(ctx, pool, migrations.Apply)
	if err != nil {
		t.Fatal(err)
	}
	// The held session is the migrator; the service owns the one remaining slot.
	migrator, err := pool.Conn(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer migrator.Close()
	var migratorPID uint32
	if err := migrator.QueryRowContext(ctx, "SELECT pg_backend_pid()").Scan(&migratorPID); err != nil {
		t.Fatal(err)
	}

	g, err := gorm.Open(postgres.New(postgres.Config{Conn: pool}), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		t.Fatal(err)
	}
	up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(500) }))
	t.Cleanup(up.Close)
	repo := bill.NewBillRepository(g)
	billHandler, currencyHandler := newCurrencyHandlers(repo, exchange.NewClient(up.URL))
	api, err := newRouter(billHandler, currencyHandler, tab.NewTabHandler(tab.NewTabService(tab.NewTabRepository(g))), nil, state)
	if err != nil {
		t.Fatal(err)
	}
	html := gin.New()
	html.LoadHTMLGlob("../../internal/web/templates/*")
	html.GET("/b/:id", web.NewWebpageHandler(bill.NewBillService(repo, exchange.NewClient(up.URL))).CreateHTML)
	service := warmService{api: api, html: html}

	var reads []warmRead
	trace.phase(func() { reads = warmGraph(t, service) })
	bodies := func() []string {
		out := make([]string, len(reads))
		for i, read := range reads {
			out[i] = service.read(t, read)
		}
		return out
	}
	var first, warm []string
	trace.phase(func() { first = bodies() })
	cached := trace.phase(func() { warm = bodies() })
	if len(cached.prepares) != 0 || len(cached.states) != 0 || len(cached.pids) != 1 || cached.pids[0] == migratorPID {
		t.Fatalf("reads are not one warm cached connection: prepares%d errors%v pids%v migrator%d", len(cached.prepares), cached.states, cached.pids, migratorPID)
	}
	for i := range reads {
		if first[i] != warm[i] || warm[i] == "" {
			t.Fatalf("%s is not a stable nonempty read", reads[i].name)
		}
	}
	servicePID := cached.pids[0]

	// The discriminator shares the service connection and is cached before DDL.
	star := func() error {
		rows, err := g.Raw("SELECT * FROM bills WHERE id > ? ORDER BY id LIMIT 1", 0).Rows()
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
		}
		return rows.Err()
	}
	for i := 0; i < 2; i++ {
		if err := star(); err != nil {
			t.Fatal("discriminator failed before DDL")
		}
	}

	tables := warmTables(t, ctx, migrator)
	if strings.Join(tables, ",") != "bill_items,bill_participants,bills,item_assignments,people,person_shares,tab_members,tab_settlements,tabs" {
		t.Fatalf("application tables changed: %v", tables)
	}
	tx, err := migrator.BeginTx(ctx, nil)
	if err != nil {
		t.Fatal(err)
	}
	for _, table := range tables {
		if _, err := tx.ExecContext(ctx, "ALTER TABLE "+pgx.Identifier{table}.Sanitize()+" ADD COLUMN warm_reader_probe text"); err != nil {
			t.Fatalf("owned additive column on %s failed", table)
		}
	}
	if err := tx.Commit(); err != nil {
		t.Fatal(err)
	}

	var after []string
	served := trace.phase(func() { after = bodies() })
	for i := range reads {
		if after[i] != warm[i] {
			t.Errorf("%s changed across additive DDL", reads[i].name)
		}
	}
	if len(served.prepares) != 0 || len(served.states) != 0 || len(served.pids) != 1 || served.pids[0] != servicePID {
		t.Fatalf("warm reads did not reuse cached statements on PID %d: prepares%d errors%v pids%v", servicePID, len(served.prepares), served.states, served.pids)
	}

	// The same connection really did have a result shape invalidated: exactly one
	// failure for the cached statement, then the driver re-prepares it.
	control := trace.phase(func() {
		var pg *pgconn.PgError
		if err := star(); !errors.As(err, &pg) || pg.Code != "0A000" {
			t.Errorf("SELECT * discriminator did not observe SQLSTATE 0A000: %v", err)
		}
		if err := star(); err != nil {
			t.Errorf("discriminator did not recover after one failure: %v", err)
		}
	})
	if len(control.pids) != 1 || control.pids[0] != servicePID || strings.Join(control.states, ",") != "0A000" || len(control.prepares) != 1 {
		t.Fatalf("discriminator did not run on warm PID %d: pids%v errors%v prepares%d", servicePID, control.pids, control.states, len(control.prepares))
	}

	// Warm writers and the reads of their new graph also survive, unretried.
	written := trace.phase(func() {
		for _, read := range warmGraph(t, service) {
			service.read(t, read)
		}
	})
	if len(written.states) != 0 || len(written.pids) != 1 || written.pids[0] != servicePID {
		t.Fatalf("warm writers failed or reconnected: errors%v pids%v", written.states, written.pids)
	}
	if len(written.prepares) != 0 {
		t.Fatalf("warm writers issued %d uncached statements", len(written.prepares))
	}
	for _, statement := range written.statements {
		if warmUnstableShape.MatchString(statement) {
			t.Fatalf("table-shaped projection reached PostgreSQL: %.80s", statement)
		}
	}
	var probes int
	if err := migrator.QueryRowContext(ctx, "SELECT count(*) FROM information_schema.columns WHERE table_schema=current_schema() AND column_name='warm_reader_probe'").Scan(&probes); err != nil || probes != len(tables) {
		t.Fatalf("owned additive columns missing: %d of %d", probes, len(tables))
	}
}

func warmTables(t *testing.T, ctx context.Context, q *sql.Conn) []string {
	t.Helper()
	rows, err := q.QueryContext(ctx, "SELECT table_name FROM information_schema.tables WHERE table_schema=current_schema() AND table_name<>'schema_migrations' ORDER BY table_name")
	if err != nil {
		t.Fatal(err)
	}
	defer rows.Close()
	var tables []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			t.Fatal(err)
		}
		tables = append(tables, name)
	}
	if err := rows.Err(); err != nil {
		t.Fatal(err)
	}
	return tables
}

func TestWarmUnstableShapePattern(t *testing.T) {
	for statement, want := range map[string]bool{
		`SELECT * FROM "bills" WHERE id = $1`:                     true,
		`SELECT "bills".* FROM "bills"`:                           true,
		`SELECT id, b.* FROM bills b`:                             true,
		`UPDATE "bills" SET "name"=$1 WHERE id = $2 RETURNING *`:  true,
		`SELECT count(*) FROM "bills"`:                            false,
		`SELECT id,price * 2 FROM bill_items`:                     false,
		`SELECT id,name FROM "bills" WHERE id = $1`:               false,
		`INSERT INTO "bills" ("name") VALUES ($1) RETURNING "id"`: false,
	} {
		if warmUnstableShape.MatchString(statement) != want {
			t.Errorf("pattern misjudged %q", statement)
		}
	}
}
