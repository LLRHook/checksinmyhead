package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"backend/pkg/security"
	"context"
	"crypto/subtle"
	"database/sql"
	"errors"
	"sort"
	"strings"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type BillItemAssignmentsUpdate = billpkg.ItemAssignmentsUpdate

type TabRepository interface {
	Create(context.Context, *models.Tab, *models.TabMember) error
	GetById(uint) (*models.Tab, error)
	GetAuthById(uint) (*models.Tab, error)
	Update(context.Context, SettingsCommand) error
	AttachBill(context.Context, AttachBillCommand) error
	UpdateBillItemAssignmentsBatch(context.Context, AssignmentCommand) error
	UpdateBillPersonSharePaid(context.Context, SharePaidCommand) error
	FinalizeOnce(context.Context, FinalizeCommand) ([]models.TabSettlement, error)
	GetSettlements(uint) ([]models.TabSettlement, error)
	UpdateSettlementPaid(context.Context, SettlementPaidCommand) error
	Join(context.Context, JoinCommand) (*models.TabMember, bool, error)
	GetMemberByToken(string) (*models.TabMember, error)
	GetMembersByTabID(uint) ([]models.TabMember, error)
	Leave(context.Context, LeaveCommand) error
}
type tabRepository struct{ db *gorm.DB }

func NewTabRepository(db *gorm.DB) TabRepository { return &tabRepository{db} }
func (r *tabRepository) Create(ctx context.Context, t *models.Tab, creator *models.TabMember) error {
	if t.ID != 0 || len(t.Bills) != 0 || len(t.Members) != 0 || t.Finalized || t.FinalizedAt != nil {
		return mutation.Invalid
	}
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(t).Error; err != nil {
			return err
		}
		if creator != nil {
			creator.TabID = t.ID
			creator.Role = "creator"
			return tx.Create(creator).Error
		}
		return nil
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
}
func (r *tabRepository) GetById(id uint) (*models.Tab, error) {
	t := &models.Tab{}
	err := r.db.Preload("Bills.Items.Assignments").Preload("Bills.Participants").Preload("Bills.PersonShares").Preload("Members").First(t, id).Error
	return t, err
}
func (r *tabRepository) GetAuthById(id uint) (*models.Tab, error) {
	t := &models.Tab{}
	err := r.db.Select("id", "access_token", "finalized").First(t, id).Error
	return t, err
}

