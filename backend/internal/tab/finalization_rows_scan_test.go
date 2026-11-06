package tab

import (
	"backend/pkg/models"
	"context"
	"database/sql"
	"database/sql/driver"
	"encoding/json"
	"errors"
	"io"
	"reflect"
	"strings"
	"sync"
	"testing"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Exercise database/sql's real conversion, iteration and close behavior. This
// driver supplies database values and faults; it does not convert model fields.
type finalizationRowScript struct {
	columns           string
	values            [][]driver.Value
	queryErr, nextErr error
	closeErr          error
	cancel            context.CancelFunc
	reuse             bool
	closed            int
}

type finalizationDBScript struct {
	mu                 sync.Mutex
	steps              []*finalizationRowScript
	queries            []string
	arguments          [][]driver.NamedValue
	commits, rollbacks int
}

type finalizationConnector struct{ script *finalizationDBScript }
type finalizationDriver struct{}
type finalizationConn struct{ script *finalizationDBScript }
type finalizationTx struct{ script *finalizationDBScript }
type finalizationScriptRows struct {
	db      *finalizationDBScript
	script  *finalizationRowScript
	ctx     context.Context
	index   int
	closed  bool
	buffers map[int][]byte
}

func (c finalizationConnector) Connect(context.Context) (driver.Conn, error) {
	return &finalizationConn{c.script}, nil
}
func (finalizationConnector) Driver() driver.Driver           { return finalizationDriver{} }
func (finalizationDriver) Open(string) (driver.Conn, error)   { return nil, driver.ErrSkip }
func (*finalizationConn) Prepare(string) (driver.Stmt, error) { return nil, driver.ErrSkip }
func (*finalizationConn) Close() error                        { return nil }
func (c *finalizationConn) Begin() (driver.Tx, error)         { return &finalizationTx{c.script}, nil }
func (c *finalizationConn) QueryContext(ctx context.Context, query string, args []driver.NamedValue) (driver.Rows, error) {
	c.script.mu.Lock()
	defer c.script.mu.Unlock()
	i := len(c.script.queries)
	c.script.queries = append(c.script.queries, query)
	c.script.arguments = append(c.script.arguments, append([]driver.NamedValue(nil), args...))
	if i >= len(c.script.steps) {
		return nil, errors.New("unexpected synthetic query")
	}
	step := c.script.steps[i]
	if step.queryErr != nil {
		return nil, step.queryErr
	}
	return &finalizationScriptRows{db: c.script, script: step, ctx: ctx, buffers: map[int][]byte{}}, nil
}
func (x *finalizationTx) Commit() error {
	x.script.mu.Lock()
	defer x.script.mu.Unlock()
	x.script.commits++
	return nil
}
func (x *finalizationTx) Rollback() error {
	x.script.mu.Lock()
	defer x.script.mu.Unlock()
	x.script.rollbacks++
	return nil
}
func (r *finalizationScriptRows) Columns() []string { return strings.Split(r.script.columns, ",") }
func (r *finalizationScriptRows) Close() error {
	r.db.mu.Lock()
	defer r.db.mu.Unlock()
	if !r.closed {
		r.closed = true
		r.script.closed++
		for _, b := range r.buffers {
			for i := range b {
				b[i] = 'X'
			}
		}
	}
	return r.script.closeErr
}
func (r *finalizationScriptRows) Next(dest []driver.Value) error {
	r.db.mu.Lock()
	defer r.db.mu.Unlock()
	if r.script.cancel != nil {
		r.script.cancel()
		return r.ctx.Err()
	}
	if r.index == len(r.script.values) {
		if r.script.nextErr != nil {
			return r.script.nextErr
		}
		return io.EOF
	}
	for i, value := range r.script.values[r.index] {
		if b, ok := value.([]byte); ok && r.script.reuse {
			buf := r.buffers[i]
			if cap(buf) < len(b) {
				buf = make([]byte, len(b))
			}
			buf = buf[:len(b)]
			copy(buf, b)
			r.buffers[i] = buf
			value = buf
		}
		dest[i] = value
	}
	r.index++
	return nil
}

func finalizationScriptDB(t *testing.T, steps ...*finalizationRowScript) (*gorm.DB, *finalizationDBScript) {
	t.Helper()
	script := &finalizationDBScript{steps: steps}
	pool := sql.OpenDB(finalizationConnector{script})
	pool.SetMaxOpenConns(1)
	t.Cleanup(func() {
		if err := pool.Close(); err != nil {
			t.Error(err)
		}
	})
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: pool}), &gorm.Config{
		DisableAutomaticPing: true, Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}
	return db, script
}

func finalizationParticipantValues(id int64) []driver.Value {
	return []driver.Value{id, int64(1), int64(10) + id, []byte("Label"), "Allocation", int64(2), int64(0), "local-ref", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil}
}
func finalizationShareValues(id int64, items driver.Value) []driver.Value {
	return []driver.Value{id, int64(1), []byte("Raw label"), items, "0.25", "0.01", "0.02", "0.28", nil, int64(2), int64(11)}
}

