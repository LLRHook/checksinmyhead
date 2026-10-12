package bill

import (
	"backend/pkg/models"
	"context"
	"errors"
	"testing"
	"time"
)

type fakeExchangeRateProvider struct {
	quote models.ExchangeRateQuote
	err   error
	calls int
}

func (f *fakeExchangeRateProvider) LatestUSD(_ context.Context, _ string) (models.ExchangeRateQuote, error) {
	f.calls++
	return f.quote, f.err
}

// ── Mock BillRepository ─────────────────────────────────────────

type mockBillRepository struct {
	bills map[uint]*models.Bill

	createErr          error
	getByIdErr         error
	updateSharePaidErr error

	updatedShareBill uint
	updatedShareName string
	updatedSharePaid bool
	updatedBillID    uint
	updatedItemID    uint
	updatedItems     []models.ItemAssignment
	updatedBatch     []ItemAssignmentsUpdate
	assignmentErr    error
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

func (m *mockBillRepository) UpdatePersonSharePaid(billID uint, personName string, paid bool) error {
	m.updatedShareBill = billID
	m.updatedShareName = personName
	m.updatedSharePaid = paid
	return m.updateSharePaidErr
}

func (m *mockBillRepository) UpdateItemAssignments(billID uint, itemID uint, assignments []models.ItemAssignment, _ *time.Time) error {
	m.updatedBillID = billID
	m.updatedItemID = itemID
	m.updatedItems = assignments
	return m.assignmentErr
}

func (m *mockBillRepository) UpdateItemAssignmentsBatch(billID uint, updates []ItemAssignmentsUpdate) error {
	m.updatedBillID = billID
	m.updatedBatch = updates
	return m.assignmentErr
}

// ── Tests ───────────────────────────────────────────────────────

func TestUpdatePersonSharePaid_Success(t *testing.T) {
	repo := newMockRepo()
	svc := NewBillService(repo)

	err := svc.UpdatePersonSharePaid(27, "Alex", true)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if repo.updatedShareBill != 27 || repo.updatedShareName != "Alex" {
		t.Errorf("unexpected share identity: bill=%d person=%q", repo.updatedShareBill, repo.updatedShareName)
	}
	if !repo.updatedSharePaid {
		t.Error("expected paid to be true")
	}
}

func TestUpdatePersonSharePaid_Error(t *testing.T) {
	repo := newMockRepo()
	repo.updateSharePaidErr = errors.New("db error")
	svc := NewBillService(repo)

	err := svc.UpdatePersonSharePaid(27, "Alex", true)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

func TestUpdateItemAssignmentsBatch_PassesAllItemsTogether(t *testing.T) {
	repo := newMockRepo()
	svc := NewBillService(repo)
	updates := []ItemAssignmentsUpdate{
		{ItemID: 8, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}},
		{ItemID: 9, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}},
	}

	if err := svc.UpdateItemAssignmentsBatch(33, updates); err != nil {
		t.Fatalf("expected batch update success, got %v", err)
	}
	if repo.updatedBillID != 33 || len(repo.updatedBatch) != 2 {
		t.Fatalf("unexpected batch write: bill=%d updates=%#v", repo.updatedBillID, repo.updatedBatch)
	}
}

func TestBuildLazyPersonShares_KeepEarlierSharesStableAsItemsAreClaimed(t *testing.T) {
	bill := &models.Bill{
		ID:        42,
		Subtotal:  30,
		Tax:       3,
		TipAmount: 6,
		Items: []models.BillItem{
			{ID: 1, Price: 10, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}},
		},
	}
	firstClaim := BuildLazyPersonShares(bill)
	if len(firstClaim) != 1 {
		t.Fatalf("expected one initial share, got %d", len(firstClaim))
	}

	bill.Items = append(bill.Items, models.BillItem{
		ID: 2, Price: 20,
		Assignments: []models.ItemAssignment{{PersonName: "Bob", Percentage: 100}},
	})
	allClaims := BuildLazyPersonShares(bill)
	var alex *models.PersonShare
	for i := range allClaims {
		if allClaims[i].PersonName == "Alex" {
			alex = &allClaims[i]
		}
	}
	if alex == nil {
		t.Fatal("expected Alex's share to remain present")
	}
	if alex.TaxShare != firstClaim[0].TaxShare || alex.TipShare != firstClaim[0].TipShare || alex.Total != firstClaim[0].Total {
		t.Fatalf("Alex's due changed after Bob claimed an item: before=%+v after=%+v", firstClaim[0], *alex)
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

func TestCreateBill_RejectsUnsupportedCurrencyWithoutCallingProvider(t *testing.T) {
	repo := newMockRepo()
	provider := &fakeExchangeRateProvider{quote: models.ExchangeRateQuote{
		Base: "ZZZ", Quote: "USD", Rate: 2, Date: "2026-08-29", Source: "unexpected",
	}}
	svc := NewBillService(repo, provider)
	b := &models.Bill{CurrencyCode: "ZZZ", Total: 25}

	if err := svc.CreateBill(context.Background(), b); !errors.Is(err, ErrInvalidCurrency) {
		t.Fatalf("expected unsupported currency error, got %v", err)
	}
	if len(repo.bills) != 0 {
		t.Fatal("unsupported currency bill must not be persisted")
	}
	if provider.calls != 0 {
		t.Fatalf("unsupported currency reached provider %d time(s)", provider.calls)
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
