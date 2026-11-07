package bill

import (
	"backend/pkg/models"
	"backend/pkg/mutation"
	"context"
	"database/sql"
	"errors"
	"math"
	"strings"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type ParticipantChange struct {
	Operation        string
	ParticipantID    uint
	ClientRef        string
	Name             *string
	ExpectedRevision *int64
	RequestRevision  *int64
	MemberID         *uint
	Decision         string
}
type ParticipantResult struct {
	Participant      models.BillParticipant `json:"participant"`
	IdentityRevision int64                  `json:"identity_revision"`
}
type ParticipantAuthority struct {
	Actor  *models.TabMember
	Roster []models.TabMember
	Source bool
	Active bool
}
type StandaloneParticipantCommand struct {
	Access BillAccess
	Change ParticipantChange
}
type ParticipantRepository interface {
	ChangeParticipant(context.Context, StandaloneParticipantCommand) (ParticipantResult, error)
}
type ParticipantService interface {
	ChangeParticipant(context.Context, StandaloneParticipantCommand) (ParticipantResult, error)
}

func (s *billService) ChangeParticipant(ctx context.Context, c StandaloneParticipantCommand) (ParticipantResult, error) {
	r, ok := s.repo.(ParticipantRepository)
	if !ok {
		return ParticipantResult{}, mutation.Invalid
	}
	return r.ChangeParticipant(ctx, c)
}
func (r *billRepository) ChangeParticipant(ctx context.Context, c StandaloneParticipantCommand) (ParticipantResult, error) {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	var result ParticipantResult
	if c.Access.BillToken == "" {
		return result, mutation.Forbidden
	}
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var b models.Bill
		err := tx.Session(&gorm.Session{SkipHooks: true}).Select(models.BillColumns).Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ? AND access_token = ? AND tab_id IS NULL", c.Access.BillID, c.Access.BillToken).Take(&b).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return mutation.Forbidden
		}
		if err != nil {
			return err
		}
		result, err = ChangeParticipantLocked(tx, b, c.Change, ParticipantAuthority{Source: true, Active: true})
		return err
	}, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
	if err != nil {
		return ParticipantResult{}, err
	}
	return result, nil
}
func participantReturning() clause.Returning {
	columns := []clause.Column{}
	for _, name := range strings.Split(models.ParticipantColumns, ",") {
		columns = append(columns, clause.Column{Name: name})
	}
	return clause.Returning{Columns: columns}
}
func oneBehind(expected *int64, current int64) bool {
	return expected != nil && *expected >= 0 && *expected < math.MaxInt64 && *expected+1 == current
}

