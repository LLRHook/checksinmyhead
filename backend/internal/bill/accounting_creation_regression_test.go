package bill

import (
	"backend/pkg/models"
	"context"
	"errors"
	"math"
	"testing"
)

// Keep the real creation and persistence preflight owners on this path; only the
// database write is replaced by the existing in-memory repository fixture.
type accountingCreationRepository struct{ *mockBillRepository }

func (r accountingCreationRepository) Create(ctx context.Context, c CreationInsert) (CreationRecord, error) {
	if err := guardCreationInsert(c); err != nil {
		return CreationRecord{}, err
	}
	return r.mockBillRepository.Create(ctx, c)
}

func TestCreationRemaindersPreserveZeroShares(t *testing.T) {
	for _, tc := range []struct {
		name             string
		first, rest, tax float64
		wantCents        int64
	}{
		{"zero_tax_share", .10, 30, 1.01, 3111},
		{"zero_total_share", 0, 10.01, 0, 1001},
	} {
		t.Run(tc.name, func(t *testing.T) {
			repo := accountingCreationRepository{newMockRepo()}
			b := &models.Bill{Name: "Synthetic split", CurrencyCode: "USD", Subtotal: tc.first + tc.rest,
				Tax: tc.tax, Total: tc.first + tc.rest + tc.tax,
				Participants: []models.Person{{Name: "Alice"}, {Name: "Bob"}, {Name: "Carol"}, {Name: "Dan"}},
				Items: []models.BillItem{
					{Name: "Small", Price: tc.first, Assignments: []models.ItemAssignment{{PersonName: "Alice", Percentage: 100}}},
					{Name: "Shared", Price: tc.rest, Assignments: []models.ItemAssignment{{PersonName: "Bob", Percentage: 100.0 / 3}, {PersonName: "Carol", Percentage: 100.0 / 3}, {PersonName: "Dan", Percentage: 100.0 / 3}}},
				}}
			created, err := NewBillService(repo, &fakeExchangeRateProvider{}).CreateBill(context.Background(), CreateBillCommand{Content: b})
			if err != nil {
				t.Fatalf("valid zero-share split rejected: %v", err)
			}
			stored := repo.bills[created.BillID]
			cents, err := FrozenUSDShareCents(*stored)
			if err != nil {
				t.Fatalf("saved zero-share split needs review: %v; shares=%+v", err, stored.PersonShares)
			}
			var total int64
			for i, s := range stored.PersonShares {
				if s.Subtotal < 0 || s.TaxShare < 0 || s.TipShare < 0 || s.Total < 0 {
					t.Fatalf("negative obligation persisted: %+v", s)
				}
				if s.PersonName == "Alice" && (s.TaxShare != 0 || s.Total != tc.first) {
					t.Fatalf("zero component was debited: %+v", s)
				}
				total += cents[i]
			}
			if len(cents) != 4 || total != tc.wantCents {
				t.Fatalf("lost participant or cents: %v want=%d", cents, tc.wantCents)
			}
		})
	}
}

func TestCreationInsertAuditsShares(t *testing.T) {
	repo := newMockRepo()
	created, err := NewBillService(repo, &fakeExchangeRateProvider{}).CreateBill(context.Background(), CreateBillCommand{Content: &models.Bill{
		Name: "Synthetic audit", Subtotal: 10, Total: 10, CurrencyCode: "USD",
		Participants: []models.Person{{Name: "Alice"}},
		Items:        []models.BillItem{{Name: "Meal", Price: 10, Assignments: []models.ItemAssignment{{PersonName: "Alice", Percentage: 100}}}},
	}})
	if err != nil {
		t.Fatal(err)
	}
	base := repo.bills[created.BillID]
	for _, tc := range []struct {
		name    string
		change  func(*models.Bill)
		invalid bool
	}{
		{"legacy_full", func(*models.Bill) {}, false},
		{"partial_below_half_cent", func(b *models.Bill) { b.PersonShares[0].Total = 9.994 }, false},
		{"unclaimed", func(b *models.Bill) { b.PersonShares = nil; b.LazyMode = true }, false},
		{"fresh_reference_input", func(b *models.Bill) {
			ref := "alice"
			b.InputVersion = 2
			b.Participants[0].ClientRef = &ref
			b.Items[0].Assignments[0].PersonName = ""
			b.Items[0].Assignments[0].ParticipantRef = ref
			b.PersonShares[0].ParticipantRef = ref
		}, false},
		{"overallocated", func(b *models.Bill) { b.PersonShares[0].Total = 10.02 }, true},
		{"negative_component", func(b *models.Bill) { b.PersonShares[0].TaxShare = -.01 }, true},
		{"nonfinite_component", func(b *models.Bill) { b.PersonShares[0].Subtotal = math.NaN() }, true},
		{"malformed_foreign_audit", func(b *models.Bill) { b.CurrencyCode = "EUR" }, true},
		{"persisted_identity_not_fresh", func(b *models.Bill) { b.IdentityVersion = 2 }, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			b := cloneCreation(base)
			b.ID = 0
			tc.change(b)
			err := guardCreationInsert(CreationInsert{Bill: b})
			if tc.invalid && !errors.Is(err, ErrInvalidCreation) || !tc.invalid && err != nil {
				t.Fatalf("invalid=%v err=%v", tc.invalid, err)
			}
			if tc.name == "partial_below_half_cent" {
				got, err := FrozenUSDShareCents(*b)
				if err != nil || len(got) != 1 || got[0] != 999 {
					t.Fatalf("partial receipt scaled up: %v %v", got, err)
				}
			}
		})
	}
}

