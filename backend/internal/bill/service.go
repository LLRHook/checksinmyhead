package bill

import "backend/pkg/models"

type BillService interface {
	CreateBill(bill *models.Bill) error
	GetBill(id uint) (bill *models.Bill, err error)
}

type billService struct {
	repo BillRepository
}

func (b *billService) CreateBill(bill *models.Bill) error {
	return b.repo.Create(bill)
}

func (b *billService) GetBill(id uint) (bill *models.Bill, err error) {
	return b.repo.GetById(id)
}

func NewBillService(repo BillRepository) BillService {
	return &billService{repo: repo}
}
