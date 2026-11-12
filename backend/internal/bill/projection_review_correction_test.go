package bill

import (
	"backend/pkg/models"
	"math"
	"reflect"
	"testing"
)

func reviewProjectionBill() models.Bill {
	pid, ordinal := uint(1), int64(0)
	return models.Bill{ID: 7, IdentityVersion: 2, IdentityState: "ready", Total: 10, USDTotal: 10, CurrencyCode: "USD", USDExchangeRate: 1, ExchangeRateSource: "native-usd",
		ParticipantRows: []models.BillParticipant{{ID: pid, BillID: 7, IdentityVersion: 2, Label: "Alex", AllocationLabel: "Alex", Ordinal: &ordinal}},
		PersonShares:    []models.PersonShare{{ID: 11, BillID: 7, IdentityVersion: 2, ParticipantID: &pid, PersonName: "Alex", Subtotal: 10, Total: 10}}}
}

func TestIdentityBReviewAllocationProjection(t *testing.T) {
	for _, tc := range []struct {
		name                 string
		change               func(*models.Bill)
		accounting, identity string
		legacyOK             bool
	}{
		{"complete", func(*models.Bill) {}, "available", "ready", true},
		{"partial", func(b *models.Bill) { b.PersonShares[0].Subtotal = 4; b.PersonShares[0].Total = 4 }, "available", "ready", true},
		{"zero_share", func(b *models.Bill) { b.PersonShares[0].Subtotal = 0; b.PersonShares[0].Total = 0 }, "available", "ready", true},
		{"negative", func(b *models.Bill) { b.PersonShares[0].Total = -1 }, "accounting_review_required", "ready", false},
		{"over_allocated", func(b *models.Bill) { b.PersonShares[0].Total = 20 }, "accounting_review_required", "ready", false},
		{"overflow", func(b *models.Bill) { b.PersonShares[0].Total = math.MaxFloat64 }, "accounting_review_required", "ready", false},
		{"bad_quote", func(b *models.Bill) { b.CurrencyCode = "EUR"; b.USDExchangeRate = 0 }, "accounting_review_required", "ready", false},
		{"bad_reference", func(b *models.Bill) { id := uint(99); b.PersonShares[0].ParticipantID = &id }, "identity_review_required", "identity_review_required", false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			b := reviewProjectionBill()
			tc.change(&b)
			before := reviewProjectionBill()
			tc.change(&before)
			v := ViewBill(b, nil)
			if v.AccountingReviewStatus != tc.accounting || v.IdentityReviewStatus != tc.identity {
				t.Fatalf("review status accounting=%s identity=%s", v.AccountingReviewStatus, v.IdentityReviewStatus)
			}
			if (LegacyBillRepresentable(b) == nil) != tc.legacyOK {
				t.Fatal("wire1 representation discarded accounting review")
			}
			if !reflect.DeepEqual(b, before) || v.Total != b.Total || v.USDTotal != b.USDTotal || len(v.PersonShares) != 1 || v.PersonShares[0].Total != b.PersonShares[0].Total {
				t.Fatal("projection rewrote raw history/frozen receipt")
			}
		})
	}
	t.Run("legacy_partial", func(t *testing.T) {
		b := reviewProjectionBill()
		b.IdentityVersion = 1
		b.IdentityState = "legacy"
		b.ParticipantRows = nil
		b.PersonShares[0].IdentityVersion = 1
		b.PersonShares[0].ParticipantID = nil
		b.PersonShares[0].Total = 4
		b.PersonShares[0].Subtotal = 4
		if LegacyBillRepresentable(b) != nil {
			t.Fatal("valid independently valued legacy partial read rejected")
		}
	})
}
