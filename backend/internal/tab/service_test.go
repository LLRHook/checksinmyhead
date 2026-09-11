package tab

import (
	"backend/pkg/models"
	"errors"
	"testing"
	"time"
)

// ── Mock TabRepository ──────────────────────────────────────────

type mockTabRepository struct {
	tabs        map[uint]*models.Tab
	members     []models.TabMember
	settlements []models.TabSettlement

	createErr            error
	getByIdErr           error
	updateErr            error
	deleteErr            error
	addBillErr           error
	finalizeErr          error
	getSettlementsErr    error
	createSettlementsErr error
	updatePaidErr        error
	createMemberErr      error
	getMemberByTokenErr  error
	getMembersByTabIDErr error
	deleteMemberErr      error
	updateAssignmentsErr error

	// Capture calls
	addBillTabID          uint
	addBillBillID         uint
	addBillBillToken      string
	addBillMemberID       *uint
	addBillPaidByMemberID *uint
	finalizedID           uint
	createdSettlements    []models.TabSettlement
	updatedAssignments    []models.ItemAssignment
}

func newMockRepo() *mockTabRepository {
	return &mockTabRepository{
		tabs: make(map[uint]*models.Tab),
	}
}

func (m *mockTabRepository) Create(tab *models.Tab) error {
	if m.createErr != nil {
		return m.createErr
	}
	tab.ID = uint(len(m.tabs) + 1)
	m.tabs[tab.ID] = tab
	return nil
}

func (m *mockTabRepository) GetById(id uint) (*models.Tab, error) {
	if m.getByIdErr != nil {
		return nil, m.getByIdErr
	}
	tab, ok := m.tabs[id]
	if !ok {
		return nil, errors.New("record not found")
	}
	return tab, nil
}

func (m *mockTabRepository) GetAuthById(id uint) (*models.Tab, error) {
	return m.GetById(id)
}

func (m *mockTabRepository) GetForFinalization(id uint) (*models.Tab, error) {
	return m.GetById(id)
}

func (m *mockTabRepository) Update(tab *models.Tab) error { return m.updateErr }
func (m *mockTabRepository) Delete(id uint) error         { return m.deleteErr }

func (m *mockTabRepository) AddBill(tabID uint, billID uint, billToken string, memberID *uint) error {
	m.addBillTabID = tabID
	m.addBillBillID = billID
	m.addBillBillToken = billToken
	m.addBillMemberID = memberID
	m.addBillPaidByMemberID = memberID
	return m.addBillErr
}

func (m *mockTabRepository) UpdateBillItemAssignments(tabID uint, billID uint, itemID uint, assignments []models.ItemAssignment, _ *time.Time) error {
	m.updatedAssignments = assignments
	return m.updateAssignmentsErr
}

func (m *mockTabRepository) UpdateBillPersonSharePaid(tabID uint, billID uint, shareID uint, paid bool) error {
	return nil
}

func (m *mockTabRepository) Finalize(id uint) error {
	m.finalizedID = id
	return m.finalizeErr
}

func (m *mockTabRepository) GetSettlements(tabID uint) ([]models.TabSettlement, error) {
	if m.getSettlementsErr != nil {
		return nil, m.getSettlementsErr
	}
	return m.settlements, nil
}

func (m *mockTabRepository) CreateSettlements(settlements []models.TabSettlement) error {
	if m.createSettlementsErr != nil {
		return m.createSettlementsErr
	}
	m.createdSettlements = settlements
	// Copy to settlements so GetSettlements returns them
	m.settlements = settlements
	return nil
}

func (m *mockTabRepository) UpdateSettlementPaid(id uint, paid bool) error {
	return m.updatePaidErr
}

func (m *mockTabRepository) CreateMember(member *models.TabMember) error {
	if m.createMemberErr != nil {
		return m.createMemberErr
	}
	member.ID = uint(len(m.members) + 1)
	m.members = append(m.members, *member)
	return nil
}

func (m *mockTabRepository) GetMemberByToken(token string) (*models.TabMember, error) {
	if m.getMemberByTokenErr != nil {
		return nil, m.getMemberByTokenErr
	}
	for _, mem := range m.members {
		if mem.MemberToken == token {
			return &mem, nil
		}
	}
	return nil, errors.New("not found")
}

