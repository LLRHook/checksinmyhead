package bill

import (
	"backend/pkg/models"
	"context"
	"encoding/json"
	"errors"
	"math"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

// These finite, bounded inputs exercise tolerance amplification without the extreme
// denominator that previously allowed unbounded remainder work.
func unsafeToleranceBills() map[string]*models.Bill {
	return map[string]*models.Bill{
		"aggregate_obligations": {Name: "Synthetic", Subtotal: 1e9, Tax: .005, Total: 1e9, Items: []models.BillItem{{Name: "Item", Price: 1e9, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 50}, {PersonName: "Blair", Percentage: 50}}}}},
		"cent_amplification":    {Name: "Synthetic", LazyMode: true, Subtotal: .01, Tax: 1, Total: 1.01, Items: []models.BillItem{{Name: "Item", Price: .02, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}}}},
		"near_zero":             {Name: "Synthetic", LazyMode: true, Subtotal: 1e-12, Tax: 1, Total: 1.000000000001, Items: []models.BillItem{{Name: "Item", Price: 1e-6, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}}}},
	}
}

func TestCreationRejectsToleranceAmplificationBeforeProviders(t *testing.T) {
	for name, b := range unsafeToleranceBills() {
		t.Run(name, func(t *testing.T) {
			repo := newMockRepo()
			provider := &fakeExchangeRateProvider{}
			b.CurrencyCode = "EUR"
			err := NewBillService(repo, provider).CreateBill(context.Background(), b)
			if !errors.Is(err, ErrInvalidCreation) || provider.calls != 0 || len(repo.bills) != 0 {
				t.Fatalf("err=%v provider_calls=%d persisted=%d shares=%+v", err, provider.calls, len(repo.bills), b.PersonShares)
			}
		})
	}
}

func TestCreationDisplayProviderFailureRetainsPENContract(t *testing.T) {
	repo := newMockRepo()
	h := NewBillHandler(NewBillService(repo, &fakeExchangeRateProvider{}))
	w := httptest.NewRecorder()
	ctx, _ := gin.CreateTestContext(w)
	ctx.Request = httptest.NewRequest("POST", "/api/bills", strings.NewReader(`{"name":"Synthetic","subtotal":10,"total":10,"currency_code":"USD","display_currency":"PEN"}`))
	h.CreateBill(ctx)
	if w.Code != 503 || len(repo.bills) != 0 {
		t.Fatalf("status=%d persisted=%d", w.Code, len(repo.bills))
	}
}

func TestCreationToleranceHTTPBeforeProviders(t *testing.T) {
	for name, b := range unsafeToleranceBills() {
		t.Run(name, func(t *testing.T) {
			// Models include privileged fields, so marshal only the public content.
			body := map[string]any{"name": b.Name, "subtotal": b.Subtotal, "tax": b.Tax, "total": b.Total, "lazy_mode": b.LazyMode, "currency_code": "EUR", "items": []any{map[string]any{"name": "Item", "price": b.Items[0].Price, "assignments": []any{map[string]any{"person_name": "Alex", "percentage": 100}}}}}
			data, err := json.Marshal(body)
			if err != nil {
				t.Fatal(err)
			}
			repo := newMockRepo()
			provider := &fakeExchangeRateProvider{}
			h := NewBillHandler(NewBillService(repo, provider))
			w := httptest.NewRecorder()
			ctx, _ := gin.CreateTestContext(w)
			ctx.Request = httptest.NewRequest("POST", "/api/bills", strings.NewReader(string(data)))
			h.CreateBill(ctx)
			if w.Code != 400 || provider.calls != 0 || len(repo.bills) != 0 {
				t.Fatalf("status=%d calls=%d persisted=%d", w.Code, provider.calls, len(repo.bills))
			}
		})
	}
}

type fakeDisplayRates struct {
	calls    int
	from, to string
	value    float64
	err      error
}

func (f *fakeDisplayRates) Latest(_ context.Context, from, to string) (models.ExchangeRateQuote, error) {
	f.calls++
	f.from = from
	f.to = to
	return models.ExchangeRateQuote{Base: from, Quote: to, Rate: f.value, Source: "synthetic-display", Date: time.Now().UTC().Format(time.DateOnly)}, f.err
}

