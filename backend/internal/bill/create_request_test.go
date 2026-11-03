package bill

import (
	"backend/pkg/models"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/gin-gonic/gin"
	"math"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestCreateBillRejectsInvalidAccountingBeforeProvidersOrWrites(t *testing.T) {
	valid := func() map[string]any {
		return map[string]any{"name": "Positive", "subtotal": 10, "total": 10, "currency_code": "EUR"}
	}
	tests := map[string]func(map[string]any){
		"negative_subtotal": func(b map[string]any) { b["subtotal"] = -10 },
		"negative_tax":      func(b map[string]any) { b["tax"] = -1; b["total"] = 9 },
		"negative_tip":      func(b map[string]any) { b["tip_amount"] = -1; b["total"] = 9 },
		"negative_total":    func(b map[string]any) { b["total"] = -1 },
		"negative_share":    func(b map[string]any) { b["person_shares"] = []any{map[string]any{"person_name": "Alex", "total": -1}} },
		"missing_subtotal":  func(b map[string]any) { delete(b, "subtotal") },
		"null_subtotal":     func(b map[string]any) { b["subtotal"] = nil },
		"null_total":        func(b map[string]any) { b["total"] = nil },
		"missing_name":      func(b map[string]any) { delete(b, "name") },
		"wrong_type":        func(b map[string]any) { b["subtotal"] = "10" },
		"mismatch_total":    func(b map[string]any) { b["total"] = 12 },
		"mismatch_items":    func(b map[string]any) { b["items"] = []any{map[string]any{"name": "Dinner", "price": 9}} },
		"too_large_money":   func(b map[string]any) { b["subtotal"] = 1e9 + 1; b["total"] = 1e9 + 1 },
		"absolute_sum": func(b map[string]any) {
			b["items"] = []any{map[string]any{"name": "Large", "price": 1e9}, map[string]any{"name": "Discount", "price": -1e9 + 10}}
		},
		"name_bound": func(b map[string]any) { b["name"] = strings.Repeat("x", 256) },
		"participant_duplicate": func(b map[string]any) {
			b["participants"] = []any{map[string]any{"name": "Alex"}, map[string]any{"name": " alex "}}
		},
		"share_duplicate": func(b map[string]any) {
			b["person_shares"] = []any{map[string]any{"person_name": "Alex", "total": 5}, map[string]any{"person_name": " alex ", "total": 5}}
		},
		"share_mismatch": func(b map[string]any) { b["person_shares"] = []any{map[string]any{"person_name": "Alex", "total": 8}} },
	}
	tests["discount_allocation_exceeds_receipt"] = func(b map[string]any) {
		b["items"] = []any{map[string]any{"name": "Dinner", "price": 20, "assignments": []any{map[string]any{"person_name": "Alex", "percentage": 100}}}, map[string]any{"name": "Unclaimed discount", "price": -10}}
	}
	for _, percentage := range []float64{0, -1, 101} {
		p := percentage
		tests[fmt.Sprintf("percentage_%v", p)] = func(b map[string]any) {
			b["items"] = []any{map[string]any{"name": "Dinner", "price": 10, "assignments": []any{map[string]any{"person_name": "Alex", "percentage": p}}}}
		}
	}
	tests["percentage_sum"] = func(b map[string]any) {
		b["items"] = []any{map[string]any{"name": "Dinner", "price": 10, "assignments": []any{map[string]any{"person_name": "Alex", "percentage": 60}, map[string]any{"person_name": "Sam", "percentage": 60}}}}
	}
	tests["assignment_duplicate"] = func(b map[string]any) {
		b["items"] = []any{map[string]any{"name": "Dinner", "price": 10, "assignments": []any{map[string]any{"person_name": "Alex", "percentage": 50}, map[string]any{"person_name": " alex ", "percentage": 50}}}}
	}
	tests["negative_person_obligation"] = func(b map[string]any) {
		b["items"] = []any{map[string]any{"name": "Dinner", "price": 20, "assignments": []any{map[string]any{"person_name": "Alex", "percentage": 100}}}, map[string]any{"name": "Discount", "price": -10, "assignments": []any{map[string]any{"person_name": "Sam", "percentage": 100}}}}
	}
	for _, kind := range []string{"items", "participants", "person_shares", "payment_methods"} {
		kind := kind
		tests["collection_"+kind] = func(b map[string]any) {
			limit := 101
			var value any = map[string]any{"name": "Alex"}
			switch kind {
			case "items":
				limit = 501
				value = map[string]any{"name": "Dinner", "price": 0}
			case "person_shares":
				value = map[string]any{"person_name": "Alex"}
			case "payment_methods":
				limit = 11
				value = map[string]any{"name": "Venmo", "identifier": "@synthetic"}
			}
			values := make([]any, limit)
			for i := range values {
				values[i] = value
			}
			b[kind] = values
		}
	}
	for name, mutate := range tests {
		t.Run(name, func(t *testing.T) {
			repo := newMockRepo()
			provider := &fakeExchangeRateProvider{}
			h := NewBillHandler(NewBillService(repo, provider))
			b := valid()
			mutate(b)
			data, _ := json.Marshal(b)
			w := httptest.NewRecorder()
			ctx, _ := gin.CreateTestContext(w)
			ctx.Request = httptest.NewRequest("POST", "/api/bills", strings.NewReader(string(data)))
			h.CreateBill(ctx)
			if w.Code != 400 || provider.calls != 0 || len(repo.bills) != 0 {
				t.Fatalf("status=%d provider=%d writes=%d", w.Code, provider.calls, len(repo.bills))
			}
		})
	}
	for _, body := range []string{`{"name":"X","subtotal":NaN,"total":10}`, `{"name":"X","subtotal":Infinity,"total":10}`, `{"name":"X","subtotal":1e309,"total":10}`, `{"name":"X","subtotal":10,"total":10}{}`, `null`, `{`, strings.Repeat(" ", 1<<20) + `{}`} {
		t.Run("decode_"+fmt.Sprint(len(body)), func(t *testing.T) {
			w := httptest.NewRecorder()
			request := httptest.NewRequest("POST", "/", strings.NewReader(body))
			if _, err := decodeCreateBill(w, request); err == nil {
				t.Fatal("invalid document accepted")
			}
		})
	}
}

func TestCreateBillDirectServiceAndRepositoryGuards(t *testing.T) {
	for _, tc := range []struct {
		name   string
		mutate func(*models.Bill)
	}{
		{"tab", func(b *models.Bill) { id := uint(1); b.TabID = &id }},
		{"tab_graph", func(b *models.Bill) { b.Tab = &models.Tab{ID: 1} }},
		{"attribution", func(b *models.Bill) { id := uint(1); b.AddedByMemberID = &id }},
		{"payer", func(b *models.Bill) { id := uint(1); b.PaidByMemberID = &id }},
		{"bill_id", func(b *models.Bill) { b.ID = 1 }},
		{"participant_id", func(b *models.Bill) { b.Participants = []models.Person{{ID: 1, Name: "Alex"}} }},
		{"item_id", func(b *models.Bill) { b.Items = []models.BillItem{{ID: 1, Name: "Dinner", Price: 10}} }},
		{"item_fk", func(b *models.Bill) { b.Items = []models.BillItem{{BillID: 1, Name: "Dinner", Price: 10}} }},
		{"assignment_id", func(b *models.Bill) {
			b.Items = []models.BillItem{{Name: "Dinner", Price: 10, Assignments: []models.ItemAssignment{{ID: 1, PersonName: "Alex", Percentage: 100}}}}
		}},
		{"assignment_fk", func(b *models.Bill) {
			b.Items = []models.BillItem{{Name: "Dinner", Price: 10, Assignments: []models.ItemAssignment{{BillItemID: 1, PersonName: "Alex", Percentage: 100}}}}
		}},
		{"share_id", func(b *models.Bill) { b.PersonShares = []models.PersonShare{{ID: 1, PersonName: "Alex", Total: 10}} }},
		{"share_fk", func(b *models.Bill) {
			b.PersonShares = []models.PersonShare{{BillID: 1, PersonName: "Alex", Total: 10}}
		}},
		{"paid", func(b *models.Bill) {
			b.PersonShares = []models.PersonShare{{Paid: true, PersonName: "Alex", Total: 10}}
		}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			b := &models.Bill{Name: "Positive", Subtotal: 10, Total: 10, CurrencyCode: "EUR"}
			tc.mutate(b)
			repo := newMockRepo()
			provider := &fakeExchangeRateProvider{}
			if err := NewBillService(repo, provider).CreateBill(context.Background(), b); !errors.Is(err, ErrInvalidCreation) || provider.calls != 0 || len(repo.bills) != 0 {
				t.Fatalf("service guard: %v", err)
			}
			db := newBillRepositoryTestDB(t)
			sql, err := db.DB()
			if err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() { _ = sql.Close() })
			if err := (&billRepository{db: db}).Create(context.Background(), b); !errors.Is(err, ErrInvalidCreation) {
				t.Errorf("repository guard: %v", err)
			}
			for _, table := range []string{"bills", "people", "bill_participants", "bill_items", "item_assignments", "person_shares"} {
				var count int64
				if err := db.Table(table).Count(&count).Error; err != nil {
					t.Fatal(err)
				}
				if count != 0 {
					t.Errorf("direct repository rejection wrote %s: %d rows", table, count)
				}
			}
		})
	}
	for _, value := range []float64{math.NaN(), math.Inf(1), math.Inf(-1)} {
		b := &models.Bill{Name: "Positive", Subtotal: value, Total: 10, CurrencyCode: "EUR"}
		repo := newMockRepo()
		provider := &fakeExchangeRateProvider{}
		if err := NewBillService(repo, provider).CreateBill(context.Background(), b); !errors.Is(err, ErrInvalidCreation) || provider.calls != 0 {
			t.Fatal("nonfinite money escaped service validation")
		}
	}
}