func TestCreationRoundingRemainsAccountable(t *testing.T) {
	for _, tc := range []struct {
		name                      string
		subtotal, tax, tip, total float64
		wantCents                 int64
	}{
		{"mobile_fifteen_percent_half_cent", 18.50, 0, 2.775, 21.275, 2128},
		{"documented_one_cent_tolerance", 10, 1, 0, 10.99, 1099},
		{"healthy_exact_cent", 18.50, 0, 1.85, 20.35, 2035},
		{"mobile_eighteen_percent", 21.75, 0, 3.915, 25.665, 2567},
		{"mobile_quarter_tip_with_tax", 12.82, 1.11, 3.205, 17.135, 1714},
	} {
		t.Run(tc.name, func(t *testing.T) {
			repo := accountingCreationRepository{newMockRepo()}
			content := &models.Bill{Name: "Synthetic rounding receipt", Subtotal: tc.subtotal, Tax: tc.tax,
				TipAmount: tc.tip, Total: tc.total, CurrencyCode: "USD",
				Participants: []models.Person{{Name: "Alice"}},
				Items: []models.BillItem{{Name: "Meal", Price: tc.subtotal,
					Assignments: []models.ItemAssignment{{PersonName: "Alice", Percentage: 100}}}}}
			created, err := NewBillService(repo, &fakeExchangeRateProvider{}).CreateBill(context.Background(), CreateBillCommand{Content: content})
			if err != nil {
				t.Fatalf("valid receipt was rejected by creation: %v", err)
			}
			stored := repo.bills[created.BillID]
			cents, err := FrozenUSDShareCents(*stored)
			if err != nil || len(cents) != 1 || cents[0] != tc.wantCents {
				t.Fatalf("saved receipt requires accounting review: cents=%v err=%v want=%d", cents, err, tc.wantCents)
			}
			if allocationReviewStatus(*stored) != "available" {
				t.Fatal("saved receipt lost its available accounting projection")
			}
		})
	}
	t.Run("signed_discount_remains_accountable", func(t *testing.T) {
		repo := accountingCreationRepository{newMockRepo()}
		b := &models.Bill{Name: "Synthetic discount", Subtotal: 8, Tax: .8, TipAmount: 1.2, Total: 10, CurrencyCode: "USD",
			Participants: []models.Person{{Name: "Alice"}},
			Items: []models.BillItem{
				{Name: "Meal", Price: 10, Assignments: []models.ItemAssignment{{PersonName: "Alice", Percentage: 100}}},
				{Name: "Discount", Price: -2, Assignments: []models.ItemAssignment{{PersonName: "Alice", Percentage: 100}}},
			}}
		created, err := NewBillService(repo, &fakeExchangeRateProvider{}).CreateBill(context.Background(), CreateBillCommand{Content: b})
		if err != nil {
			t.Fatal(err)
		}
		stored := repo.bills[created.BillID]
		cents, err := FrozenUSDShareCents(*stored)
		if err != nil || len(cents) != 1 || cents[0] != 1000 || len(stored.PersonShares[0].Items) != 2 || stored.PersonShares[0].Items[1].Amount != -2 {
			t.Fatalf("discount or audit changed: %v %v %+v", cents, err, stored.PersonShares)
		}
	})
}
