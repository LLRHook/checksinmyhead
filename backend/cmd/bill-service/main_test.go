package main

import (
	"backend/internal/bill"
	"backend/internal/exchange"
	"backend/pkg/models"
	"context"
	"encoding/json"
	"fmt"
	"github.com/gin-gonic/gin"
	"math"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"
)

type compositionRepo struct {
	bill.BillRepository
	saved []*models.Bill
}

func (r *compositionRepo) Create(_ context.Context, c bill.CreationInsert) (bill.CreationRecord, error) {
	b := c.Bill
	b.ID = uint(len(r.saved) + 1)
	r.saved = append(r.saved, b)
	return bill.CreationRecord{Result: bill.CreateBillResult{BillID: b.ID, AccessToken: b.AccessToken, CurrencyCode: b.CurrencyCode, USDExchangeRate: b.USDExchangeRate, USDTotal: b.USDTotal, ExchangeRateDate: b.ExchangeRateDate, ExchangeRateSource: b.ExchangeRateSource}}, nil
}
func (r *compositionRepo) LookupCreation(context.Context, [32]byte) (*bill.CreationRecord, error) {
	return nil, nil
}

func (r *compositionRepo) GetById(id uint) (*models.Bill, error) {
	for _, b := range r.saved {
		if b.ID == id {
			v := *b
			return &v, nil
		}
	}
	return nil, fmt.Errorf("synthetic missing bill")
}
func compositionRouter(repo bill.BillRepository, client *exchange.Client) *gin.Engine {
	gin.SetMode(gin.TestMode)
	b, c := newCurrencyHandlers(repo, client)
	r := gin.New()
	r.POST("/api/bills", b.CreateBill)
	r.GET("/api/bills/:id", b.GetBill)
	r.GET("/api/exchange-rates/:currency", b.GetExchangeRate)
	r.GET("/api/currency/rate", c.GetRate)
	return r
}
func compositionRequest(r http.Handler, method, path, body string) *httptest.ResponseRecorder {
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(method, path, strings.NewReader(body)))
	return w
}

type receiptFixture struct {
	Code string  `json:"code"`
	Rate float64 `json:"usd_rate"`
}

