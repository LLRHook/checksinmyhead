package tab

import (
	"backend/pkg/models"

	"gorm.io/gorm"
)

type TabRepository interface {
	Create(tab *models.Tab) error
	GetById(id uint) (tab *models.Tab, err error)
	Update(tab *models.Tab) error
	Delete(id uint) error
	AddBill(tabID uint, billID uint) error
}

type tabRepository struct {
	db *gorm.DB
}

func (r *tabRepository) Create(tab *models.Tab) error {
	return r.db.Create(tab).Error
}

func (r *tabRepository) GetById(id uint) (tab *models.Tab, err error) {
	tab = &models.Tab{}
	err = r.db.
		Preload("Bills.Items.Assignments").
		Preload("Bills.Participants").
		Preload("Bills.PersonShares").
		First(tab, id).Error
	return tab, err
}

func (r *tabRepository) Update(tab *models.Tab) error {
	return r.db.Model(tab).Updates(models.Tab{
		Name:        tab.Name,
		Description: tab.Description,
	}).Error
}

func (r *tabRepository) Delete(id uint) error {
	return r.db.Delete(&models.Tab{}, id).Error
}

func (r *tabRepository) AddBill(tabID uint, billID uint) error {
	return r.db.Model(&models.Bill{}).Where("id = ?", billID).Update("tab_id", tabID).Error
}

func NewTabRepository(db *gorm.DB) TabRepository {
	return &tabRepository{db: db}
}
