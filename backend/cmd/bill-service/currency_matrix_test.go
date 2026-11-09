package main

import (
	"backend/internal/exchange"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

// matrixMarket is a synthetic provider whose rates and availability the test
// moves between requests. Every upstream request is recorded.
type matrixMarket struct {
	mu     sync.Mutex
	rates  map[string]float64
	status int
	after  string
	calls  []string
}

func (m *matrixMarket) set(status int, after string, rates map[string]float64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.status, m.after = status, after
	if rates != nil {
		m.rates = rates
	}
}
func (m *matrixMarket) seen() []string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return append([]string(nil), m.calls...)
}
func (m *matrixMarket) serve(t *testing.T) *httptest.Server {
	t.Helper()
	up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		m.mu.Lock()
		defer m.mu.Unlock()
		pair := strings.TrimPrefix(r.URL.Path, "/rate/")
		m.calls = append(m.calls, pair)
		if m.status != 0 {
			w.Header().Set("Retry-After", m.after)
			w.WriteHeader(m.status)
			fmt.Fprint(w, "synthetic-private-error")
			return
		}
		rate, ok := m.rates[pair]
		base, quote, _ := strings.Cut(pair, "/")
		if !ok {
			w.WriteHeader(404)
			return
		}
		fmt.Fprintf(w, `{"date":%q,"base":%q,"quote":%q,"rate":%v}`, time.Now().UTC().Format(time.DateOnly), base, quote, rate)
	}))
	t.Cleanup(up.Close)
	return up
}

