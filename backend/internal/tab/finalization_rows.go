package tab

import (
	"backend/pkg/models"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// loadFinalizationRows owns complete locked row conversion and per-bill grouping.
// bills are the fresh scalar projection already locked by FinalizeOnce.
func loadFinalizationRows(tx *gorm.DB, bills []models.Bill) ([]*models.BillParticipant, error) {
	ids := make([]uint, len(bills))
	byID := map[uint]int{}
	for i, b := range bills {
		ids[i] = b.ID
		byID[b.ID] = i
	}
	var participants []*models.BillParticipant
	var shares []*models.PersonShare
	if len(ids) > 0 {
		if err := tx.Select(models.ParticipantColumns).Where("bill_id IN ?", ids).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&participants).Error; err != nil {
			return nil, err
		}
		if err := tx.Select(models.ShareColumns).Where("bill_id IN ?", ids).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&shares).Error; err != nil {
			return nil, err
		}
	}
	// Reserve only the rows actually read for each bill. Bills with no rows
	// retain nil associations, and appends preserve the global ID read order.
	participantCounts := make([]int, len(bills))
	shareCounts := make([]int, len(bills))
	for _, p := range participants {
		participantCounts[byID[p.BillID]]++
	}
	for _, s := range shares {
		shareCounts[byID[s.BillID]]++
	}
	for i := range bills {
		if n := participantCounts[i]; n > 0 {
			bills[i].ParticipantRows = make([]models.BillParticipant, 0, n)
		}
		if n := shareCounts[i]; n > 0 {
			bills[i].PersonShares = make([]models.PersonShare, 0, n)
		}
	}
	for _, p := range participants {
		i := byID[p.BillID]
		bills[i].ParticipantRows = append(bills[i].ParticipantRows, *p)
	}
	for _, s := range shares {
		i := byID[s.BillID]
		bills[i].PersonShares = append(bills[i].PersonShares, *s)
	}
	return participants, nil
}
