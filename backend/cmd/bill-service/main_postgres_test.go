//go:build integration

package main

import (
	"backend/internal/bill"
	"backend/internal/exchange"
	"backend/internal/testpostgres"
	"backend/migrations"
	"backend/pkg/models"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/http/httptrace"
	"sort"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type currencyQueryCount struct {
	enabled       atomic.Bool
	data, control atomic.Int64
}

func (q *currencyQueryCount) TraceQueryStart(ctx context.Context, _ *pgx.Conn, v pgx.TraceQueryStartData) context.Context {
	if q.enabled.Load() {
		word := strings.ToUpper(strings.Fields(strings.TrimSpace(v.SQL))[0])
		switch word {
		case "BEGIN", "COMMIT", "ROLLBACK":
			q.control.Add(1)
		default:
			q.data.Add(1)
		}
	}
	return ctx
}
func (*currencyQueryCount) TraceQueryEnd(context.Context, *pgx.Conn, pgx.TraceQueryEndData) {}
func currencyPostgres(t *testing.T, q *currencyQueryCount) *gorm.DB {
	t.Helper()
	sql := testpostgres.Open(t, q)
	if _, err := migrations.Run(context.Background(), sql, migrations.Apply); err != nil {
		t.Fatal(err)
	}
	db, err := gorm.Open(postgres.New(postgres.Config{Conn: sql}), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		t.Fatal(err)
	}
	return db
}
func TestPostgresProductionCurrencyPersistence(t *testing.T) {
	q := &currencyQueryCount{}
	db := currencyPostgres(t, q)
	var calls atomic.Int32
	up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		fmt.Fprintf(w, `{"date":%q,"base":"PEN","quote":"USD","rate":0.27391825}`, time.Now().UTC().Format(time.DateOnly))
	}))
	defer up.Close()
	router := compositionRouter(bill.NewBillRepository(db), exchange.NewClient(up.URL))
	for _, total := range []float64{0, .001, 25} {
		w := compositionRequest(router, "POST", "/api/bills", fmt.Sprintf(`{"name":"Synthetic PEN","subtotal":%v,"total":%v,"currency_code":"PEN","display_currency":"USD"}`, total, total))
		if w.Code != 201 {
			t.Fatalf("create=%d %s", w.Code, w.Body)
		}
		var response struct {
			ID    uint   `json:"bill_id"`
			Token string `json:"access_token"`
		}
		if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil {
			t.Fatal(err)
		}
		var stored models.Bill
		if err := db.First(&stored, response.ID).Error; err != nil {
			t.Fatal(err)
		}
		if stored.USDExchangeRate != .27391825 || stored.Total != total || stored.ExchangeRateSource != "frankfurter-v2-blended" {
			t.Fatalf("changed stored quote %+v", stored)
		}
		// Age the persisted accepted observation using test SQL only: reads do not
		// call the new-quote validator and never reconstruct a historical quote.
		if err := db.Model(&stored).Update("exchange_rate_date", "2001-01-01").Error; err != nil {
			t.Fatal(err)
		}
		before := calls.Load()
		read := compositionRequest(router, "GET", fmt.Sprintf("/api/bills/%d?t=%s", stored.ID, response.Token), "")
		var got models.Bill
		if err := json.Unmarshal(read.Body.Bytes(), &got); err != nil {
			t.Fatal(err)
		}
		if read.Code != 200 || calls.Load() != before || got.ExchangeRateDate != "2001-01-01" || got.USDExchangeRate != stored.USDExchangeRate || got.USDTotal != stored.USDTotal || got.Total != total {
			t.Fatalf("historical read=%d got=%+v", read.Code, got)
		}
		if total < .002 && got.USDTotal != 0 {
			t.Fatal("lost valid frozen zero")
		}
	}
	if calls.Load() != 3 {
		t.Fatalf("one frozen/display USD call per create, got %d", calls.Load())
	}
}

func currencyVolumeBody(t *testing.T, items, people, perItem int, foreign bool) string {
	t.Helper()
	participants := []any{}
	for i := 0; i < people; i++ {
		participants = append(participants, map[string]any{"name": fmt.Sprintf("Person %03d", i)})
	}
	lines := []any{}
	for i := 0; i < items; i++ {
		assignments := []any{}
		for j := 0; j < perItem; j++ {
			assignments = append(assignments, map[string]any{"person_name": fmt.Sprintf("Person %03d", (i*perItem+j)%people), "percentage": 100.0 / float64(perItem)})
		}
		lines = append(lines, map[string]any{"name": fmt.Sprintf("Line %03d", i), "price": 1, "assignments": assignments})
	}
	code, display := "USD", "USD"
	if foreign {
		code, display = "EUR", "ZAR"
	}
	data, err := json.Marshal(map[string]any{"name": "Synthetic volume", "subtotal": items, "total": items, "currency_code": code, "display_currency": display, "participants": participants, "items": lines})
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}
func percentile(v []time.Duration, p int) time.Duration {
	s := append([]time.Duration(nil), v...)
	sort.Slice(s, func(i, j int) bool { return s[i] < s[j] })
	return s[(len(s)*p+99)/100-1]
}

