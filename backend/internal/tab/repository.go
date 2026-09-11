package tab

import (
	"backend/pkg/models"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var ErrAssignmentConflict = errors.New("bill item changed since it was loaded")

type TabRepository interface {
	Create(tab *models.Tab) error
	GetById(id uint) (tab *models.Tab, err error)
	GetAuthById(id uint) (tab *models.Tab, err error)
	GetForFinalization(id uint) (tab *models.Tab, err error)
	Update(tab *models.Tab) error
	Delete(id uint) error
	AddBill(tabID uint, billID uint, billToken string, memberID *uint) error
	UpdateBillItemAssignments(tabID uint, billID uint, itemID uint, assignments []models.ItemAssignment, expectedUpdatedAt *time.Time) error
	UpdateBillPersonSharePaid(tabID uint, billID uint, shareID uint, paid bool) error
	Finalize(id uint) error
	GetSettlements(tabID uint) ([]models.TabSettlement, error)
	CreateSettlements(settlements []models.TabSettlement) error
	UpdateSettlementPaid(id uint, paid bool) error
	CreateMember(member *models.TabMember) error
	GetMemberByToken(token string) (*models.TabMember, error)
	GetMembersByTabID(tabID uint) ([]models.TabMember, error)
	DeleteMember(tabID uint, memberID uint) error
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

func (r *tabRepository) GetAuthById(id uint) (tab *models.Tab, err error) {
	tab = &models.Tab{}
	err = r.db.
		Select("id", "access_token", "finalized").
		First(tab, id).Error
	return tab, err
}

func (r *tabRepository) GetForFinalization(id uint) (tab *models.Tab, err error) {
	tab = &models.Tab{}
	err = r.db.
		Preload("Bills.PersonShares").
		First(tab, id).Error
	return tab, err
}

func (r *tabRepository) Update(tab *models.Tab) error {
	return r.db.Model(tab).Updates(models.Tab{
		Name:            tab.Name,
		Description:     tab.Description,
		DisplayCurrency: tab.DisplayCurrency,
	}).Error
}

func (r *tabRepository) Delete(id uint) error {
	return r.db.Delete(&models.Tab{}, id).Error
}

func (r *tabRepository) AddBill(tabID uint, billID uint, billToken string, memberID *uint) error {
	updates := map[string]interface{}{"tab_id": tabID}
	if memberID != nil {
		updates["added_by_member_id"] = *memberID
		updates["paid_by_member_id"] = *memberID
	}
	query := r.db.Model(&models.Bill{}).Where("id = ? AND (tab_id IS NULL OR tab_id = ?)", billID, tabID)
	if billToken != "" {
		query = query.Where("access_token = ?", billToken)
	}
	result := query.Updates(updates)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func (r *tabRepository) UpdateBillItemAssignments(tabID uint, billID uint, itemID uint, assignments []models.ItemAssignment, expectedUpdatedAt *time.Time) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		var bill models.Bill
		if err := tx.
			Where("id = ? AND tab_id = ?", billID, tabID).
			First(&bill).Error; err != nil {
			return err
		}

		var item models.BillItem
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND bill_id = ?", itemID, billID).First(&item).Error; err != nil {
			if err == gorm.ErrRecordNotFound {
				return err
			}
			return err
		}
		if expectedUpdatedAt != nil && !item.UpdatedAt.Equal(*expectedUpdatedAt) {
			return ErrAssignmentConflict
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
		if err := tx.
			Preload("Items.Assignments").
			Where("id = ?", billID).
			First(&refreshed).Error; err != nil {
			return err
		}

		shares := buildPersonShares(&refreshed)
		if len(shares) == 0 {
			return tx.Model(&models.BillItem{}).Where("id = ?", itemID).Update("updated_at", time.Now()).Error
		}
		if err := tx.Create(&shares).Error; err != nil {
			return err
		}
		return tx.Model(&models.BillItem{}).Where("id = ?", itemID).Update("updated_at", time.Now()).Error
	})
}

func (r *tabRepository) UpdateBillPersonSharePaid(tabID uint, billID uint, shareID uint, paid bool) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		var share models.PersonShare
		if err := tx.Joins("JOIN bills ON bills.id = person_shares.bill_id").Where("person_shares.id = ? AND person_shares.bill_id = ? AND bills.tab_id = ?", shareID, billID, tabID).First(&share).Error; err != nil {
			return err
		}
		return tx.Model(&models.PersonShare{}).Where("id = ?", shareID).Update("paid", paid).Error
	})
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

func (r *tabRepository) DeleteMember(tabID uint, memberID uint) error {
	result := r.db.Where("id = ? AND tab_id = ? AND role <> ?", memberID, tabID, "creator").Delete(&models.TabMember{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func NewTabRepository(db *gorm.DB) TabRepository {
	return &tabRepository{db: db}
}