func TestCreationAllMobileDisplayChoicesAndProviderDefinedPair(t *testing.T) {
	// ZAR demonstrates that the twelve receipt/selector codes do not restrict
	// provider-defined display pairs.
	for _, code := range []string{"USD", "EUR", "GBP", "CAD", "JPY", "MXN", "PEN", "AUD", "BRL", "CNY", "INR", "CHF", "ZAR"} {
		t.Run(code, func(t *testing.T) {
			repo := newMockRepo()
			rates := &fakeDisplayRates{value: 2.5}
			h := NewBillHandler(NewBillService(repo, rates))
			w := httptest.NewRecorder()
			ctx, _ := gin.CreateTestContext(w)
			ctx.Request = httptest.NewRequest("POST", "/api/bills", strings.NewReader(`{"name":"Synthetic","subtotal":10,"total":10,"currency_code":"USD","display_currency":" `+strings.ToLower(code)+` "}`))
			h.CreateBill(ctx)
			if w.Code != 201 || len(repo.bills) != 1 {
				t.Fatalf("status=%d persisted=%d", w.Code, len(repo.bills))
			}
			for _, b := range repo.bills {
				wantTotal := 25.0
				wantCalls := 1
				if code == "USD" {
					wantTotal = 10
					wantCalls = 0
				}
				if rates.calls != wantCalls || b.DisplayCurrency != code || b.DisplayTotal == nil || *b.DisplayTotal != wantTotal || b.USDTotal != 10 || b.USDExchangeRate != 1 || b.CurrencyCode != "USD" {
					t.Fatalf("calls=%d native/frozen/display accounting=%+v", rates.calls, b)
				}
				if wantCalls == 1 && (rates.from != "USD" || rates.to != code || b.ExchangeRate == nil || *b.ExchangeRate != 2.5) {
					t.Fatal("display provider pair not used")
				}
			}
		})
	}
}

func TestCreationDisplayFailureAndInvalidMoneyNeverPersist(t *testing.T) {
	for _, tc := range []struct {
		name string
		rate float64
		err  error
	}{
		{"offline", 0, errors.New("synthetic offline")}, {"zero", 0, nil}, {"negative", -1, nil}, {"nan", math.NaN(), nil}, {"inf", math.Inf(1), nil}, {"overflow", math.MaxFloat64, nil},
	} {
		t.Run(tc.name, func(t *testing.T) {
			repo := newMockRepo()
			rates := &fakeDisplayRates{value: tc.rate, err: tc.err}
			h := NewBillHandler(NewBillService(repo, rates))
			w := httptest.NewRecorder()
			ctx, _ := gin.CreateTestContext(w)
			ctx.Request = httptest.NewRequest("POST", "/api/bills", strings.NewReader(`{"name":"Synthetic","subtotal":10,"total":10,"display_currency":"PEN"}`))
			h.CreateBill(ctx)
			if w.Code != 503 || rates.calls != 1 || len(repo.bills) != 0 {
				t.Fatalf("status=%d calls=%d persisted=%d", w.Code, rates.calls, len(repo.bills))
			}
		})
	}
	for name, b := range unsafeToleranceBills() {
		t.Run("invalid_before_display/"+name, func(t *testing.T) {
			repo := newMockRepo()
			rates := &fakeDisplayRates{value: 2.5}
			h := NewBillHandler(NewBillService(repo, rates))
			b.DisplayCurrency = "PEN"
			// Exercise the same service operation used by the HTTP handler.
			err := h.service.CreateBill(context.Background(), b)
			if !errors.Is(err, ErrInvalidCreation) || rates.calls != 0 || len(repo.bills) != 0 {
				t.Fatalf("err=%v calls=%d persisted=%d", err, rates.calls, len(repo.bills))
			}
		})
	}
}

