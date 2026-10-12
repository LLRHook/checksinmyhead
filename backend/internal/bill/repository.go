package bill

import (
	"backend/pkg/models"
	"strings"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type BillRepository interface {
	Create(bill *models.Bill) error
	GetById(id uint) (bill *models.Bill, err error)
	UpdatePersonSharePaid(id uint, paid bool) error
	UpdateItemAssignments(billID uint, itemID uint, assignments []models.ItemAssignment, expectedUpdatedAt *time.Time) error
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

func (b *billRepository) UpdatePersonSharePaid(id uint, paid bool) error {
	return b.db.Model(&models.PersonShare{}).Where("id = ?", id).Update("paid", paid).Error
}

func (b *billRepository) UpdateItemAssignments(billID uint, itemID uint, assignments []models.ItemAssignment, expectedUpdatedAt *time.Time) error {
	return b.db.Transaction(func(tx *gorm.DB) error {
		var bill models.Bill
		if err := tx.Where("id = ? AND lazy_mode = ?", billID, true).First(&bill).Error; err != nil {
			return err
		}

		var item models.BillItem
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND bill_id = ?", itemID, billID).First(&item).Error; err != nil {
			return err
		}
		if expectedUpdatedAt != nil && !item.UpdatedAt.Equal(*expectedUpdatedAt) {
			return ErrAssignmentConflict
		}

		var currentAssignments []models.ItemAssignment
		if err := tx.Where("bill_item_id = ?", itemID).Find(&currentAssignments).Error; err != nil {
			return err
		}
		for _, assignment := range currentAssignments {
			var paidCount int64
			if err := tx.Model(&models.PersonShare{}).Where("bill_id = ? AND LOWER(person_name) = LOWER(?) AND paid = ?", billID, assignment.PersonName, true).Count(&paidCount).Error; err != nil {
				return err
			}
			if paidCount > 0 {
				return ErrItemAlreadyPaid
			}
		}

		var existingShares []models.PersonShare
		if err := tx.Where("bill_id = ?", billID).Find(&existingShares).Error; err != nil {
			return err
		}
		paidByName := make(map[string]bool, len(existingShares))
		for _, share := range existingShares {
			paidByName[strings.ToLower(share.PersonName)] = share.Paid
		}

		if err := tx.Where("bill_item_id = ?", itemID).Delete(&models.ItemAssignment{}).Error; err != nil {
			return err
		}
		for i := range assignments {
			assignments[i].BillItemID = itemID
		}
		if len(assignments) > 0 {
			if err := tx.Create(&assignments).Error; err != nil {
				return err
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
		return tx.Model(&models.BillItem{}).Where("id = ?", itemID).Update("updated_at", time.Now()).Error
	})
}

func NewBillRepository(db *gorm.DB) BillRepository {
	return &billRepository{db: db}
}
