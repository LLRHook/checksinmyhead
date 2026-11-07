package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"gorm.io/gorm"
	"math"
	"sort"
)

func grossSettlements(tabID uint, bills []models.Bill, rosters ...[]models.TabMember) ([]models.TabSettlement, error) {
	if len(bills) == 0 {
		return nil, mutation.NoBills
	}
	allocated := 0
	for _, b := range bills {
		allocated += len(b.PersonShares)
	}
	if allocated == 0 {
		return nil, mutation.NoAllocation
	}
	roster := map[uint]models.TabMember{}
	if len(rosters) > 0 {
		for _, m := range rosters[0] {
			if m.ID == 0 || m.TabID != tabID {
				return nil, billpkg.ErrIdentityReview
			}
			roster[m.ID] = m
		}
	}
	totals := map[string]int64{}
	parties := map[string]models.Party{}
	for _, b := range bills {
		index, err := billpkg.ParticipantIndex(b)
		if err != nil {
			return nil, err
		}
		for _, p := range b.ParticipantRows {
			if _, err := billpkg.PartyFor(tabID, b, p, roster); err != nil {
				return nil, err
			}
		}
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
			party, err := billpkg.PartyFor(tabID, b, p, roster)
			if err != nil {
				return nil, err
			}
			key := billpkg.PartyKey(party)
			totals[key], err = billpkg.AddObligationCents(totals[key], cents[i])
			if err != nil {
				return nil, err
			}
			parties[key] = party
		}
	}
	if len(totals) == 0 {
		return nil, mutation.NoAllocation
	}
	keys := make([]string, 0, len(totals))
	for k := range totals {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	result := make([]models.TabSettlement, 0, len(keys))
	var aggregate int64
	for _, key := range keys {
		var err error
		aggregate, err = billpkg.AddObligationCents(aggregate, totals[key])
		if err != nil {
			return nil, err
		}
		amount, err := billpkg.ObligationDollars(totals[key])
		if err != nil {
			return nil, err
		}
		party := parties[key]
		row := models.TabSettlement{TabID: tabID, SnapshotVersion: 2, PersonName: party.Label, Amount: amount, GuestBillID: party.BillID}
		if party.Kind == "member" {
			id := party.MemberID
			row.MemberID = &id
		} else {
			id := party.ParticipantID
			row.ParticipantID = &id
		}
		result = append(result, row)
	}
	return result, nil
}

func validStoredSnapshot(t models.Tab, rows []models.TabSettlement) error {
	if !t.Finalized || t.FinalizedAt == nil || t.FinalizedAt.IsZero() || len(rows) == 0 {
		return mutation.Review
	}
	version := rows[0].SnapshotVersion
	if version != 1 && version != 2 {
		return billpkg.ErrIdentityReview
	}
	ids := map[uint]bool{}
	parties := map[string]bool{}
	var aggregate int64
	for _, s := range rows {
		cents := math.Round(s.Amount * 100)
		if s.ID == 0 || ids[s.ID] || s.TabID != t.ID || s.CreatedAt.IsZero() || s.SnapshotVersion != version || math.IsNaN(cents) || math.IsInf(cents, 0) || cents < 0 || cents >= float64(math.MaxInt64) || math.Abs(s.Amount*100-cents) > 1e-6 {
			return mutation.Review
		}
		ids[s.ID] = true
		if version == 1 {
			if s.MemberID != nil || s.ParticipantID != nil {
				return billpkg.ErrIdentityReview
			}
		} else {
			if (s.MemberID == nil) == (s.ParticipantID == nil) {
				return billpkg.ErrIdentityReview
			}
			p := models.Party{Kind: "guest", BillID: s.GuestBillID}
			if s.MemberID != nil {
				if *s.MemberID == 0 {
					return billpkg.ErrIdentityReview
				}
				p.Kind = "member"
				p.TabID = t.ID
				p.MemberID = *s.MemberID
			} else {
				if *s.ParticipantID == 0 {
					return billpkg.ErrIdentityReview
				}
				p.ParticipantID = *s.ParticipantID
			}
			key := billpkg.PartyKey(p)
			if parties[key] {
				return billpkg.ErrIdentityReview
			}
			parties[key] = true
		}
		var err error
		aggregate, err = billpkg.AddObligationCents(aggregate, int64(cents))
		if err != nil {
			return err
		}
	}
	return nil
}

func validateStoredSnapshot(tx *gorm.DB, t models.Tab, rows []models.TabSettlement, roster []models.TabMember) error {
	ids := []uint{}
	for _, s := range rows {
		if s.ParticipantID != nil {
			ids = append(ids, *s.ParticipantID)
		}
	}
	var participants []models.BillParticipant
	if len(ids) > 0 {
		if err := tx.Select(models.ParticipantColumns).Where("id IN ?", ids).Order("id ASC").Find(&participants).Error; err != nil {
			return err
		}
	}
	byID := map[uint]models.BillParticipant{}
	for _, p := range participants {
		byID[p.ID] = p
	}
	members := map[uint]bool{}
	for _, m := range roster {
		if m.TabID == t.ID {
			members[m.ID] = true
		}
	}
	for i, s := range rows {
		if s.SnapshotVersion == 2 {
			if s.MemberID != nil && !members[*s.MemberID] {
				return billpkg.ErrIdentityReview
			}
			if s.ParticipantID != nil {
				p, ok := byID[*s.ParticipantID]
				if !ok || p.IdentityVersion != 2 || p.TabID == nil || *p.TabID != t.ID || p.BillID == 0 {
					return billpkg.ErrIdentityReview
				}
				rows[i].GuestBillID = p.BillID
			}
		}
	}
	return validStoredSnapshot(t, rows)
}
