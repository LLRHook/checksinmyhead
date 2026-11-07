package bill

import (
	"backend/pkg/models"
	"backend/pkg/mutation"
	"backend/pkg/security"
	"fmt"
	"gorm.io/gorm"
	"math"
	"strconv"
	"strings"
	"unicode/utf8"
)

var (
	ErrIdentityReview = &mutation.Failure{Status: 409, Code: "identity_review_required", Message: "participant identity needs review"}
	ErrClientUpgrade  = &mutation.Failure{Status: 409, Code: "client_upgrade_required", Message: "use a participant-reference client and refresh current references"}
	ErrRevision       = &mutation.Failure{Status: 409, Code: "identity_revision_conflict", Message: "participant state changed; refresh and try again"}
)

func validClientRef(s string) bool {
	if len(s) < 1 || len(s) > 64 {
		return false
	}
	for _, c := range []byte(s) {
		if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_' || c == '-') {
			return false
		}
	}
	return true
}
func participantLabel(s string) (string, error) {
	s = security.SanitizeString(s)
	if !utf8.ValidString(s) || utf8.RuneCountInString(s) > 30 {
		return "", mutation.Invalid
	}
	return s, nil
}
func revisionNext(b models.Bill, expected *int64) (int64, error) {
	if expected == nil || *expected < 0 {
		return 0, mutation.Invalid
	}
	if *expected != b.IdentityRevision || b.IdentityRevision == math.MaxInt64 {
		return 0, ErrRevision
	}
	return b.IdentityRevision + 1, nil
}
func Ready(b models.Bill) bool {
	return b.IdentityVersion == 2 && b.IdentityState == "ready" && b.IdentityRevision >= 0
}
func creationRef(b *models.Bill, key string) string {
	if b.InputVersion == 2 {
		return key
	}
	return ""
}

func documentParticipantOrder(b *models.Bill) []string {
	order := []string{}
	seen := map[string]bool{}
	add := func(key string) {
		if !seen[key] {
			seen[key] = true
			order = append(order, key)
		}
	}
	for _, p := range b.Participants {
		add(creationPersonKey(b, p))
	}
	for _, item := range b.Items {
		for _, a := range item.Assignments {
			add(assignmentKey(b, a))
		}
	}
	for _, s := range b.PersonShares {
		add(shareKey(b, s))
	}
	return order
}
func creationPersonKey(b *models.Bill, p models.Person) string {
	if b.InputVersion == 2 && p.ClientRef != nil {
		return *p.ClientRef
	}
	return nameKey(p.Name)
}
func assignmentKey(b *models.Bill, a models.ItemAssignment) string {
	if a.ParticipantID != nil {
		return strconv.FormatUint(uint64(*a.ParticipantID), 10)
	}
	if b.InputVersion == 2 {
		return a.ParticipantRef
	}
	return nameKey(a.PersonName)
}
func shareKey(b *models.Bill, s models.PersonShare) string {
	if s.ParticipantID != nil {
		return strconv.FormatUint(uint64(*s.ParticipantID), 10)
	}
	if b.InputVersion == 2 {
		return s.ParticipantRef
	}
	return nameKey(s.PersonName)
}

type allocationTie struct {
	label   string
	ordinal int64
}

func allocationOrder(b *models.Bill) map[string]allocationTie {
	order := map[string]allocationTie{}
	for i, p := range b.Participants {
		order[creationPersonKey(b, p)] = allocationTie{strings.ToLower(p.Name), int64(i)}
	}
	for _, p := range b.ParticipantRows {
		if p.Ordinal != nil {
			order[strconv.FormatUint(uint64(p.ID), 10)] = allocationTie{strings.ToLower(p.AllocationLabel), *p.Ordinal}
		}
	}
	return order
}

