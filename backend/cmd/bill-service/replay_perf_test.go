//go:build integration && replayperf

package main

import (
	"backend/internal/bill"
	"backend/internal/exchange"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/http/httptrace"
	"os"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
)

type replayStatement struct {
	SQL     string `json:"sql"`
	Control bool   `json:"control"`
	Error   bool   `json:"error"`
	Nanos   int64  `json:"nanos"`
}
type replayMeasureTrace struct {
	enabled          atomic.Bool
	mu               sync.Mutex
	statements       []replayStatement
	transactionStart time.Time
	locked           time.Duration
}
type replayTraceStart struct {
	start time.Time
	sql   string
}

func (q *replayMeasureTrace) TraceQueryStart(ctx context.Context, _ *pgx.Conn, d pgx.TraceQueryStartData) context.Context {
	if !q.enabled.Load() {
		return ctx
	}
	return context.WithValue(ctx, replayTraceStart{}, replayTraceStart{time.Now(), d.SQL})
}
func (q *replayMeasureTrace) TraceQueryEnd(ctx context.Context, _ *pgx.Conn, d pgx.TraceQueryEndData) {
	v, ok := ctx.Value(replayTraceStart{}).(replayTraceStart)
	if !ok {
		return
	}
	fields := strings.Fields(v.sql)
	if len(fields) == 0 {
		return
	}
	word := strings.ToUpper(fields[0])
	control := word == "BEGIN" || word == "COMMIT" || word == "ROLLBACK" || word == "SAVEPOINT" || word == "RELEASE"
	q.mu.Lock()
	defer q.mu.Unlock()
	if word == "BEGIN" {
		q.transactionStart = v.start
	}
	if (word == "COMMIT" || word == "ROLLBACK") && !q.transactionStart.IsZero() {
		q.locked += time.Since(q.transactionStart)
		q.transactionStart = time.Time{}
	}
	q.statements = append(q.statements, replayStatement{v.sql, control, d.Err != nil, time.Since(v.start).Nanoseconds()})
}
func (q *replayMeasureTrace) reset() {
	q.mu.Lock()
	q.statements = nil
	q.locked = 0
	q.transactionStart = time.Time{}
	q.mu.Unlock()
}
func (q *replayMeasureTrace) result() ([]replayStatement, time.Duration) {
	q.mu.Lock()
	defer q.mu.Unlock()
	return append([]replayStatement(nil), q.statements...), q.locked
}

type replayObservation struct {
	TotalNS, ProviderNS, ApplicationNS, TransactionHeldNS int64
	AllocatedBytes, Allocations                           uint64
	Data, Control, TotalStatements, ProviderCalls         int
	Statements                                            []replayStatement
}
type replayMeasurement struct {
	Volume, Path                                                    string
	Run, Items, People, Assignments, BodyBytes, DataTarget, DataCap int
	Observations                                                    []replayObservation
}

