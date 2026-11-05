package tab

import (
	"backend/internal/bill"
	"backend/pkg/models"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// The caller has locked and reauthorized Tab -> Bill. One checked PostgreSQL
// statement changes the parent and scoped locations, preserving the established
// four-statement attachment budget. The materialized ascending participant lock
// set supplies its expected count before UPDATE RETURNING can suppress rows.
func attachLocationLocked(tx *gorm.DB, source models.Bill, tabID uint, memberID *uint) error {
	if tx.Dialector.Name() == "postgres" {
		var count struct{ Bills, Expected, Actual int64 }
		row := tx.Raw(`WITH locked AS MATERIALIZED (
 SELECT id FROM bill_participants WHERE bill_id = ? ORDER BY id FOR UPDATE
), parent AS (
 UPDATE bills SET tab_id = ?, added_by_member_id = ?, paid_by_member_id = ?, identity_revision = ?, updated_at = ?
 WHERE id = ? AND tab_id IS NULL AND identity_revision = ? RETURNING id
), changed AS (
 UPDATE bill_participants SET tab_id = ? FROM parent
 WHERE bill_participants.bill_id = parent.id AND bill_participants.id IN (SELECT id FROM locked) RETURNING bill_participants.id
)
SELECT (SELECT count(*) FROM parent) AS bills, (SELECT count(*) FROM locked) AS expected, (SELECT count(*) FROM changed) AS actual`, source.ID, tabID, memberID, memberID, source.IdentityRevision+1, tx.NowFunc(), source.ID, source.IdentityRevision, tabID).Scan(&count)
		if row.Error != nil {
			return row.Error
		}
		if count.Bills != 1 {
			return bill.ErrRevision
		}
		if row.RowsAffected != 1 || count.Expected != count.Actual {
			return bill.ErrIdentityReview
		}
		return nil
	}
	// SQLite is the maintained unit-test adapter; it lacks data-changing CTEs.
	updated := tx.Model(&source).Where("id = ? AND tab_id IS NULL AND identity_revision = ?", source.ID, source.IdentityRevision).Updates(map[string]any{"tab_id": tabID, "added_by_member_id": memberID, "paid_by_member_id": memberID, "identity_revision": source.IdentityRevision + 1})
	if updated.Error != nil {
		return updated.Error
	}
	if updated.RowsAffected != 1 {
		return bill.ErrRevision
	}
	var rows []models.BillParticipant
	if err := tx.Select(models.ParticipantColumns).Where("bill_id = ?", source.ID).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&rows).Error; err != nil {
		return err
	}
	if len(rows) == 0 {
		return nil
	}
	updated = tx.Model(&models.BillParticipant{}).Where("bill_id = ?", source.ID).UpdateColumn("tab_id", tabID)
	if updated.Error != nil {
		return updated.Error
	}
	if updated.RowsAffected != int64(len(rows)) {
		return bill.ErrIdentityReview
	}
	return nil
}
