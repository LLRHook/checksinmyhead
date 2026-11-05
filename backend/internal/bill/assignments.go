package bill

import (
	"backend/pkg/models"
	"backend/pkg/mutation"
	"errors"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"math"
	"strings"
	"time"
)

func ValidateAssignmentUpdates(updates []ItemAssignmentsUpdate) error {
	if len(updates) == 0 || len(updates) > 500 {
		return mutation.Invalid
	}
	count := 0
	ids := map[uint]bool{}
	for _, u := range updates {
		if u.ItemID == 0 || uint64(u.ItemID) > math.MaxInt64 || ids[u.ItemID] || len(u.Assignments) > 100 {
			return mutation.Invalid
		}
		count += len(u.Assignments)
		if count > 50000 {
			return mutation.Invalid
		}
		ids[u.ItemID] = true
		seen := map[string]bool{}
		total := 0.0
		for _, a := range u.Assignments {
			key := assignmentIdentityKey(a)
			if (a.ParticipantID == nil && (strings.TrimSpace(key) == "" || len([]rune(key)) > 30)) || (a.ParticipantID != nil && (*a.ParticipantID == 0 || uint64(*a.ParticipantID) > math.MaxInt64 || a.PersonName != "")) || seen[key] || !finite(a.Percentage) || a.Percentage <= 0 || a.Percentage > 100 {
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
func ReplaceAssignmentsLocked(tx *gorm.DB, b models.Bill, updates []ItemAssignmentsUpdate, expected ...*int64) error {
	if err := ValidateAssignmentUpdates(updates); err != nil {
		return err
	}
	if !Ready(b) {
		return ErrIdentityReview
	}
	for _, u := range updates {
		for _, a := range u.Assignments {
			if a.ParticipantID == nil {
				return ErrClientUpgrade
			}
		}
	}
	var revision *int64
	if len(expected) == 1 {
		revision = expected[0]
	}
	if revision == nil {
		return ErrClientUpgrade
	}
	if *revision < 0 {
		return mutation.Invalid
	}
	if *revision != b.IdentityRevision {
		return ErrRevision
	}
	if err := tx.Select(models.ParticipantColumns).Where("bill_id = ?", b.ID).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&b.ParticipantRows).Error; err != nil {
		return err
	}
	participants, err := ParticipantIndex(b)
	if err != nil {
		return err
	}
	if b.TabID != nil {
		if b.Tab == nil {
			return ErrIdentityReview
		}
		roster := map[uint]models.TabMember{}
		for _, m := range b.Tab.Members {
			roster[m.ID] = m
		}
		for _, p := range b.ParticipantRows {
			if _, err := PartyFor(*b.TabID, b, p, roster); err != nil {
				return err
			}
		}
	}
	for _, u := range updates {
		for _, a := range u.Assignments {
			if _, ok := participants[*a.ParticipantID]; !ok {
				return gorm.ErrRecordNotFound
			}
		}
	}
	if err := tx.Select(models.ItemColumns).Where("bill_id = ?", b.ID).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&b.Items).Error; err != nil {
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
		if err := tx.Select(models.AssignmentColumns).Where("bill_item_id IN ?", allIDs).Order("bill_item_id ASC,id ASC").Find(&assignments).Error; err != nil {
			return err
		}
	}
	for _, a := range assignments {
		if a.ParticipantID == nil || a.IdentityVersion != 2 || a.BillID == nil || *a.BillID != b.ID || participants[*a.ParticipantID].ID == 0 {
			return ErrIdentityReview
		}
		i := byID[a.BillItemID]
		b.Items[i].Assignments = append(b.Items[i].Assignments, a)
	}
	var existing []models.PersonShare
	if err := tx.Select(models.ShareColumns).Where("bill_id = ?", b.ID).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&existing).Error; err != nil {
		return err
	}
	oldByName := map[string]models.PersonShare{}
	paid := map[string]bool{}
	for _, s := range existing {
		key := shareKey(&b, s)
		if _, ok := oldByName[key]; ok {
			return mutation.Review
		}
		oldByName[key] = s
		paid[key] = s.Paid
	}
	b.PersonShares = existing
	if err := ValidateReferenceGraph(b); err != nil {
		return err
	}
	if _, err := FrozenUSDShareCents(b); err != nil {
		return err
	}
	now := time.Now()
	changedIDs := []uint{}
	nextAssignments := []models.ItemAssignment{}
	for _, u := range updates {
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
		if assignmentSetsEqual(item.Assignments, u.Assignments) {
			continue
		}
		next := append([]models.ItemAssignment(nil), u.Assignments...)
		for j := range next {
			next[j].CreatedAt = time.Time{}
			next[j].PersonName = participants[*next[j].ParticipantID].Label
			bid := b.ID
			next[j].BillID = &bid
			next[j].IdentityVersion = 2
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
		changedIDs = append(changedIDs, item.ID)
		nextAssignments = append(nextAssignments, next...)
	}
	if len(changedIDs) == 0 {
		return nil
	}
	nextRevision, err := revisionNext(b, revision)
	if err != nil {
		return err
	}
	var proposed []models.PersonShare
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
		present[shareKey(&b, s)] = true
	}
	for _, s := range existing {
		if !present[shareKey(&b, s)] && s.Total == 0 && s.Subtotal == 0 && s.TaxShare == 0 && s.TipShare == 0 && len(s.Items) == 0 {
			proposed = append(proposed, models.PersonShare{BillID: b.ID, PersonName: s.PersonName, Items: s.Items, IdentityVersion: 2, ParticipantID: s.ParticipantID})
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
			beforeUSD[shareKey(&b, s)] = before[i]
		}
		b.PersonShares = proposed
		after, err := FrozenUSDShareCents(b)
		if err != nil {
			return err
		}
		for i, s := range proposed {
			afterUSD[shareKey(&b, s)] = after[i]
		}
	}
	inserts := []models.PersonShare{}
	keep := map[uint]bool{}
	for _, next := range proposed {
		key := shareKey(&b, next)
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
		if err := insertCheckedBatches(tx, nextAssignments, 1000); err != nil {
			return err
		}
	}
	if len(remove) > 0 {
		if err := tx.Where("id IN ?", remove).Delete(&models.PersonShare{}).Error; err != nil {
			return err
		}
	}
	if len(inserts) > 0 {
		if err := insertCheckedBatches(tx, inserts, 500); err != nil {
			return err
		}
	}
	updated := tx.Model(&models.BillItem{}).Where("bill_id = ? AND id IN ?", b.ID, changedIDs).Update("updated_at", now)
	if updated.Error != nil {
		return updated.Error
	}
	if updated.RowsAffected != int64(len(changedIDs)) {
		return ErrIdentityReview
	}
	return AdvanceRevisionLocked(tx, b, nextRevision)
}