func (m *mockTabRepository) GetMembersByTabID(tabID uint) ([]models.TabMember, error) {
	if m.getMembersByTabIDErr != nil {
		return nil, m.getMembersByTabIDErr
	}
	var result []models.TabMember
	for _, mem := range m.members {
		if mem.TabID == tabID {
			result = append(result, mem)
		}
	}
	return result, nil
}

func (m *mockTabRepository) DeleteMember(tabID uint, memberID uint) error {
	return m.deleteMemberErr
}

// ── Tests ───────────────────────────────────────────────────────

func TestFinalizeTab_Success(t *testing.T) {
	repo := newMockRepo()

	repo.tabs[1] = &models.Tab{
		ID:        1,
		Finalized: false,
		Bills: []models.Bill{
			{
				ID: 1, Total: 100,
				PersonShares: []models.PersonShare{
					{PersonName: "Alice", Total: 60},
					{PersonName: "Bob", Total: 40},
				},
			},
			{
				ID: 2, Total: 50,
				PersonShares: []models.PersonShare{
					{PersonName: "alice", Total: 30},
					{PersonName: "Bob", Total: 20},
				},
			},
		},
	}

	svc := NewTabService(repo)
	settlements, err := svc.FinalizeTab(1)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(settlements) != 2 {
		t.Fatalf("expected 2 settlements, got %d", len(settlements))
	}

	totals := make(map[string]float64)
	for _, s := range settlements {
		totals[s.PersonName] = s.Amount
	}

	// Alice (60) + alice (30) = 90, case-insensitive merge
	if totals["Alice"] != 90 {
		t.Errorf("expected Alice total 90, got %f", totals["Alice"])
	}
	// Bob (40) + Bob (20) = 60
	if totals["Bob"] != 60 {
		t.Errorf("expected Bob total 60, got %f", totals["Bob"])
	}

	if repo.finalizedID != 1 {
		t.Errorf("expected Finalize called with id 1, got %d", repo.finalizedID)
	}
}

func TestFinalizeTab_UsesFrozenUSDAmountsForMixedCurrencies(t *testing.T) {
	repo := newMockRepo()
	repo.tabs[1] = &models.Tab{
		ID: 1,
		Bills: []models.Bill{
			{CurrencyCode: "USD", USDExchangeRate: 1, Total: 25, USDTotal: 25, PersonShares: []models.PersonShare{{PersonName: "Alice", Total: 25}}},
			{CurrencyCode: "EUR", USDExchangeRate: 1.25, Total: 40, USDTotal: 50, PersonShares: []models.PersonShare{{PersonName: "Alice", Total: 24}, {PersonName: "Bob", Total: 16}}},
		},
	}
	svc := NewTabService(repo)

	settlements, err := svc.FinalizeTab(1)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	totals := map[string]float64{}
	for _, settlement := range settlements {
		totals[settlement.PersonName] = settlement.Amount
	}
	if totals["Alice"] != 55 || totals["Bob"] != 20 {
		t.Fatalf("expected stable USD settlements Alice=55 Bob=20, got %#v", totals)
	}
}

func TestFinalizeTab_ReconcilesFractionalCentsToFrozenUSDTotal(t *testing.T) {
	repo := newMockRepo()
	repo.tabs[1] = &models.Tab{
		ID: 1,
		Bills: []models.Bill{{
			CurrencyCode:    "EUR",
			USDExchangeRate: 1.25,
			Total:           0.80,
			USDTotal:        1.00,
			PersonShares: []models.PersonShare{
				{PersonName: "Alice", Total: 0.80 / 3},
				{PersonName: "Bob", Total: 0.80 / 3},
				{PersonName: "Cara", Total: 0.80 / 3},
			},
		}},
	}
	svc := NewTabService(repo)

	settlements, err := svc.FinalizeTab(1)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	totals := map[string]float64{}
	var sum float64
	for _, settlement := range settlements {
		totals[settlement.PersonName] = settlement.Amount
		sum += settlement.Amount
	}
	if sum != 1.00 {
		t.Fatalf("expected shares to reconcile to frozen USD total 1.00, got %.2f", sum)
	}
	if totals["Alice"] != 0.34 || totals["Bob"] != 0.33 || totals["Cara"] != 0.33 {
		t.Fatalf("expected deterministic largest-remainder allocation, got %#v", totals)
	}
}

