package tab

import "backend/pkg/models"

type TabService interface {
	CreateTab(tab *models.Tab) error
	GetTab(id uint) (tab *models.Tab, err error)
	UpdateTab(tab *models.Tab) error
	AddBillToTab(tabID uint, billID uint) error
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

func (s *tabService) AddBillToTab(tabID uint, billID uint) error {
	return s.repo.AddBill(tabID, billID)
}

func NewTabService(repo TabRepository) TabService {
	return &tabService{repo: repo}
}
