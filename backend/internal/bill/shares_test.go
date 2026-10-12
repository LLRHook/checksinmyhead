package bill

import (
	"backend/pkg/models"
	"math"
	"testing"
	"time"
)

func TestBuildLazyPersonSharesDistributesTaxAndTipRemainders(t *testing.T) {
	bill := &models.Bill{
		Subtotal:  3,
		Tax:       1,
		TipAmount: 1,
		Items: []models.BillItem{
			{Name: "A", Price: 1, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100, CreatedAt: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)}}},
			{Name: "B", Price: 1, Assignments: []models.ItemAssignment{{PersonName: "Blair", Percentage: 100, CreatedAt: time.Date(2026, 1, 2, 0, 0, 0, 0, time.UTC)}}},
			{Name: "C", Price: 1, Assignments: []models.ItemAssignment{{PersonName: "Casey", Percentage: 100, CreatedAt: time.Date(2026, 1, 3, 0, 0, 0, 0, time.UTC)}}},
		},
	}

	shares := BuildLazyPersonShares(bill)
	var tax, tip, total float64
	for _, share := range shares {
		tax += share.TaxShare
		tip += share.TipShare
		total += share.Total
	}
	if math.Abs(tax-bill.Tax) > 0.001 {
		t.Errorf("allocated tax = %.2f, want %.2f", tax, bill.Tax)
	}
	if math.Abs(tip-bill.TipAmount) > 0.001 {
		t.Errorf("allocated tip = %.2f, want %.2f", tip, bill.TipAmount)
	}
	if math.Abs(total-(bill.Subtotal+bill.Tax+bill.TipAmount)) > 0.001 {
		t.Errorf("share totals = %.2f, want bill total %.2f", total, bill.Subtotal+bill.Tax+bill.TipAmount)
	}
}

func TestBuildLazyPersonSharesKeepsEarlierClaimTaxStable(t *testing.T) {
	firstClaimAt := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	secondClaimAt := firstClaimAt.Add(time.Minute)
	bill := &models.Bill{
		Subtotal: 3,
		Tax:      1,
		Items: []models.BillItem{{
			Name:  "First",
			Price: 1,
			Assignments: []models.ItemAssignment{{
				PersonName: "Alex", Percentage: 100, CreatedAt: firstClaimAt,
			}},
		}},
	}
	first := BuildLazyPersonShares(bill)[0]
	bill.Items = append(bill.Items, models.BillItem{
		Name: "Second", Price: 1,
		Assignments: []models.ItemAssignment{{
			PersonName: "Blair", Percentage: 100, CreatedAt: secondClaimAt,
		}},
	})

	shares := BuildLazyPersonShares(bill)
	for _, share := range shares {
		if share.PersonName == "Alex" && share.TaxShare != first.TaxShare {
			t.Fatalf("earlier share changed from %.2f to %.2f", first.TaxShare, share.TaxShare)
		}
	}
}

func TestBuildLazyPersonSharesDoesNotCreateOrLoseSplitItemPennies(t *testing.T) {
	bill := &models.Bill{
		Subtotal: 0.01,
		Total:    0.01,
		Items: []models.BillItem{{
			Name:  "One-cent item",
			Price: 0.01,
			Assignments: []models.ItemAssignment{
				{PersonName: "Alex", Percentage: 50, CreatedAt: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)},
				{PersonName: "Blair", Percentage: 50, CreatedAt: time.Date(2026, 1, 2, 0, 0, 0, 0, time.UTC)},
			},
		}},
	}

	shares := BuildLazyPersonShares(bill)
	var subtotal float64
	for _, share := range shares {
		subtotal += share.Subtotal
	}
	if subtotal != bill.Subtotal {
		t.Fatalf("allocated subtotals = %.2f, want %.2f", subtotal, bill.Subtotal)
	}
}
