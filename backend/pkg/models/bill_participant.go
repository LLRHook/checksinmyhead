package models

import "time"

// BillParticipant is the scoped participation. PersonID retains the old join
// key for storage compatibility; it confers no identity or authority.
type BillParticipant struct {
	ID                         uint       `gorm:"primaryKey;autoIncrement" json:"participant_id"`
	BillID                     uint       `json:"bill_id"`
	PersonID                   uint       `json:"-"`
	Label                      string     `json:"label"`
	AllocationLabel            string     `json:"-"`
	IdentityVersion            int16      `gorm:"not null;default:1" json:"identity_version"`
	Ordinal                    *int64     `json:"-"`
	ClientRef                  *string    `json:"client_ref"`
	TabID                      *uint      `json:"tab_id"`
	MemberID                   *uint      `json:"member_id"`
	PendingMemberID            *uint      `json:"pending_member_id"`
	ApprovedByMemberID         *uint      `json:"approved_by_member_id"`
	ApprovalKind               *string    `json:"approval_kind"`
	RequestedAt                *time.Time `json:"requested_at"`
	ApprovedAt                 *time.Time `json:"approved_at"`
	PendingRequestRevision     *int64     `json:"pending_request_revision"`
	LastBindingMemberID        *uint      `json:"-"`
	LastBindingRequestRevision *int64     `json:"-"`
	LastBindingDecision        *string    `json:"-"`
	LastBindingActorMemberID   *uint      `json:"-"`
	LastBindingActorKind       *string    `json:"-"`
	LastBindingResultRevision  *int64     `json:"-"`
	LastBindingDecidedAt       *time.Time `json:"-"`
}

func (p BillParticipant) BindingState() string {
	if p.MemberID != nil {
		return "confirmed"
	}
	if p.PendingMemberID != nil {
		return "pending"
	}
	return "unbound"
}
