package bill

import (
	"backend/pkg/models"
	"backend/pkg/mutation"
	"errors"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"strings"
	"time"
)

func ValidateAssignmentUpdates(updates []ItemAssignmentsUpdate) error {
	if len(updates) == 0 || len(updates) > 500 {
		return mutation.Invalid
	}
	ids := map[uint]bool{}
	for _, u := range updates {
		if u.ItemID == 0 || ids[u.ItemID] || len(u.Assignments) > 100 {
			return mutation.Invalid
		}
		ids[u.ItemID] = true
		seen := map[string]bool{}
		total := 0.0
		for _, a := range u.Assignments {
			key := strings.ToLower(a.PersonName)
			if strings.TrimSpace(key) == "" || len([]rune(key)) > 30 || seen[key] || !finite(a.Percentage) || a.Percentage <= 0 || a.Percentage > 100 {
				return mutation.Invalid
			}
			seen[key] = true
			total += a.Percentage
		}
		if !models.ItemAssignmentTotalIsValid(total) {
			return mutation.Invalid
		}
	}
	return nil
}
func sameEconomics(a, b models.PersonShare) bool {
	if a.Subtotal != b.Subtotal || a.TaxShare != b.TaxShare || a.TipShare != b.TipShare || a.Total != b.Total || len(a.Items) != len(b.Items) {
		return false
	}
	for i := range a.Items {
		if a.Items[i] != b.Items[i] {
			return false
		}
	}
	return true
}

// ReplaceAssignmentsLocked owns both standalone and attached transformations.
// Caller must hold Bill, and Tab first when attached; it supplies the transaction.
// Items -> Shares are locked in ID order, and all replacement work is batched.
func ReplaceAssignmentsLocked(tx *gorm.DB, b models.Bill, updates []ItemAssignmentsUpdate) error {
	if err := ValidateAssignmentUpdates(updates); err != nil {
		return err
	}
	if err := tx.Where("bill_id = ?", b.ID).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&b.Items).Error; err != nil {
		return err
	}
	allIDs := make([]uint, len(b.Items))
	byID := map[uint]int{}
	for i, item := range b.Items {
		allIDs[i] = item.ID
		byID[item.ID] = i
	}
	var assignments []models.ItemAssignment
	if len(allIDs) > 0 {
		if err := tx.Where("bill_item_id IN ?", allIDs).Order("bill_item_id ASC,id ASC").Find(&assignments).Error; err != nil {
			return err
		}
	}
	for _, a := range assignments {
		i := byID[a.BillItemID]
		b.Items[i].Assignments = append(b.Items[i].Assignments, a)
	}
	var existing []models.PersonShare
	if err := tx.Where("bill_id = ?", b.ID).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&existing).Error; err != nil {
		return err
	}
	oldByName := map[string]models.PersonShare{}
	paid := map[string]bool{}
	for _, s := range existing {
		key := strings.ToLower(s.PersonName)
		if _, ok := oldByName[key]; ok {
			return mutation.Review
		}
		oldByName[key] = s
		paid[key] = s.Paid
	}
	now := time.Now()
	changedIDs := make([]uint, len(updates))
	nextAssignments := []models.ItemAssignment{}
	for i, u := range updates {
		pos, ok := byID[u.ItemID]
		if !ok {
			return gorm.ErrRecordNotFound
		}
		item := &b.Items[pos]
		if u.ExpectedUpdatedAt != nil && !item.UpdatedAt.Equal(*u.ExpectedUpdatedAt) {
			return ErrAssignmentConflict
		}
		if !PreservesPaidAssignments(item.Assignments, u.Assignments, paid) {
			return ErrItemAlreadyPaid
		}
		next := append([]models.ItemAssignment(nil), u.Assignments...)
		for j := range next {
			next[j].CreatedAt = time.Time{}
		}
		next = PreserveAssignmentClaimTimes(item.Assignments, next)
		for j := range next {
			if next[j].CreatedAt.IsZero() {
				next[j].CreatedAt = now
			}
			next[j].ID = 0
			next[j].BillItemID = item.ID
			next[j].UpdatedAt = time.Time{}
		}
		item.Assignments = next
		changedIDs[i] = item.ID
		nextAssignments = append(nextAssignments, next...)
	}
	var proposed []models.PersonShare
	var err error
	if b.LazyMode {
		proposed, err = BuildLazyPersonShares(&b)
	} else {
		proposed, err = BuildPersonShares(&b)
	}
	if err != nil {
		return errors.Join(mutation.Review, err)
	}
	// Explicit recorded zero participants survive refresh even without item claims.
	present := map[string]bool{}
	for _, s := range proposed {
		present[strings.ToLower(s.PersonName)] = true
	}
	for _, s := range existing {
		if !present[strings.ToLower(s.PersonName)] && s.Total == 0 && s.Subtotal == 0 && s.TaxShare == 0 && s.TipShare == 0 && len(s.Items) == 0 {
			proposed = append(proposed, models.PersonShare{BillID: b.ID, PersonName: s.PersonName, Items: s.Items})
		}
	}
	beforeUSD, afterUSD := map[string]int64{}, map[string]int64{}
	{
		b.PersonShares = existing
		before, err := FrozenUSDShareCents(b)
		if err != nil {
			return err
		}
		for i, s := range existing {
			beforeUSD[strings.ToLower(s.PersonName)] = before[i]
		}
		b.PersonShares = proposed
		after, err := FrozenUSDShareCents(b)
		if err != nil {
			return err
		}
		for i, s := range proposed {
			afterUSD[strings.ToLower(s.PersonName)] = after[i]
		}
	}
	inserts := []models.PersonShare{}
	keep := map[uint]bool{}
	for _, next := range proposed {
		key := strings.ToLower(next.PersonName)
		old, ok := oldByName[key]
		equal := ok && sameEconomics(old, next) && beforeUSD[key] == afterUSD[key]
		if ok && old.Paid && (!equal || beforeUSD[key] != afterUSD[key]) {
			return ErrItemAlreadyPaid
		}
		if equal {
			keep[old.ID] = true
		} else {
			inserts = append(inserts, next)
		}
	}
	remove := []uint{}
	for _, old := range existing {
		if !keep[old.ID] {
			if old.Paid {
				return ErrItemAlreadyPaid
			}
			remove = append(remove, old.ID)
		}
	}
	if err := tx.Where("bill_item_id IN ?", changedIDs).Delete(&models.ItemAssignment{}).Error; err != nil {
		return err
	}
	if len(nextAssignments) > 0 {
		if err := tx.CreateInBatches(&nextAssignments, 1000).Error; err != nil {
			return err
		}
	}
	if len(remove) > 0 {
		if err := tx.Where("id IN ?", remove).Delete(&models.PersonShare{}).Error; err != nil {
			return err
		}
	}
	if len(inserts) > 0 {
		if err := tx.CreateInBatches(&inserts, 500).Error; err != nil {
			return err
		}
	}
	return tx.Model(&models.BillItem{}).Where("bill_id = ? AND id IN ?", b.ID, changedIDs).Update("updated_at", now).Error
}
