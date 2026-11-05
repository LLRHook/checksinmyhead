package bill

import (
	"backend/pkg/models"
	"backend/pkg/mutation"
	"crypto/subtle"
	"errors"
	"strings"
)

type ParticipantView struct {
	models.BillParticipant
	BindingState string `json:"binding_state"`
}
type AssignmentView struct {
	models.ItemAssignment
	IdentityVersion int16   `json:"identity_version"`
	ParticipantID   *uint   `json:"participant_id"`
	Label           *string `json:"label"`
}
type ItemView struct {
	models.BillItem
	Assignments []AssignmentView `json:"assignments"`
}
type ShareView struct {
	models.PersonShare
	IdentityVersion int16   `json:"identity_version"`
	ParticipantID   *uint   `json:"participant_id"`
	Label           *string `json:"label"`
}
type BillView struct {
	models.Bill
	IdentityVersion        int16             `json:"identity_version"`
	IdentityState          string            `json:"identity_state"`
	IdentityRevision       int64             `json:"identity_revision"`
	IdentityReviewStatus   string            `json:"identity_review_status"`
	AccountingReviewStatus string            `json:"accounting_review_status"`
	ViewerMemberID         *uint             `json:"viewer_member_id"`
	Participants           []ParticipantView `json:"participants"`
	Items                  []ItemView        `json:"items"`
	PersonShares           []ShareView       `json:"person_shares"`
}

func ViewerMember(tabID uint, rows []models.TabMember, token string) (*uint, error) {
	if token == "" {
		return nil, nil
	}
	for _, m := range rows {
		if m.TabID == tabID && m.MemberToken != "" && subtle.ConstantTimeCompare([]byte(token), []byte(m.MemberToken)) == 1 {
			id := m.ID
			return &id, nil
		}
	}
	return nil, mutation.Forbidden
}
func BillViewer(b models.Bill, token string) (*uint, error) {
	if token == "" {
		return nil, nil
	}
	if b.TabID == nil || b.Tab == nil {
		return nil, mutation.Forbidden
	}
	return ViewerMember(*b.TabID, b.Tab.Members, token)
}
func ViewBill(b models.Bill, viewer *uint) BillView {
	b.AccessToken = ""
	v := BillView{Bill: b, IdentityVersion: b.IdentityVersion, IdentityState: b.IdentityState, IdentityRevision: b.IdentityRevision, IdentityReviewStatus: "ready", ViewerMemberID: viewer, Participants: []ParticipantView{}, Items: []ItemView{}, PersonShares: []ShareView{}}
	v.AccountingReviewStatus = allocationReviewStatus(b)
	if v.AccountingReviewStatus == "identity_review_required" {
		v.IdentityReviewStatus = "identity_review_required"
	}
	index, err := ParticipantIndex(b)
	if err != nil {
		v.IdentityReviewStatus = "identity_review_required"
	}
	if ValidateReferenceGraph(b) != nil {
		v.IdentityReviewStatus = "identity_review_required"
	}
	for _, p := range b.ParticipantRows {
		if p.BillID == b.ID {
			v.Participants = append(v.Participants, ParticipantView{p, p.BindingState()})
		} else {
			v.IdentityReviewStatus = "identity_review_required"
		}
	}
	label := func(id *uint) *string {
		if id != nil {
			if p, ok := index[*id]; ok {
				name := p.Label
				return &name
			}
		}
		v.IdentityReviewStatus = "identity_review_required"
		return nil
	}
	for _, item := range b.Items {
		next := ItemView{BillItem: item, Assignments: []AssignmentView{}}
		seen := map[uint]bool{}
		for _, a := range item.Assignments {
			l := label(a.ParticipantID)
			if a.IdentityVersion != 2 || a.BillID == nil || *a.BillID != b.ID || a.BillItemID != item.ID || a.ParticipantID != nil && seen[*a.ParticipantID] {
				v.IdentityReviewStatus = "identity_review_required"
			}
			if a.ParticipantID != nil {
				seen[*a.ParticipantID] = true
			}
			next.Assignments = append(next.Assignments, AssignmentView{ItemAssignment: a, IdentityVersion: a.IdentityVersion, ParticipantID: a.ParticipantID, Label: l})
		}
		v.Items = append(v.Items, next)
	}
	seen := map[uint]bool{}
	for _, s := range b.PersonShares {
		l := label(s.ParticipantID)
		if s.IdentityVersion != 2 || s.BillID != b.ID || s.ParticipantID != nil && seen[*s.ParticipantID] {
			v.IdentityReviewStatus = "identity_review_required"
		}
		if s.ParticipantID != nil {
			seen[*s.ParticipantID] = true
		}
		v.PersonShares = append(v.PersonShares, ShareView{PersonShare: s, IdentityVersion: s.IdentityVersion, ParticipantID: s.ParticipantID, Label: l})
	}
	if b.TabID != nil && b.Tab != nil {
		roster := map[uint]models.TabMember{}
		for _, m := range b.Tab.Members {
			roster[m.ID] = m
		}
		for _, p := range b.ParticipantRows {
			if _, err := PartyFor(*b.TabID, b, p, roster); err != nil {
				v.IdentityReviewStatus = "identity_review_required"
			}
		}
	}
	return v
}
func allocationReviewStatus(b models.Bill) string {
	if _, err := FrozenUSDShareCents(b); err != nil {
		if errors.Is(err, ErrIdentityReview) {
			return "identity_review_required"
		}
		return "accounting_review_required"
	}
	return "available"
}

func LegacyBillRepresentable(b models.Bill) error {
	if allocationReviewStatus(b) != "available" {
		return ErrClientUpgrade
	}
	if b.IdentityVersion != 2 {
		labels := []string{}
		for _, p := range b.ParticipantRows {
			labels = append(labels, p.Label)
		}
		if !legacyLabelsDistinct(labels) {
			return ErrClientUpgrade
		}
		labels = nil
		for _, s := range b.PersonShares {
			labels = append(labels, s.PersonName)
		}
		if !legacyLabelsDistinct(labels) {
			return ErrClientUpgrade
		}
		for _, item := range b.Items {
			labels = nil
			for _, a := range item.Assignments {
				labels = append(labels, a.PersonName)
			}
			if !legacyLabelsDistinct(labels) {
				return ErrClientUpgrade
			}
		}
		return nil
	}
	if _, err := ParticipantIndex(b); err != nil {
		return ErrClientUpgrade
	}
	for i, p := range b.ParticipantRows {
		if strings.TrimSpace(p.Label) == "" {
			return ErrClientUpgrade
		}
		for _, old := range b.ParticipantRows[:i] {
			if strings.EqualFold(old.Label, p.Label) {
				return ErrClientUpgrade
			}
		}
	}
	if ViewBill(b, nil).IdentityReviewStatus != "ready" {
		return ErrClientUpgrade
	}
	return nil
}

func legacyLabelsDistinct(labels []string) bool {
	for i, label := range labels {
		if strings.TrimSpace(label) == "" {
			return false
		}
		for _, old := range labels[:i] {
			if strings.EqualFold(old, label) {
				return false
			}
		}
	}
	return true
}
