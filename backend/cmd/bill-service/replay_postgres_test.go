//go:build integration

package main

import (
	"backend/internal/bill"
	"backend/internal/exchange"
	"backend/internal/tab"
	"backend/internal/testpostgres"
	"backend/migrations"
	"backend/pkg/database"
	"bufio"
	"bytes"
	"context"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func replayRouter(t *testing.T) (*sql.DB, *gorm.DB, http.Handler, *atomic.Int64, *bytes.Buffer) {
	t.Helper()
	t.Setenv("TRUSTED_PROXY_CIDRS", "")
	db := testpostgres.Open(t)
	state, err := migrations.Run(context.Background(), db, migrations.Apply)
	if err != nil {
		t.Fatal(err)
	}
	logs := &bytes.Buffer{}
	prior := log.Writer()
	log.SetOutput(logs)
	t.Cleanup(func() { log.SetOutput(prior) })
	g, err := gorm.Open(postgres.New(postgres.Config{Conn: db}), &gorm.Config{Logger: database.NewSQLLogger().LogMode(logger.Info)})
	if err != nil {
		t.Fatal(err)
	}
	calls := &atomic.Int64{}
	up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		base, quote, rate, day := "EUR", "USD", 1.25, time.Now().UTC().Format(time.DateOnly)
		if strings.HasSuffix(r.URL.Path, "/ZAR") {
			quote, rate, day = "ZAR", 20, time.Now().UTC().AddDate(0, 0, -2).Format(time.DateOnly)
		}
		fmt.Fprintf(w, `{"base":%q,"quote":%q,"rate":%v,"date":%q}`, base, quote, rate, day)
	}))
	t.Cleanup(up.Close)
	b, c := newCurrencyHandlers(bill.NewBillRepository(g), exchange.NewClient(up.URL))
	r, err := newRouter(b, c, tab.NewTabHandler(tab.NewTabService(tab.NewTabRepository(g))), nil, state)
	if err != nil {
		t.Fatal(err)
	}
	return db, g, r, calls, logs
}
func replayRequest(t *testing.T, r http.Handler, method, path, body, key, member string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	if key != "" {
		req.Header.Set("Idempotency-Key", key)
	}
	if member != "" {
		req.Header.Set("X-Member-Token", member)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}
func replaySnapshot(t *testing.T, db *sql.DB) string {
	t.Helper()
	var out []string
	for _, table := range []string{"bills", "people", "bill_participants", "bill_items", "item_assignments", "person_shares", "tabs", "tab_members", "tab_settlements"} {
		var v string
		if err := db.QueryRow(`SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text),'[]')::text FROM ` + table + ` x`).Scan(&v); err != nil {
			t.Fatal(err)
		}
		out = append(out, v)
	}
	return strings.Join(out, "\n")
}
func TestPostgresProductionReplayLifecycleLost201AndSecrecy(t *testing.T) {
	db, g, r, calls, logs := replayRouter(t)
	key := base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{84}, 32))
	body := `{"name":"Receipt","lazy_mode":true,"subtotal":10,"total":10,"currency_code":"EUR","display_currency":"USD","participants":[{"name":"Alex"}],"items":[{"name":"Repeated","price":6,"assignments":[{"person_name":"Alex","percentage":100}]},{"name":"Repeated","price":4}]}`
	// The first201 is deliberately treated as lost by the client. Recovery uses
	// the original key/content; it never invents a second identity.
	first := replayRequest(t, r, "POST", "/api/bills", body, key, "")
	directives := map[string]bool{}
	for _, directive := range strings.Split(first.Header().Get("Cache-Control"), ",") {
		directives[strings.ToLower(strings.TrimSpace(directive))] = true
	}
	if first.Code != 201 || !directives["private"] || !directives["no-store"] || directives["public"] || calls.Load() != 1 {
		t.Fatalf("first201=%d calls=%d", first.Code, calls.Load())
	}
	var result struct {
		ID    uint   `json:"bill_id"`
		Token string `json:"access_token"`
	}
	if err := json.Unmarshal(first.Body.Bytes(), &result); err != nil || result.ID == 0 || result.Token == "" {
		t.Fatal("invalid persisted201")
	}
	// Retrieve database credentials independently of the HTTP projection.
	var token string
	var digest, fingerprint []byte
	if err := db.QueryRow("SELECT access_token,creation_key_digest,creation_fingerprint FROM bills WHERE id=$1", result.ID).Scan(&token, &digest, &fingerprint); err != nil || token != result.Token {
		t.Fatal("201 not persisted")
	}
	checkReplay := func() {
		t.Helper()
		before := replaySnapshot(t, db)
		n := calls.Load()
		w := replayRequest(t, r, "POST", "/api/bills", body, key, "")
		if w.Code != 201 || w.Body.String() != first.Body.String() || before != replaySnapshot(t, db) || calls.Load() != n {
			t.Fatal("original replay changed identity,graph,attribution,accounting or provider")
		}
	}
	checkReplay()
	var item uint
	var stamp time.Time
	if err := db.QueryRow("SELECT id,updated_at FROM bill_items WHERE bill_id=$1 ORDER BY id DESC LIMIT 1", result.ID).Scan(&item, &stamp); err != nil {
		t.Fatal(err)
	}
	participant := identityRequest(t, r, "POST", fmt.Sprintf("/api/bills/%d/participants", result.ID), `{"client_ref":"claim_blair","name":"Blair","expected_revision":0}`, token, "", "", 2, 200)
	var added struct {
		P struct {
			ID uint `json:"participant_id"`
		} `json:"participant"`
	}
	if err := json.Unmarshal(participant.Body.Bytes(), &added); err != nil {
		t.Fatal(err)
	}
	claim := fmt.Sprintf(`{"expected_revision":1,"expected_updated_at":%q,"assignments":[{"participant_id":%d,"percentage":100}]}`, stamp.Format(time.RFC3339Nano), added.P.ID)
	w := identityRequest(t, r, "PATCH", fmt.Sprintf("/api/bills/%d/items/%d/assignments", result.ID, item), claim, token, "", "", 2, 200)
	if w.Code != 200 {
		t.Fatalf("claim %d %s", w.Code, w.Body)
	}
	checkReplay()
	w = replayRequest(t, r, "POST", "/api/tabs", `{"name":"Trip","creator_display_name":"Alex"}`, "", "")
	var dst struct {
		ID       uint   `json:"tab_id"`
		Token    string `json:"access_token"`
		Member   string `json:"member_token"`
		MemberID uint   `json:"member_id"`
	}
	if w.Code != 201 || json.Unmarshal(w.Body.Bytes(), &dst) != nil {
		t.Fatal("create tab")
	}
	w = replayRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/bills?t=%s", dst.ID, dst.Token), fmt.Sprintf(`{"bill_id":%d,"bill_token":%q}`, result.ID, token), "", dst.Member)
	if w.Code != 200 {
		t.Fatalf("attach %d %s", w.Code, w.Body)
	}
	checkReplay()
	var share uint
	if err := db.QueryRow("SELECT id FROM person_shares WHERE bill_id=$1 ORDER BY id LIMIT 1", result.ID).Scan(&share); err != nil {
		t.Fatal(err)
	}
	var participantID uint
	var revision int64
	if err := db.QueryRow("SELECT participant_id FROM person_shares WHERE id=$1 AND bill_id=$2", share, result.ID).Scan(&participantID); err != nil {
		t.Fatal(err)
	}
	if err := db.QueryRow("SELECT identity_revision FROM bills WHERE id=$1", result.ID).Scan(&revision); err != nil {
		t.Fatal(err)
	}
	binding := fmt.Sprintf("/api/tabs/%d/bills/%d/participants/%d", dst.ID, result.ID, participantID)
	identityRequest(t, r, "POST", binding+"/binding-request", fmt.Sprintf(`{"expected_revision":%d}`, revision), dst.Token, dst.Member, "", 2, 200)
	identityRequest(t, r, "PUT", binding+"/binding", fmt.Sprintf(`{"expected_revision":%d,"request_revision":%d,"member_id":%d,"decision":"approve"}`, revision+1, revision+1, dst.MemberID), dst.Token, dst.Member, "", 2, 200)
	w = replayRequest(t, r, "PATCH", fmt.Sprintf("/api/tabs/%d/bills/%d/shares/%d/paid?t=%s", dst.ID, result.ID, share, dst.Token), `{"paid":true}`, "", dst.Member)
	if w.Code != 200 {
		t.Fatalf("paid %d %s", w.Code, w.Body)
	}
	checkReplay()
	w = replayRequest(t, r, "POST", fmt.Sprintf("/api/tabs/%d/finalize?t=%s", dst.ID, dst.Token), "", "", dst.Member)
	if w.Code != 200 {
		t.Fatalf("finalize %d %s", w.Code, w.Body)
	}
	checkReplay()
	// Established replay has no ORM graph hooks or create/update/delete callbacks.
	if err := g.Callback().Create().Before("gorm:create").Register("test:no_create", func(tx *gorm.DB) { tx.AddError(fmt.Errorf("replay wrote graph")) }); err != nil {
		t.Fatal(err)
	}
	checkReplay()
	reads := replayRequest(t, r, "GET", fmt.Sprintf("/api/bills/%d?t=%s", result.ID, token), "", "", "")
	if reads.Code != 200 {
		t.Fatal("public authorized read")
	}
	for _, secret := range []string{key, hex.EncodeToString(digest), hex.EncodeToString(fingerprint), "creation_key_digest", "creation_fingerprint"} {
		if strings.Contains(reads.Body.String(), secret) || strings.Contains(logs.String(), secret) {
			t.Fatal("replay metadata leak")
		}
	}
	for _, bad := range []string{
		strings.Replace(body, `"name":"Receipt"`, `"name":"Changed"`, 1),
		strings.Replace(body, `"name":"Receipt"`, `"name":"Receipt","date":null`, 1),
		strings.Replace(body, `"name":"Alex"`, `"name":"Alex","id":0`, 1),
		strings.Replace(body, `"price":6`, `"price":null`, 1), body + `{}`,
	} {
		n := calls.Load()
		w := replayRequest(t, r, "POST", "/api/bills", bad, key, "")
		want := 400
		if strings.Contains(bad, "Changed") {
			want = 409
		}
		if w.Code != want || calls.Load() != n || strings.Contains(w.Body.String(), token) || strings.Contains(w.Body.String(), key) {
			t.Fatal("malformed/conflict replay bypass or capability disclosure")
		}
	}
	if _, err := db.Exec("UPDATE bills SET creation_fingerprint_version=3 WHERE id=$1", result.ID); err != nil {
		t.Fatal(err)
	}
	w = replayRequest(t, r, "POST", "/api/bills", body, key, "")
	if w.Code != 503 || strings.Contains(w.Body.String(), token) {
		t.Fatal("unknown version fallback")
	}
}
func TestPostgresProductionReplaySeparateReceiptsAndDisplayProvenance(t *testing.T) {
	db, _, r, calls, _ := replayRouter(t)
	for _, display := range []string{"EUR", "USD", "ZAR"} {
		t.Run(display, func(t *testing.T) {
			body := fmt.Sprintf(`{"name":"Receipt","subtotal":10,"total":10,"currency_code":"EUR","display_currency":%q}`, display)
			n := calls.Load()
			w := replayRequest(t, r, "POST", "/api/bills", body, "", "")
			if w.Code != 201 {
				t.Fatal(w.Code, w.Body)
			}
			var row struct {
				ID uint `json:"bill_id"`
			}
			json.Unmarshal(w.Body.Bytes(), &row)
			var day, source sql.NullString
			var retrieved sql.NullTime
			if err := db.QueryRow("SELECT display_rate_date,display_rate_source,display_rate_retrieved_at FROM bills WHERE id=$1", row.ID).Scan(&day, &source, &retrieved); err != nil {
				t.Fatal(err)
			}
			wantCalls := int64(1)
			if display == "ZAR" {
				wantCalls = 2
			}
			if calls.Load()-n != wantCalls {
				t.Fatal("wrong distinct quote count")
			}
			if display == "EUR" {
				if source.String != "same_currency" || day.Valid || retrieved.Valid {
					t.Fatal("invented same-currency observation")
				}
			} else {
				want := time.Now().UTC()
				if display == "ZAR" {
					want = want.AddDate(0, 0, -2)
				}
				if day.String != want.Format(time.DateOnly) || source.String != "frankfurter-v2-blended" || !retrieved.Valid || retrieved.Time.Nanosecond()%1000 != 0 {
					t.Fatal("display observation/retrieval ownership")
				}
			}
		})
	}
	body := `{"name":"Same content","subtotal":0.001,"total":0.001}`
	seen := map[uint]bool{}
	for _, key := range []string{"", "", base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{1}, 32)), base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{2}, 32))} {
		w := replayRequest(t, r, "POST", "/api/bills", body, key, "")
		var v struct {
			ID  uint    `json:"bill_id"`
			USD float64 `json:"usd_total"`
		}
		if w.Code != 201 || json.Unmarshal(w.Body.Bytes(), &v) != nil || v.USD != 0 || seen[v.ID] {
			t.Fatal("independent receipts/subcent zero USD changed")
		}
		seen[v.ID] = true
	}
}
func TestPostgresProductionReplayRawTCPParsedContractAndCORS(t *testing.T) {
	_, _, r, _, _ := replayRouter(t)
	server := httptest.NewServer(r)
	defer server.Close()
	key := base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{3}, 32))
	body := `{"name":"Receipt","subtotal":10,"total":10}`
	cases := []struct {
		name, header string
		code         int
	}{
		{"canonical", "Idempotency-Key: " + key, 201},
		{"parser-trims-leading-ows", "Idempotency-Key: \t " + key + " \t", 201},
		{"parser-equivalent-fold", "Idempotency-Key:\r\n " + key, 201},
		{"fold-internal-space", "Idempotency-Key: " + key[:20] + "\r\n " + key[20:], 400},
		{"duplicate", "Idempotency-Key: " + key + "\r\nidempotency-key: " + key, 400},
		{"raw-control-parser-rejection", "Idempotency-Key: " + key + "\x00", 400},
		{"raw-bad-header-parser-rejection", "Idempotency Key: " + key, 400},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			conn, err := net.DialTimeout("tcp", strings.TrimPrefix(server.URL, "http://"), time.Second)
			if err != nil {
				t.Fatal(err)
			}
			defer conn.Close()
			conn.SetDeadline(time.Now().Add(3 * time.Second))
			fmt.Fprintf(conn, "POST /api/bills HTTP/1.1\r\nHost: local\r\nConnection: close\r\nContent-Type: application/json\r\nContent-Length: %d\r\n%s\r\n\r\n%s", len(body), tc.header, body)
			response, err := http.ReadResponse(bufio.NewReader(conn), nil)
			if err != nil {
				t.Fatal(err)
			}
			defer response.Body.Close()
			io.Copy(io.Discard, response.Body)
			if response.StatusCode != tc.code {
				t.Fatalf("parsed/TCP status%d want%d", response.StatusCode, tc.code)
			}
		})
	}
	req := httptest.NewRequest("OPTIONS", "/api/bills", nil)
	req.Header.Set("Origin", "https://billingtonapp.vercel.app")
	req.Header.Set("Access-Control-Request-Method", "POST")
	req.Header.Set("Access-Control-Request-Headers", "Idempotency-Key,Content-Type")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != 204 || !strings.Contains(w.Header().Get("Access-Control-Allow-Headers"), "Idempotency-Key") {
		t.Fatal("key CORS preflight")
	}
}
