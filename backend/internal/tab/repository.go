package tab

import (
	"backend/pkg/models"
	"time"

	"gorm.io/gorm"
)

type TabRepository interface {
	Create(tab *models.Tab) error
	GetById(id uint) (tab *models.Tab, err error)
	Update(tab *models.Tab) error
	Delete(id uint) error
	AddBill(tabID uint, billID uint, memberID *uint) error
	Finalize(id uint) error
	GetSettlements(tabID uint) ([]models.TabSettlement, error)
	CreateSettlements(settlements []models.TabSettlement) error
	UpdateSettlementPaid(id uint, paid bool) error
	CreateMember(member *models.TabMember) error
	GetMemberByToken(token string) (*models.TabMember, error)
	GetMembersByTabID(tabID uint) ([]models.TabMember, error)
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
		Preload("Members").
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

func (r *tabRepository) AddBill(tabID uint, billID uint, memberID *uint) error {
	updates := map[string]interface{}{"tab_id": tabID}
	if memberID != nil {
		updates["added_by_member_id"] = *memberID
	}
	return r.db.Model(&models.Bill{}).Where("id = ?", billID).Updates(updates).Error
}

func (r *tabRepository) Finalize(id uint) error {
	now := time.Now()
	return r.db.Model(&models.Tab{}).Where("id = ?", id).Updates(map[string]interface{}{
		"finalized":    true,
		"finalized_at": now,
	}).Error
}

func (r *tabRepository) GetSettlements(tabID uint) ([]models.TabSettlement, error) {
	var settlements []models.TabSettlement
	err := r.db.Where("tab_id = ?", tabID).Order("amount DESC").Find(&settlements).Error
	return settlements, err
}

func (r *tabRepository) CreateSettlements(settlements []models.TabSettlement) error {
	return r.db.Create(&settlements).Error
}

func (r *tabRepository) UpdateSettlementPaid(id uint, paid bool) error {
	return r.db.Model(&models.TabSettlement{}).Where("id = ?", id).Update("paid", paid).Error
}

func (r *tabRepository) CreateMember(member *models.TabMember) error {
	return r.db.Create(member).Error
}

func (r *tabRepository) GetMemberByToken(token string) (*models.TabMember, error) {
	member := &models.TabMember{}
	err := r.db.Where("member_token = ?", token).First(member).Error
	return member, err
}

func (r *tabRepository) GetMembersByTabID(tabID uint) ([]models.TabMember, error) {
	var members []models.TabMember
	err := r.db.Where("tab_id = ?", tabID).Order("joined_at ASC").Find(&members).Error
	return members, err
}

func NewTabRepository(db *gorm.DB) TabRepository {
	return &tabRepository{db: db}
}
