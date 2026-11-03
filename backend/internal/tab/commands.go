package tab

import (
	"backend/internal/bill"
	"backend/pkg/mutation"
)

type TabAccess struct {
	TabID                 uint
	TabToken, MemberToken string
}
type FinalizeCommand struct{ Access TabAccess }
type AssignmentCommand struct {
	Access  TabAccess
	BillID  uint
	Updates []BillItemAssignmentsUpdate
}
type SharePaidCommand struct {
	Access          TabAccess
	BillID, ShareID uint
	Paid            bool
}
type SettlementPaidCommand struct {
	Access       TabAccess
	SettlementID uint
	Paid         bool
}
type SettingsCommand struct {
	Access                             TabAccess
	Name, Description, DisplayCurrency *string
}
type JoinCommand struct {
	Access      TabAccess
	DisplayName string
}
type LeaveCommand struct{ Access TabAccess }

var (
	ErrAssignmentConflict  = bill.ErrAssignmentConflict
	ErrItemAlreadyPaid     = bill.ErrItemAlreadyPaid
	ErrDuplicateItemUpdate = mutation.Invalid
	ErrAccountingReview    = mutation.Review
)
