package tab

import (
	"backend/pkg/models"
	"reflect"
	"testing"
	"time"
)

// Fixed, synthetic values are independent of database reads and the materializer.
// Interleaved IDs prevent accidental grouping by contiguous bill ranges.
func materializationFixture() (models.Tab, []models.TabMember, []models.Bill) {
	ptr := func(v uint) *uint { return &v }
	i64 := func(v int64) *int64 { return &v }
	str := func(v string) *string { return &v }
	when := time.Date(2026, 11, 5, 1, 2, 3, 123456000, time.UTC)
	tab := models.Tab{ID: 5, Name: "Synthetic", AccessToken: "synthetic-tab", DisplayCurrency: "USD"}
	roster := []models.TabMember{
		{ID: 7, TabID: 5, DisplayName: "Creator", MemberToken: "synthetic-creator", Role: "creator", JoinedAt: when},
		{ID: 8, TabID: 5, DisplayName: "Same member", MemberToken: "synthetic-member", Role: "member", JoinedAt: when},
		{ID: 9, TabID: 5, DisplayName: "Pending", MemberToken: "synthetic-pending", Role: "member", JoinedAt: when},
	}
	bills := make([]models.Bill, 2)
	for bi := range bills {
		b := &bills[bi]
		*b = models.Bill{ID: uint(101 + bi), TabID: ptr(tab.ID), Name: "Synthetic receipt", AccessToken: []string{"synthetic-a", "synthetic-b"}[bi], IdentityVersion: 2, IdentityState: "ready", IdentityRevision: 1<<34 + 4, CurrencyCode: "USD", DisplayCurrency: "USD", USDExchangeRate: 1, ExchangeRateSource: "native-usd", Total: .01, Subtotal: .01, USDTotal: .01, Date: when}
		for pi := 0; pi < 4; pi++ {
			labels := []string{"Renamed 🧾", "", "Display", "Unused"}
			allocation := []string{"Z", "A", "A", "Unused"}
			ordinals := []int64{0, 2, 1, 3}
			p := models.BillParticipant{ID: uint(10 + 2*pi + bi), BillID: b.ID, PersonID: uint(50 + 2*pi + bi), IdentityVersion: 2, Label: labels[pi], AllocationLabel: allocation[pi], Ordinal: i64(ordinals[pi]), TabID: ptr(tab.ID)}
			if pi > 0 {
				p.ClientRef = str([]string{"", "pending", "confirmed", "unused"}[pi])
			}
			if pi == 1 {
				p.PendingMemberID = ptr(9)
				p.PendingRequestRevision = i64(1<<34 + 1)
				p.RequestedAt = &when
			}
			if pi == 2 {
				p.MemberID = ptr(8)
				p.ApprovedByMemberID = ptr(7)
				p.ApprovalKind = str("creator")
				p.ApprovedAt = &when
			}
			if pi >= 2 {
				p.LastBindingMemberID = ptr(9)
				p.LastBindingActorMemberID = ptr(7)
				p.LastBindingRequestRevision = i64(1<<34 + 1)
				p.LastBindingResultRevision = i64(1<<34 + 2)
				p.LastBindingActorKind = str("source")
				p.LastBindingDecision = str("reject")
				p.LastBindingDecidedAt = &when
				if pi == 2 {
					p.LastBindingMemberID = ptr(8)
					p.LastBindingActorKind = str("creator")
					p.LastBindingDecision = str("approve")
				}
			}
			b.ParticipantRows = append(b.ParticipantRows, p)
			if pi < 3 {
				var details []models.ItemDetail
				if pi == 1 {
					details = []models.ItemDetail{}
				}
				if pi == 2 {
					details = []models.ItemDetail{{Name: "Line 🧾\n\"", Amount: .02, IsShared: true}, {Name: "Discount", Amount: -.01}}
				}
				b.PersonShares = append(b.PersonShares, models.PersonShare{ID: uint(30 + 2*pi + bi), BillID: b.ID, IdentityVersion: 2, ParticipantID: ptr(p.ID), PersonName: "Raw historical label", Items: details, Subtotal: .01 / 3, TaxShare: .001, TipShare: .002, Total: .01 / 3, Paid: pi == 2})
			}
		}
	}
	return tab, roster, bills
}

func TestMaterializationAccountingFidelity(t *testing.T) {
	tab, roster, bills := materializationFixture()
	_, _, before := materializationFixture()
	rows, err := grossSettlements(tab.ID, bills, roster)
	if err != nil || len(rows) != 5 {
		t.Fatalf("gross rows=%d error=%v; want five distinct parties", len(rows), err)
	}
	members, guests := 0, 0
	for _, s := range rows {
		if s.MemberID != nil {
			members++
			if *s.MemberID != 8 || s.Amount != .02 || s.PersonName != "Same member" {
				t.Fatalf("wrong member cents or label: %+v", s)
			}
		} else {
			guests++
			if s.Amount != 0 || s.ParticipantID == nil || (s.GuestBillID != 101 && s.GuestBillID != 102) {
				t.Fatalf("wrong distinct guest: %+v", s)
			}
		}
	}
	if members != 1 || guests != 4 || !reflect.DeepEqual(bills, before) {
		t.Fatal("lost guest/member distinction or mutated complete inputs")
	}
}
