package tab

import (
	"backend/pkg/models"
	"database/sql"
	"encoding/json"
	"errors"

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
		var err error
		participants, err = readFinalizationParticipants(tx, ids)
		if err != nil {
			return nil, err
		}
		shares, err = readFinalizationShares(tx, ids)
		if err != nil {
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

func readFinalizationParticipants(tx *gorm.DB, ids []uint) (result []*models.BillParticipant, err error) {
	rows, err := tx.Model(&models.BillParticipant{}).Select(models.ParticipantColumns).
		Where("bill_id IN ?", ids).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Rows()
	if err != nil {
		return nil, err
	}
	defer func() {
		err = errors.Join(err, rows.Close())
		if err != nil {
			result = nil
		}
	}()
	for rows.Next() {
		p := new(models.BillParticipant)
		if err := rows.Scan(&p.ID, &p.BillID, &p.PersonID, &p.Label, &p.AllocationLabel,
			&p.IdentityVersion, &p.Ordinal, &p.ClientRef, &p.TabID, &p.MemberID,
			&p.PendingMemberID, &p.ApprovedByMemberID, &p.ApprovalKind, &p.RequestedAt,
			&p.ApprovedAt, &p.PendingRequestRevision, &p.LastBindingMemberID,
			&p.LastBindingRequestRevision, &p.LastBindingDecision, &p.LastBindingActorMemberID,
			&p.LastBindingActorKind, &p.LastBindingResultRevision, &p.LastBindingDecidedAt); err != nil {
			return nil, err
		}
		result = append(result, p)
	}
	return result, rows.Err()
}

func readFinalizationShares(tx *gorm.DB, ids []uint) (result []*models.PersonShare, err error) {
	rows, err := tx.Model(&models.PersonShare{}).Select(models.ShareColumns).
		Where("bill_id IN ?", ids).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Rows()
	if err != nil {
		return nil, err
	}
	defer func() {
		err = errors.Join(err, rows.Close())
		if err != nil {
			result = nil
		}
	}()
	for rows.Next() {
		s := new(models.PersonShare)
		var items []byte
		var paid sql.NullBool // The frozen schema permits SQL NULL; GORM reads it as false.
		if err := rows.Scan(&s.ID, &s.BillID, &s.PersonName, &items, &s.Subtotal,
			&s.TaxShare, &s.TipShare, &s.Total, &paid, &s.IdentityVersion, &s.ParticipantID); err != nil {
			return nil, err
		}
		s.Paid = paid.Bool
		// Match the existing GORM JSON serializer: SQL NULL and JSON null are nil,
		// [] remains an allocated empty slice, and unknown object fields are ignored.
		if len(items) > 0 {
			if err := json.Unmarshal(items, &s.Items); err != nil {
				return nil, err
			}
		}
		result = append(result, s)
	}
	return result, rows.Err()
}
