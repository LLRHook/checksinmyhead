package bill

import (
	"backend/pkg/models"
	"backend/pkg/mutation"
	"context"
	"database/sql"
	"errors"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"math"
	"strings"
	"time"
)

type BillAccess struct {
	BillID    uint
	BillToken string
}
type BillSharePaidCommand struct {
	Access  BillAccess
	ShareID uint
	Paid    bool
}
type ClaimCommand struct {
	Access  BillAccess
	Updates []ItemAssignmentsUpdate
}
type BillRepository interface {
	Create(context.Context, CreationInsert) (CreationRecord, error)
	LookupCreation(context.Context, [32]byte) (*CreationRecord, error)
	GetById(uint) (*models.Bill, error)
	UpdatePersonSharePaid(context.Context, BillSharePaidCommand) error
	UpdateItemAssignmentsBatch(context.Context, ClaimCommand) error
}
type ItemAssignmentsUpdate struct {
	ItemID            uint
	Assignments       []models.ItemAssignment
	ExpectedUpdatedAt *time.Time
}
type billRepository struct{ db *gorm.DB }

func (b *billRepository) GetById(id uint) (*models.Bill, error) {
	v := &models.Bill{}
	err := b.db.Preload("Tab").Preload("Items.Assignments").Preload("Participants").Preload("PersonShares").First(v, id).Error
	return v, err
}

// Association discovery holds no row lock. An attachment winning the standalone
// predicate causes rollback and one fresh discovery, under the same deadline.
func (b *billRepository) UpdatePersonSharePaid(ctx context.Context, c BillSharePaidCommand) error {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	restart := errors.New("association changed")
	for attempt := 0; attempt < 2; attempt++ {
		var association struct {
			ID    uint
			TabID *uint
		}
		if c.Access.BillToken == "" {
			return mutation.Forbidden
		}
		err := b.db.WithContext(ctx).Table("bills").Select("id,tab_id").Where("id = ? AND access_token = ?", c.Access.BillID, c.Access.BillToken).Take(&association).Error
		if err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return mutation.Forbidden
			}
			return err
		}
		err = b.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
			if association.TabID != nil {
				var t models.Tab
				if err := tx.Select("id").Clauses(clause.Locking{Strength: "UPDATE"}).First(&t, *association.TabID).Error; err != nil {
					return err
				}
			}
			var locked struct{ ID uint }
			q := tx.Table("bills").Select("id").Where("id = ? AND access_token = ?", c.Access.BillID, c.Access.BillToken).Clauses(clause.Locking{Strength: "UPDATE"})
			if association.TabID == nil {
				q = q.Where("tab_id IS NULL")
			} else {
				q = q.Where("tab_id = ?", *association.TabID)
			}
			if err := q.Take(&locked).Error; err != nil {
				if errors.Is(err, gorm.ErrRecordNotFound) {
					return restart
				}
				return err
			}
			var share models.PersonShare
			if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND bill_id = ?", c.ShareID, c.Access.BillID).First(&share).Error; err != nil {
				if errors.Is(err, gorm.ErrRecordNotFound) {
					return ErrPersonShareNotFound
				}
				return err
			}
			if share.Paid == c.Paid {
				return nil
			}
			return tx.Model(&share).Update("paid", c.Paid).Error
		}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
		if !errors.Is(err, restart) {
			return err
		}
	}
	return mutation.Review
}
func (b *billRepository) UpdateItemAssignmentsBatch(ctx context.Context, c ClaimCommand) error {
	if err := ValidateAssignmentUpdates(c.Updates); err != nil {
		return err
	}
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	if c.Access.BillToken == "" {
		return mutation.Forbidden
	}
	var eligibility struct {
		ID       uint
		LazyMode bool
		TabID    *uint
	}
	if err := b.db.WithContext(ctx).Table("bills").Select("id,lazy_mode,tab_id").Where("id = ? AND access_token = ?", c.Access.BillID, c.Access.BillToken).Take(&eligibility).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return mutation.Forbidden
		}
		return err
	}
	if !eligibility.LazyMode || eligibility.TabID != nil {
		return mutation.StandaloneOnly
	}
	return b.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if c.Access.BillToken == "" {
			return mutation.Forbidden
		}
		var v models.Bill
		if err := tx.Session(&gorm.Session{SkipHooks: true}).Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND access_token = ? AND lazy_mode = ? AND tab_id IS NULL", c.Access.BillID, c.Access.BillToken, true).First(&v).Error; err != nil {
			return err
		}
		return ReplaceAssignmentsLocked(tx, v, c.Updates)
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
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
		if paidByName[name] && math.Abs(nextByName[name]-percentage) > 1e-9 {
			return false
		}
	}
	for name, percentage := range nextByName {
		if paidByName[name] && math.Abs(currentByName[name]-percentage) > 1e-9 {
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
