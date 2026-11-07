package tab

import (
	"backend/internal/bill"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"backend/pkg/security"
	"context"
	"crypto/subtle"
	"database/sql"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"unicode/utf8"
)

type ParticipantCommand struct {
	Access    TabAccess
	BillID    uint
	BillToken string
	Change    bill.ParticipantChange
}
type MemberCommand struct {
	Access TabAccess
	Name   *string
}
type ParticipantRepository interface {
	ChangeParticipant(context.Context, ParticipantCommand) (bill.ParticipantResult, error)
	MemberSelf(context.Context, MemberCommand) (models.TabMember, error)
}
type ParticipantService interface {
	ChangeParticipant(context.Context, ParticipantCommand) (bill.ParticipantResult, error)
	MemberSelf(context.Context, MemberCommand) (models.TabMember, error)
}

func (s *tabService) ChangeParticipant(ctx context.Context, c ParticipantCommand) (bill.ParticipantResult, error) {
	r, ok := s.repo.(ParticipantRepository)
	if !ok {
		return bill.ParticipantResult{}, mutation.Invalid
	}
	return r.ChangeParticipant(ctx, c)
}
func (s *tabService) MemberSelf(ctx context.Context, c MemberCommand) (models.TabMember, error) {
	r, ok := s.repo.(ParticipantRepository)
	if !ok {
		return models.TabMember{}, mutation.Invalid
	}
	return r.MemberSelf(ctx, c)
}
func (r *tabRepository) ChangeParticipant(ctx context.Context, c ParticipantCommand) (bill.ParticipantResult, error) {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	var result bill.ParticipantResult
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		t, err := lockAccess(tx, c.Access)
		if err != nil {
			return err
		}
		roster, err := members(tx, t.ID)
		if err != nil {
			return err
		}
		actor, err := currentMember(roster, c.Access, false, false)
		if err != nil {
			return err
		}
		var b models.Bill
		if err := tx.Session(&gorm.Session{SkipHooks: true}).Select(models.BillColumns).Where("id = ? AND tab_id = ?", c.BillID, t.ID).Clauses(clause.Locking{Strength: "UPDATE"}).Take(&b).Error; err != nil {
			return err
		}
		source := c.BillToken != "" && b.AccessToken != "" && subtle.ConstantTimeCompare([]byte(c.BillToken), []byte(b.AccessToken)) == 1
		if c.BillToken != "" && !source {
			return mutation.Forbidden
		}
		result, err = bill.ChangeParticipantLocked(tx, b, c.Change, bill.ParticipantAuthority{Actor: actor, Roster: roster, Source: source, Active: !t.Finalized})
		return err
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		return bill.ParticipantResult{}, err
	}
	return result, nil
}
func (r *tabRepository) MemberSelf(ctx context.Context, c MemberCommand) (models.TabMember, error) {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	var result models.TabMember
	if c.Name != nil {
		name := security.SanitizeString(*c.Name)
		if !utf8.ValidString(name) || utf8.RuneCountInString(name) > 30 {
			return result, mutation.Invalid
		}
		c.Name = &name
	}
	opts := &sql.TxOptions{Isolation: sql.LevelReadCommitted}
	if c.Name == nil {
		opts = &sql.TxOptions{Isolation: sql.LevelRepeatableRead, ReadOnly: true}
	}
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var t models.Tab
		var err error
		if c.Name == nil {
			err = tx.Select(models.TabColumns).First(&t, c.Access.TabID).Error
			if err == nil && (c.Access.TabToken == "" || t.AccessToken == "" || subtle.ConstantTimeCompare([]byte(c.Access.TabToken), []byte(t.AccessToken)) != 1) {
				err = mutation.Forbidden
			}
		} else {
			t, err = lockAccess(tx, c.Access)
		}
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
		result = *actor
		if c.Name == nil || result.DisplayName == *c.Name {
			return nil
		}
		updated := tx.Model(&result).Where("id = ? AND tab_id = ?", actor.ID, t.ID).UpdateColumn("display_name", *c.Name)
		if updated.Error != nil {
			return updated.Error
		}
		if updated.RowsAffected != 1 {
			return mutation.Forbidden
		}
		result.DisplayName = *c.Name
		return nil
	}, opts)
	if err != nil {
		return models.TabMember{}, err
	}
	return result, nil
}