func TestCreationExtremeArithmeticRejectedBeforeAllocation(t *testing.T) {
	extreme := &models.Bill{Subtotal: 1e-300, Tax: 1e9, Total: 1e9, LazyMode: true, Items: []models.BillItem{
		{Name: "Large ratio", Price: .005, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}},
		{Name: "Tiny", Price: 1e-300, Assignments: []models.ItemAssignment{{PersonName: "Blair", Percentage: 100}}},
	}}
	for name, b := range map[string]*models.Bill{"extreme": extreme, "aggregate": unsafeToleranceBills()["aggregate_obligations"]} {
		t.Run(name, func(t *testing.T) {
			// Pure raw calculation only: never send the extreme input over HTTP,
			// nor feed its overflowing values to the historical unchecked allocator.
			if _, err := calculatePersonShares(b, b.LazyMode); !errors.Is(err, ErrInvalidCreation) {
				t.Fatalf("unsafe raw arithmetic accepted: %v", err)
			}
		})
	}
}

func TestRoundedCentsRejectsNonfiniteAndUnrepresentableValues(t *testing.T) {
	for _, amount := range []float64{math.NaN(), math.Inf(1), math.Inf(-1), math.MaxFloat64, float64(math.MaxInt64) / 100, -math.MaxFloat64} {
		if _, err := roundedCents(amount); !errors.Is(err, ErrInvalidCreation) {
			t.Errorf("unsafe cent conversion accepted: %v", err)
		}
	}
	if _, err := allocateRoundedCents(map[string]float64{"Alex": math.MaxFloat64}, nil); !errors.Is(err, ErrInvalidCreation) {
		t.Fatal("allocator did not reject unsafe cents")
	}
}

func TestCentRemaindersPreserveClaimAndNameOrder(t *testing.T) {
	now := time.Date(2026, 11, 2, 0, 0, 0, 0, time.UTC)
	for _, tc := range []struct {
		name   string
		raw    map[string]float64
		claims map[string]time.Time
		want   map[string]float64
	}{
		{"positive_name", map[string]float64{"Alex": .004, "Blair": .004}, nil, map[string]float64{"Alex": .01, "Blair": 0}},
		{"negative_name", map[string]float64{"Alex": .005, "Blair": .005}, nil, map[string]float64{"Alex": 0, "Blair": .01}},
		{"positive_recent", map[string]float64{"Alex": .004, "Blair": .004}, map[string]time.Time{"Blair": now}, map[string]float64{"Alex": 0, "Blair": .01}},
		{"negative_recent", map[string]float64{"Alex": .005, "Blair": .005}, map[string]time.Time{"Blair": now}, map[string]float64{"Alex": .01, "Blair": 0}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			got, err := allocateRoundedCents(tc.raw, tc.claims)
			if err != nil || !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("got=%v err=%v want=%v", got, err, tc.want)
			}
		})
	}
}

func TestRemainderDistributionIsBoundedForExtremeCounts(t *testing.T) {
	for _, tc := range []struct {
		name      string
		remaining int64
		want      []int64
	}{
		{"positive", 100_000_000_001, []int64{33_333_333_334, 33_333_333_334, 33_333_333_333}},
		{"negative", -100_000_000_001, []int64{-33_333_333_334, -33_333_333_334, -33_333_333_333}},
		{"min_int64", math.MinInt64, []int64{-3_074_457_345_618_258_603, -3_074_457_345_618_258_603, -3_074_457_345_618_258_602}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			// Pure bounded distribution: never run these counts through the old loop.
			shares := []roundedShare{{key: "Alex"}, {key: "Blair"}, {key: "Casey"}}
			if err := distributeRemainder(shares, tc.remaining); err != nil {
				t.Fatal(err)
			}
			for i, share := range shares {
				if share.cents != tc.want[i] {
					t.Errorf("%s cents=%d want=%d", share.key, share.cents, tc.want[i])
				}
			}
		})
	}
	if _, err := allocateRoundedCents(map[string]float64{"Alex": 6e16, "Blair": 6e16}, nil); !errors.Is(err, ErrInvalidCreation) {
		t.Fatal("cent aggregate overflow accepted")
	}
}
