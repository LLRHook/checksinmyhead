package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"backend/pkg/security"
	"context"
	"errors"
	"math"
	"strings"
	"time"
)

// AttachBillCommand carries independent source and destination capabilities.
// Attribution is resolved in the transaction; callers cannot supply member IDs.
type AttachBillCommand struct {
	TabID            uint
	BillID           uint
	TabToken         string
	MemberToken      string
	BillToken        string
	ExpectedRevision *int64
	IdentityVersion  int16
}

var (
	ErrInvalidAttachment    = errors.New("bill id and source token are required")
	ErrDestinationForbidden = mutation.Forbidden
	ErrTabFinalized         = mutation.Finalized
	ErrSourceUnavailable    = errors.New("source bill unavailable")
)

func validateAttach(command AttachBillCommand) error {
	if command.TabID == 0 || command.TabID > math.MaxUint32 || command.BillID == 0 || command.BillID > math.MaxUint32 || strings.TrimSpace(command.BillToken) == "" {
		return ErrInvalidAttachment
	}
	if strings.TrimSpace(command.TabToken) == "" {
		return ErrDestinationForbidden
	}
	return nil
}

type TabService interface {
	CreateTab(context.Context, *models.Tab, string) (*models.TabMember, error)
	GetTab(uint) (*models.Tab, error)
	GetTabAuth(uint) (*models.Tab, error)
	UpdateTab(context.Context, SettingsCommand) error
	AddBillToTab(context.Context, AttachBillCommand) error
	UpdateBillItemAssignmentsBatch(context.Context, AssignmentCommand) error
	UpdateBillPersonSharePaid(context.Context, SharePaidCommand) error
	FinalizeTab(context.Context, FinalizeCommand) ([]models.TabSettlement, error)
	GetSettlements(uint) ([]models.TabSettlement, error)
	UpdateSettlementPaid(context.Context, SettlementPaidCommand) error
	JoinTab(context.Context, JoinCommand) (*models.TabMember, bool, error)
	GetMemberByToken(string) (*models.TabMember, error)
	GetMembers(uint) ([]models.TabMember, error)
	DeleteMember(context.Context, LeaveCommand) error
}
type tabService struct{ repo TabRepository }

func (s *tabService) CreateTab(ctx context.Context, t *models.Tab, name string) (*models.TabMember, error) {
	var creator *models.TabMember
	if name != "" {
		token, err := security.GenerateSecureToken()
		if err != nil {
			return nil, err
		}
		creator = &models.TabMember{DisplayName: name, MemberToken: token, Role: "creator", JoinedAt: time.Now()}
	}
	if err := s.repo.Create(ctx, t, creator); err != nil {
		return nil, err
	}
	return creator, nil
}
func (s *tabService) GetTab(id uint) (tab *models.Tab, err error) {
	tab, err = s.repo.GetById(id)
	if err != nil {
		return nil, err
	}
	// Strip every source capability even when a later bill needs review. Retain
	// the tab capability internally so the handler can authorize that response.
	for i := range tab.Bills {
		tab.Bills[i] = billpkg.ReadCurrency(tab.Bills[i])
		tab.Bills[i].AccessToken = ""
	}
	tab.TotalStatus = "available"
	var total int64
	var totalErr error
	for _, b := range tab.Bills {
		cents, e := billpkg.FrozenUSDTotalCents(b)
		if e != nil {
			totalErr = e
			break
		}
		total, e = billpkg.AddObligationCents(total, cents)
		if e != nil {
			totalErr = e
			break
		}
	}
	if totalErr == nil {
		tab.TotalAmount, totalErr = billpkg.ObligationDollars(total)
	}
	if totalErr != nil {
		tab.TotalStatus = "accounting_review_required"
	}
	tab.ReferenceBalances, err = ReferenceNetBalances(tab)
	tab.NetBalanceStatus = "available"
	if err != nil {
		tab.ReferenceBalances = nil
		tab.NetBalanceStatus = "identity_review_required"
		if errors.Is(err, mutation.Review) {
			tab.NetBalanceStatus = "accounting_review_required"
		}
	}
	if totalErr != nil {
		tab.ReferenceBalances = nil
		tab.NetBalanceStatus = "accounting_review_required"
	}
	if err == nil && totalErr == nil {
		tab.NetBalances = legacyNetBalances(tab.ReferenceBalances)
	}
	return tab, totalErr
}

func (s *tabService) GetTabAuth(id uint) (tab *models.Tab, err error) {
	return s.repo.GetAuthById(id)
}

func (s *tabService) UpdateTab(ctx context.Context, c SettingsCommand) error {
	return s.repo.Update(ctx, c)
}
func (s *tabService) AddBillToTab(ctx context.Context, c AttachBillCommand) error {
	if err := validateAttach(c); err != nil {
		return err
	}
	return s.repo.AttachBill(ctx, c)
}
func (s *tabService) UpdateBillItemAssignmentsBatch(ctx context.Context, c AssignmentCommand) error {
	return s.repo.UpdateBillItemAssignmentsBatch(ctx, c)
}
func (s *tabService) UpdateBillPersonSharePaid(ctx context.Context, c SharePaidCommand) error {
	return s.repo.UpdateBillPersonSharePaid(ctx, c)
}
func (s *tabService) FinalizeTab(ctx context.Context, c FinalizeCommand) ([]models.TabSettlement, error) {
	return s.repo.FinalizeOnce(ctx, c)
}
func (s *tabService) GetSettlements(id uint) ([]models.TabSettlement, error) {
	return s.repo.GetSettlements(id)
}
func (s *tabService) UpdateSettlementPaid(ctx context.Context, c SettlementPaidCommand) error {
	return s.repo.UpdateSettlementPaid(ctx, c)
}
func (s *tabService) JoinTab(ctx context.Context, c JoinCommand) (*models.TabMember, bool, error) {
	return s.repo.Join(ctx, c)
}
func (s *tabService) GetMemberByToken(token string) (*models.TabMember, error) {
	return s.repo.GetMemberByToken(token)
}
func (s *tabService) GetMembers(id uint) ([]models.TabMember, error) {
	return s.repo.GetMembersByTabID(id)
}
func (s *tabService) DeleteMember(ctx context.Context, c LeaveCommand) error {
	return s.repo.Leave(ctx, c)
}
func NewTabService(repo TabRepository) TabService { return &tabService{repo} }

func legacyNetBalances(rows []models.ReferenceNetBalance) []models.NetBalance {
	result := make([]models.NetBalance, 0, len(rows))
	for _, row := range rows {
		result = append(result, models.NetBalance{From: row.From.Label, To: row.To.Label, Amount: row.Amount})
	}
	return result
}