func TestCreateBillConversionOverflowDoesNotPersist(t *testing.T) {
	repo := newMockRepo()
	provider := &fakeExchangeRateProvider{quote: models.ExchangeRateQuote{Base: "EUR", Quote: "USD", Rate: math.MaxFloat64, Date: time.Now().UTC().Format(time.DateOnly), Source: "synthetic"}}
	err := NewBillService(repo, provider).CreateBill(context.Background(), &models.Bill{Name: "Positive", Subtotal: 10, Total: 10, CurrencyCode: "EUR"})
	if err == nil || len(repo.bills) != 0 {
		t.Fatal("overflow persisted")
	}
}

func TestCreateBillRejectsNonfiniteNestedAndDirectAmounts(t *testing.T) {
	for _, value := range []float64{math.NaN(), math.Inf(1), math.Inf(-1)} {
		for _, field := range []string{"subtotal", "tax", "tip", "total", "percentage", "price", "assignment", "share", "detail", "display"} {
			t.Run(fmt.Sprint(value)+"/"+field, func(t *testing.T) {
				b := &models.Bill{Name: "Positive", Subtotal: 10, Total: 10}
				switch field {
				case "subtotal":
					b.Subtotal = value
				case "tax":
					b.Tax = value
				case "tip":
					b.TipAmount = value
				case "total":
					b.Total = value
				case "percentage":
					b.TipPercentage = value
				case "price":
					b.Items = []models.BillItem{{Name: "Dinner", Price: value}}
				case "assignment":
					b.Items = []models.BillItem{{Name: "Dinner", Price: 10, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: value}}}}
				case "share":
					b.PersonShares = []models.PersonShare{{PersonName: "Alex", Total: value}}
				case "detail":
					b.PersonShares = []models.PersonShare{{PersonName: "Alex", Total: 10, Items: []models.ItemDetail{{Name: "Dinner", Amount: value}}}}
				case "display":
					b.DisplayTotal = &value
				}
				repo := newMockRepo()
				if err := NewBillService(repo, &fakeExchangeRateProvider{}).CreateBill(context.Background(), b); !errors.Is(err, ErrInvalidCreation) || len(repo.bills) != 0 {
					t.Fatalf("nonfinite %s: %v", field, err)
				}
			})
		}
	}
}

