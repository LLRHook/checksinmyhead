package tab

import (
	"backend/internal/bill"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"context"
	"crypto/subtle"
	"database/sql"
	"gorm.io/gorm"
	"time"
)

type TabView struct {
	models.Tab
	Bills              []bill.BillView              `json:"bills"`
	TotalAmount        *float64                     `json:"total_amount"`
	TotalStatus        string                       `json:"total_status"`
	NetBalances        []models.ReferenceNetBalance `json:"net_balances"`
	NetBalanceStatus   string                       `json:"net_balance_status"`
	AccountingCurrency string                       `json:"accounting_currency"`
	ViewerMemberID     *uint                        `json:"viewer_member_id"`
}

func viewTab(t models.Tab, viewer *uint) TabView {
	t.AccessToken = ""
	v := TabView{Tab: t, Bills: []bill.BillView{}, TotalStatus: t.TotalStatus, NetBalances: t.ReferenceBalances, NetBalanceStatus: t.NetBalanceStatus, AccountingCurrency: "USD", ViewerMemberID: viewer}
	if t.TotalStatus == "available" {
		amount := t.TotalAmount
		v.TotalAmount = &amount
	}
	for _, b := range t.Bills {
		copy := t
		copy.Bills = nil
		b.Tab = &copy
		v.Bills = append(v.Bills, bill.ViewBill(b, viewer))
	}
	return v
}

type SettlementView struct {
	ID              uint          `json:"id"`
	TabID           uint          `json:"tab_id"`
	SnapshotVersion int16         `json:"snapshot_version"`
	Party           *models.Party `json:"party"`
	PersonName      string        `json:"person_name"`
	Amount          float64       `json:"amount"`
	Paid            bool          `json:"paid"`
	CreatedAt       time.Time     `json:"created_at"`
}
type SettlementHistory struct {
	RawRows []models.TabSettlement `json:"-"`

	Rows               []SettlementView `json:"settlements"`
	ReviewStatus       string           `json:"identity_review_status"`
	AccountingCurrency string           `json:"accounting_currency"`
	ViewerMemberID     *uint            `json:"viewer_member_id"`
}

func viewSettlements(t models.Tab, rows []models.TabSettlement, viewer *uint, validation error) SettlementHistory {
	result := SettlementHistory{RawRows: rows, Rows: []SettlementView{}, ReviewStatus: "ready", AccountingCurrency: "USD", ViewerMemberID: viewer}
	if validation != nil {
		result.ReviewStatus = "identity_review_required"
	}
	if validation == nil && len(rows) > 0 && rows[0].SnapshotVersion == 1 {
		result.ReviewStatus = "legacy_identity_review_required"
	}
	for _, s := range rows {
		row := SettlementView{ID: s.ID, TabID: s.TabID, SnapshotVersion: s.SnapshotVersion, PersonName: s.PersonName, Amount: s.Amount, Paid: s.Paid, CreatedAt: s.CreatedAt}
		if s.SnapshotVersion == 2 && validation == nil {
			p := models.Party{Label: s.PersonName}
			if s.MemberID != nil {
				p.Kind = "member"
				p.TabID = t.ID
				p.MemberID = *s.MemberID
			} else {
				p.Kind = "guest"
				p.BillID = s.GuestBillID
				p.ParticipantID = *s.ParticipantID
			}
			row.Party = &p
		}
		result.Rows = append(result.Rows, row)
	}
	return result
}

type SettlementReader interface {
	ReadSettlements(context.Context, TabAccess) (SettlementHistory, error)
}

func (s *tabService) ReadSettlements(ctx context.Context, a TabAccess) (SettlementHistory, error) {
	r, ok := s.repo.(SettlementReader)
	if !ok {
		return SettlementHistory{}, mutation.Invalid
	}
	return r.ReadSettlements(ctx, a)
}
func (r *tabRepository) ReadSettlements(ctx context.Context, a TabAccess) (SettlementHistory, error) {
	ctx, cancel := mutation.Bound(ctx)
	defer cancel()
	var result SettlementHistory
	err := r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var t models.Tab
		if err := tx.Select(models.TabColumns).First(&t, a.TabID).Error; err != nil {
			return err
		}
		if a.TabToken == "" || t.AccessToken == "" || subtle.ConstantTimeCompare([]byte(a.TabToken), []byte(t.AccessToken)) != 1 {
			return mutation.Forbidden
		}
		roster, err := members(tx, t.ID)
		if err != nil {
			return err
		}
		viewer, err := bill.ViewerMember(t.ID, roster, a.MemberToken)
		if err != nil {
			return err
		}
		var rows []models.TabSettlement
		if err := tx.Select(models.SettlementColumns).Where("tab_id = ?", t.ID).Order("amount DESC, id ASC").Find(&rows).Error; err != nil {
			return err
		}
		var validation error
		if t.Finalized || t.FinalizedAt != nil || len(rows) != 0 {
			validation = validateStoredSnapshot(tx, t, rows, roster)
		}
		result = viewSettlements(t, rows, viewer, validation)
		return nil
	}, &sql.TxOptions{Isolation: sql.LevelRepeatableRead, ReadOnly: true})
	return result, err
}
