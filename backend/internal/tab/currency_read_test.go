package tab

import (
	"backend/pkg/models"
	"backend/pkg/mutation"
	"errors"
	"testing"
)

func TestGetTabFrozenUSDReadContract(t *testing.T) {
	display := func(v float64) *float64 { return &v }
	quoted := func(code string, total, rate, usd float64, shown *float64) models.Bill {
		return models.Bill{CurrencyCode: code, Total: total, USDExchangeRate: rate,
			USDTotal: usd, DisplayTotal: shown, ExchangeRateSource: "saved-quote",
			ExchangeRateDate: "2001-01-01", AccessToken: "synthetic-source"}
	}
	for _, tc := range []struct {
		name   string
		bill   models.Bill
		want   float64
		review bool
	}{
		{"foreign_rounded_zero_native_display", quoted("PEN", .01, .27, 0, display(.01)), 0, false},
		{"foreign_rounded_zero_other_display", quoted("PEN", .01, .27, 0, display(.4)), 0, false},
		{"legacy_usd_uses_native_identity", models.Bill{Total: 10, DisplayCurrency: "EUR", DisplayTotal: display(8)}, 10, false},
		{"ordinary_frozen_foreign", quoted("EUR", 20, 1.25, 25, display(20)), 25, false},
		{"known_native_zero", models.Bill{CurrencyCode: "USD", USDExchangeRate: 1, ExchangeRateSource: "native-usd", DisplayTotal: display(0)}, 0, false},
		{"foreign_missing_audit", models.Bill{CurrencyCode: "PEN", Total: 10, USDExchangeRate: .27, DisplayTotal: display(10)}, 0, true},
		{"foreign_sql_default_is_not_identity", models.Bill{CurrencyCode: "PEN", Total: 10, USDExchangeRate: 1, USDTotal: 10}, 0, true},
		{"explicit_usd_zero_cannot_be_legacy_unset", models.Bill{CurrencyCode: "USD", Total: 10, USDExchangeRate: 1, ExchangeRateSource: "native-usd"}, 0, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			repo := newMockRepo()
			repo.tabs[1] = &models.Tab{ID: 1, Bills: []models.Bill{tc.bill}}
			got, err := NewTabService(repo).GetTab(1)
			if tc.review {
				if !errors.Is(err, mutation.Review) {
					t.Fatalf("unavailable frozen USD requires review, got tab=%+v err=%v", got, err)
				}
				return
			}
			if err != nil || got.TotalAmount != tc.want {
				t.Fatalf("tab USD total=%v err=%v; want %.2f", got, err, tc.want)
			}
			if got.Bills[0].AccessToken != "" {
				t.Fatal("tab read disclosed source capability")
			}
		})
	}
}