func receiptFixtures(t *testing.T) []receiptFixture {
	t.Helper()
	data, err := os.ReadFile("../../internal/currency/testdata/receipts.json")
	if err != nil {
		t.Fatal(err)
	}
	var result []receiptFixture
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatal(err)
	}
	return result
}
func TestProductionCurrencyComposition(t *testing.T) {
	for _, fixture := range receiptFixtures(t) {
		t.Run(fixture.Code, func(t *testing.T) {
			var paths []string
			upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				paths = append(paths, r.URL.Path)
				if r.URL.Path != "/rate/"+fixture.Code+"/USD" {
					t.Errorf("wrong upstream pair %s", r.URL)
				}
				fmt.Fprintf(w, `{"date":%q,"base":%q,"quote":"USD","rate":%v}`, time.Now().UTC().Format(time.DateOnly), fixture.Code, fixture.Rate)
			}))
			defer upstream.Close()
			repo := &compositionRepo{}
			router := compositionRouter(repo, exchange.NewClient(upstream.URL))
			w := compositionRequest(router, "GET", "/api/exchange-rates/"+fixture.Code, "")
			if w.Code != 200 {
				t.Fatalf("preview %d %s", w.Code, w.Body)
			}
			w = compositionRequest(router, "POST", "/api/bills", fmt.Sprintf(`{"name":"Synthetic","subtotal":20,"tax":2,"tip_amount":3,"total":25,"currency_code":%q,"display_currency":"USD"}`, fixture.Code))
			if w.Code != 201 || len(repo.saved) != 1 {
				t.Fatalf("create %d %s saved=%d", w.Code, w.Body, len(repo.saved))
			}
			b := repo.saved[0]
			want := math.Round(25*fixture.Rate*100) / 100
			if b.CurrencyCode != fixture.Code || b.Total != 25 || b.USDExchangeRate != fixture.Rate || b.USDTotal != want || b.DisplayTotal == nil || *b.DisplayTotal != 25*fixture.Rate {
				t.Fatalf("incorrect native/frozen/display %+v", b)
			}
			count := 2
			if fixture.Code == "USD" {
				count = 0
				if b.ExchangeRateDate != "" || b.ExchangeRateSource != "native-usd" {
					t.Fatalf("invented native market quote %+v", b)
				}
			} else if b.ExchangeRateDate != time.Now().UTC().Format(time.DateOnly) || b.ExchangeRateSource != "frankfurter-v2-blended" {
				t.Fatalf("lost provenance %+v", b)
			}
			if len(paths) != count {
				t.Fatalf("calls=%v want %d (preview and create independently; frozen/display USD reused)", paths, count)
			}
		})
	}
	t.Run("omitted_USD", func(t *testing.T) {
		repo := &compositionRepo{}
		up := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { t.Error("native upstream call") }))
		defer up.Close()
		w := compositionRequest(compositionRouter(repo, exchange.NewClient(up.URL)), "POST", "/api/bills", `{"name":"Legacy","subtotal":10,"total":10}`)
		if w.Code != 201 || repo.saved[0].CurrencyCode != "USD" {
			t.Fatalf("legacy control %d", w.Code)
		}
	})
}
func TestProductionDisplayHasIndependentPairAndSourceOwnership(t *testing.T) {
	var paths []string
	day := time.Now().UTC().Format(time.DateOnly)
	displayDay := time.Now().UTC().AddDate(0, 0, -2).Format(time.DateOnly)
	up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		paths = append(paths, r.URL.Path)
		switch r.URL.Path {
		case "/rate/EUR/USD":
			fmt.Fprintf(w, `{"date":%q,"base":"EUR","quote":"USD","rate":1.25}`, day)
		case "/rate/EUR/ZAR":
			fmt.Fprintf(w, `{"date":%q,"base":"EUR","quote":"ZAR","rate":21.12345}`, displayDay)
		default:
			t.Errorf("unexpected %s", r.URL)
			w.WriteHeader(404)
		}
	}))
	defer up.Close()
	repo := &compositionRepo{}
	router := compositionRouter(repo, exchange.NewClient(up.URL))
	w := compositionRequest(router, "POST", "/api/bills", `{"name":"Synthetic","subtotal":20,"total":20,"currency_code":"EUR","display_currency":"ZAR"}`)
	if w.Code != 201 || len(repo.saved) != 1 {
		t.Fatalf("create %d %s", w.Code, w.Body)
	}
	b := repo.saved[0]
	if b.ExchangeRateDate != day || b.ExchangeRateSource != "frankfurter-v2-blended" || b.USDTotal != 25 || b.ExchangeRate == nil || *b.ExchangeRate != 21.12345 || b.DisplayTotal == nil || math.Abs(*b.DisplayTotal-20*21.12345) > 1e-9 {
		t.Fatalf("ownership %+v", b)
	}
	if strings.Join(paths, ",") != "/rate/EUR/USD,/rate/EUR/ZAR" {
		t.Fatalf("calls=%v", paths)
	}
	w = compositionRequest(router, "GET", "/api/currency/rate?from=eur&to=zar", "")
	var rate struct {
		Rate      float64   `json:"rate"`
		Source    string    `json:"source"`
		UpdatedAt time.Time `json:"updated_at"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &rate); err != nil {
		t.Fatal(err)
	}
	if w.Code != 200 || rate.Rate != 21.12345 || rate.Source != "frankfurter-v2-blended" || rate.UpdatedAt.Format(time.DateOnly) != displayDay || rate.UpdatedAt.Hour() != 0 {
		t.Fatalf("display compatibility %d %s", w.Code, w.Body)
	}
}
func TestProductionQuoteFailuresNeverPersistOrLeak(t *testing.T) {
	for _, tc := range []struct {
		name, body, after string
		status            int
	}{
		{"wrong_pair", `{"date":"2026-11-03","base":"GBP","quote":"USD","rate":1.25}`, "", 200},
		{"malformed", "synthetic-private-error", "", 200}, {"too_many", `{} {}`, "", 200}, {"oversize", strings.Repeat("x", 65537), "", 200},
		{"quota", "synthetic-private-error", "120", 429}, {"unavailable", "synthetic-private-error", "Wed, 04 Nov 2026 12:00:00 GMT", 503},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var calls int
			up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				calls++
				w.Header().Set("Retry-After", tc.after)
				w.WriteHeader(tc.status)
				fmt.Fprint(w, tc.body)
			}))
			defer up.Close()
			repo := &compositionRepo{}
			router := compositionRouter(repo, exchange.NewClient(up.URL))
			for _, route := range []string{"create", "preview", "display"} {
				var w *httptest.ResponseRecorder
				switch route {
				case "create":
					w = compositionRequest(router, "POST", "/api/bills", `{"name":"Synthetic","subtotal":20,"total":20,"currency_code":"EUR"}`)
				case "preview":
					w = compositionRequest(router, "GET", "/api/exchange-rates/EUR", "")
				case "display":
					w = compositionRequest(router, "GET", "/api/currency/rate?from=EUR&to=USD", "")
				}
				if w.Code != 503 || len(repo.saved) != 0 || len(w.Body.Bytes()) > 256 || strings.Contains(w.Body.String(), "private") || w.Header().Get("Retry-After") != tc.after {
					t.Fatalf("route=%s status=%d body=%s headers=%v", route, w.Code, w.Body, w.Header())
				}
			}
			if calls != 3 {
				t.Fatalf("hidden retries calls=%d", calls)
			}
		})
	}
}
func TestProductionDisplayFailureNeverUsesIdentity(t *testing.T) {
	var paths []string
	up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		paths = append(paths, r.URL.Path)
		if strings.HasSuffix(r.URL.Path, "/USD") {
			fmt.Fprintf(w, `{"date":%q,"base":"EUR","quote":"USD","rate":1.25}`, time.Now().UTC().Format(time.DateOnly))
			return
		}
		w.Header().Set("Retry-After", "90")
		w.WriteHeader(503)
	}))
	defer up.Close()
	repo := &compositionRepo{}
	w := compositionRequest(compositionRouter(repo, exchange.NewClient(up.URL)), "POST", "/api/bills", `{"name":"Synthetic","subtotal":20,"total":20,"currency_code":"EUR","display_currency":"ZAR"}`)
	if w.Code != 503 || len(repo.saved) != 0 || w.Header().Get("Retry-After") != "90" || len(paths) != 2 {
		t.Fatalf("display failure %d %s calls=%v", w.Code, w.Body, paths)
	}
}
func TestProductionHistoricalAndZeroQuotesAreNeverRefetched(t *testing.T) {
	repo := &compositionRepo{saved: []*models.Bill{
		{ID: 1, AccessToken: "synthetic", CurrencyCode: "EUR", Total: .001, USDExchangeRate: .27, USDTotal: 0, ExchangeRateDate: "2001-01-01", ExchangeRateSource: "accepted-historical", DisplayCurrency: "JPY"},
		{ID: 2, AccessToken: "synthetic", CurrencyCode: "PEN", Total: 20, USDExchangeRate: .27391825, USDTotal: 5.48, ExchangeRateDate: "2001-01-02", ExchangeRateSource: "accepted-historical"},
		{ID: 3, AccessToken: "synthetic", CurrencyCode: "USD", Total: 0, USDExchangeRate: 1, USDTotal: 0, ExchangeRateSource: "native-usd"},
	}}
	up := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { t.Error("historical provider call") }))
	defer up.Close()
	router := compositionRouter(repo, exchange.NewClient(up.URL))
	for _, saved := range repo.saved {
		w := compositionRequest(router, "GET", fmt.Sprintf("/api/bills/%d?t=synthetic", saved.ID), "")
		var got models.Bill
		if err := json.Unmarshal(w.Body.Bytes(), &got); err != nil {
			t.Fatal(err)
		}
		if w.Code != 200 || got.USDTotal != saved.USDTotal || got.USDExchangeRate != saved.USDExchangeRate || got.Total != saved.Total || got.ExchangeRateDate != saved.ExchangeRateDate || got.ExchangeRateSource != saved.ExchangeRateSource {
			t.Fatalf("historical changed status=%d got=%+v original=%+v", w.Code, got, saved)
		}
	}
}
func TestProductionSharedProviderBudget(t *testing.T) {
	var mu sync.Mutex
	var paths []string
	up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		paths = append(paths, r.URL.Path)
		mu.Unlock()
		if strings.HasSuffix(r.URL.Path, "/USD") {
			select {
			case <-time.After(2600 * time.Millisecond):
				fmt.Fprintf(w, `{"date":%q,"base":"EUR","quote":"USD","rate":1.25}`, time.Now().UTC().Format(time.DateOnly))
			case <-r.Context().Done():
			}
			return
		}
		<-r.Context().Done()
	}))
	defer up.Close()
	repo := &compositionRepo{}
	started := time.Now()
	w := compositionRequest(compositionRouter(repo, exchange.NewClient(up.URL)), "POST", "/api/bills", `{"name":"Synthetic","subtotal":20,"total":20,"currency_code":"EUR","display_currency":"ZAR"}`)
	elapsed := time.Since(started)
	mu.Lock()
	defer mu.Unlock()
	if w.Code != 503 || len(repo.saved) != 0 || elapsed > 5500*time.Millisecond || len(paths) != 2 {
		t.Fatalf("shared deadline elapsed=%s status=%d calls=%v", elapsed, w.Code, paths)
	}
}
func TestProductionCallerCancellation(t *testing.T) {
	up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { <-r.Context().Done() }))
	defer up.Close()
	for _, path := range []string{"/api/exchange-rates/EUR", "/api/currency/rate?from=EUR&to=ZAR", "/api/bills"} {
		repo := &compositionRepo{}
		r := compositionRouter(repo, exchange.NewClient(up.URL))
		ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
		method, body := "GET", ""
		if path == "/api/bills" {
			method = "POST"
			body = `{"name":"Synthetic","subtotal":20,"total":20,"currency_code":"EUR"}`
		}
		req := httptest.NewRequest(method, path, strings.NewReader(body)).WithContext(ctx)
		w := httptest.NewRecorder()
		started := time.Now()
		r.ServeHTTP(w, req)
		cancel()
		if w.Code != 503 || len(repo.saved) != 0 || time.Since(started) > time.Second {
			t.Fatalf("cancellation %s status=%d", path, w.Code)
		}
	}
}
