package bill

import (
	"backend/pkg/models"
	"backend/pkg/mutation"
	"errors"
	"math"
	"testing"
)

func TestFrozenUSDEvidenceAndConservation(t *testing.T) {
	for _, tc := range []struct {
		name    string
		b       models.Bill
		want    []int64
		invalid bool
	}{
		{"legacy USD", models.Bill{Total: 10, PersonShares: []models.PersonShare{{PersonName: "A", Total: 4}, {PersonName: "B", Total: 6}}}, []int64{400, 600}, false},
		{"partial foreign", models.Bill{Total: 80, CurrencyCode: "EUR", USDExchangeRate: 1.25, USDTotal: 100, ExchangeRateSource: "fixture", ExchangeRateDate: "2026-11-03", PersonShares: []models.PersonShare{{Total: 8}}}, []int64{1000}, false},
		{"foreign subcent", models.Bill{Total: .001, CurrencyCode: "EUR", USDExchangeRate: 1.25, USDTotal: 0, ExchangeRateSource: "fixture", ExchangeRateDate: "2026-11-03", PersonShares: []models.PersonShare{{Total: .001}}}, []int64{0}, false},
		{"tiny foreign zero birthday", models.Bill{Total: .004, CurrencyCode: "EUR", USDExchangeRate: 10, USDTotal: .04, ExchangeRateSource: "fixture", ExchangeRateDate: "2026-11-03", PersonShares: []models.PersonShare{{Total: 0}}}, []int64{0}, false},
		{"zero birthday", models.Bill{Total: 1, PersonShares: []models.PersonShare{{PersonName: "Birthday", Total: 0}, {PersonName: "A", Total: 1}}}, []int64{0, 100}, false},
		{"native frozen mismatch", models.Bill{Total: 10, USDTotal: 11}, nil, true},
		{"missing foreign source", models.Bill{Total: 10, CurrencyCode: "EUR", USDExchangeRate: 1.25, USDTotal: 12.5, ExchangeRateDate: "2026-11-03"}, nil, true},
		{"missing foreign date", models.Bill{Total: 10, CurrencyCode: "EUR", USDExchangeRate: 1.25, USDTotal: 12.5, ExchangeRateSource: "fixture"}, nil, true},
		{"bad quote", models.Bill{Total: 10, CurrencyCode: "EUR", USDExchangeRate: math.Inf(1)}, nil, true},
		{"negative share", models.Bill{Total: 10, PersonShares: []models.PersonShare{{Total: -1}}}, nil, true},
		{"NaN share", models.Bill{Total: 10, PersonShares: []models.PersonShare{{Total: math.NaN()}}}, nil, true},
		{"overflow", models.Bill{Total: float64(math.MaxInt64)}, nil, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			got, err := FrozenUSDShareCents(tc.b)
			if tc.invalid {
				if !errors.Is(err, mutation.Review) {
					t.Fatalf("invalid evidence accepted: %v", err)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			if len(got) != len(tc.want) {
				t.Fatal(got)
			}
			for i := range got {
				if got[i] != tc.want[i] {
					t.Fatalf("got %v want %v", got, tc.want)
				}
			}
		})
	}
	if _, err := AddObligationCents(math.MaxInt64, 1); !errors.Is(err, mutation.Review) {
		t.Fatal("aggregate overflow accepted")
	}
	if _, err := ObligationDollars(math.MaxInt64); !errors.Is(err, mutation.Review) {
		t.Fatal("unrepresentable stored cents accepted")
	}
}
