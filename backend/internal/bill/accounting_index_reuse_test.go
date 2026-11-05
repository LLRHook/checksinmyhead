package bill

import (
	"backend/pkg/models"
	"errors"
	"reflect"
	"testing"
	"time"
)

// Characterization covers immutable USD ties and full reference validation,
// including retained receipt evidence, without timing or allocation sampling.
func materializationAccountingFixture() models.Bill {
	tabID := uint(11)
	b := models.Bill{ID: 7, TabID: &tabID, IdentityVersion: 2, IdentityState: "ready", IdentityRevision: 4,
		Total: .01, USDTotal: .01, CurrencyCode: "USD", USDExchangeRate: 1, ExchangeRateSource: "native-usd"}
	for i := 0; i < 3; i++ {
		id, ordinal := uint(i+1), int64(2-i)
		label := "A"
		if i == 0 {
			label = "Z"
		}
		b.ParticipantRows = append(b.ParticipantRows, models.BillParticipant{
			ID: id, BillID: b.ID, IdentityVersion: 2, TabID: &tabID, Ordinal: &ordinal,
			Label: []string{"A current", "B current", "Z current"}[i], AllocationLabel: label,
		})
		b.PersonShares = append(b.PersonShares, models.PersonShare{
			ID: uint(20 + i), BillID: b.ID, IdentityVersion: 2, ParticipantID: &id,
			PersonName: "Historical display label", Total: .01 / 3,
			Items: []models.ItemDetail{{Name: "retained detail", Amount: .01 / 3, IsShared: true}},
		})
	}
	// A complete prior rejection receipt must remain evidence on an unbound row.
	target, actor := uint(81), uint(82)
	request, result := int64(2), int64(3)
	decision, kind := "reject", "source"
	when := time.Unix(1_700_000_000, 123456000).UTC()
	p := &b.ParticipantRows[0]
	p.LastBindingMemberID, p.LastBindingActorMemberID = &target, &actor
	p.LastBindingRequestRevision, p.LastBindingResultRevision = &request, &result
	p.LastBindingDecision, p.LastBindingActorKind, p.LastBindingDecidedAt = &decision, &kind, &when
	return b
}

func TestFrozenUSDReferenceTieAndInputPreservation(t *testing.T) {
	for _, order := range [][]int{{0, 1, 2}, {2, 0, 1}} {
		b, unchanged := materializationAccountingFixture(), materializationAccountingFixture()
		shares := append([]models.PersonShare(nil), b.PersonShares...)
		want := make([]int64, len(order))
		for i, source := range order {
			b.PersonShares[i] = shares[source]
			unchanged.PersonShares[i] = materializationAccountingFixture().PersonShares[source]
			if source == 2 {
				want[i] = 1
			}
		}
		for call := 0; call < 2; call++ {
			got, err := FrozenUSDShareCents(b)
			if err != nil || !reflect.DeepEqual(got, want) {
				t.Fatalf("order %v call %d: got %v, error %v; want %v", order, call, got, err, want)
			}
			if !reflect.DeepEqual(b, unchanged) {
				t.Fatal("accounting mutated full input rows or retained receipt evidence")
			}
		}
	}
}

func TestFrozenUSDReferenceValidationBeforeZeroReturn(t *testing.T) {
	for _, valuation := range []struct {
		name  string
		total float64
	}{{"zero", 0}, {"positive", .01}} {
		for _, guard := range []struct {
			name   string
			change func(*models.Bill)
		}{
			{"unused_partial_receipt", func(b *models.Bill) { b.ParticipantRows[0].LastBindingActorKind = nil }},
			{"unused_duplicate_ordinal", func(b *models.Bill) { b.ParticipantRows[0].Ordinal = b.ParticipantRows[1].Ordinal }},
			{"unused_future_pending", func(b *models.Bill) {
				id, revision := uint(91), b.IdentityRevision+1
				when := time.Unix(1_700_000_000, 0).UTC()
				b.ParticipantRows[0].PendingMemberID, b.ParticipantRows[0].PendingRequestRevision = &id, &revision
				b.ParticipantRows[0].RequestedAt = &when
			}},
			{"mixed_share_version", func(b *models.Bill) { b.PersonShares[0].IdentityVersion = 1 }},
			{"dangling_share", func(b *models.Bill) { id := uint(99); b.PersonShares[0].ParticipantID = &id }},
			{"wrong_share_bill", func(b *models.Bill) { b.PersonShares[0].BillID++ }},
		} {
			t.Run(guard.name+"/"+valuation.name, func(t *testing.T) {
				b := materializationAccountingFixture()
				// The malformed participant can be absent from the share set; every
				// participant still requires validation before the zero early return.
				b.PersonShares = b.PersonShares[2:]
				b.PersonShares[0].Total = valuation.total
				guard.change(&b)
				if got, err := FrozenUSDShareCents(b); !errors.Is(err, ErrIdentityReview) || got != nil {
					t.Fatalf("invalid evidence accepted: cents %v, error %v", got, err)
				}
			})
		}
	}
}
