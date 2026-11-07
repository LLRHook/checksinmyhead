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
	"math"
	"sort"
	"time"
	"unicode/utf8"

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
	ctx, cancel := mutation.Bound(context.Background())
	defer cancel()
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		return tx.Select(models.TabColumns).Preload("Bills", func(q *gorm.DB) *gorm.DB { return billpkg.GraphQuery(q).Order("id ASC") }).Preload("Members", func(q *gorm.DB) *gorm.DB { return q.Select(models.MemberColumns).Order("id ASC") }).First(t, id).Error
	}, &sql.TxOptions{Isolation: sql.LevelRepeatableRead, ReadOnly: true})
	if err == nil {
		for i := range t.Bills {
			billpkg.PopulateLegacyParticipants(&t.Bills[i])
		}
	}
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
	if err := tx.Select(models.TabColumns).Clauses(clause.Locking{Strength: "UPDATE"}).First(&t, a.TabID).Error; err != nil {
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
	err := tx.Select(models.MemberColumns).Where("tab_id = ?", id).Order("id ASC").Find(&result).Error
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
	var viewer *uint
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		t, err := lockAccess(tx, c.Access)
		if err != nil {
			return err
		}
		roster, err := members(tx, t.ID)
		if err != nil {
			return err
		}
		actor, err := currentMember(roster, c.Access, true, false)
		if err != nil {
			return err
		}
		if actor != nil {
			id := actor.ID
			viewer = &id
		}
		if err := tx.Select(models.SettlementColumns).Where("tab_id = ?", t.ID).Order("amount DESC, id ASC").Find(&result).Error; err != nil {
			return err
		}
		if t.Finalized {
			return validateStoredSnapshot(tx, t, result, roster)
		}
		if len(result) != 0 || t.FinalizedAt != nil {
			return mutation.Review
		}
		// Check assignment/reference completeness inside the existing locked
		// bill projection. This adds no statement or financial recalculation.
		type finalizationBill struct {
			models.Bill
			InvalidAssignmentRefs bool
		}
		var projected []finalizationBill
		columns := models.BillColumns + `, EXISTS (
 SELECT 1 FROM bill_items i JOIN item_assignments a ON a.bill_item_id=i.id
 WHERE i.bill_id=bills.id AND (a.identity_version<>2 OR a.bill_id IS DISTINCT FROM bills.id OR a.participant_id IS NULL OR
 NOT EXISTS (SELECT 1 FROM bill_participants p WHERE p.id=a.participant_id AND p.bill_id=bills.id AND p.identity_version=2) OR
 NOT EXISTS (SELECT 1 FROM person_shares s WHERE s.bill_id=bills.id AND s.participant_id=a.participant_id AND s.identity_version=2))
) AS invalid_assignment_refs`
		if err := tx.Table("bills").Session(&gorm.Session{SkipHooks: true}).Select(columns).Where("tab_id = ?", t.ID).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&projected).Error; err != nil {
			return err
		}
		bills := make([]models.Bill, len(projected))
		invalidReferences := false
		for i, p := range projected {
			bills[i] = p.Bill
			if p.IdentityVersion == 2 && p.InvalidAssignmentRefs {
				invalidReferences = true
			}
		}
		participants, err := loadFinalizationRows(tx, bills)
		if err != nil {
			return err
		}
		allocated := 0
		for _, b := range bills {
			allocated += len(b.PersonShares)
		}
		if allocated > 0 && invalidReferences {
			return billpkg.ErrIdentityReview
		}
		result, err = grossSettlements(t.ID, bills, roster)
		if err != nil {
			return err
		}
		// Scan the stored values, including PostgreSQL timestamp precision, before
		// acknowledging. A trigger may suppress rows and RETURNING may resize the
		// slice, so retain the expected count before executing the insert.
		expected := int64(len(result))
		inserted := tx.Clauses(clause.Returning{Columns: []clause.Column{
			{Name: "id"}, {Name: "tab_id"}, {Name: "person_name"},
			{Name: "amount"}, {Name: "paid"}, {Name: "created_at"},
			{Name: "snapshot_version"}, {Name: "member_id"}, {Name: "participant_id"},
		}}).CreateInBatches(&result, 500)
		if inserted.Error != nil {
			return inserted.Error
		}
		if inserted.RowsAffected != expected {
			return mutation.Review
		}
		for i := range result {
			if result[i].ParticipantID != nil {
				for _, p := range participants {
					if p.ID == *result[i].ParticipantID {
						result[i].GuestBillID = p.BillID
						break
					}
				}
			}
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
	for i := range result {
		result[i].ViewerMemberID = viewer
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
		roster, err := members(tx, t.ID)
		if err != nil {
			return err
		}
		member, err := currentMember(roster, a, false, false)
		if err != nil {
			return err
		}
		var source models.Bill
		if err := tx.Session(&gorm.Session{SkipHooks: true}).Clauses(clause.Locking{Strength: "UPDATE"}).Select(models.BillColumns).Where("id = ? AND access_token = ?", c.BillID, c.BillToken).First(&source).Error; err != nil {
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
		if t.Finalized {
			return ErrTabFinalized
		}
		expected := c.ExpectedRevision
		if c.IdentityVersion != 2 {
			v := source.IdentityRevision
			expected = &v
		}
		if source.IdentityRevision == math.MaxInt64 || expected == nil || *expected != source.IdentityRevision {
			return billpkg.ErrRevision
		}
		var memberID *uint
		if member != nil {
			memberID = &member.ID
		}
		return attachLocationLocked(tx, source, t.ID, memberID)
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
		if err := tx.Session(&gorm.Session{SkipHooks: true}).Select(models.BillColumns).Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND tab_id = ?", c.BillID, t.ID).First(&b).Error; err != nil {
			return err
		}
		t.Members = roster
		b.Tab = &t
		return billpkg.ReplaceAssignmentsLocked(tx, b, c.Updates, c.ExpectedRevision)
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
		var b models.Bill
		if err := tx.Session(&gorm.Session{SkipHooks: true}).Select(models.BillColumns).Where("id = ? AND tab_id = ?", c.BillID, t.ID).Clauses(clause.Locking{Strength: "UPDATE"}).First(&b).Error; err != nil {
			return err
		}
		if !billpkg.Ready(b) {
			return billpkg.ErrIdentityReview
		}
		if err := tx.Select(models.ParticipantColumns).Where("bill_id = ?", b.ID).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&b.ParticipantRows).Error; err != nil {
			return err
		}
		index, err := billpkg.ParticipantIndex(b)
		if err != nil {
			return err
		}
		rosterByID := map[uint]models.TabMember{}
		for _, m := range roster {
			rosterByID[m.ID] = m
		}
		for _, p := range b.ParticipantRows {
			if _, err := billpkg.PartyFor(t.ID, b, p, rosterByID); err != nil {
				return err
			}
		}
		var share models.PersonShare
		if err := tx.Select(models.ShareColumns).Where("id = ? AND bill_id = ?", c.ShareID, b.ID).Clauses(clause.Locking{Strength: "UPDATE"}).First(&share).Error; err != nil {
			return err
		}
		if share.IdentityVersion != 2 || share.ParticipantID == nil {
			return billpkg.ErrIdentityReview
		}
		p, ok := index[*share.ParticipantID]
		if !ok {
			return billpkg.ErrIdentityReview
		}
		if p.MemberID == nil || *p.MemberID != actor.ID {
			return mutation.Forbidden
		}
		if share.Paid == c.Paid {
			return nil
		}
		return tx.Model(&share).Update("paid", c.Paid).Error
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
}
func (r *tabRepository) GetSettlements(id uint) ([]models.TabSettlement, error) {
	var rows []models.TabSettlement
	err := r.db.Select(models.SettlementColumns).Where("tab_id = ?", id).Order("amount DESC, id ASC").Find(&rows).Error
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
		if err := tx.Select(models.SettlementColumns).Where("tab_id = ?", t.ID).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&rows).Error; err != nil {
			return err
		}
		if err := validateStoredSnapshot(tx, t, rows, roster); err != nil {
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
		if c.DisplayName == "" || utf8.RuneCountInString(c.DisplayName) > 30 || !utf8.ValidString(c.DisplayName) {
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
		if err := tx.Model(&models.BillParticipant{}).Where("member_id = ? OR pending_member_id = ? OR approved_by_member_id = ? OR last_binding_member_id = ? OR last_binding_actor_member_id = ?", actor.ID, actor.ID, actor.ID, actor.ID, actor.ID).Count(&count).Error; err != nil {
			return err
		}
		if count != 0 {
			return mutation.Referenced
		}
		if err := tx.Model(&models.TabSettlement{}).Where("tab_id = ? AND member_id = ?", t.ID, actor.ID).Count(&count).Error; err != nil {
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
	err := r.db.Select(models.MemberColumns).Where("member_token = ?", token).First(m).Error
	return m, err
}
func (r *tabRepository) GetMembersByTabID(id uint) ([]models.TabMember, error) {
	return members(r.db, id)
}