func TestCreateBillBoundsAssignmentWorkAndPersonNames(t *testing.T) {
	for _, kind := range []string{"per_item", "overall", "person", "payment_name", "identifier"} {
		t.Run(kind, func(t *testing.T) {
			b := &models.Bill{Name: "Positive", Subtotal: 1, Total: 1}
			switch kind {
			case "per_item":
				item := models.BillItem{Name: "Dinner", Price: 1}
				for i := 0; i < 101; i++ {
					item.Assignments = append(item.Assignments, models.ItemAssignment{PersonName: fmt.Sprint(i), Percentage: 100.0 / 101})
				}
				b.Items = []models.BillItem{item}
			case "overall":
				b.Subtotal = 51
				b.Total = 51
				for i := 0; i < 51; i++ {
					item := models.BillItem{Name: "Dinner", Price: 1}
					for j := 0; j < 100; j++ {
						item.Assignments = append(item.Assignments, models.ItemAssignment{PersonName: fmt.Sprint(j), Percentage: 1})
					}
					b.Items = append(b.Items, item)
				}
			case "person":
				b.Participants = []models.Person{{Name: strings.Repeat("界", 31)}}
			case "payment_name":
				b.PaymentMethods = []models.PaymentMethod{{Name: strings.Repeat("x", 51)}}
			case "identifier":
				b.PaymentMethods = []models.PaymentMethod{{Name: "Venmo", Identifier: strings.Repeat("x", 257)}}
			}
			if err := prepareCreation(b); !errors.Is(err, ErrInvalidCreation) {
				t.Fatalf("unbounded %s: %v", kind, err)
			}
		})
	}
}

func TestDerivedClaimSharesKeepRepeatedItemBreakdowns(t *testing.T) {
	b := &models.Bill{Subtotal: 10, Total: 10, Items: []models.BillItem{
		{Name: "Repeated", Price: 6, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 50}}},
		{Name: "Repeated", Price: 4, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}},
	}}
	shares, err := BuildLazyPersonShares(b)
	if err != nil {
		t.Fatal(err)
	}
	if len(shares) != 1 || len(shares[0].Items) != 2 || shares[0].Items[0].Amount != 3 || shares[0].Items[1].Amount != 4 || shares[0].Total != 7 {
		t.Fatalf("lost detail/partial amount: %#v", shares)
	}
}