func TestFinalizationRowsReaderFailures(t *testing.T) {
	for _, family := range []string{"participants", "shares"} {
		for _, failure := range []string{"query", "scan", "iteration", "close", "cancel"} {
			t.Run(family+"/"+failure, func(t *testing.T) {
				marker := errors.New("synthetic row failure")
				step := &finalizationRowScript{columns: models.ParticipantColumns, values: [][]driver.Value{finalizationParticipantValues(11)}}
				if family == "shares" {
					step.columns = models.ShareColumns
					step.values = [][]driver.Value{finalizationShareValues(30, []byte("[]"))}
				}
				ctx, cancel := context.WithCancel(context.Background())
				defer cancel()
				switch failure {
				case "query":
					step.queryErr = marker
				case "scan":
					step.values[0][0] = "-1" // Unsigned IDs must not wrap or truncate.
				case "iteration":
					step.nextErr = marker
				case "close":
					step.closeErr = marker
				case "cancel":
					step.cancel = cancel
				}
				db, script := finalizationScriptDB(t, step)
				var got any
				var err error
				if family == "participants" {
					got, err = readFinalizationParticipants(db.WithContext(ctx), []uint{1})
				} else {
					got, err = readFinalizationShares(db.WithContext(ctx), []uint{1})
				}
				if err == nil || !reflect.ValueOf(got).IsNil() {
					t.Fatalf("failure acknowledged partial rows: %v %v", got, err)
				}
				if failure != "scan" && failure != "cancel" && !errors.Is(err, marker) {
					t.Fatalf("original cause lost: %v", err)
				}
				if failure == "cancel" && !errors.Is(err, context.Canceled) {
					t.Fatalf("cancellation cause lost: %v", err)
				}
				script.mu.Lock()
				closed := step.closed
				script.mu.Unlock()
				wantClosed := 1
				if failure == "query" {
					wantClosed = 0
				}
				if closed != wantClosed {
					t.Fatalf("row stream not joined/closed: %d", closed)
				}
			})
		}
	}
}

func TestFinalizationRowsJSONAndDriverOwnership(t *testing.T) {
	for _, tc := range []struct {
		name string
		raw  driver.Value
		want []models.ItemDetail
	}{
		{"sql_null", nil, nil},
		{"json_null", []byte("null"), nil},
		{"empty", []byte("[]"), []models.ItemDetail{}},
		{"unknown_fields", []byte(`[{"name":"First 🧾","amount":0.25,"is_shared":true,"unknown":{"a":1}}]`), []models.ItemDetail{{Name: "First 🧾", Amount: .25, IsShared: true}}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			step := &finalizationRowScript{columns: models.ShareColumns, values: [][]driver.Value{finalizationShareValues(30, tc.raw)}, reuse: true}
			db, script := finalizationScriptDB(t, step)
			got, err := readFinalizationShares(db, []uint{1, 900})
			if err != nil || len(got) != 1 || !reflect.DeepEqual(got[0].Items, tc.want) || got[0].PersonName != "Raw label" || got[0].Paid {
				t.Fatalf("JSON/null/driver ownership changed: %+v %v", got, err)
			}
			if step.closed != 1 || len(script.queries) != 1 || !strings.Contains(script.queries[0], "ORDER BY id ASC FOR UPDATE") || !strings.Contains(script.queries[0], models.ShareColumns) || len(script.arguments[0]) != 2 {
				t.Fatal("complete scoped locked stream changed")
			}
		})
	}
	first := finalizationParticipantValues(11)
	second := finalizationParticipantValues(12)
	second[3], second[6], second[7] = []byte("Other"), int64(1), []byte("other-ref")
	step := &finalizationRowScript{columns: models.ParticipantColumns, values: [][]driver.Value{first, second}, reuse: true}
	db, _ := finalizationScriptDB(t, step)
	rows, err := readFinalizationParticipants(db, []uint{1})
	if err != nil || len(rows) != 2 || rows[0].Label != "Label" || rows[1].Label != "Other" || *rows[0].ClientRef != "local-ref" || *rows[1].ClientRef != "other-ref" {
		t.Fatalf("driver backing storage retained: %+v %v", rows, err)
	}
	rows[0].Label = "mutated"
	*rows[0].Ordinal = 99
	*rows[0].ClientRef = "mutated"
	if rows[1].Label != "Other" || *rows[1].Ordinal != 1 || *rows[1].ClientRef != "other-ref" {
		t.Fatal("fresh row backing storage aliases another row")
	}
}