// MISS-only translation of the document-local union. No Person/member lookup,
// ownership inference, or mutation of the frozen normalized format1 input.
func creationParticipants(b *models.Bill) ([]models.BillParticipant, error) {
	rows := []models.BillParticipant{}
	seen := map[string]int{}
	add := func(key, label string, ref *string) error {
		if _, ok := seen[key]; ok {
			return nil
		}
		if b.InputVersion != 2 {
			for _, p := range rows {
				if strings.EqualFold(p.Label, label) && nameKey(p.Label) != key {
					return ErrClientUpgrade
				}
			}
		}
		if len(rows) >= 100 {
			return ErrInvalidCreation
		}
		ordinal := int64(len(rows))
		seen[key] = len(rows)
		rows = append(rows, models.BillParticipant{Label: label, AllocationLabel: label, IdentityVersion: 2, Ordinal: &ordinal, ClientRef: ref})
		return nil
	}
	for _, p := range b.Participants {
		if err := add(creationPersonKey(b, p), p.Name, p.ClientRef); err != nil {
			return nil, err
		}
	}
	for _, item := range b.Items {
		for _, a := range item.Assignments {
			if err := add(assignmentKey(b, a), a.PersonName, nil); err != nil {
				return nil, err
			}
		}
	}
	for _, s := range b.PersonShares {
		key := shareKey(b, s)
		if err := add(key, s.PersonName, nil); err != nil {
			return nil, err
		}
		rows[seen[key]].AllocationLabel = s.PersonName
	}
	return rows, nil
}

// Validate cross-row closure independently of database FK enforcement. A safe
// raw read may retain malformed rows, but no accounting/authority resolves them.
func ParticipantIndex(b models.Bill) (map[uint]models.BillParticipant, error) {
	if !Ready(b) {
		return nil, ErrIdentityReview
	}
	if len(b.ParticipantRows) > 100 {
		return nil, ErrIdentityReview
	}
	index := map[uint]models.BillParticipant{}
	ord := map[int64]bool{}
	refs := map[string]bool{}
	members := map[uint]bool{}
	pending := map[uint]bool{}
	for _, p := range b.ParticipantRows {
		if p.ID == 0 || p.BillID != b.ID || p.IdentityVersion != 2 || p.Ordinal == nil || *p.Ordinal < 0 || ord[*p.Ordinal] || index[p.ID].ID != 0 || !sameUint(p.TabID, b.TabID) || utf8.RuneCountInString(p.Label) > 30 || utf8.RuneCountInString(p.AllocationLabel) > 30 || !utf8.ValidString(p.Label) || !utf8.ValidString(p.AllocationLabel) {
			return nil, ErrIdentityReview
		}
		if p.ClientRef != nil {
			if !validClientRef(*p.ClientRef) || refs[*p.ClientRef] {
				return nil, ErrIdentityReview
			}
			refs[*p.ClientRef] = true
		}
		if p.MemberID != nil {
			if b.TabID == nil || *p.MemberID == 0 || members[*p.MemberID] || p.PendingMemberID != nil || p.ApprovedByMemberID == nil || p.ApprovalKind == nil || (*p.ApprovalKind != "creator" && *p.ApprovalKind != "source") || p.ApprovedAt == nil || p.ApprovedAt.IsZero() {
				return nil, ErrIdentityReview
			}
			members[*p.MemberID] = true
		} else if p.ApprovedByMemberID != nil || p.ApprovalKind != nil || p.ApprovedAt != nil {
			return nil, ErrIdentityReview
		}
		if p.PendingMemberID != nil {
			if b.TabID == nil || *p.PendingMemberID == 0 || pending[*p.PendingMemberID] || p.RequestedAt == nil || p.RequestedAt.IsZero() || p.PendingRequestRevision == nil || *p.PendingRequestRevision <= 0 || *p.PendingRequestRevision > b.IdentityRevision {
				return nil, ErrIdentityReview
			}
			pending[*p.PendingMemberID] = true
		} else if p.RequestedAt != nil || p.PendingRequestRevision != nil {
			return nil, ErrIdentityReview
		}
		receipt := []bool{p.LastBindingMemberID != nil, p.LastBindingRequestRevision != nil, p.LastBindingDecision != nil, p.LastBindingActorMemberID != nil, p.LastBindingActorKind != nil, p.LastBindingResultRevision != nil, p.LastBindingDecidedAt != nil}
		n := 0
		for _, v := range receipt {
			if v {
				n++
			}
		}
		if n != 0 {
			if n != 7 || b.TabID == nil || *p.LastBindingMemberID == 0 || *p.LastBindingActorMemberID == 0 || *p.LastBindingRequestRevision <= 0 || *p.LastBindingResultRevision <= *p.LastBindingRequestRevision || *p.LastBindingResultRevision > b.IdentityRevision || (*p.LastBindingDecision != "approve" && *p.LastBindingDecision != "reject") || (*p.LastBindingActorKind != "creator" && *p.LastBindingActorKind != "source") || p.LastBindingDecidedAt.IsZero() {
				return nil, ErrIdentityReview
			}
		}
		ord[*p.Ordinal] = true
		index[p.ID] = p
	}
	return index, nil
}
func sameUint(a, b *uint) bool { return a == nil && b == nil || a != nil && b != nil && *a == *b }
func PartyFor(tabID uint, b models.Bill, p models.BillParticipant, roster map[uint]models.TabMember) (models.Party, error) {
	if b.TabID == nil || *b.TabID != tabID || p.TabID == nil || *p.TabID != tabID {
		return models.Party{}, ErrIdentityReview
	}
	for _, id := range []*uint{p.MemberID, p.PendingMemberID, p.ApprovedByMemberID, p.LastBindingMemberID, p.LastBindingActorMemberID} {
		if id != nil {
			m, ok := roster[*id]
			if !ok || m.TabID != tabID {
				return models.Party{}, ErrIdentityReview
			}
		}
	}
	if p.MemberID != nil {
		m := roster[*p.MemberID]
		return models.Party{Kind: "member", TabID: tabID, MemberID: m.ID, Label: m.DisplayName}, nil
	}
	return models.Party{Kind: "guest", BillID: b.ID, ParticipantID: p.ID, Label: p.Label}, nil
}
func PartyKey(p models.Party) string {
	if p.Kind == "member" {
		return fmt.Sprintf("m:%020d:%020d", p.TabID, p.MemberID)
	}
	return fmt.Sprintf("g:%020d:%020d", p.BillID, p.ParticipantID)
}

