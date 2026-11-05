package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"math"
	"sort"
	"strings"
)

func ReferenceNetBalances(t *models.Tab) ([]models.ReferenceNetBalance, error) {
	if t == nil {
		return nil, billpkg.ErrIdentityReview
	}
	roster := map[uint]models.TabMember{}
	for _, m := range t.Members {
		if m.ID == 0 || m.TabID != t.ID || roster[m.ID].ID != 0 {
			return nil, billpkg.ErrIdentityReview
		}
		roster[m.ID] = m
	}
	nets := map[string]int64{}
	parties := map[string]models.Party{}
	var aggregate int64
	for _, b := range t.Bills {
		if err := billpkg.ValidateReferenceGraph(b); err != nil {
			return nil, err
		}
		index, err := billpkg.ParticipantIndex(b)
		if err != nil {
			return nil, err
		}
		for _, p := range b.ParticipantRows {
			if _, err := billpkg.PartyFor(t.ID, b, p, roster); err != nil {
				return nil, err
			}
		}
		if b.PaidByMemberID == nil {
			return nil, billpkg.ErrIdentityReview
		}
		payer, ok := roster[*b.PaidByMemberID]
		if !ok || payer.TabID != t.ID || b.TabID == nil || *b.TabID != t.ID {
			return nil, billpkg.ErrIdentityReview
		}
		creditor := models.Party{Kind: "member", TabID: t.ID, MemberID: payer.ID, Label: payer.DisplayName}
		creditKey := billpkg.PartyKey(creditor)
		parties[creditKey] = creditor
		cents, err := billpkg.FrozenUSDShareCents(b)
		if err != nil {
			return nil, err
		}
		for i, s := range b.PersonShares {
			if s.ParticipantID == nil {
				return nil, billpkg.ErrIdentityReview
			}
			p, ok := index[*s.ParticipantID]
			if !ok {
				return nil, billpkg.ErrIdentityReview
			}
			party, err := billpkg.PartyFor(t.ID, b, p, roster)
			if err != nil {
				return nil, err
			}
			key := billpkg.PartyKey(party)
			parties[key] = party
			aggregate, err = billpkg.AddObligationCents(aggregate, cents[i])
			if err != nil {
				return nil, err
			}
			nets[creditKey], err = billpkg.AddObligationCents(nets[creditKey], cents[i])
			if err != nil {
				return nil, err
			}
			nets[key], err = billpkg.AddObligationCents(nets[key], -cents[i])
			if err != nil {
				return nil, err
			}
		}
	}
	type entry struct {
		key    string
		amount int64
	}
	creditors, debtors := []entry{}, []entry{}
	for key, n := range nets {
		if n > 0 {
			creditors = append(creditors, entry{key, n})
		} else if n < 0 {
			if n == math.MinInt64 {
				return nil, mutation.Review
			}
			debtors = append(debtors, entry{key, -n})
		}
	}
	order := func(rows []entry) {
		sort.Slice(rows, func(i, j int) bool {
			if rows[i].amount != rows[j].amount {
				return rows[i].amount > rows[j].amount
			}
			return rows[i].key < rows[j].key
		})
	}
	order(creditors)
	order(debtors)
	result := []models.ReferenceNetBalance{}
	ci, di := 0, 0
	for ci < len(creditors) && di < len(debtors) {
		amount := min(creditors[ci].amount, debtors[di].amount)
		dollars, err := billpkg.ObligationDollars(amount)
		if err != nil {
			return nil, err
		}
		result = append(result, models.ReferenceNetBalance{From: parties[debtors[di].key], To: parties[creditors[ci].key], Amount: dollars})
		creditors[ci].amount -= amount
		debtors[di].amount -= amount
		if creditors[ci].amount == 0 {
			ci++
		}
		if debtors[di].amount == 0 {
			di++
		}
	}
	if ci != len(creditors) || di != len(debtors) {
		return nil, mutation.Review
	}
	return result, nil
}

func legacyTabRepresentable(t *models.Tab) error {
	if t.TotalStatus != "available" || t.NetBalanceStatus != "available" {
		return billpkg.ErrClientUpgrade
	}
	parties := map[string]string{}
	add := func(key, label string) error {
		if strings.TrimSpace(label) == "" {
			return billpkg.ErrClientUpgrade
		}
		for k, old := range parties {
			if k != key && strings.EqualFold(old, label) {
				return billpkg.ErrClientUpgrade
			}
		}
		parties[key] = label
		return nil
	}
	roster := map[uint]models.TabMember{}
	for _, m := range t.Members {
		roster[m.ID] = m
	}
	for _, b := range t.Bills {
		if err := billpkg.LegacyBillRepresentable(b); err != nil {
			return err
		}
		for _, p := range b.ParticipantRows {
			party, err := billpkg.PartyFor(t.ID, b, p, roster)
			if err != nil {
				return billpkg.ErrClientUpgrade
			}
			if err := add(billpkg.PartyKey(party), party.Label); err != nil {
				return err
			}
		}
		if b.PaidByMemberID != nil {
			m := roster[*b.PaidByMemberID]
			if err := add(billpkg.PartyKey(models.Party{Kind: "member", TabID: t.ID, MemberID: m.ID}), m.DisplayName); err != nil {
				return err
			}
		}
	}
	return nil
}