// ChangeParticipantLocked owns the bounded participant transitions for both
// locations. Its caller has reauthorized and locked Tab -> Bill, and supplies
// only current scoped authority. This function locks participants before shares.
func ChangeParticipantLocked(tx *gorm.DB, b models.Bill, c ParticipantChange, a ParticipantAuthority) (ParticipantResult, error) {
	result := ParticipantResult{IdentityRevision: b.IdentityRevision}
	if !Ready(b) {
		return result, ErrIdentityReview
	}
	if b.TabID == nil && !a.Source || b.TabID != nil && a.Actor == nil && len(a.Roster) != 0 {
		return result, mutation.Forbidden
	}
	if c.ExpectedRevision == nil || *c.ExpectedRevision < 0 {
		return result, mutation.Invalid
	}
	if err := tx.Select(models.ParticipantColumns).Where("bill_id = ?", b.ID).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&b.ParticipantRows).Error; err != nil {
		return result, err
	}
	index, err := ParticipantIndex(b)
	if err != nil {
		return result, err
	}
	if b.TabID != nil {
		roster := map[uint]models.TabMember{}
		for _, m := range a.Roster {
			roster[m.ID] = m
		}
		for _, p := range b.ParticipantRows {
			if _, err := PartyFor(*b.TabID, b, p, roster); err != nil {
				return result, err
			}
		}
	}
	var p models.BillParticipant
	if c.Operation != "create" {
		var ok bool
		p, ok = index[c.ParticipantID]
		if !ok {
			return result, gorm.ErrRecordNotFound
		}
	}
	label := ""
	if c.Operation == "create" || c.Operation == "rename" {
		if c.Name == nil {
			return result, mutation.Invalid
		}
		label, err = participantLabel(*c.Name)
		if err != nil {
			return result, err
		}
	}
	switch c.Operation {
	case "create":
		if !validClientRef(c.ClientRef) {
			return result, mutation.Invalid
		}
		for _, old := range b.ParticipantRows {
			if old.ClientRef != nil && *old.ClientRef == c.ClientRef {
				if old.AllocationLabel != label {
					return result, ErrRevision
				}
				result.Participant = old
				return result, nil
			}
		}
	case "rename":
		authorized := a.Source
		if b.TabID != nil {
			authorized = a.Source || a.Actor != nil && (a.Actor.Role == "creator" || p.MemberID != nil && *p.MemberID == a.Actor.ID)
		}
		if !authorized {
			return result, mutation.Forbidden
		}
		if label == p.Label && (*c.ExpectedRevision == b.IdentityRevision || oneBehind(c.ExpectedRevision, b.IdentityRevision)) {
			result.Participant = p
			return result, nil
		}
	case "request":
		if b.TabID == nil || a.Actor == nil {
			return result, mutation.Forbidden
		}
		if p.PendingMemberID != nil && *p.PendingMemberID == a.Actor.ID && (*c.ExpectedRevision == b.IdentityRevision || oneBehind(c.ExpectedRevision, b.IdentityRevision) && p.PendingRequestRevision != nil && *p.PendingRequestRevision == b.IdentityRevision) {
			result.Participant = p
			return result, nil
		}
	case "decision":
		if b.TabID == nil || a.Actor == nil || !(a.Actor.Role == "creator" || a.Source) {
			return result, mutation.Forbidden
		}
		if c.MemberID == nil || *c.MemberID == 0 || uint64(*c.MemberID) > math.MaxInt64 || c.RequestRevision == nil || *c.RequestRevision <= 0 || (c.Decision != "approve" && c.Decision != "reject") {
			return result, mutation.Invalid
		}
		if p.LastBindingMemberID != nil && *p.LastBindingMemberID == *c.MemberID && p.LastBindingRequestRevision != nil && *p.LastBindingRequestRevision == *c.RequestRevision && p.LastBindingDecision != nil && *p.LastBindingDecision == c.Decision && p.LastBindingActorMemberID != nil && *p.LastBindingActorMemberID == a.Actor.ID && p.LastBindingResultRevision != nil && *p.LastBindingResultRevision == b.IdentityRevision && oneBehind(c.ExpectedRevision, b.IdentityRevision) {
			result.Participant = p
			return result, nil
		}
	default:
		return result, mutation.Invalid
	}
	next, err := revisionNext(b, c.ExpectedRevision)
	if err != nil {
		return result, err
	}
	if !a.Active {
		return result, mutation.Finalized
	}
	var shares []models.PersonShare
	if err := tx.Select(models.ShareColumns).Where("bill_id = ?", b.ID).Order("id ASC").Clauses(clause.Locking{Strength: "UPDATE"}).Find(&shares).Error; err != nil {
		return result, err
	}
	paid := false
	for _, s := range shares {
		if s.Paid && (c.Operation == "create" || s.ParticipantID != nil && *s.ParticipantID == p.ID) {
			paid = true
		}
	}
	values := map[string]any{}
	now := tx.NowFunc()
	switch c.Operation {
	case "create":
		if len(b.ParticipantRows) >= 100 || paid {
			return result, ErrRevision
		}
		ordinal := int64(0)
		for _, old := range b.ParticipantRows {
			if old.Ordinal != nil && *old.Ordinal >= ordinal {
				if *old.Ordinal == math.MaxInt64 {
					return result, ErrRevision
				}
				ordinal = *old.Ordinal + 1
			}
		}
		person := models.Person{Name: label}
		inserted := tx.Create(&person)
		if inserted.Error != nil {
			return result, inserted.Error
		}
		if inserted.RowsAffected != 1 {
			return result, ErrIdentityReview
		}
		if person.ID == 0 {
			return result, ErrIdentityReview
		}
		ref := c.ClientRef
		p = models.BillParticipant{BillID: b.ID, PersonID: person.ID, Label: label, AllocationLabel: label, IdentityVersion: 2, Ordinal: &ordinal, ClientRef: &ref, TabID: b.TabID}
		inserted = tx.Omit(clause.Associations).Clauses(participantReturning()).Create(&p)
		if inserted.Error != nil {
			return result, inserted.Error
		}
		if inserted.RowsAffected != 1 {
			return result, ErrIdentityReview
		}
		if p.ID == 0 || p.BillID != b.ID || p.PersonID != person.ID || !sameUint(p.TabID, b.TabID) || p.MemberID != nil || p.PendingMemberID != nil {
			return result, ErrIdentityReview
		}
	case "rename":
		values["label"] = label
	case "request":
		if p.MemberID != nil || p.PendingMemberID != nil || paid {
			return result, ErrRevision
		}
		for _, old := range b.ParticipantRows {
			if old.ID != p.ID && (old.MemberID != nil && *old.MemberID == a.Actor.ID || old.PendingMemberID != nil && *old.PendingMemberID == a.Actor.ID) {
				return result, ErrRevision
			}
		}
		values = map[string]any{"pending_member_id": a.Actor.ID, "requested_at": now, "pending_request_revision": next}
	case "decision":
		if p.MemberID != nil || p.PendingMemberID == nil || *p.PendingMemberID != *c.MemberID || p.PendingRequestRevision == nil || *p.PendingRequestRevision != *c.RequestRevision || paid {
			return result, ErrRevision
		}
		kind := "source"
		if a.Actor.Role == "creator" {
			kind = "creator"
		}
		values = map[string]any{"pending_member_id": nil, "requested_at": nil, "pending_request_revision": nil, "last_binding_member_id": *c.MemberID, "last_binding_request_revision": *c.RequestRevision, "last_binding_decision": c.Decision, "last_binding_actor_member_id": a.Actor.ID, "last_binding_actor_kind": kind, "last_binding_result_revision": next, "last_binding_decided_at": now}
		if c.Decision == "approve" {
			for _, old := range b.ParticipantRows {
				if old.MemberID != nil && *old.MemberID == *c.MemberID {
					return result, ErrRevision
				}
			}
			values["member_id"] = *c.MemberID
			values["approved_by_member_id"] = a.Actor.ID
			values["approval_kind"] = kind
			values["approved_at"] = now
		}
	}
	if len(values) > 0 {
		updated := tx.Model(&p).Clauses(participantReturning()).Where("id = ? AND bill_id = ?", p.ID, b.ID).UpdateColumns(values)
		if updated.Error != nil {
			return result, updated.Error
		}
		if updated.RowsAffected != 1 {
			return result, ErrIdentityReview
		}
	}
	if err := AdvanceRevisionLocked(tx, b, next); err != nil {
		return result, err
	}
	return ParticipantResult{Participant: p, IdentityRevision: next}, nil
}
