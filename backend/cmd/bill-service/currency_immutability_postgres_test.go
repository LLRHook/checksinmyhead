//go:build integration

package main

import (
	"backend/internal/bill"
	"backend/internal/exchange"
	"backend/internal/tab"
	"backend/internal/testpostgres"
	"backend/migrations"
	"backend/pkg/database"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"testing"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func marketRouter(t *testing.T, market *matrixMarket) (*gorm.DB, http.Handler) {
	t.Helper()
	t.Setenv("TRUSTED_PROXY_CIDRS", "")
	db := testpostgres.Open(t)
	state, err := migrations.Run(context.Background(), db, migrations.Apply)
	if err != nil {
		t.Fatal(err)
	}
	prior := log.Writer()
	log.SetOutput(&bytes.Buffer{})
	t.Cleanup(func() { log.SetOutput(prior) })
	g, err := gorm.Open(postgres.New(postgres.Config{Conn: db}), &gorm.Config{Logger: database.NewSQLLogger().LogMode(logger.Info)})
	if err != nil {
		t.Fatal(err)
	}
	b, c := newCurrencyHandlers(bill.NewBillRepository(g), exchange.NewClient(market.serve(t).URL))
	r, err := newRouter(b, c, tab.NewTabHandler(tab.NewTabService(tab.NewTabRepository(g))), nil, state)
	if err != nil {
		t.Fatal(err)
	}
	return g, r
}

// A saved foreign receipt keeps its original amounts and its dated frozen and
// display quotes while the market moves, the provider fails, the trip's display
// currency changes and the trip is finalized. Display conversion is answered
// live and writes nothing.
func TestPostgresDisplayConversionNeverRewritesFrozenQuote(t *testing.T) {
	market := &matrixMarket{rates: map[string]float64{"EUR/USD": 1.25, "EUR/ZAR": 20}}
	g, r := marketRouter(t, market)
	today := time.Now().UTC().Format(time.DateOnly)
	trip := identityNewTab(t, r, "Creator")
	created := identityRequest(t, r, "POST", "/api/bills", `{"name":"Paris","subtotal":20,"total":20,"currency_code":"EUR","display_currency":"ZAR","participants":[{"client_ref":"a","name":"Alex"}],"items":[{"name":"Meal","price":20,"assignments":[{"participant_ref":"a","percentage":100}]}]}`, "", "", "", 2, 201)
	var receipt identityReceipt
	if err := json.Unmarshal(created.Body.Bytes(), &receipt); err != nil || receipt.ID == 0 {
		t.Fatalf("create response: %v %s", err, created.Body)
	}
	identityAttach(t, r, trip, receipt, 0)

	evidence := func() string {
		t.Helper()
		var value string
		if err := g.Raw(`SELECT jsonb_build_object(
			'bill',(SELECT to_jsonb(b) FROM bills b WHERE b.id=@id),
			'items',(SELECT coalesce(jsonb_agg(to_jsonb(i) ORDER BY i.id),'[]') FROM bill_items i WHERE i.bill_id=@id),
			'shares',(SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY s.id),'[]') FROM person_shares s WHERE s.bill_id=@id))::text`, map[string]any{"id": receipt.ID}).Scan(&value).Error; err != nil {
			t.Fatal(err)
		}
		return value
	}
	type quoteFields struct {
		Currency     string   `json:"currency_code"`
		Total        float64  `json:"total"`
		Subtotal     float64  `json:"subtotal"`
		USDRate      float64  `json:"usd_exchange_rate"`
		USDTotal     float64  `json:"usd_total"`
		Date         string   `json:"exchange_rate_date"`
		Source       string   `json:"exchange_rate_source"`
		Display      string   `json:"display_currency"`
		DisplayRate  *float64 `json:"exchange_rate"`
		DisplayTotal *float64 `json:"display_total"`
		DisplayDate  *string  `json:"display_rate_date"`
		DisplayFrom  *string  `json:"display_rate_source"`
	}
	billPath := fmt.Sprintf("/api/bills/%d", receipt.ID)
	readBill := func() string {
		t.Helper()
		w := identityRequest(t, r, "GET", billPath, "", receipt.Token, "", "", 2, 200)
		var q quoteFields
		if err := json.Unmarshal(w.Body.Bytes(), &q); err != nil {
			t.Fatal(err)
		}
		if q.Currency != "EUR" || q.Total != 20 || q.Subtotal != 20 || q.USDRate != 1.25 || q.USDTotal != 25 || q.Date != today || q.Source != "frankfurter-v2-blended" ||
			q.Display != "ZAR" || q.DisplayRate == nil || *q.DisplayRate != 20 || q.DisplayTotal == nil || *q.DisplayTotal != 400 || q.DisplayDate == nil || *q.DisplayDate != today || q.DisplayFrom == nil || *q.DisplayFrom != "frankfurter-v2-blended" {
			t.Fatalf("receipt read lost its original amounts or quotes: %s", w.Body)
		}
		return w.Body.String()
	}
	before, firstRead := evidence(), readBill()
	if calls := market.seen(); len(calls) != 2 {
		t.Fatalf("creation calls=%v", calls)
	}

	// The market moves. Live display and preview follow it.
	market.set(0, "", map[string]float64{"EUR/USD": 1.31, "EUR/ZAR": 23, "USD/JPY": 150})
	for path, want := range map[string]float64{"/api/currency/rate?from=EUR&to=ZAR": 23, "/api/currency/rate?from=EUR&to=USD": 1.31, "/api/exchange-rates/EUR": 1.31} {
		w := identityRequest(t, r, "GET", path, "", "", "", "", 0, 200)
		var live struct {
			Rate float64 `json:"rate"`
		}
		if err := json.Unmarshal(w.Body.Bytes(), &live); err != nil || live.Rate != want {
			t.Fatalf("%s: live rate %v want %v (%v)", path, live.Rate, want, err)
		}
	}
	// The trip's display preference changes and is read back.
	tabPath := fmt.Sprintf("/api/tabs/%d", trip.ID)
	identityRequest(t, r, "PATCH", tabPath, `{"display_currency":"JPY"}`, trip.Token, trip.Member, "", 2, 200)
	identityRequest(t, r, "GET", tabPath, "", trip.Token, trip.Member, "", 2, 200)
	if readBill() != firstRead {
		t.Fatal("receipt read changed after display conversion")
	}
	// The provider fails. Display says so; saved receipts are still readable.
	market.set(503, "30", nil)
	if w := identityRequest(t, r, "GET", "/api/currency/rate?from=EUR&to=ZAR", "", "", "", "", 0, 503); w.Header().Get("Retry-After") != "30" {
		t.Fatalf("outage headers %v", w.Header())
	}
	if readBill() != firstRead {
		t.Fatal("receipt read changed during the outage")
	}
	identityRequest(t, r, "GET", tabPath, "", trip.Token, trip.Member, "", 2, 200)
	// Finalization settles on the frozen 25.00, not on any later rate.
	identityRequest(t, r, "POST", tabPath+"/finalize", "", trip.Token, trip.Member, "", 2, 200)
	var amounts []float64
	if err := g.Raw("SELECT amount FROM tab_settlements WHERE tab_id = ? ORDER BY id", trip.ID).Scan(&amounts).Error; err != nil {
		t.Fatal(err)
	}
	if len(amounts) != 1 || amounts[0] != 25 {
		t.Fatalf("settlement used a later rate: %v", amounts)
	}
	if readBill() != firstRead {
		t.Fatal("receipt read changed after finalization")
	}

	if evidence() != before {
		t.Fatal("display conversion, reads or finalization rewrote the stored receipt")
	}
	// Two creation quotes, three live requests, one failed request. Nothing else.
	if calls := market.seen(); len(calls) != 6 {
		t.Fatalf("provider calls=%d %v", len(calls), calls)
	}
}