func TestAllocateUSDShareCents_UsesOrdinalNameTieBreak(t *testing.T) {
	bill := models.Bill{
		CurrencyCode:    "EUR",
		USDExchangeRate: 1.25,
		Total:           0.80,
		USDTotal:        1.00,
		PersonShares: []models.PersonShare{
			{PersonName: "ä", Total: 0.80 / 3},
			{PersonName: "z", Total: 0.80 / 3},
			{PersonName: "Ω", Total: 0.80 / 3},
		},
	}

	amounts := allocateUSDShareCents(bill)
	if amounts[0] != 33 || amounts[1] != 34 || amounts[2] != 33 {
		t.Fatalf("expected ordinal tie-break to award z the extra cent, got %#v", amounts)
	}
}

func TestAllocateUSDShareCents_UsesUTF8OrderForSupplementaryNames(t *testing.T) {
	bill := models.Bill{
		CurrencyCode:    "EUR",
		USDExchangeRate: 1.25,
		Total:           0.008,
		USDTotal:        0.01,
		PersonShares: []models.PersonShare{
			{PersonName: "😀", Total: 0.004},
			{PersonName: "Ａ", Total: 0.004},
		},
	}

	amounts := allocateUSDShareCents(bill)
	if amounts[0] != 0 || amounts[1] != 1 {
		t.Fatalf("expected UTF-8 order to award fullwidth A the cent, got %#v", amounts)
	}
}

func TestFinalizeTab_DoesNotScalePartialAssignmentsToFullBill(t *testing.T) {
	repo := newMockRepo()
	repo.tabs[1] = &models.Tab{
		ID: 1,
		Bills: []models.Bill{{
			CurrencyCode:    "EUR",
			USDExchangeRate: 1.25,
			Total:           80,
			USDTotal:        100,
			PersonShares:    []models.PersonShare{{PersonName: "Alice", Total: 8}},
		}},
	}
	svc := NewTabService(repo)

	settlements, err := svc.FinalizeTab(1)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(settlements) != 1 || settlements[0].Amount != 10 {
		t.Fatalf("expected only the assigned EUR 8 to convert to USD 10, got %#v", settlements)
	}
}

func TestGetTab_UsesFrozenUSDTotalAndLegacyUSDFallback(t *testing.T) {
	repo := newMockRepo()
	repo.tabs[1] = &models.Tab{ID: 1, Bills: []models.Bill{
		{Total: 10},
		{CurrencyCode: "EUR", USDExchangeRate: 1.25, Total: 20, USDTotal: 25},
	}}
	svc := NewTabService(repo)

	tab, err := svc.GetTab(1)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if tab.TotalAmount != 35 {
		t.Fatalf("expected USD tab total 35, got %.2f", tab.TotalAmount)
	}
}