// lockAccess is only called at the beginning of a tab transaction, before any
// bill/item/share lock. Membership writers use the same root lock.
func lockAccess(tx *gorm.DB, a TabAccess) (models.Tab, error) {
	var t models.Tab
	if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(&t, a.TabID).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return t, mutation.Forbidden
		}
		return t, err
	}
	if a.TabToken == "" || t.AccessToken == "" || subtle.ConstantTimeCompare([]byte(a.TabToken), []byte(t.AccessToken)) != 1 {
		return t, mutation.Forbidden
	}
	return t, nil
}
func members(tx *gorm.DB, id uint) ([]models.TabMember, error) {
	var result []models.TabMember
	err := tx.Where("tab_id = ?", id).Order("id ASC").Find(&result).Error
	return result, err
}
func currentMember(rows []models.TabMember, a TabAccess, creator, required bool) (*models.TabMember, error) {
	if a.MemberToken != "" {
		for i := range rows {
			if subtle.ConstantTimeCompare([]byte(rows[i].MemberToken), []byte(a.MemberToken)) == 1 {
				if creator && rows[i].Role != "creator" {
					return nil, mutation.Forbidden
				}
				return &rows[i], nil
			}
		}
		return nil, mutation.Forbidden
	}
	if required || len(rows) != 0 {
		return nil, mutation.Forbidden
	}
	return nil, nil
}
func (r *tabRepository) FinalizeOnce(ctx context.Context, c FinalizeCommand) ([]models.TabSettlement, error) {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	var result []models.TabSettlement
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		t, err := lockAccess(tx, c.Access)
		if err != nil {
			return err
		}
		roster, err := members(tx, t.ID)
		if err != nil {
			return err
		}
		if _, err = currentMember(roster, c.Access, true, false); err != nil {
			return err
		}
		if err := tx.Where("tab_id = ?", t.ID).Order("amount DESC, id ASC").Find(&result).Error; err != nil {
			return err
		}
		if t.Finalized {
			return validStoredSnapshot(t, result)
		}
		if len(result) != 0 || t.FinalizedAt != nil {
			return mutation.Review
		}
		labels := map[string]bool{}
		for _, m := range roster {
			key := strings.ToLower(strings.TrimSpace(m.DisplayName))
			if strings.TrimSpace(key) == "" || labels[key] {
				return mutation.Review
			}
			labels[key] = true
		}
		// A projection without Bill's AfterFind hook or association graph.
		type accountingBill struct {
			ID                                   uint
			Total                                float64
			CurrencyCode                         string
			USDExchangeRate, USDTotal            float64
			ExchangeRateSource, ExchangeRateDate string
		}
		var projected []accountingBill
		if err := tx.Table("bills").Select("id,total,currency_code,usd_exchange_rate,usd_total,exchange_rate_source,exchange_rate_date").Where("tab_id = ?", t.ID).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&projected).Error; err != nil {
			return err
		}
		ids := make([]uint, len(projected))
		bills := make([]models.Bill, len(projected))
		byID := map[uint]int{}
		for i, p := range projected {
			ids[i] = p.ID
			byID[p.ID] = i
			bills[i] = models.Bill{ID: p.ID, Total: p.Total, CurrencyCode: p.CurrencyCode, USDExchangeRate: p.USDExchangeRate, USDTotal: p.USDTotal, ExchangeRateSource: p.ExchangeRateSource, ExchangeRateDate: p.ExchangeRateDate}
		}
		var shares []models.PersonShare
		if len(ids) > 0 {
			if err := tx.Select("id,bill_id,person_name,subtotal,tax_share,tip_share,total").Where("bill_id IN ?", ids).Order("bill_id ASC, id ASC").Find(&shares).Error; err != nil {
				return err
			}
		}
		for _, s := range shares {
			i := byID[s.BillID]
			bills[i].PersonShares = append(bills[i].PersonShares, s)
		}
		result, err = grossSettlements(t.ID, bills)
		if err != nil {
			return err
		}
		if err := tx.CreateInBatches(&result, 500).Error; err != nil {
			return err
		}
		now := time.Now()
		updated := tx.Model(&models.Tab{}).Where("id = ? AND finalized = ?", t.ID, false).Updates(map[string]any{"finalized": true, "finalized_at": now})
		if updated.Error != nil {
			return updated.Error
		}
		if updated.RowsAffected != 1 {
			return mutation.Review
		}
		sort.Slice(result, func(i, j int) bool {
			if result[i].Amount != result[j].Amount {
				return result[i].Amount > result[j].Amount
			}
			return result[i].ID < result[j].ID
		})
		return nil
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		return nil, err
	}
	return result, nil
}
func (r *tabRepository) AttachBill(ctx context.Context, c AttachBillCommand) error {
	if err := validateAttach(c); err != nil {
		return err
	}
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		a := TabAccess{c.TabID, c.TabToken, c.MemberToken}
		t, err := lockAccess(tx, a)
		if err != nil {
			return err
		}
		if t.Finalized {
			return ErrTabFinalized
		}
		roster, err := members(tx, t.ID)
		if err != nil {
			return err
		}
		member, err := currentMember(roster, a, false, false)
		if err != nil {
			return err
		}
		var source models.Bill
		if err := tx.Session(&gorm.Session{SkipHooks: true}).Clauses(clause.Locking{Strength: "UPDATE"}).Select("id", "tab_id", "access_token").Where("id = ? AND access_token = ?", c.BillID, c.BillToken).First(&source).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return ErrSourceUnavailable
			}
			return err
		}
		if source.TabID != nil {
			if *source.TabID == t.ID {
				return nil
			}
			return ErrSourceUnavailable
		}
		var memberID *uint
		if member != nil {
			memberID = &member.ID
		}
		updated := tx.Model(&source).Updates(map[string]any{"tab_id": t.ID, "added_by_member_id": memberID, "paid_by_member_id": memberID})
		return updated.Error
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
}
func (r *tabRepository) UpdateBillItemAssignmentsBatch(ctx context.Context, c AssignmentCommand) error {
	if err := billpkg.ValidateAssignmentUpdates(c.Updates); err != nil {
		return err
	}
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		t, err := lockAccess(tx, c.Access)
		if err != nil {
			return err
		}
		roster, err := members(tx, t.ID)
		if err != nil {
			return err
		}
		if _, err = currentMember(roster, c.Access, false, false); err != nil {
			return err
		}
		if t.Finalized {
			return ErrTabFinalized
		}
		var b models.Bill
		if err := tx.Session(&gorm.Session{SkipHooks: true}).Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND tab_id = ?", c.BillID, t.ID).First(&b).Error; err != nil {
			return err
		}
		return billpkg.ReplaceAssignmentsLocked(tx, b, c.Updates)
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
}
func (r *tabRepository) UpdateBillPersonSharePaid(ctx context.Context, c SharePaidCommand) error {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		t, err := lockAccess(tx, c.Access)
		if err != nil {
			return err
		}
		roster, err := members(tx, t.ID)
		if err != nil {
			return err
		}
		actor, err := currentMember(roster, c.Access, false, true)
		if err != nil {
			return err
		}
		matches := 0
		for _, m := range roster {
			if strings.EqualFold(m.DisplayName, actor.DisplayName) {
				matches++
			}
		}
		if matches != 1 {
			return mutation.Review
		}
		var b models.Bill
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Select("id").Where("id = ? AND tab_id = ?", c.BillID, t.ID).First(&b).Error; err != nil {
			return err
		}
		var share models.PersonShare
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND bill_id = ?", c.ShareID, c.BillID).First(&share).Error; err != nil {
			return err
		}
		if !strings.EqualFold(share.PersonName, actor.DisplayName) {
			return mutation.Forbidden
		}
		var count int64
		if err := tx.Model(&models.PersonShare{}).Where("bill_id = ? AND LOWER(person_name) = ?", c.BillID, strings.ToLower(share.PersonName)).Count(&count).Error; err != nil {
			return err
		}
		if count != 1 {
			return mutation.Review
		}
		if share.Paid == c.Paid {
			return nil
		}
		return tx.Model(&share).Update("paid", c.Paid).Error
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
}
func (r *tabRepository) GetSettlements(id uint) ([]models.TabSettlement, error) {
	var rows []models.TabSettlement
	err := r.db.Where("tab_id = ?", id).Order("amount DESC, id ASC").Find(&rows).Error
	return rows, err
}
func (r *tabRepository) UpdateSettlementPaid(ctx context.Context, c SettlementPaidCommand) error {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		t, err := lockAccess(tx, c.Access)
		if err != nil {
			return err
		}
		roster, err := members(tx, t.ID)
		if err != nil {
			return err
		}
		if _, err = currentMember(roster, c.Access, false, false); err != nil {
			return err
		}
		var rows []models.TabSettlement
		if err := tx.Where("tab_id = ?", t.ID).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&rows).Error; err != nil {
			return err
		}
		if err := validStoredSnapshot(t, rows); err != nil {
			return err
		}
		for _, s := range rows {
			if s.ID == c.SettlementID {
				if s.Paid == c.Paid {
					return nil
				}
				return tx.Model(&s).Update("paid", c.Paid).Error
			}
		}
		return gorm.ErrRecordNotFound
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
}
func (r *tabRepository) Update(ctx context.Context, c SettingsCommand) error {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		t, err := lockAccess(tx, c.Access)
		if err != nil {
			return err
		}
		roster, err := members(tx, t.ID)
		if err != nil {
			return err
		}
		if _, err = currentMember(roster, c.Access, true, false); err != nil {
			return err
		}
		if t.Finalized {
			return ErrTabFinalized
		}
		values := map[string]any{}
		// Retain the existing zero-value omission contract for name/description.
		if c.Name != nil && *c.Name != "" {
			values["name"] = *c.Name
		}
		if c.Description != nil && *c.Description != "" {
			values["description"] = *c.Description
		}
		if c.DisplayCurrency != nil {
			values["display_currency"] = *c.DisplayCurrency
		}
		if len(values) == 0 {
			return nil
		}
		return tx.Model(&t).Updates(values).Error
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
}
func (r *tabRepository) Join(ctx context.Context, c JoinCommand) (*models.TabMember, bool, error) {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	var result *models.TabMember
	replay := false
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		t, err := lockAccess(tx, c.Access)
		if err != nil {
			return err
		}
		if c.Access.MemberToken != "" {
			rows, err := members(tx, t.ID)
			if err != nil {
				return err
			}
			result, err = currentMember(rows, c.Access, false, true)
			replay = err == nil
			return err
		}
		if c.DisplayName == "" || len(c.DisplayName) > 30 {
			return mutation.Invalid
		}
		token, err := security.GenerateSecureToken()
		if err != nil {
			return err
		}
		result = &models.TabMember{TabID: t.ID, DisplayName: c.DisplayName, MemberToken: token, Role: "member", JoinedAt: time.Now()}
		return tx.Create(result).Error
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		return nil, false, err
	}
	return result, replay, nil
}
func (r *tabRepository) Leave(ctx context.Context, c LeaveCommand) error {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		t, err := lockAccess(tx, c.Access)
		if err != nil {
			return err
		}
		roster, err := members(tx, t.ID)
		if err != nil {
			return err
		}
		actor, err := currentMember(roster, c.Access, false, true)
		if err != nil {
			return err
		}
		if actor.Role == "creator" {
			return mutation.CreatorLeave
		}
		var count int64
		if err := tx.Model(&models.Bill{}).Where("added_by_member_id = ? OR paid_by_member_id = ?", actor.ID, actor.ID).Count(&count).Error; err != nil {
			return err
		}
		if count != 0 {
			return mutation.Referenced
		}
		return tx.Delete(actor).Error
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
}
func (r *tabRepository) GetMemberByToken(token string) (*models.TabMember, error) {
	m := &models.TabMember{}
	err := r.db.Where("member_token = ?", token).First(m).Error
	return m, err
}
func (r *tabRepository) GetMembersByTabID(id uint) ([]models.TabMember, error) {
	return members(r.db, id)
}
