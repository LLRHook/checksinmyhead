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

// ImageQuerier provides read access to tab images without importing the image package.
type ImageQuerier interface {
	GetByTabID(tabID uint) ([]models.TabImage, error)
}

type TabService interface {
	CreateTab(tab *models.Tab) error
	GetTab(id uint) (tab *models.Tab, err error)
	UpdateTab(tab *models.Tab) error
	AddBillToTab(tabID uint, billID uint, memberID *uint) error
	FinalizeTab(id uint) ([]models.TabSettlement, error)
	GetSettlements(tabID uint) ([]models.TabSettlement, error)
	UpdateSettlementPaid(id uint, paid bool) error
	JoinTab(tabID uint, displayName string) (*models.TabMember, error)
	JoinTabAsCreator(tabID uint, displayName string) (*models.TabMember, error)
	GetMemberByToken(token string) (*models.TabMember, error)
	GetMembers(tabID uint) ([]models.TabMember, error)
}

type tabService struct {
	repo       TabRepository
	imgQuerier ImageQuerier
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
		total += tab.Bills[i].Total
		tab.Bills[i].AccessToken = ""
	}
	tab.TotalAmount = total
	tab.NetBalances = ComputeNetBalances(tab)
	return tab, nil
}

func (s *tabService) UpdateTab(tab *models.Tab) error {
	return s.repo.Update(tab)
}

func (s *tabService) AddBillToTab(tabID uint, billID uint, memberID *uint) error {
	return s.repo.AddBill(tabID, billID, memberID)
}

func (s *tabService) FinalizeTab(id uint) ([]models.TabSettlement, error) {
	tab, err := s.GetTab(id)
	if err != nil {
		return nil, err
	}

	if tab.Finalized {
		return nil, errors.New("tab is already finalized")
	}

	if len(tab.Bills) == 0 {
		return nil, errors.New("tab has no bills")
	}

	// Check all images are processed
	images, err := s.imgQuerier.GetByTabID(id)
	if err != nil {
		return nil, err
	}
	for _, img := range images {
		if !img.Processed {
			return nil, errors.New("all images must be marked as processed before finalizing")
		}
	}

	// Compute per-person totals from bill person_shares
	personTotals := make(map[string]float64)
	personDisplayNames := make(map[string]string) // preserve original casing
	for _, bill := range tab.Bills {
		for _, share := range bill.PersonShares {
			key := strings.ToLower(share.PersonName)
			personTotals[key] += share.Total
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
			Amount:     amount,
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

func NewTabService(repo TabRepository, imgQuerier ImageQuerier) TabService {
	return &tabService{repo: repo, imgQuerier: imgQuerier}
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

	nets := make(map[string]float64)

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
		nets[payerKey] += bill.Total

		for _, share := range bill.PersonShares {
			key := strings.ToLower(share.PersonName)
			nets[key] -= share.Total
			if _, exists := displayNames[key]; !exists {
				displayNames[key] = share.PersonName
			}
		}
	}

	type entry struct {
		name   string
		amount float64
	}

	var creditors, debtors []entry
	for key, net := range nets {
		rounded := math.Round(net*100) / 100
		if rounded >= 0.01 {
			creditors = append(creditors, entry{displayNames[key], rounded})
		} else if rounded <= -0.01 {
			debtors = append(debtors, entry{displayNames[key], -rounded})
		}
	}

	sort.Slice(creditors, func(i, j int) bool { return creditors[i].amount > creditors[j].amount })
	sort.Slice(debtors, func(i, j int) bool { return debtors[i].amount > debtors[j].amount })

	var balances []models.NetBalance
	ci, di := 0, 0
	for ci < len(creditors) && di < len(debtors) {
		amt := math.Min(creditors[ci].amount, debtors[di].amount)
		amt = math.Round(amt*100) / 100
		if amt > 0 {
			balances = append(balances, models.NetBalance{
				From:   debtors[di].name,
				To:     creditors[ci].name,
				Amount: amt,
			})
		}
		creditors[ci].amount -= amt
		debtors[di].amount -= amt
		if creditors[ci].amount < 0.01 {
			ci++
		}
		if debtors[di].amount < 0.01 {
			di++
		}
	}

	return balances
}
