//go:build integration

package tab

import (
	"backend/pkg/models"
	"context"
	"encoding/json"
	"fmt"
	"math"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

type currencyReadQuote struct{ calls atomic.Int32 }

func (q *currencyReadQuote) Latest(_ context.Context, base, quote string) (models.ExchangeRateQuote, error) {
	q.calls.Add(1)
	rates := map[string]float64{"PEN/USD": .27, "PEN/JPY": 40, "USD/EUR": .8, "EUR/USD": 1.25}
	rate, ok := rates[base+"/"+quote]
	if !ok {
		return models.ExchangeRateQuote{}, fmt.Errorf("unexpected synthetic pair")
	}
	return models.ExchangeRateQuote{RetrievedAt: quoteReceiptTime(), Base: base, Quote: quote, Rate: rate,
		Date: time.Now().UTC().Format(time.DateOnly), Source: "synthetic-read-proof"}, nil
}

func TestPostgresCurrencyBillTabAndFinalizationAgree(t *testing.T) {
	for _, tc := range []struct {
		name, code, display string
		native, usd         float64
		legacy              bool
	}{
		{"foreign_zero_native_display", "PEN", "PEN", .01, 0, false},
		{"foreign_zero_other_display", "PEN", "JPY", .01, 0, false},
		{"legacy_omitted_usd", "USD", "EUR", 10, 10, true},
		{"ordinary_foreign", "EUR", "EUR", 20, 25, false},
		{"native_zero", "USD", "USD", 0, 0, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			db := authorizationPostgres(t)
			quote := &currencyReadQuote{}
			r := authorizationRouter(db, quote)
			h := NewTabHandler(NewTabService(NewTabRepository(db)))
			r.POST("/api/tabs/:id/finalize", h.FinalizeTab)
			dst := models.Tab{Name: "Synthetic currency trip", AccessToken: "synthetic-tab"}
			saveAuthFixture(t, db, &dst)
			body := fmt.Sprintf(`{"name":"Synthetic receipt","subtotal":%v,"total":%v,"currency_code":%q,"display_currency":%q,"participants":[{"name":"Alex"},{"name":"Birthday"}],"items":[{"name":"Unit","price":%v,"assignments":[{"person_name":"Alex","percentage":100}]}]}`, tc.native, tc.native, tc.code, tc.display, tc.native)
			created := authRequest(r, "POST", "/api/bills", body, "", "")
			if created.Code != 201 {
				t.Fatalf("create=%d %s", created.Code, created.Body)
			}
			var receipt struct {
				ID    uint   `json:"bill_id"`
				Token string `json:"access_token"`
			}
			if err := json.Unmarshal(created.Body.Bytes(), &receipt); err != nil {
				t.Fatal(err)
			}
			if tc.legacy {
				if err := db.Table("bills").Where("id = ?", receipt.ID).Updates(map[string]any{"currency_code": "", "usd_total": 0, "exchange_rate_source": "", "exchange_rate_date": ""}).Error; err != nil {
					t.Fatal(err)
				}
			} else if tc.code != "USD" {
				if err := db.Table("bills").Where("id = ?", receipt.ID).Update("exchange_rate_date", "2001-01-01").Error; err != nil {
					t.Fatal(err)
				}
			}
			attached := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/bills", dst.ID), fmt.Sprintf(`{"bill_id":%d,"bill_token":%q}`, receipt.ID, receipt.Token), dst.AccessToken, "")
			if attached.Code != 200 {
				t.Fatalf("attach=%d %s", attached.Code, attached.Body)
			}
			storedBill := func() string {
				var value string
				if err := db.Raw("SELECT row_to_json(b)::text FROM bills b WHERE id = ?", receipt.ID).Scan(&value).Error; err != nil {
					t.Fatal(err)
				}
				return value
			}
			before, calls := storedBill(), quote.calls.Load()
			billRead := authRequest(r, "GET", fmt.Sprintf("/api/bills/%d", receipt.ID), "", receipt.Token, "")
			var bill models.Bill
			if err := json.Unmarshal(billRead.Body.Bytes(), &bill); err != nil {
				t.Fatal(err)
			}
			if billRead.Code != 200 || bill.USDTotal != tc.usd || bill.Total != tc.native {
				t.Errorf("bill read=%d bill=%+v", billRead.Code, bill)
			}
			for _, finalized := range []bool{false, true} {
				if finalized {
					first := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", dst.ID), "", dst.AccessToken, "")
					retry := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", dst.ID), "", dst.AccessToken, "")
					if first.Code != 200 || retry.Code != 200 || first.Body.String() != retry.Body.String() {
						t.Fatalf("finalize/retry=%d/%d %s", first.Code, retry.Code, first.Body)
					}
					var rows []models.TabSettlement
					if err := json.Unmarshal(first.Body.Bytes(), &rows); err != nil {
						t.Fatal(err)
					}
					seen := map[string]float64{}
					for _, row := range rows {
						seen[row.PersonName] = row.Amount
					}
					alex, hasAlex := seen["Alex"]
					birthday, hasBirthday := seen["Birthday"]
					if len(rows) != 2 || !hasAlex || !hasBirthday || alex != tc.usd || birthday != 0 {
						t.Errorf("per-person settlement=%+v; want Alex %.2f, Birthday0", rows, tc.usd)
					}
				}
				read := authRequest(r, "GET", fmt.Sprintf("/api/tabs/%d", dst.ID), "", dst.AccessToken, "")
				var trip models.Tab
				if err := json.Unmarshal(read.Body.Bytes(), &trip); err != nil {
					t.Fatal(err)
				}
				if read.Code != 200 || trip.TotalAmount != tc.usd || len(trip.Bills) != 1 || trip.Bills[0].USDTotal != tc.usd {
					t.Errorf("finalized=%v tab read=%d total %.2f bills=%+v; want USD %.2f", finalized, read.Code, trip.TotalAmount, trip.Bills, tc.usd)
				}
				if strings.Contains(read.Body.String(), receipt.Token) || strings.Contains(read.Body.String(), dst.AccessToken) {
					t.Error("tab read disclosed capability")
				}
			}
			if quote.calls.Load() != calls || storedBill() != before {
				t.Error("reads/finalization refetched or rewrote immutable bill evidence")
			}
			if !tc.legacy && math.Abs(bill.USDExchangeRate*tc.native*100-math.Round(tc.usd*100)) >= .5 {
				t.Error("fixture frozen cent rounding is inconsistent")
			}
		})
	}
}

