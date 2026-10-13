package bill

import (
	"backend/pkg/models"
	"errors"
	"math"
	"sort"
	"strings"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type BillRepository interface {
	Create(bill *models.Bill) error
	GetById(id uint) (bill *models.Bill, err error)
	UpdatePersonSharePaid(billID uint, personName string, paid bool) error
	UpdateItemAssignments(billID uint, itemID uint, assignments []models.ItemAssignment, expectedUpdatedAt *time.Time) error
	UpdateItemAssignmentsBatch(billID uint, updates []ItemAssignmentsUpdate) error
}

type ItemAssignmentsUpdate struct {
	ItemID            uint
	Assignments       []models.ItemAssignment
	ExpectedUpdatedAt *time.Time
}

type billRepository struct {
	db *gorm.DB
}

func (b *billRepository) Create(bill *models.Bill) error {
	return b.db.Create(bill).Error
}

func (b *billRepository) GetById(id uint) (bill *models.Bill, err error) {
	bill = &models.Bill{}
	err = b.db.
		Preload("Tab").
		Preload("Items.Assignments").
		Preload("Participants").
		Preload("PersonShares").
		First(bill, id).Error
	return bill, err
}

func (b *billRepository) UpdatePersonSharePaid(billID uint, personName string, paid bool) error {
	return b.db.Transaction(func(tx *gorm.DB) error {
		var bill models.Bill
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Select("id").First(&bill, billID).Error; err != nil {
			return err
		}

		var share models.PersonShare
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("bill_id = ? AND LOWER(person_name) = ?", billID, strings.ToLower(personName)).
			First(&share).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrPersonShareNotFound
			}
			return err
		}
		return tx.Model(&share).Update("paid", paid).Error
	})
}

func (b *billRepository) UpdateItemAssignments(billID uint, itemID uint, assignments []models.ItemAssignment, expectedUpdatedAt *time.Time) error {
	return b.UpdateItemAssignmentsBatch(billID, []ItemAssignmentsUpdate{{
		ItemID: itemID, Assignments: assignments, ExpectedUpdatedAt: expectedUpdatedAt,
	}})
}

func (b *billRepository) UpdateItemAssignmentsBatch(billID uint, updates []ItemAssignmentsUpdate) error {
	updates = append([]ItemAssignmentsUpdate(nil), updates...)
	sort.Slice(updates, func(i, j int) bool { return updates[i].ItemID < updates[j].ItemID })
	for i := 1; i < len(updates); i++ {
		if updates[i-1].ItemID == updates[i].ItemID {
			return gorm.ErrInvalidData
		}
	}
	if len(updates) == 0 {
		return nil
	}

	return b.db.Transaction(func(tx *gorm.DB) error {
		var bill models.Bill
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND lazy_mode = ?", billID, true).First(&bill).Error; err != nil {
			return err
		}

		var existingShares []models.PersonShare
		if err := tx.Where("bill_id = ?", billID).Find(&existingShares).Error; err != nil {
			return err
		}
		paidByName := make(map[string]bool, len(existingShares))
		for _, share := range existingShares {
			paidByName[strings.ToLower(share.PersonName)] = share.Paid
		}

		for _, update := range updates {
			var item models.BillItem
			if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND bill_id = ?", update.ItemID, billID).First(&item).Error; err != nil {
				return err
			}
			if update.ExpectedUpdatedAt != nil && !item.UpdatedAt.Equal(*update.ExpectedUpdatedAt) {
				return ErrAssignmentConflict
			}

			var currentAssignments []models.ItemAssignment
			if err := tx.Where("bill_item_id = ?", update.ItemID).Find(&currentAssignments).Error; err != nil {
				return err
			}
			if !PreservesPaidAssignments(currentAssignments, update.Assignments, paidByName) {
				return ErrItemAlreadyPaid
			}
			update.Assignments = PreserveAssignmentClaimTimes(currentAssignments, update.Assignments)

			if err := tx.Where("bill_item_id = ?", update.ItemID).Delete(&models.ItemAssignment{}).Error; err != nil {
				return err
			}
			for i := range update.Assignments {
				update.Assignments[i].BillItemID = update.ItemID
			}
			if len(update.Assignments) > 0 {
				if err := tx.Create(&update.Assignments).Error; err != nil {
					return err
				}
			}
		}

		if err := tx.Where("bill_id = ?", billID).Delete(&models.PersonShare{}).Error; err != nil {
			return err
		}
		var refreshed models.Bill
		if err := tx.Preload("Items.Assignments").Where("id = ?", billID).First(&refreshed).Error; err != nil {
			return err
		}
		shares := BuildLazyPersonShares(&refreshed)
		for i := range shares {
			shares[i].Paid = paidByName[strings.ToLower(shares[i].PersonName)]
		}
		if len(shares) > 0 {
			if err := tx.Create(&shares).Error; err != nil {
				return err
			}
		}
		now := time.Now()
		for _, update := range updates {
			if err := tx.Model(&models.BillItem{}).Where("id = ?", update.ItemID).Update("updated_at", now).Error; err != nil {
				return err
			}
		}
		return nil
	})
}

// PreservesPaidAssignments prevents changes to already-paid portions while
// allowing unpaid percentages of the same item to remain claimable.
func PreservesPaidAssignments(current, next []models.ItemAssignment, paidByName map[string]bool) bool {
	currentByName := make(map[string]float64, len(current))
	nextByName := make(map[string]float64, len(next))
	for _, existing := range current {
		currentByName[strings.ToLower(existing.PersonName)] = existing.Percentage
	}
	for _, candidate := range next {
		nextByName[strings.ToLower(candidate.PersonName)] = candidate.Percentage
	}
	for name, percentage := range currentByName {
		if paidByName[name] && math.Abs(nextByName[name]-percentage) >= 0.01 {
			return false
		}
	}
	for name, percentage := range nextByName {
		if paidByName[name] && math.Abs(currentByName[name]-percentage) >= 0.01 {
			return false
		}
	}
	return true
}

func PreserveAssignmentClaimTimes(current, next []models.ItemAssignment) []models.ItemAssignment {
	createdAtByName := make(map[string]time.Time, len(current))
	for _, assignment := range current {
		createdAtByName[strings.ToLower(assignment.PersonName)] = assignment.CreatedAt
	}
	for i := range next {
		if createdAt, ok := createdAtByName[strings.ToLower(next[i].PersonName)]; ok {
			next[i].CreatedAt = createdAt
		}
	}
	return next
}

func NewBillRepository(db *gorm.DB) BillRepository {
	return &billRepository{db: db}
}