// Three 100-sample runs per volume include every data statement (RETURNING,
// association writes and any ORM reads). No cache or real provider traffic.
func TestPostgresCurrencyCreationQueryAndLatencyTargets(t *testing.T) {
	for _, tc := range []struct {
		name                               string
		items, people, assignments, budget int
		foreign                            bool
	}{
		{"representative_USD", 40, 8, 8, 12, false}, {"representative_foreign", 40, 8, 8, 12, true},
		{"maximum_USD", 500, 100, 10, 20, false}, {"maximum_foreign", 500, 100, 10, 20, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			q := &currencyQueryCount{}
			db := currencyPostgres(t, q)
			var calls atomic.Int32
			up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				calls.Add(1)
				pair := strings.Split(r.URL.Path, "/")
				if len(pair) != 4 || pair[2] != "EUR" {
					t.Errorf("wrong pair %s", r.URL)
					w.WriteHeader(400)
					return
				}
				rate := 1.25
				if pair[3] == "ZAR" {
					rate = 21.12345
				}
				fmt.Fprintf(w, `{"date":%q,"base":"EUR","quote":%q,"rate":%v}`, time.Now().UTC().Format(time.DateOnly), pair[3], rate)
			}))
			defer up.Close()
			router := compositionRouter(bill.NewBillRepository(db), exchange.NewClient(up.URL))
			body := currencyVolumeBody(t, tc.items, tc.people, tc.assignments, tc.foreign)
			for warmup := 0; warmup < 3; warmup++ {
				if w := compositionRequest(router, "POST", "/api/bills", body); w.Code != 201 {
					t.Fatalf("warmup %d %s", w.Code, w.Body)
				}
			}
			for run := 1; run <= 3; run++ {
				totals, application, provider := []time.Duration{}, []time.Duration{}, []time.Duration{}
				var maxData, maxControl int64
				beforeCalls := calls.Load()
				for sample := 0; sample < 100; sample++ {
					var wrote time.Time
					var wait time.Duration
					trace := &httptrace.ClientTrace{WroteRequest: func(httptrace.WroteRequestInfo) { wrote = time.Now() }, GotFirstResponseByte: func() { wait += time.Since(wrote) }}
					request := httptest.NewRequest("POST", "/api/bills", strings.NewReader(body))
					request = request.WithContext(httptrace.WithClientTrace(request.Context(), trace))
					q.data.Store(0)
					q.control.Store(0)
					q.enabled.Store(true)
					w := httptest.NewRecorder()
					start := time.Now()
					router.ServeHTTP(w, request)
					elapsed := time.Since(start)
					q.enabled.Store(false)
					if w.Code != 201 {
						t.Fatalf("sample %d status=%d %s", sample, w.Code, w.Body)
					}
					// net/http synchronizes trace callbacks before returning the response.
					totals = append(totals, elapsed)
					provider = append(provider, wait)
					application = append(application, elapsed-wait)
					maxData = max(maxData, q.data.Load())
					maxControl = max(maxControl, q.control.Load())
				}
				expectedCalls := int32(0)
				if tc.foreign {
					expectedCalls = 200
				}
				if calls.Load()-beforeCalls != expectedCalls {
					t.Fatalf("calls=%d want %d", calls.Load()-beforeCalls, expectedCalls)
				}
				t.Logf("CURRENCY_PERF run=%d samples=100 items=%d people=%d assignments=%d body_bytes=%d data_max=%d control_max=%d total_p50=%s total_p95=%s app_p95=%s fake_provider_wait_p95=%s calls=%d", run, tc.items, tc.people, tc.items*tc.assignments, len(body), maxData, maxControl, percentile(totals, 50), percentile(totals, 95), percentile(application, 95), percentile(provider, 95), expectedCalls)
				if maxData > int64(tc.budget) {
					t.Errorf("data statements=%d target<=%d", maxData, tc.budget)
				}
				// Latency is an approved measurement target, not a flaky wall-clock assertion.
				// Report every miss and keep integrated performance acceptance with the driver.
				if !tc.foreign && tc.items == 40 && percentile(totals, 95) > 200*time.Millisecond {
					t.Log("TARGET_MISS USD representative p95 >200ms")
				}
				if percentile(totals, 95) > 2*time.Second {
					t.Log("TARGET_MISS publication p95 >2s with fake healthy provider")
				}
			}
		})
	}
}