func TestFinalizationRowsJSONAndCloseFailures(t *testing.T) {
	marker := errors.New("synthetic close failure")
	for _, raw := range []string{"{}", `[{"amount":1e999}]`, "["} {
		t.Run(raw, func(t *testing.T) {
			step := &finalizationRowScript{columns: models.ShareColumns, values: [][]driver.Value{finalizationShareValues(30, []byte(raw))}, closeErr: marker}
			db, _ := finalizationScriptDB(t, step)
			rows, err := readFinalizationShares(db, []uint{1})
			var syntax *json.SyntaxError
			var invalidType *json.UnmarshalTypeError
			if err == nil || rows != nil || !errors.Is(err, marker) || (!errors.As(err, &syntax) && !errors.As(err, &invalidType)) || step.closed != 1 {
				t.Fatalf("JSON/close cause or cleanup lost: %v", err)
			}
		})
	}
}

func TestFinalizationRowsRejectScalarOverflow(t *testing.T) {
	for _, tc := range []struct {
		name   string
		share  bool
		column int
		value  driver.Value
	}{
		{"participant_id", false, 0, "18446744073709551616"},
		{"participant_version", false, 5, int64(70000)},
		{"ordinal", false, 6, "9223372036854775808"},
		{"request_revision", false, 15, "9223372036854775808"},
		{"share_id", true, 0, "18446744073709551616"},
		{"share_version", true, 9, int64(70000)},
		{"share_participant_id", true, 10, "18446744073709551616"},
		{"share_subtotal", true, 4, "1e999"},
		{"share_paid", true, 8, "invalid-bool"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			step := &finalizationRowScript{columns: models.ParticipantColumns, values: [][]driver.Value{finalizationParticipantValues(11)}}
			if tc.share {
				step.columns = models.ShareColumns
				step.values = [][]driver.Value{finalizationShareValues(30, []byte("[]"))}
			}
			step.values[0][tc.column] = tc.value
			db, _ := finalizationScriptDB(t, step)
			var got any
			var err error
			if tc.share {
				got, err = readFinalizationShares(db, []uint{1})
			} else {
				got, err = readFinalizationParticipants(db, []uint{1})
			}
			if err == nil || !reflect.ValueOf(got).IsNil() || step.closed != 1 {
				t.Fatalf("invalid scalar truncated/coerced or stream retained: %v %v", got, err)
			}
		})
	}
}

func TestFinalizationRowsFailureRollsBack(t *testing.T) {
	for _, stage := range []string{"participant_iteration", "participant_close", "participant_cancel", "share_query", "share_iteration", "share_close", "share_json", "share_cancel"} {
		t.Run(stage, func(t *testing.T) {
			marker := errors.New("synthetic transaction row failure")
			queryContext, cancel := context.WithCancel(context.Background())
			defer cancel()
			p := &finalizationRowScript{columns: models.ParticipantColumns, values: [][]driver.Value{finalizationParticipantValues(11)}}
			s := &finalizationRowScript{columns: models.ShareColumns, values: [][]driver.Value{finalizationShareValues(30, []byte("[]"))}}
			switch stage {
			case "participant_iteration":
				p.nextErr = marker
			case "participant_close":
				p.closeErr = marker
			case "participant_cancel":
				p.cancel = cancel
			case "share_query":
				s.queryErr = marker
			case "share_iteration":
				s.nextErr = marker
			case "share_close":
				s.closeErr = marker
			case "share_json":
				s.values[0][3] = []byte("{}")
			case "share_cancel":
				s.cancel = cancel
			}
			db, script := finalizationScriptDB(t, p, s)
			bills := []models.Bill{{ID: 1}}
			err := db.Transaction(func(tx *gorm.DB) error {
				// Cancel only the query context: the surrounding transaction remains
				// live so the caller can witness closure before its own rollback.
				rows, err := loadFinalizationRows(tx.WithContext(queryContext), bills)
				if err == nil || rows != nil {
					t.Fatal("failed stream returned successful rows")
				}
				script.mu.Lock()
				closedBeforeRollback := p.closed == 1 && (stage != "share_cancel" || s.closed == 1)
				rollbackBeforeReturn := script.rollbacks != 0
				script.mu.Unlock()
				if strings.HasSuffix(stage, "_cancel") && (!closedBeforeRollback || rollbackBeforeReturn) {
					t.Fatal("canceled stream returned before closure or after transaction cleanup")
				}
				return err
			})
			if err == nil || script.commits != 0 || script.rollbacks != 1 || bills[0].ParticipantRows != nil || bills[0].PersonShares != nil {
				t.Fatalf("partial graph committed: commits=%d rollbacks=%d error=%v", script.commits, script.rollbacks, err)
			}
			if strings.HasSuffix(stage, "_cancel") && !errors.Is(err, context.Canceled) {
				t.Fatalf("transaction cancellation cause lost: %v", err)
			}
			if stage != "share_json" && !strings.HasSuffix(stage, "_cancel") && !errors.Is(err, marker) {
				t.Fatalf("original transaction cause lost: %v", err)
			}
		})
	}
}
