package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"errors"
	"testing"
	"time"
)

// Two confirmed members and one unbound guest all carry the label "Alex" on
// one receipt. Balances and the finalization rows must keep three debts keyed
// by member/participant identity; a label can neither merge nor move a debt.
func TestIdentity0003SameNameMembersKeepSeparateDebts(t *testing.T) {
	build := func() *models.Tab {
		trip := &models.Tab{ID: 1, Members: []models.TabMember{{ID: 1, DisplayName: "Payer"}, {ID: 2, DisplayName: "Alex"}, {ID: 3, DisplayName: "Alex"}}, Bills: []models.Bill{{ID: 1, Total: 60, PaidByMemberID: ptrUint(1), PersonShares: []models.PersonShare{{PersonName: "Alex", Total: 10}, {PersonName: "Alex", Total: 20}, {PersonName: "Alex", Total: 30}}}}}
		referenceMoneyFixture(t, trip, nil)
		kind := "creator"
		now := time.Date(2026, 11, 9, 0, 0, 0, 0, time.UTC)
		for i, member := range []uint{2, 3} {
			p := &trip.Bills[0].ParticipantRows[i]
			p.MemberID, p.ApprovedByMemberID, p.ApprovalKind, p.ApprovedAt = ptrUint(member), ptrUint(1), &kind, &now
		}
		return trip
	}
	guest := build().Bills[0].ParticipantRows[2].ID
	check := func(t *testing.T, trip *models.Tab) {
		t.Helper()
		balances, err := ReferenceNetBalances(trip)
		if err != nil || len(balances) != 3 {
			t.Fatalf("same-label debts merged or failed: %+v %v", balances, err)
		}
		members, guests := map[uint]float64{}, map[uint]float64{}
		for _, row := range balances {
			if row.To.Kind != "member" || row.To.MemberID != 1 {
				t.Fatalf("creditor changed: %+v", row)
			}
			if row.From.Kind == "member" {
				members[row.From.MemberID] = row.Amount
			} else {
				guests[row.From.ParticipantID] = row.Amount
			}
		}
		if len(members) != 2 || members[2] != 10 || members[3] != 20 || len(guests) != 1 || guests[guest] != 30 {
			t.Fatalf("balance followed a label, not an identity: %v %v", members, guests)
		}
		rows, err := grossSettlements(trip.ID, trip.Bills, trip.Members)
		if err != nil || len(rows) != 3 {
			t.Fatalf("finalization rows merged or failed: %+v %v", rows, err)
		}
		members, guests = map[uint]float64{}, map[uint]float64{}
		for _, row := range rows {
			if (row.MemberID == nil) == (row.ParticipantID == nil) {
				t.Fatalf("finalization row lost its identity: %+v", row)
			}
			if row.MemberID != nil {
				members[*row.MemberID] = row.Amount
			} else {
				guests[*row.ParticipantID] = row.Amount
			}
		}
		if len(members) != 2 || members[2] != 10 || members[3] != 20 || len(guests) != 1 || guests[guest] != 30 {
			t.Fatalf("finalization followed a label, not an identity: %v %v", members, guests)
		}
	}
	t.Run("two_members_and_a_guest_named_alex", func(t *testing.T) { check(t, build()) })
	t.Run("taking_the_payer_name_moves_no_debt", func(t *testing.T) {
		trip := build()
		trip.Members[2].DisplayName = "Payer"
		trip.Bills[0].ParticipantRows[2].Label = "Payer"
		check(t, trip)
	})
	t.Run("name_only_clients_are_told_to_upgrade", func(t *testing.T) {
		trip := build()
		trip.TotalStatus, trip.NetBalanceStatus = "available", "available"
		if err := legacyTabRepresentable(trip); !errors.Is(err, billpkg.ErrClientUpgrade) {
			t.Fatalf("name-keyed view accepted colliding people: %v", err)
		}
	})
}
