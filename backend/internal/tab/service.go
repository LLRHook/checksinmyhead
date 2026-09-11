package tab

import (
	"backend/pkg/models"
	"backend/pkg/security"
	"errors"
	"fmt"
	"math"
	"sort"
	"strings"
	"time"
)

type TabService interface {
	CreateTab(tab *models.Tab) error
	GetTab(id uint) (tab *models.Tab, err error)
	GetTabAuth(id uint) (tab *models.Tab, err error)
	UpdateTab(tab *models.Tab) error
	AddBillToTab(tabID uint, billID uint, billToken string, memberID *uint) error
	UpdateBillItemAssignments(tabID uint, billID uint, itemID uint, assignments []models.ItemAssignment, expectedUpdatedAt *time.Time) error
	UpdateBillPersonSharePaid(tabID uint, billID uint, shareID uint, paid bool) error
	FinalizeTab(id uint) ([]models.TabSettlement, error)
	GetSettlements(tabID uint) ([]models.TabSettlement, error)
	UpdateSettlementPaid(id uint, paid bool) error
	JoinTab(tabID uint, displayName string) (*models.TabMember, error)
	JoinTabAsCreator(tabID uint, displayName string) (*models.TabMember, error)
	GetMemberByToken(token string) (*models.TabMember, error)
	GetMembers(tabID uint) ([]models.TabMember, error)
}

type tabService struct {
	repo TabRepository
}

func (s *tabService) CreateTab(tab *models.Tab) error {
	return s.repo.Create(tab)
}

func (s *tabService) GetTab(id uint) (tab *models.Tab, err error) {
	tab, err = s.repo.GetById(id)
	if err != nil {
		return nil, err
	}
	// Recalculate total from bills and strip bill access tokens
	var total float64
	for i := range tab.Bills {
		if tab.Bills[i].USDTotal > 0 {
			total += tab.Bills[i].USDTotal
		} else if tab.Bills[i].DisplayTotal != nil {
			total += *tab.Bills[i].DisplayTotal
		} else {
			total += tab.Bills[i].Total
		}
		tab.Bills[i].AccessToken = ""
	}
	tab.TotalAmount = total
	tab.NetBalances = ComputeNetBalances(tab)
	return tab, nil
}

func (s *tabService) GetTabAuth(id uint) (tab *models.Tab, err error) {
	return s.repo.GetAuthById(id)
}

func (s *tabService) UpdateTab(tab *models.Tab) error {
	return s.repo.Update(tab)
}

func (s *tabService) AddBillToTab(tabID uint, billID uint, billToken string, memberID *uint) error {
	return s.repo.AddBill(tabID, billID, billToken, memberID)
}

func (s *tabService) UpdateBillItemAssignments(tabID uint, billID uint, itemID uint, assignments []models.ItemAssignment, expectedUpdatedAt *time.Time) error {
	return s.repo.UpdateBillItemAssignments(tabID, billID, itemID, assignments, expectedUpdatedAt)
}

func (s *tabService) UpdateBillPersonSharePaid(tabID uint, billID uint, shareID uint, paid bool) error {
	return s.repo.UpdateBillPersonSharePaid(tabID, billID, shareID, paid)
}

func (s *tabService) FinalizeTab(id uint) ([]models.TabSettlement, error) {
	tab, err := s.repo.GetForFinalization(id)
	if err != nil {
		return nil, err
	}

	if tab.Finalized {
		return nil, errors.New("tab is already finalized")
	}

	if len(tab.Bills) == 0 {
		return nil, errors.New("tab has no bills")
	}

	// Compute per-person totals from bill person_shares
	personTotals := make(map[string]int64)
	personDisplayNames := make(map[string]string) // preserve original casing
	for _, bill := range tab.Bills {
		shareCents := allocateUSDShareCents(bill)
		for i, share := range bill.PersonShares {
			key := strings.ToLower(share.PersonName)
			personTotals[key] += shareCents[i]
			// Prefer a capitalized variant over all-lowercase
			if existing, ok := personDisplayNames[key]; !ok {
				personDisplayNames[key] = share.PersonName
			} else if existing == key && share.PersonName != key {
				personDisplayNames[key] = share.PersonName
			}
		}
	}

	// Create settlement records
	var settlements []models.TabSettlement
	for key, amount := range personTotals {
		settlements = append(settlements, models.TabSettlement{
			TabID:      id,
			PersonName: personDisplayNames[key],
			Amount:     float64(amount) / 100,
			Paid:       false,
		})
	}

	if err := s.repo.CreateSettlements(settlements); err != nil {
		return nil, err
	}

	if err := s.repo.Finalize(id); err != nil {
		return nil, err
	}

	// Return the created settlements (now with IDs)
	return s.repo.GetSettlements(id)
}

func (s *tabService) GetSettlements(tabID uint) ([]models.TabSettlement, error) {
	return s.repo.GetSettlements(tabID)
}

func (s *tabService) UpdateSettlementPaid(id uint, paid bool) error {
	return s.repo.UpdateSettlementPaid(id, paid)
}

func (s *tabService) JoinTab(tabID uint, displayName string) (*models.TabMember, error) {
	return s.createMember(tabID, displayName, "member")
}

func (s *tabService) JoinTabAsCreator(tabID uint, displayName string) (*models.TabMember, error) {
	return s.createMember(tabID, displayName, "creator")
}

func (s *tabService) createMember(tabID uint, displayName string, role string) (*models.TabMember, error) {
	memberToken, err := security.GenerateSecureToken()
	if err != nil {
		return nil, fmt.Errorf("failed to generate member token: %w", err)
	}
	member := &models.TabMember{
		TabID:       tabID,
		DisplayName: displayName,
		MemberToken: memberToken,
		Role:        role,
		JoinedAt:    time.Now(),
	}
	if err := s.repo.CreateMember(member); err != nil {
		return nil, err
	}
	return member, nil
}

func (s *tabService) GetMemberByToken(token string) (*models.TabMember, error) {
	return s.repo.GetMemberByToken(token)
}

func (s *tabService) GetMembers(tabID uint) ([]models.TabMember, error) {
	return s.repo.GetMembersByTabID(tabID)
}

func NewTabService(repo TabRepository) TabService {
	return &tabService{repo: repo}
}

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
	for i := int64(0); i < remaining; i++ {
		result[remainders[int(i%int64(len(remainders)))].index]++
	}

	return result
}

// ComputeNetBalances takes a Tab (with Members, Bills, PersonShares preloaded)
// and returns simplified "who owes whom" transactions using greedy settlement.
func ComputeNetBalances(tab *models.Tab) []models.NetBalance {
	memberNames := make(map[uint]string)
	for _, m := range tab.Members {
		memberNames[m.ID] = m.DisplayName
	}

	displayNames := make(map[string]string)
	for _, m := range tab.Members {
		key := strings.ToLower(m.DisplayName)
		displayNames[key] = m.DisplayName
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
