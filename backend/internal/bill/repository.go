package bill

import (
	"backend/pkg/models"

	"gorm.io/gorm"
)

type BillRepository interface {
	Create(bill *models.Bill) error
	GetById(id uint) (bill *models.Bill, err error)
	Update(bill *models.Bill) error
	Delete(id uint) error
}

type billRepository struct {
	db *gorm.DB
}

func (b *billRepository) Create(bill *models.Bill) error {
	return b.db.Create(bill).Error
}

func (b *billRepository) Delete(id uint) error {
	return b.db.Delete(&models.Bill{}, id).Error
}

func (b *billRepository) GetById(id uint) (bill *models.Bill, err error) {
	bill = &models.Bill{}
	err = b.db.
		Preload("Items.Assignments").
		Preload("Participants").
		Preload("PersonShares").
		First(bill, id).Error
	return bill, err
}

func (b *billRepository) Update(bill *models.Bill) error {
	return b.db.Session(&gorm.Session{FullSaveAssociations: true}).Updates(bill).Error
}

func NewBillRepository(db *gorm.DB) BillRepository {
	return &billRepository{db: db}
}