func TestFinalizeTab_AlreadyFinalized(t *testing.T) {
	repo := newMockRepo()

	repo.tabs[1] = &models.Tab{
		ID:        1,
		Finalized: true,
		Bills:     []models.Bill{{ID: 1}},
	}

	svc := NewTabService(repo)
	_, err := svc.FinalizeTab(1)
	if err == nil {
		t.Fatal("expected error for already finalized tab")
	}
	if err.Error() != "tab is already finalized" {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestFinalizeTab_NoBills(t *testing.T) {
	repo := newMockRepo()

	repo.tabs[1] = &models.Tab{
		ID:        1,
		Finalized: false,
		Bills:     []models.Bill{},
	}

	svc := NewTabService(repo)
	_, err := svc.FinalizeTab(1)
	if err == nil {
		t.Fatal("expected error for tab with no bills")
	}
	if err.Error() != "tab has no bills" {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestUpdateBillItemAssignments_ForwardsToRepository(t *testing.T) {
	repo := newMockRepo()
	svc := NewTabService(repo)

	assignments := []models.ItemAssignment{
		{PersonName: "Alice", Percentage: 100},
	}

	err := svc.UpdateBillItemAssignments(3, 9, 12, assignments, nil)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(repo.updatedAssignments) != 1 {
		t.Fatalf("expected 1 assignment, got %d", len(repo.updatedAssignments))
	}
	if repo.updatedAssignments[0].PersonName != "Alice" {
		t.Fatalf("expected assignment name Alice, got %q", repo.updatedAssignments[0].PersonName)
	}
}

func TestBuildPersonShares_FromAssignments(t *testing.T) {
	bill := &models.Bill{
		ID:        7,
		Subtotal:  80,
		Tax:       8,
		TipAmount: 12,
		Items: []models.BillItem{
			{
				ID:    1,
				Name:  "Pizza",
				Price: 40,
				Assignments: []models.ItemAssignment{
					{PersonName: "Alice", Percentage: 100},
				},
			},
			{
				ID:    2,
				Name:  "Wings",
				Price: 40,
				Assignments: []models.ItemAssignment{
					{PersonName: "Bob", Percentage: 50},
					{PersonName: "Alice", Percentage: 50},
				},
			},
		},
	}

	shares := buildPersonShares(bill)
	if len(shares) != 2 {
		t.Fatalf("expected 2 shares, got %d", len(shares))
	}

	if shares[0].PersonName != "Alice" || shares[0].Subtotal != 60 {
		t.Fatalf("expected Alice subtotal 60, got %+v", shares[0])
	}
	if shares[1].PersonName != "Bob" || shares[1].Subtotal != 20 {
		t.Fatalf("expected Bob subtotal 20, got %+v", shares[1])
	}
}

func TestJoinTab_Success(t *testing.T) {
	repo := newMockRepo()
	svc := NewTabService(repo)

	member, err := svc.JoinTab(1, "Charlie")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if member.DisplayName != "Charlie" {
		t.Errorf("expected display name Charlie, got %s", member.DisplayName)
	}
	if member.Role != "member" {
		t.Errorf("expected role member, got %s", member.Role)
	}
	if member.MemberToken == "" {
		t.Error("expected non-empty member token")
	}
	if member.TabID != 1 {
		t.Errorf("expected tab ID 1, got %d", member.TabID)
	}
	if member.JoinedAt.IsZero() {
		t.Error("expected non-zero JoinedAt")
	}
}

func TestJoinTabAsCreator_Success(t *testing.T) {
	repo := newMockRepo()
	svc := NewTabService(repo)

	member, err := svc.JoinTabAsCreator(1, "Alice")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if member.Role != "creator" {
		t.Errorf("expected role creator, got %s", member.Role)
	}
	if member.DisplayName != "Alice" {
		t.Errorf("expected display name Alice, got %s", member.DisplayName)
	}
	if member.MemberToken == "" {
		t.Error("expected non-empty member token")
	}
}

func TestAddBillToTab_WithMember(t *testing.T) {
	repo := newMockRepo()

	repo.tabs[1] = &models.Tab{ID: 1}

	svc := NewTabService(repo)
	memberID := uint(42)
	err := svc.AddBillToTab(1, 99, "bill-token", &memberID)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if repo.addBillTabID != 1 {
		t.Errorf("expected tabID 1, got %d", repo.addBillTabID)
	}
	if repo.addBillBillID != 99 {
		t.Errorf("expected billID 99, got %d", repo.addBillBillID)
	}
	if repo.addBillBillToken != "bill-token" {
		t.Errorf("expected bill token to be passed through, got %q", repo.addBillBillToken)
	}
	if repo.addBillMemberID == nil || *repo.addBillMemberID != 42 {
		t.Error("expected memberID 42 to be passed through")
	}
}

func TestAddBillToTab_SetsPaidByMemberID(t *testing.T) {
	repo := newMockRepo()

	repo.tabs[1] = &models.Tab{ID: 1}

	svc := NewTabService(repo)
	memberID := uint(42)
	err := svc.AddBillToTab(1, 99, "bill-token", &memberID)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if repo.addBillPaidByMemberID == nil || *repo.addBillPaidByMemberID != 42 {
		t.Error("expected PaidByMemberID 42 to be set when adding bill with member")
	}
}

func TestAddBillToTab_AllowsMissingBillTokenForLegacyClients(t *testing.T) {
	repo := newMockRepo()
	svc := NewTabService(repo)

	err := svc.AddBillToTab(1, 99, "", nil)
	if err != nil {
		t.Fatalf("expected no error for legacy request, got %v", err)
	}
	if repo.addBillBillID != 99 {
		t.Fatalf("expected repository to receive bill id 99, got %d", repo.addBillBillID)
	}
	if repo.addBillBillToken != "" {
		t.Fatalf("expected empty bill token, got %q", repo.addBillBillToken)
	}
}

func TestGetMembers_Success(t *testing.T) {
	repo := newMockRepo()

	repo.members = []models.TabMember{
		{ID: 1, TabID: 5, DisplayName: "Alice", Role: "creator", JoinedAt: time.Now()},
		{ID: 2, TabID: 5, DisplayName: "Bob", Role: "member", JoinedAt: time.Now()},
		{ID: 3, TabID: 9, DisplayName: "Eve", Role: "member", JoinedAt: time.Now()},
	}

	svc := NewTabService(repo)
	members, err := svc.GetMembers(5)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if len(members) != 2 {
		t.Fatalf("expected 2 members for tab 5, got %d", len(members))
	}
	if members[0].DisplayName != "Alice" {
		t.Errorf("expected first member Alice, got %s", members[0].DisplayName)
	}
	if members[1].DisplayName != "Bob" {
		t.Errorf("expected second member Bob, got %s", members[1].DisplayName)
	}
}

// ── ComputeNetBalances Tests ────────────────────────────────────

func TestComputeNetBalances_SingleBill(t *testing.T) {
	// Alice pays a $100 bill. Bob owes $40, Alice owes $30, Charlie owes $30.
	tab := &models.Tab{
		ID: 1,
		Members: []models.TabMember{
			{ID: 1, TabID: 1, DisplayName: "Alice"},
			{ID: 2, TabID: 1, DisplayName: "Bob"},
		},
		Bills: []models.Bill{
			{
				ID: 1, Total: 100,
				PaidByMemberID: ptrUint(1),
				PersonShares: []models.PersonShare{
					{PersonName: "Alice", Total: 30},
					{PersonName: "Bob", Total: 40},
					{PersonName: "Charlie", Total: 30},
				},
			},
		},
	}

	balances := ComputeNetBalances(tab)

	// Alice paid 100, owes 30 → net +70 (owed 70)
	// Bob paid 0, owes 40 → net -40 (owes 40)
	// Charlie paid 0, owes 30 → net -30 (owes 30)
	// Simplified: Bob→Alice $40, Charlie→Alice $30
	if len(balances) != 2 {
		t.Fatalf("expected 2 balances, got %d: %+v", len(balances), balances)
	}

	balanceMap := make(map[string]float64)
	for _, b := range balances {
		balanceMap[b.From+"→"+b.To] = b.Amount
	}

	if balanceMap["Bob→Alice"] != 40 {
		t.Errorf("expected Bob→Alice 40, got %f", balanceMap["Bob→Alice"])
	}
	if balanceMap["Charlie→Alice"] != 30 {
		t.Errorf("expected Charlie→Alice 30, got %f", balanceMap["Charlie→Alice"])
	}
}

func TestComputeNetBalances_MultipleBills(t *testing.T) {
	// Alice pays $100 dinner (Bob $40, Alice $30, Charlie $30)
	// Bob pays $60 drinks (Alice $20, Bob $20, Charlie $20)
	tab := &models.Tab{
		ID: 1,
		Members: []models.TabMember{
			{ID: 1, TabID: 1, DisplayName: "Alice"},
			{ID: 2, TabID: 1, DisplayName: "Bob"},
		},
		Bills: []models.Bill{
			{
				ID: 1, Total: 100,
				PaidByMemberID: ptrUint(1),
				PersonShares: []models.PersonShare{
					{PersonName: "Alice", Total: 30},
					{PersonName: "Bob", Total: 40},
					{PersonName: "Charlie", Total: 30},
				},
			},
			{
				ID: 2, Total: 60,
				PaidByMemberID: ptrUint(2),
				PersonShares: []models.PersonShare{
					{PersonName: "Alice", Total: 20},
					{PersonName: "Bob", Total: 20},
					{PersonName: "Charlie", Total: 20},
				},
			},
		},
	}

	balances := ComputeNetBalances(tab)

	// Alice: paid 100, owes 50 → net +50
	// Bob: paid 60, owes 60 → net 0
	// Charlie: paid 0, owes 50 → net -50
	// Simplified: Charlie→Alice $50
	if len(balances) != 1 {
		t.Fatalf("expected 1 balance, got %d: %+v", len(balances), balances)
	}
	if balances[0].From != "Charlie" || balances[0].To != "Alice" {
		t.Errorf("expected Charlie→Alice, got %s→%s", balances[0].From, balances[0].To)
	}
	if balances[0].Amount != 50 {
		t.Errorf("expected amount 50, got %f", balances[0].Amount)
	}
}

func TestComputeNetBalances_AllEven(t *testing.T) {
	tab := &models.Tab{
		ID: 1,
		Members: []models.TabMember{
			{ID: 1, TabID: 1, DisplayName: "Alice"},
		},
		Bills: []models.Bill{
			{
				ID: 1, Total: 50,
				PaidByMemberID: ptrUint(1),
				PersonShares: []models.PersonShare{
					{PersonName: "Alice", Total: 50},
				},
			},
		},
	}

	balances := ComputeNetBalances(tab)
	if len(balances) != 0 {
		t.Errorf("expected 0 balances when even, got %d: %+v", len(balances), balances)
	}
}

func TestComputeNetBalances_NoPaidByMember(t *testing.T) {
	tab := &models.Tab{
		ID: 1,
		Bills: []models.Bill{
			{
				ID: 1, Total: 100,
				PaidByMemberID: nil,
				PersonShares: []models.PersonShare{
					{PersonName: "Alice", Total: 60},
					{PersonName: "Bob", Total: 40},
				},
			},
		},
	}

	balances := ComputeNetBalances(tab)
	if len(balances) != 0 {
		t.Errorf("expected 0 balances for unattributed bills, got %d", len(balances))
	}
}

func TestComputeNetBalances_CaseInsensitive(t *testing.T) {
	tab := &models.Tab{
		ID: 1,
		Members: []models.TabMember{
			{ID: 1, TabID: 1, DisplayName: "Alice"},
			{ID: 2, TabID: 1, DisplayName: "Bob"},
		},
		Bills: []models.Bill{
			{
				ID: 1, Total: 100,
				PaidByMemberID: ptrUint(1),
				PersonShares: []models.PersonShare{
					{PersonName: "alice", Total: 30},
					{PersonName: "bob", Total: 70},
				},
			},
		},
	}

	balances := ComputeNetBalances(tab)
	if len(balances) != 1 {
		t.Fatalf("expected 1 balance, got %d: %+v", len(balances), balances)
	}
	if balances[0].From != "Bob" {
		t.Errorf("expected From='Bob' (capitalized), got '%s'", balances[0].From)
	}
	if balances[0].To != "Alice" {
		t.Errorf("expected To='Alice', got '%s'", balances[0].To)
	}
	if balances[0].Amount != 70 {
		t.Errorf("expected amount 70, got %f", balances[0].Amount)
	}
}

func TestComputeNetBalances_ReconcilesFractionalCents(t *testing.T) {
	payerID := uint(1)
	tab := &models.Tab{
		Members: []models.TabMember{
			{ID: payerID, DisplayName: "Alice"},
			{ID: 2, DisplayName: "Bob"},
			{ID: 3, DisplayName: "Cara"},
			{ID: 4, DisplayName: "Dana"},
		},
		Bills: []models.Bill{{
			PaidByMemberID:  &payerID,
			CurrencyCode:    "EUR",
			USDExchangeRate: 1.25,
			Total:           0.80,
			USDTotal:        1.00,
			PersonShares: []models.PersonShare{
				{PersonName: "Bob", Total: 0.80 / 3},
				{PersonName: "Cara", Total: 0.80 / 3},
				{PersonName: "Dana", Total: 0.80 / 3},
			},
		}},
	}

	balances := ComputeNetBalances(tab)
	var sum float64
	amounts := map[string]float64{}
	for _, balance := range balances {
		if balance.To != "Alice" {
			t.Fatalf("expected Alice to receive each payment, got %#v", balance)
		}
		sum += balance.Amount
		amounts[balance.From] = balance.Amount
	}
	if sum != 1.00 {
		t.Fatalf("expected net balances to reconcile to 1.00, got %.2f", sum)
	}
	if amounts["Bob"] != 0.34 || amounts["Cara"] != 0.33 || amounts["Dana"] != 0.33 {
		t.Fatalf("expected deterministic cent allocation, got %#v", amounts)
	}
}

func TestComputeNetBalances_DoesNotScalePartialAssignmentsToFullBill(t *testing.T) {
	payerID := uint(1)
	tab := &models.Tab{
		Members: []models.TabMember{
			{ID: payerID, DisplayName: "Alice"},
			{ID: 2, DisplayName: "Bob"},
		},
		Bills: []models.Bill{{
			PaidByMemberID:  &payerID,
			CurrencyCode:    "EUR",
			USDExchangeRate: 1.25,
			Total:           80,
			USDTotal:        100,
			PersonShares:    []models.PersonShare{{PersonName: "Bob", Total: 8}},
		}},
	}

	balances := ComputeNetBalances(tab)
	if len(balances) != 1 || balances[0].From != "Bob" || balances[0].To != "Alice" || balances[0].Amount != 10 {
		t.Fatalf("expected only the assigned USD 10 to be owed, got %#v", balances)
	}
}

func ptrUint(v uint) *uint {
	return &v
}
