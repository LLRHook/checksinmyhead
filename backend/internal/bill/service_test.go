package bill

import (
	"backend/pkg/models"
	"backend/pkg/mutation"
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

func (f *fakeExchangeRateProvider) Latest(_ context.Context, _, _ string) (models.ExchangeRateQuote, error) {
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
	updatedShareID   uint
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

func (m *mockBillRepository) Create(_ context.Context, c CreationInsert) (CreationRecord, error) {
	if m.createErr != nil {
		return CreationRecord{}, m.createErr
	}
	bill := c.Bill
	bill.ID = uint(len(m.bills) + 1)
	if c.Replay != nil {
		bill.CreationKeyDigest = append([]byte(nil), c.Replay.KeyDigest[:]...)
		bill.CreationFingerprint = append([]byte(nil), c.Replay.Fingerprint[:]...)
		v := c.Replay.Version
		bill.CreationFingerprintVersion = &v
	}
	m.bills[bill.ID] = bill
	return creationRow{ID: bill.ID, AccessToken: bill.AccessToken, CurrencyCode: bill.CurrencyCode, USDExchangeRate: bill.USDExchangeRate, USDTotal: bill.USDTotal, ExchangeRateDate: bill.ExchangeRateDate, ExchangeRateSource: bill.ExchangeRateSource, CreationFingerprint: bill.CreationFingerprint, CreationFingerprintVersion: bill.CreationFingerprintVersion}.record(), nil
}
func (m *mockBillRepository) LookupCreation(_ context.Context, digest [32]byte) (*CreationRecord, error) {
	for _, v := range m.bills {
		if string(v.CreationKeyDigest) == string(digest[:]) {
			r := creationRow{ID: v.ID, AccessToken: v.AccessToken, CurrencyCode: v.CurrencyCode, USDExchangeRate: v.USDExchangeRate, USDTotal: v.USDTotal, ExchangeRateDate: v.ExchangeRateDate, ExchangeRateSource: v.ExchangeRateSource, CreationFingerprint: v.CreationFingerprint, CreationFingerprintVersion: v.CreationFingerprintVersion}.record()
			return &r, nil
		}
	}
	return nil, nil
}

func (m *mockBillRepository) GetById(id uint) (*models.Bill, error) {
	if m.getByIdErr != nil {
		return nil, m.getByIdErr
	}
	bill, ok := m.bills[id]
	if !ok {
		return nil, errors.New("record not found")
	}
	copy := *bill
	return &copy, nil
}

func (m *mockBillRepository) UpdatePersonSharePaid(_ context.Context, c BillSharePaidCommand) error {
	if b, ok := m.bills[c.Access.BillID]; ok && c.Access.BillToken != b.AccessToken {
		return mutation.Forbidden
	}
	m.updatedShareBill = c.Access.BillID
	m.updatedShareID = c.ShareID
	m.updatedSharePaid = c.Paid
	return m.updateSharePaidErr
}
func (m *mockBillRepository) UpdateItemAssignmentsBatch(_ context.Context, c ClaimCommand) error {
	if b, ok := m.bills[c.Access.BillID]; ok {
		if b.AccessToken != c.Access.BillToken {
			return mutation.Forbidden
		}
		if !b.LazyMode || b.TabID != nil {
			return mutation.StandaloneOnly
		}
	}
	m.updatedBillID = c.Access.BillID
	m.updatedBatch = c.Updates
	if len(c.Updates) > 0 {
		m.updatedItemID = c.Updates[0].ItemID
		m.updatedItems = c.Updates[0].Assignments
	}
	return m.assignmentErr
}

// ── Tests ───────────────────────────────────────────────────────

func TestUpdatePersonSharePaid_Success(t *testing.T) {
	repo := newMockRepo()
	svc := NewBillService(repo, &fakeExchangeRateProvider{})

	err := svc.UpdatePersonSharePaid(context.Background(), BillSharePaidCommand{Access: BillAccess{BillID: 27, BillToken: "source"}, ShareID: 159, Paid: true})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if repo.updatedShareBill != 27 || repo.updatedShareID != 159 {
		t.Errorf("unexpected share identity: bill=%d share=%d", repo.updatedShareBill, repo.updatedShareID)
	}
	if !repo.updatedSharePaid {
		t.Error("expected paid to be true")
	}
}

func TestUpdatePersonSharePaid_Error(t *testing.T) {
	repo := newMockRepo()
	repo.updateSharePaidErr = errors.New("db error")
	svc := NewBillService(repo, &fakeExchangeRateProvider{})

	err := svc.UpdatePersonSharePaid(context.Background(), BillSharePaidCommand{Access: BillAccess{BillID: 27, BillToken: "source"}, ShareID: 159, Paid: true})
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

func TestUpdateItemAssignmentsBatch_PassesAllItemsTogether(t *testing.T) {
	repo := newMockRepo()
	svc := NewBillService(repo, &fakeExchangeRateProvider{})
	updates := []ItemAssignmentsUpdate{
		{ItemID: 8, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}},
		{ItemID: 9, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 100}}},
	}

	if err := svc.UpdateItemAssignmentsBatch(context.Background(), ClaimCommand{Access: BillAccess{BillID: 33}, Updates: updates}); err != nil {
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
	firstClaim, err := BuildLazyPersonShares(bill)
	if err != nil {
		t.Fatal(err)
	}
	if len(firstClaim) != 1 {
		t.Fatalf("expected one initial share, got %d", len(firstClaim))
	}

	bill.Items = append(bill.Items, models.BillItem{
		ID: 2, Price: 20,
		Assignments: []models.ItemAssignment{{PersonName: "Bob", Percentage: 100}},
	})
	allClaims, err := BuildLazyPersonShares(bill)
	if err != nil {
		t.Fatal(err)
	}
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
	provider := &fakeExchangeRateProvider{quote: models.ExchangeRateQuote{RetrievedAt: quoteReceiptTime(),
		Base: "EUR", Quote: "USD", Rate: 1.1652, Date: time.Now().UTC().Format(time.DateOnly), Source: "frankfurter-v2-blended",
	}}
	svc := NewBillService(repo, provider)
	b := &models.Bill{Name: "Cafe", Subtotal: 85.82, CurrencyCode: "eur", Total: 85.82}

	_, err := svc.CreateBill(context.Background(), CreateBillCommand{Content: b})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	b = repo.bills[1]
	if b.CurrencyCode != "EUR" || b.USDExchangeRate != 1.1652 || b.ExchangeRateDate != provider.quote.Date || b.ExchangeRateSource != "frankfurter-v2-blended" {
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
	b := &models.Bill{Name: "Cafe", Subtotal: 25, CurrencyCode: "CAD", Total: 25}

	if _, err := svc.CreateBill(context.Background(), CreateBillCommand{Content: b}); err == nil {
		t.Fatal("expected explicit exchange-rate error")
	}
	if len(repo.bills) != 0 {
		t.Fatal("foreign-currency bill must not be persisted without a verified rate")
	}
}

func TestCreateBill_RejectsUnsupportedCurrencyWithoutCallingProvider(t *testing.T) {
	repo := newMockRepo()
	provider := &fakeExchangeRateProvider{quote: models.ExchangeRateQuote{RetrievedAt: quoteReceiptTime(),
		Base: "ZZZ", Quote: "USD", Rate: 2, Date: time.Now().UTC().Format(time.DateOnly), Source: "unexpected",
	}}
	svc := NewBillService(repo, provider)
	b := &models.Bill{Name: "Cafe", Subtotal: 25, CurrencyCode: "ZZZ", Total: 25}

	if _, err := svc.CreateBill(context.Background(), CreateBillCommand{Content: b}); !errors.Is(err, ErrInvalidCurrency) {
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
	svc := NewBillService(repo, &fakeExchangeRateProvider{})
	b := &models.Bill{Name: "Cafe", Subtotal: 42.37, Total: 42.37}

	if _, err := svc.CreateBill(context.Background(), CreateBillCommand{Content: b}); err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	b = repo.bills[1]
	if b.CurrencyCode != "USD" || b.USDExchangeRate != 1 || b.USDTotal != 42.37 {
		t.Fatalf("unexpected USD defaults: %+v", b)
	}
}