// One executable owner for the documented currency support matrix
// (docs/backend-api.md, "Currency support matrix"), through the production
// composition: one provider instance behind creation, USD preview and display.
func TestProductionCurrencySupportMatrix(t *testing.T) {
	today := time.Now().UTC().Format(time.DateOnly)
	rate := func(t *testing.T, w *httptest.ResponseRecorder) (float64, string) {
		t.Helper()
		var body struct {
			Rate   float64 `json:"rate"`
			Source string  `json:"source"`
		}
		if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
			t.Fatalf("rate body %s: %v", w.Body, err)
		}
		return body.Rate, body.Source
	}

	t.Run("native_usd_never_asks_the_provider", func(t *testing.T) {
		market := &matrixMarket{}
		repo := &compositionRepo{}
		router := compositionRouter(repo, exchange.NewClient(market.serve(t).URL))
		for _, body := range []string{`{"name":"Omitted","subtotal":10,"total":10}`, `{"name":"Explicit","subtotal":10,"total":10,"currency_code":" usd "}`} {
			if w := compositionRequest(router, "POST", "/api/bills", body); w.Code != 201 {
				t.Fatalf("create %d %s", w.Code, w.Body)
			}
		}
		for _, b := range repo.saved {
			if b.CurrencyCode != "USD" || b.Total != 10 || b.USDExchangeRate != 1 || b.USDTotal != 10 || b.ExchangeRateSource != "native-usd" || b.ExchangeRateDate != "" ||
				b.ExchangeRate != nil || b.DisplayTotal == nil || *b.DisplayTotal != 10 || b.DisplayRateSource == nil || *b.DisplayRateSource != "same_currency" || b.DisplayRateDate != nil || b.DisplayRateRetrievedAt != nil {
				t.Fatalf("native USD invented a market observation: %+v", b)
			}
		}
		w := compositionRequest(router, "GET", "/api/exchange-rates/usd", "")
		if value, source := rate(t, w); w.Code != 200 || value != 1 || source != "native-usd" {
			t.Fatalf("USD preview %d %s", w.Code, w.Body)
		}
		if calls := market.seen(); len(calls) != 0 {
			t.Fatalf("native USD reached the provider: %v", calls)
		}
	})

	t.Run("approved_foreign_receipt_freezes_one_dated_quote", func(t *testing.T) {
		// PEN is an approved receipt currency, not a display-only pair.
		market := &matrixMarket{rates: map[string]float64{"PEN/USD": .27}}
		repo := &compositionRepo{}
		router := compositionRouter(repo, exchange.NewClient(market.serve(t).URL))
		w := compositionRequest(router, "POST", "/api/bills", `{"name":"Lima","subtotal":20,"tax":2,"tip_amount":3,"total":25,"currency_code":"pen","display_currency":"USD"}`)
		if w.Code != 201 || len(repo.saved) != 1 {
			t.Fatalf("create %d %s", w.Code, w.Body)
		}
		b := repo.saved[0]
		if b.CurrencyCode != "PEN" || b.Total != 25 || b.Subtotal != 20 || b.Tax != 2 || b.TipAmount != 3 {
			t.Fatalf("original amounts changed: %+v", b)
		}
		if b.USDExchangeRate != .27 || b.USDTotal != 6.75 || b.ExchangeRateDate != today || b.ExchangeRateSource != "frankfurter-v2-blended" {
			t.Fatalf("frozen USD valuation: %+v", b)
		}
		if b.ExchangeRate == nil || *b.ExchangeRate != .27 || b.DisplayRateSource == nil || *b.DisplayRateSource != "frankfurter-v2-blended" || b.DisplayRateDate == nil || *b.DisplayRateDate != today {
			t.Fatalf("USD display did not reuse the accepted pair: %+v", b)
		}
		if calls := market.seen(); len(calls) != 1 || calls[0] != "PEN/USD" {
			t.Fatalf("calls=%v want one frozen pair", calls)
		}
	})

	t.Run("same_currency_is_identity_without_a_market_observation", func(t *testing.T) {
		market := &matrixMarket{rates: map[string]float64{"EUR/USD": 1.25}}
		repo := &compositionRepo{}
		router := compositionRouter(repo, exchange.NewClient(market.serve(t).URL))
		w := compositionRequest(router, "POST", "/api/bills", `{"name":"Paris","subtotal":20,"total":20,"currency_code":"EUR","display_currency":"eur"}`)
		if w.Code != 201 || len(repo.saved) != 1 {
			t.Fatalf("create %d %s", w.Code, w.Body)
		}
		b := repo.saved[0]
		if b.USDTotal != 25 || b.ExchangeRate != nil || b.DisplayTotal == nil || *b.DisplayTotal != 20 || b.DisplayRateSource == nil || *b.DisplayRateSource != "same_currency" || b.DisplayRateDate != nil || b.DisplayRateRetrievedAt != nil {
			t.Fatalf("same-currency display: %+v", b)
		}
		for _, pair := range []string{"from=eur&to=EUR", "from=USD&to=usd", "from=ZAR&to=ZAR"} {
			w := compositionRequest(router, "GET", "/api/currency/rate?"+pair, "")
			if value, source := rate(t, w); w.Code != 200 || value != 1 || source != "same_currency" {
				t.Fatalf("%s: %d %s", pair, w.Code, w.Body)
			}
		}
		if calls := market.seen(); len(calls) != 1 || calls[0] != "EUR/USD" {
			t.Fatalf("identity reached the provider: %v", calls)
		}
	})

	t.Run("display_pairs_are_wider_than_the_receipt_policy", func(t *testing.T) {
		market := &matrixMarket{rates: map[string]float64{"USD/ZAR": 18.4}}
		repo := &compositionRepo{}
		router := compositionRouter(repo, exchange.NewClient(market.serve(t).URL))
		// ZAR is a provider display pair. It is not an approved receipt currency.
		w := compositionRequest(router, "GET", "/api/currency/rate?from=USD&to=ZAR", "")
		if value, source := rate(t, w); w.Code != 200 || value != 18.4 || source != "frankfurter-v2-blended" {
			t.Fatalf("display %d %s", w.Code, w.Body)
		}
		before := len(market.seen())
		for _, request := range [][2]string{
			{"POST /api/bills", `{"name":"Unsupported","subtotal":10,"total":10,"currency_code":"ZAR"}`},
			{"POST /api/bills", `{"name":"Malformed display","subtotal":10,"total":10,"display_currency":"EURO"}`},
			{"GET /api/exchange-rates/ZAR", ""},
			{"GET /api/exchange-rates/EURO", ""},
		} {
			method, path, _ := strings.Cut(request[0], " ")
			if w := compositionRequest(router, method, path, request[1]); w.Code != 400 || !strings.Contains(w.Body.String(), "unsupported currency code") {
				t.Fatalf("%s: %d %s", request[0], w.Code, w.Body)
			}
		}
		// Malformed display codes fail closed as unavailable, never as rate 1.
		for _, pair := range []string{"from=US&to=USD", "from=USD&to=USDD", "from=U1D&to=USD", "from=&to=USD", "from=USD"} {
			w := compositionRequest(router, "GET", "/api/currency/rate?"+pair, "")
			if w.Code != 503 || strings.Contains(w.Body.String(), `"rate"`) {
				t.Fatalf("%s: %d %s", pair, w.Code, w.Body)
			}
		}
		if len(repo.saved) != 0 || len(market.seen()) != before {
			t.Fatalf("rejected codes saved=%d calls=%v", len(repo.saved), market.seen())
		}
	})

	t.Run("outage_is_never_answered_from_an_earlier_quote", func(t *testing.T) {
		market := &matrixMarket{rates: map[string]float64{"EUR/USD": 1.25}}
		repo := &compositionRepo{}
		router := compositionRouter(repo, exchange.NewClient(market.serve(t).URL))
		create := `{"name":"Paris","subtotal":20,"total":20,"currency_code":"EUR"}`
		for _, path := range []string{"/api/currency/rate?from=EUR&to=USD", "/api/exchange-rates/EUR"} {
			w := compositionRequest(router, "GET", path, "")
			if value, _ := rate(t, w); w.Code != 200 || value != 1.25 {
				t.Fatalf("healthy %s: %d %s", path, w.Code, w.Body)
			}
		}
		market.set(503, "30", nil)
		for _, request := range [][3]string{{"GET", "/api/currency/rate?from=EUR&to=USD", ""}, {"GET", "/api/exchange-rates/EUR", ""}, {"POST", "/api/bills", create}} {
			w := compositionRequest(router, request[0], request[1], request[2])
			if w.Code != 503 || w.Header().Get("Retry-After") != "30" || strings.Contains(w.Body.String(), "1.25") || strings.Contains(w.Body.String(), "private") {
				t.Fatalf("outage %s: %d %s %v", request[1], w.Code, w.Body, w.Header())
			}
		}
		if len(repo.saved) != 0 {
			t.Fatal("outage saved a receipt")
		}
		market.set(0, "", map[string]float64{"EUR/USD": 1.31})
		for _, path := range []string{"/api/currency/rate?from=EUR&to=USD", "/api/exchange-rates/EUR"} {
			w := compositionRequest(router, "GET", path, "")
			if value, _ := rate(t, w); w.Code != 200 || value != 1.31 {
				t.Fatalf("recovered %s: %d %s", path, w.Code, w.Body)
			}
		}
		if w := compositionRequest(router, "POST", "/api/bills", create); w.Code != 201 || len(repo.saved) != 1 || repo.saved[0].USDExchangeRate != 1.31 || repo.saved[0].USDTotal != 26.2 {
			t.Fatalf("recovered create %d %s", w.Code, w.Body)
		}
		// Eight requests, eight provider calls: no application cache in between.
		if calls := market.seen(); len(calls) != 8 {
			t.Fatalf("provider calls=%d %v", len(calls), calls)
		}
	})
}
