package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"backend/pkg/security"
	"context"
	"errors"
	"math"
	"sort"
	"strings"
	"time"
)

// AttachBillCommand carries independent source and destination capabilities.
// Attribution is resolved in the transaction; callers cannot supply member IDs.
type AttachBillCommand struct {
	TabID       uint
	BillID      uint
	TabToken    string
	MemberToken string
	BillToken   string
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
		tab.Bills[i].AccessToken = ""
	}
	var total int64
	for _, b := range tab.Bills {
		cents, valueErr := billpkg.FrozenUSDTotalCents(b)
		if valueErr != nil {
			return tab, valueErr
		}
		total, err = billpkg.AddObligationCents(total, cents)
		if err != nil {
			return tab, err
		}
	}
	tab.TotalAmount, err = billpkg.ObligationDollars(total)
	if err != nil {
		return tab, err
	}
	tab.NetBalances = ComputeNetBalances(tab)
	return tab, nil
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

// allocateUSDShareCents converts one bill's assigned shares to USD. Fully
// assigned bills preserve the frozen USD total exactly; partial bills preserve
// only their assigned value. Any fractional-cent remainder uses a stable
// largest-remainder allocation so recalculation is deterministic.
func allocateUSDShareCents(bill models.Bill) []int64 {
	result := make([]int64, len(bill.PersonShares))
	if len(result) == 0 {
		return result
	}

	bill.NormalizeCurrency()
	var shareTotal float64
	for _, share := range bill.PersonShares {
		if share.Total > 0 {
			shareTotal += share.Total
		}
	}
	if shareTotal <= 0 {
		return result
	}

	// Partial active assignments must remain partial. Reconcile against the
	// full frozen bill total only when the recorded shares cover the bill;
	// otherwise reconcile only the converted amount that has been assigned.
	targetCents := int64(math.Round(shareTotal * bill.USDExchangeRate * 100))
	if math.Abs(shareTotal-bill.Total) < 0.005 {
		targetCents = int64(math.Round(bill.USDTotal * 100))
	}
	if targetCents <= 0 {
		return result
	}

	type remainder struct {
		index    int
		fraction float64
		name     string
	}
	remainders := make([]remainder, 0, len(bill.PersonShares))
	var allocated int64
	for i, share := range bill.PersonShares {
		exactCents := 0.0
		if share.Total > 0 {
			exactCents = float64(targetCents) * share.Total / shareTotal
		}
		wholeCents := int64(exactCents)
		result[i] = wholeCents
		allocated += wholeCents
		remainders = append(remainders, remainder{
			index:    i,
			fraction: exactCents - float64(wholeCents),
			name:     share.PersonName,
		})
	}

	sort.SliceStable(remainders, func(i, j int) bool {
		if remainders[i].fraction != remainders[j].fraction {
			return remainders[i].fraction > remainders[j].fraction
		}
		if remainders[i].name != remainders[j].name {
			return remainders[i].name < remainders[j].name
		}
		return remainders[i].index < remainders[j].index
	})
	remaining := targetCents - allocated
	each, residual := remaining/int64(len(remainders)), remaining%int64(len(remainders))
	for i, r := range remainders {
		result[r.index] += each
		if int64(i) < residual {
			result[r.index]++
		}
	}

	return result
}

// ComputeNetBalances takes a Tab (with Members, Bills, PersonShares preloaded)
// and returns simplified "who owes whom" transactions using greedy settlement.
func ComputeNetBalances(tab *models.Tab) []models.NetBalance {
	memberNames := make(map[uint]string)
	displayNames := make(map[string]string)
	for _, m := range tab.Members {
		memberNames[m.ID] = m.DisplayName
		displayNames[strings.ToLower(m.DisplayName)] = m.DisplayName
	}

	nets := make(map[string]int64)

	for _, bill := range tab.Bills {
		if bill.PaidByMemberID == nil {
			continue
		}
		payerName, ok := memberNames[*bill.PaidByMemberID]
		if !ok {
			continue
		}
		payerKey := strings.ToLower(payerName)
		displayNames[payerKey] = payerName
		shareCents := allocateUSDShareCents(bill)
		for i, share := range bill.PersonShares {
			key := strings.ToLower(share.PersonName)
			nets[payerKey] += shareCents[i]
			nets[key] -= shareCents[i]
			if _, exists := displayNames[key]; !exists {
				displayNames[key] = share.PersonName
			}
		}
	}

	type entry struct {
		name   string
		amount int64
	}

	var creditors, debtors []entry
	for key, net := range nets {
		if net >= 1 {
			creditors = append(creditors, entry{displayNames[key], net})
		} else if net <= -1 {
			debtors = append(debtors, entry{displayNames[key], -net})
		}
	}

	sort.Slice(creditors, func(i, j int) bool { return creditors[i].amount > creditors[j].amount })
	sort.Slice(debtors, func(i, j int) bool { return debtors[i].amount > debtors[j].amount })

	var balances []models.NetBalance
	ci, di := 0, 0
	for ci < len(creditors) && di < len(debtors) {
		amt := min(creditors[ci].amount, debtors[di].amount)
		if amt > 0 {
			balances = append(balances, models.NetBalance{
				From:   debtors[di].name,
				To:     creditors[ci].name,
				Amount: float64(amt) / 100,
			})
		}
		creditors[ci].amount -= amt
		debtors[di].amount -= amt
		if creditors[ci].amount == 0 {
			ci++
		}
		if debtors[di].amount == 0 {
			di++
		}
	}

	return balances
}