// This optional harness is executed only in a root-activated quiet window. It
// records each observation, including conflicts/errors, without budget changes.
func TestReplayCreationMeasurements(t *testing.T) {
	output := os.Getenv("REPLAY_MEASURE_OUTPUT")
	if output == "" {
		t.Fatal("explicit owned measurement output required")
	}
	var rows []replayMeasurement
	for _, size := range []struct {
		name                                string
		items, people, perItem, target, cap int
	}{{"representative", 40, 8, 8, 7, 12}, {"maximum", 500, 100, 10, 16, 20}} {
		for _, foreign := range []bool{false, true} {
			t.Run(fmt.Sprintf("%s/foreign=%v", size.name, foreign), func(t *testing.T) {
				q := &replayMeasureTrace{}
				sqlDB := testpostgresOpenReplayMeasure(t, q)
				g := replayMeasureGorm(t, sqlDB)
				var calls atomic.Int64
				up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					calls.Add(1)
					pair := strings.Split(r.URL.Path, "/")
					quote := "USD"
					rate := 1.25
					if len(pair) == 4 && pair[3] == "ZAR" {
						quote = "ZAR"
						rate = 21.12345
					}
					fmt.Fprintf(w, `{"date":%q,"base":"EUR","quote":%q,"rate":%v}`, time.Now().UTC().Format(time.DateOnly), quote, rate)
				}))
				defer up.Close()
				router := compositionRouter(bill.NewBillRepository(g), exchange.NewClient(up.URL))
				body := currencyVolumeBody(t, size.items, size.people, size.perItem, foreign)
				if len(body) >= 1<<20 {
					t.Fatal("maximum creation body exceeds approved1MiB")
				}
				keyFor := func(s string) string {
					v := sha256.Sum256([]byte(s))
					return base64.RawURLEncoding.EncodeToString(v[:])
				}
				establishedKey := keyFor(size.name + fmt.Sprint(foreign))
				established := func(key, content string) *httptest.ResponseRecorder {
					request := httptest.NewRequest("POST", "/api/bills", strings.NewReader(content))
					request.Header.Set("Idempotency-Key", key)
					w := httptest.NewRecorder()
					router.ServeHTTP(w, request)
					return w
				}
				first := established(establishedKey, body)
				if first.Code != 201 {
					t.Fatal("establish replay", first.Code)
				}
				for _, path := range []string{"keyed_create", "established_replay", "content_conflict", "invalid_dto"} {
					want := 201
					target, cap := size.target, size.cap
					switch path {
					case "established_replay":
						target, cap = 1, 2
					case "content_conflict":
						want, target, cap = 409, 1, 2
					case "invalid_dto":
						want, target, cap = 400, 0, 0
					}
					for run := 1; run <= 3; run++ {
						row := replayMeasurement{Volume: size.name, Path: fmt.Sprintf("%s/foreign=%v", path, foreign), Run: run, Items: size.items, People: size.people, Assignments: size.items * size.perItem, BodyBytes: len(body), DataTarget: target, DataCap: cap}
						for sample := 0; sample < 100; sample++ {
							key, content := establishedKey, body
							if path == "keyed_create" {
								key = keyFor(fmt.Sprintf("%s/%v/%d/%d", size.name, foreign, run, sample))
							}
							if path == "content_conflict" {
								content = strings.Replace(body, "Synthetic volume", "Changed volume", 1)
							}
							if path == "invalid_dto" {
								content = strings.TrimSuffix(body, "}") + `,"access_token":null}`
							}
							var wrote time.Time
							var provider time.Duration
							trace := &httptrace.ClientTrace{WroteRequest: func(httptrace.WroteRequestInfo) { wrote = time.Now() }, GotFirstResponseByte: func() { provider += time.Since(wrote) }}
							request := httptest.NewRequest("POST", "/api/bills", strings.NewReader(content))
							request.Header.Set("Idempotency-Key", key)
							request = request.WithContext(httptrace.WithClientTrace(request.Context(), trace))
							w := httptest.NewRecorder()
							q.reset()
							n := calls.Load()
							var before, after runtime.MemStats
							runtime.ReadMemStats(&before)
							q.enabled.Store(true)
							start := time.Now()
							router.ServeHTTP(w, request)
							elapsed := time.Since(start)
							q.enabled.Store(false)
							runtime.ReadMemStats(&after)
							statements, locked := q.result()
							data, control := 0, 0
							for _, s := range statements {
								if s.Control {
									control++
								} else {
									data++
								}
							}
							observation := replayObservation{TotalNS: elapsed.Nanoseconds(), ProviderNS: provider.Nanoseconds(), ApplicationNS: (elapsed - provider).Nanoseconds(), TransactionHeldNS: locked.Nanoseconds(), AllocatedBytes: after.TotalAlloc - before.TotalAlloc, Allocations: after.Mallocs - before.Mallocs, Data: data, Control: control, TotalStatements: len(statements), ProviderCalls: int(calls.Load() - n), Statements: statements}
							row.Observations = append(row.Observations, observation)
							if w.Code != want {
								t.Fatalf("path%s status%d want%d", path, w.Code, want)
							}
							if path == "established_replay" && w.Body.String() != first.Body.String() {
								t.Fatal("measured recovery identity changed")
							}
							expectedCalls := 0
							if foreign && path == "keyed_create" {
								expectedCalls = 2
							}
							if observation.ProviderCalls != expectedCalls {
								t.Fatal("measured provider work escaped path")
							}
							if path == "established_replay" {
								for _, s := range statements {
									if !strings.HasPrefix(strings.ToUpper(strings.TrimSpace(s.SQL)), "SELECT") || !strings.Contains(s.SQL, "creation_key_digest") {
										t.Fatal("measured established replay is not indexed scalar-only")
									}
								}
							}
						}
						rows = append(rows, row)
						bytes, err := json.MarshalIndent(rows, "", "  ")
						if err != nil {
							t.Fatal(err)
						}
						if err := os.WriteFile(output, append(bytes, '\n'), 0600); err != nil {
							t.Fatal(err)
						}
					}
				}
				decoded, err := base64.RawURLEncoding.DecodeString(establishedKey)
				if err != nil {
					t.Fatal(err)
				}
				digest := sha256.Sum256(decoded)
				var plan string
				if err := sqlDB.QueryRow("EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) SELECT id,access_token,currency_code,usd_exchange_rate,usd_total,exchange_rate_date,exchange_rate_source,creation_fingerprint,creation_fingerprint_version FROM bills WHERE creation_key_digest=$1 LIMIT 1", digest[:]).Scan(&plan); err != nil {
					t.Fatal(err)
				}
				plan = strings.ReplaceAll(plan, hex.EncodeToString(digest[:]), "<digest>")
				if err := os.WriteFile(fmt.Sprintf("%s.%s.%v.plan.json", output, size.name, foreign), []byte(plan), 0600); err != nil {
					t.Fatal(err)
				}

			})
		}
	}
}