func TestPostgresCurrencyUnavailableSummaryIsAuthorizedReview(t *testing.T) {
	db := authorizationPostgres(t)
	quote := &currencyReadQuote{}
	r := authorizationRouter(db, quote)
	h := NewTabHandler(NewTabService(NewTabRepository(db)))
	r.POST("/api/tabs/:id/finalize", h.FinalizeTab)
	dst := models.Tab{Name: "Synthetic review trip", AccessToken: "synthetic-tab"}
	saveAuthFixture(t, db, &dst)
	b := models.Bill{Name: "Legacy foreign", AccessToken: "synthetic-source", TabID: &dst.ID, CurrencyCode: "PEN", Total: 10, Subtotal: 10, USDExchangeRate: 1,
		PersonShares: []models.PersonShare{{PersonName: "Alex", Subtotal: 10, Total: 10}}}
	saveAuthFixture(t, db, &b)
	before := lifecycleSnapshot(t, db)
	for _, token := range []string{"", "wrong", dst.AccessToken} {
		got := authRequest(r, "GET", fmt.Sprintf("/api/tabs/%d", dst.ID), "", token, "")
		want := 403
		if token == dst.AccessToken {
			want = 409
		}
		if got.Code != want {
			t.Errorf("summary token=%q status=%d want=%d body=%s", token, got.Code, want, got.Body)
		}
		if token == dst.AccessToken && !strings.Contains(got.Body.String(), `"accounting_review_required"`) {
			t.Error("missing finite accounting-review code")
		}
		if strings.Contains(got.Body.String(), b.AccessToken) || strings.Contains(got.Body.String(), dst.AccessToken) {
			t.Error("review response disclosed capability")
		}
	}
	finalized := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/finalize", dst.ID), "", dst.AccessToken, "")
	if finalized.Code != 409 || quote.calls.Load() != 0 || lifecycleSnapshot(t, db) != before {
		t.Error("unavailable review must neither finalize, fetch a quote, nor rewrite raw history")
	}
}