// ValidateReferenceGraph checks only the saved graph's reference/shape closure.
// It never recalculates financial history or repairs an incomplete projection.
func ValidateReferenceGraph(b models.Bill) error {
	index, err := ParticipantIndex(b)
	if err != nil {
		return err
	}
	shareRefs := map[uint]bool{}
	shareIDs := map[uint]bool{}
	for _, s := range b.PersonShares {
		if s.ID == 0 || shareIDs[s.ID] || s.BillID != b.ID || s.IdentityVersion != 2 || s.ParticipantID == nil || index[*s.ParticipantID].ID == 0 || shareRefs[*s.ParticipantID] {
			return ErrIdentityReview
		}
		shareIDs[s.ID] = true
		shareRefs[*s.ParticipantID] = true
	}
	itemIDs := map[uint]bool{}
	assignmentIDs := map[uint]bool{}
	count := 0
	for _, item := range b.Items {
		if item.ID == 0 || item.BillID != b.ID || itemIDs[item.ID] || len(item.Assignments) > 100 {
			return ErrIdentityReview
		}
		itemIDs[item.ID] = true
		seen := map[uint]bool{}
		total := 0.0
		for _, a := range item.Assignments {
			count++
			if count > 50000 || a.ID == 0 || assignmentIDs[a.ID] || a.BillItemID != item.ID || a.BillID == nil || *a.BillID != b.ID || a.IdentityVersion != 2 || a.ParticipantID == nil || index[*a.ParticipantID].ID == 0 || seen[*a.ParticipantID] || !shareRefs[*a.ParticipantID] || !finite(a.Percentage) || a.Percentage <= 0 || a.Percentage > 100 {
				return ErrIdentityReview
			}
			assignmentIDs[a.ID] = true
			seen[*a.ParticipantID] = true
			total += a.Percentage
		}
		if !models.ItemAssignmentTotalIsValid(total) {
			return ErrIdentityReview
		}
	}
	return nil
}

func assignmentIdentityKey(a models.ItemAssignment) string {
	if a.ParticipantID != nil {
		return strconv.FormatUint(uint64(*a.ParticipantID), 10)
	}
	return strings.ToLower(a.PersonName)
}
func assignmentSetsEqual(a, b []models.ItemAssignment) bool {
	if len(a) != len(b) {
		return false
	}
	values := map[string]float64{}
	for _, v := range a {
		values[assignmentIdentityKey(v)] = v.Percentage
	}
	for _, v := range b {
		if p, ok := values[assignmentIdentityKey(v)]; !ok || p != v.Percentage {
			return false
		}
	}
	return true
}
func AdvanceRevisionLocked(tx *gorm.DB, b models.Bill, next int64) error {
	if b.IdentityRevision == math.MaxInt64 || next != b.IdentityRevision+1 {
		return ErrRevision
	}
	updated := tx.Model(&models.Bill{}).Where("id = ? AND identity_revision = ?", b.ID, b.IdentityRevision).UpdateColumn("identity_revision", next)
	if updated.Error != nil {
		return updated.Error
	}
	if updated.RowsAffected != 1 {
		return ErrRevision
	}
	return nil
}
