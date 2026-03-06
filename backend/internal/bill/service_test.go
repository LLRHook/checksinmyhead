package bill

import (
	"backend/pkg/models"
	"errors"
	"testing"
)

// ── Mock BillRepository ─────────────────────────────────────────

type mockBillRepository struct {
	bills map[uint]*models.Bill

	createErr          error
	getByIdErr         error
	updateErr          error
	deleteErr          error
	updateSharePaidErr error

	updatedShareID   uint
	updatedSharePaid bool
}

func newMockRepo() *mockBillRepository {
	return &mockBillRepository{
		bills: make(map[uint]*models.Bill),
	}
}

func (m *mockBillRepository) Create(bill *models.Bill) error {
	if m.createErr != nil {
		return m.createErr
	}
	bill.ID = uint(len(m.bills) + 1)
	m.bills[bill.ID] = bill
	return nil
}

func (m *mockBillRepository) GetById(id uint) (*models.Bill, error) {
	if m.getByIdErr != nil {
		return nil, m.getByIdErr
	}
	bill, ok := m.bills[id]
	if !ok {
		return nil, errors.New("record not found")
	}
	return bill, nil
}

func (m *mockBillRepository) Update(bill *models.Bill) error { return m.updateErr }
func (m *mockBillRepository) Delete(id uint) error           { return m.deleteErr }

func (m *mockBillRepository) UpdatePersonSharePaid(id uint, paid bool) error {
	m.updatedShareID = id
	m.updatedSharePaid = paid
	return m.updateSharePaidErr
}

// ── Tests ───────────────────────────────────────────────────────

func TestUpdatePersonSharePaid_Success(t *testing.T) {
	repo := newMockRepo()
	svc := NewBillService(repo)

	err := svc.UpdatePersonSharePaid(5, true)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if repo.updatedShareID != 5 {
		t.Errorf("expected share ID 5, got %d", repo.updatedShareID)
	}
	if !repo.updatedSharePaid {
		t.Error("expected paid to be true")
	}
}

func TestUpdatePersonSharePaid_Error(t *testing.T) {
	repo := newMockRepo()
	repo.updateSharePaidErr = errors.New("db error")
	svc := NewBillService(repo)

	err := svc.UpdatePersonSharePaid(5, true)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}
