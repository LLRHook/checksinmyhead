package tab

import (
	"backend/pkg/models"
	"backend/pkg/security"
	"errors"
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
	// Recalculate total from bills
	var total float64
	for _, bill := range tab.Bills {
		total += bill.Total
	}
	tab.TotalAmount = total
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
	for _, bill := range tab.Bills {
		for _, share := range bill.PersonShares {
			key := strings.ToLower(share.PersonName)
			personTotals[key] += share.Total
		}
	}

	// Create settlement records
	var settlements []models.TabSettlement
	for name, amount := range personTotals {
		// Capitalize first letter for display
		displayName := strings.ToUpper(name[:1]) + name[1:]
		settlements = append(settlements, models.TabSettlement{
			TabID:      id,
			PersonName: displayName,
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
	member := &models.TabMember{
		TabID:       tabID,
		DisplayName: displayName,
		MemberToken: security.GenerateSecureToken(),
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
