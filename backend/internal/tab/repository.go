package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"errors"
	"sort"
	"strings"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var ErrAssignmentConflict = errors.New("bill item changed since it was loaded")
var ErrItemAlreadyPaid = errors.New("item belongs to a paid share")
var ErrDuplicateItemUpdate = errors.New("bill item appears more than once in assignment updates")

type BillItemAssignmentsUpdate struct {
	ItemID            uint
	Assignments       []models.ItemAssignment
	ExpectedUpdatedAt *time.Time
}

type TabRepository interface {
	Create(tab *models.Tab) error
	GetById(id uint) (tab *models.Tab, err error)
	GetAuthById(id uint) (tab *models.Tab, err error)
	GetForFinalization(id uint) (tab *models.Tab, err error)
	Update(tab *models.Tab) error
	AddBill(tabID uint, billID uint, billToken string, memberID *uint) error
	UpdateBillItemAssignments(tabID uint, billID uint, itemID uint, assignments []models.ItemAssignment, expectedUpdatedAt *time.Time) error
	UpdateBillItemAssignmentsBatch(tabID uint, billID uint, updates []BillItemAssignmentsUpdate) error
	UpdateBillPersonSharePaid(tabID uint, billID uint, shareID uint, paid bool) error
	Finalize(id uint) error
	GetSettlements(tabID uint) ([]models.TabSettlement, error)
	CreateSettlements(settlements []models.TabSettlement) error
	UpdateSettlementPaid(tabID uint, id uint, paid bool) error
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
	return r.UpdateBillItemAssignmentsBatch(tabID, billID, []BillItemAssignmentsUpdate{{
		ItemID: itemID, Assignments: assignments, ExpectedUpdatedAt: expectedUpdatedAt,
	}})
}

func (r *tabRepository) UpdateBillItemAssignmentsBatch(tabID uint, billID uint, updates []BillItemAssignmentsUpdate) error {
	if len(updates) == 0 {
		return errors.New("item assignment updates are required")
	}
	updates = append([]BillItemAssignmentsUpdate(nil), updates...)
	sort.Slice(updates, func(i, j int) bool { return updates[i].ItemID < updates[j].ItemID })
	for i := 1; i < len(updates); i++ {
		if updates[i-1].ItemID == updates[i].ItemID {
			return ErrDuplicateItemUpdate
		}
	}

	return r.db.Transaction(func(tx *gorm.DB) error {
		var bill models.Bill
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("id = ? AND tab_id = ?", billID, tabID).
			First(&bill).Error; err != nil {
			return err
		}

		for _, update := range updates {
			var item models.BillItem
			if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND bill_id = ?", update.ItemID, billID).First(&item).Error; err != nil {
				return err
			}
			if update.ExpectedUpdatedAt != nil && !item.UpdatedAt.Equal(*update.ExpectedUpdatedAt) {
				return ErrAssignmentConflict
			}
		}

		var existingShares []models.PersonShare
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("bill_id = ?", billID).Find(&existingShares).Error; err != nil {
			return err
		}
		paidByName := make(map[string]bool, len(existingShares))
		for _, share := range existingShares {
			paidByName[strings.ToLower(share.PersonName)] = share.Paid
		}
		for _, update := range updates {
			var currentAssignments []models.ItemAssignment
			if err := tx.Where("bill_item_id = ?", update.ItemID).Find(&currentAssignments).Error; err != nil {
				return err
			}
			for _, assignment := range currentAssignments {
				if paidByName[strings.ToLower(assignment.PersonName)] {
					return ErrItemAlreadyPaid
				}
			}
			for _, assignment := range update.Assignments {
				if paidByName[strings.ToLower(assignment.PersonName)] {
					return ErrItemAlreadyPaid
				}
			}

			if err := tx.Where("bill_item_id = ?", update.ItemID).Delete(&models.ItemAssignment{}).Error; err != nil {
				return err
			}
			assignments := append([]models.ItemAssignment(nil), update.Assignments...)
			for i := range assignments {
				assignments[i].BillItemID = update.ItemID
			}
			if len(assignments) > 0 {
				if err := tx.Create(&assignments).Error; err != nil {
					return err
				}
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

		shares := billpkg.BuildPersonShares(&refreshed)
		for i := range shares {
			shares[i].Paid = paidByName[strings.ToLower(shares[i].PersonName)]
		}
		if len(shares) > 0 {
			if err := tx.Create(&shares).Error; err != nil {
				return err
			}
		}
		itemIDs := make([]uint, len(updates))
		for i, update := range updates {
			itemIDs[i] = update.ItemID
		}
		return tx.Model(&models.BillItem{}).Where("id IN ?", itemIDs).Update("updated_at", time.Now()).Error
	})
}

func (r *tabRepository) UpdateBillPersonSharePaid(tabID uint, billID uint, shareID uint, paid bool) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		var bill models.Bill
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND tab_id = ?", billID, tabID).First(&bill).Error; err != nil {
			return err
		}
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

func (r *tabRepository) UpdateSettlementPaid(tabID uint, id uint, paid bool) error {
	result := r.db.Model(&models.TabSettlement{}).Where("id = ? AND tab_id = ?", id, tabID).Update("paid", paid)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
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
