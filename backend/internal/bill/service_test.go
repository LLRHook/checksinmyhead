package bill

import (
	"backend/pkg/models"
	"context"
	"errors"
	"testing"
)

type fakeExchangeRateProvider struct {
	quote models.ExchangeRateQuote
	err   error
}

func (f *fakeExchangeRateProvider) LatestUSD(_ context.Context, _ string) (models.ExchangeRateQuote, error) {
	return f.quote, f.err
}

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

func TestCreateBill_FreezesLatestDailyConversion(t *testing.T) {
	repo := newMockRepo()
	provider := &fakeExchangeRateProvider{quote: models.ExchangeRateQuote{
		Base: "EUR", Quote: "USD", Rate: 1.1652, Date: "2026-08-29", Source: "frankfurter-v2-blended",
	}}
	svc := NewBillService(repo, provider)
	b := &models.Bill{CurrencyCode: "eur", Total: 85.82}

	err := svc.CreateBill(context.Background(), b)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if b.CurrencyCode != "EUR" || b.USDExchangeRate != 1.1652 || b.ExchangeRateDate != "2026-08-29" || b.ExchangeRateSource != "frankfurter-v2-blended" {
		t.Fatalf("unexpected frozen conversion: %+v", b)
	}
	if b.USDTotal != 100.00 {
		t.Fatalf("expected converted USD total 100.00, got %.2f", b.USDTotal)
	}
	if b.ID == 0 {
		t.Fatal("expected bill to be persisted")
	}
}

func TestCreateBill_ProviderFailureDoesNotPersistForeignCurrencyBill(t *testing.T) {
	repo := newMockRepo()
	provider := &fakeExchangeRateProvider{err: errors.New("provider unavailable")}
	svc := NewBillService(repo, provider)
	b := &models.Bill{CurrencyCode: "CAD", Total: 25}

	if err := svc.CreateBill(context.Background(), b); err == nil {
		t.Fatal("expected explicit exchange-rate error")
	}
	if len(repo.bills) != 0 {
		t.Fatal("foreign-currency bill must not be persisted without a verified rate")
	}
}

func TestCreateBill_LegacyUSDUsesStableIdentityConversion(t *testing.T) {
	repo := newMockRepo()
	svc := NewBillService(repo, nil)
	b := &models.Bill{Total: 42.37}

	if err := svc.CreateBill(context.Background(), b); err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if b.CurrencyCode != "USD" || b.USDExchangeRate != 1 || b.USDTotal != 42.37 {
		t.Fatalf("unexpected USD defaults: %+v", b)
	}
}
