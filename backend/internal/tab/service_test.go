package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"backend/pkg/mutation"
	"backend/pkg/security"
	"context"
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
	addBillErr           error
	finalizeErr          error
	getSettlementsErr    error
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
	updatedAssignments    []models.ItemAssignment
}

func newMockRepo() *mockTabRepository {
	return &mockTabRepository{
		tabs: make(map[uint]*models.Tab),
	}
}

func (m *mockTabRepository) Create(_ context.Context, tab *models.Tab, creator *models.TabMember) error {
	if creator != nil {
		creator.ID = 1
		creator.TabID = 1
		m.members = append(m.members, *creator)
	}
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

func (m *mockTabRepository) Update(context.Context, SettingsCommand) error { return m.updateErr }
func (m *mockTabRepository) AttachBill(_ context.Context, command AttachBillCommand) error {
	m.addBillTabID = command.TabID
	m.addBillBillID = command.BillID
	m.addBillBillToken = command.BillToken
	return m.addBillErr
}

func (m *mockTabRepository) UpdateBillItemAssignmentsBatch(_ context.Context, c AssignmentCommand) error {
	if len(c.Updates) > 0 {
		m.updatedAssignments = c.Updates[0].Assignments
	}
	return m.updateAssignmentsErr
}
func (m *mockTabRepository) UpdateBillPersonSharePaid(context.Context, SharePaidCommand) error {
	return nil
}
func (m *mockTabRepository) FinalizeOnce(_ context.Context, c FinalizeCommand) ([]models.TabSettlement, error) {
	m.finalizedID = c.Access.TabID
	return m.settlements, m.finalizeErr
}
func (m *mockTabRepository) GetSettlements(tabID uint) ([]models.TabSettlement, error) {
	if m.getSettlementsErr != nil {
		return nil, m.getSettlementsErr
	}
	return m.settlements, nil
}

func (m *mockTabRepository) UpdateSettlementPaid(context.Context, SettlementPaidCommand) error {
	return m.updatePaidErr
}

func (m *mockTabRepository) Join(_ context.Context, c JoinCommand) (*models.TabMember, bool, error) {
	token, _ := security.GenerateSecureToken()
	member := &models.TabMember{ID: 1, TabID: c.Access.TabID, DisplayName: c.DisplayName, MemberToken: token, Role: "member", JoinedAt: time.Now()}
	return member, false, m.createMemberErr
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

func (m *mockTabRepository) Leave(context.Context, LeaveCommand) error {
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

	repo.tabs[1].Members = []models.TabMember{{ID: 1, TabID: 1, DisplayName: "Alice"}, {ID: 2, TabID: 1, DisplayName: "Bob"}, {ID: 3, TabID: 1, DisplayName: "Cara"}}
	referenceMoneyFixture(t, repo.tabs[1], map[string]uint{"Alice": 1, "alice": 1, "Bob": 2, "Cara": 3})
	settlements, err := grossSettlements(1, repo.tabs[1].Bills, repo.tabs[1].Members)
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

	// Both explicit Alice/alice participations are confirmed to member1.
	if totals["Alice"] != 90 {
		t.Errorf("expected Alice total 90, got %f", totals["Alice"])
	}
	// Bob (40) + Bob (20) = 60
	if totals["Bob"] != 60 {
		t.Errorf("expected Bob total 60, got %f", totals["Bob"])
	}

}

func TestFinalizeTab_UsesFrozenUSDAmountsForMixedCurrencies(t *testing.T) {
	repo := newMockRepo()
	repo.tabs[1] = &models.Tab{
		ID: 1,
		Bills: []models.Bill{
			{CurrencyCode: "USD", USDExchangeRate: 1, Total: 25, USDTotal: 25, PersonShares: []models.PersonShare{{PersonName: "Alice", Total: 25}}},
			{ExchangeRateSource: "frozen-fixture", ExchangeRateDate: "2026-11-03", CurrencyCode: "EUR", USDExchangeRate: 1.25, Total: 40, USDTotal: 50, PersonShares: []models.PersonShare{{PersonName: "Alice", Total: 24}, {PersonName: "Bob", Total: 16}}},
		},
	}
	repo.tabs[1].Members = []models.TabMember{{ID: 1, TabID: 1, DisplayName: "Alice"}, {ID: 2, TabID: 1, DisplayName: "Bob"}, {ID: 3, TabID: 1, DisplayName: "Cara"}}
	referenceMoneyFixture(t, repo.tabs[1], map[string]uint{"Alice": 1, "alice": 1, "Bob": 2, "Cara": 3})
	settlements, err := grossSettlements(1, repo.tabs[1].Bills, repo.tabs[1].Members)
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
			ExchangeRateSource: "frozen-fixture", ExchangeRateDate: "2026-11-03", CurrencyCode: "EUR",
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
	repo.tabs[1].Members = []models.TabMember{{ID: 1, TabID: 1, DisplayName: "Alice"}, {ID: 2, TabID: 1, DisplayName: "Bob"}, {ID: 3, TabID: 1, DisplayName: "Cara"}}
	referenceMoneyFixture(t, repo.tabs[1], map[string]uint{"Alice": 1, "alice": 1, "Bob": 2, "Cara": 3})
	settlements, err := grossSettlements(1, repo.tabs[1].Bills, repo.tabs[1].Members)
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
		ExchangeRateSource: "frozen-fixture", ExchangeRateDate: "2026-11-03", CurrencyCode: "EUR",
		USDExchangeRate: 1.25,
		Total:           0.80,
		USDTotal:        1.00,
		PersonShares: []models.PersonShare{
			{PersonName: "ä", Total: 0.80 / 3},
			{PersonName: "z", Total: 0.80 / 3},
			{PersonName: "Ω", Total: 0.80 / 3},
		},
	}

	amounts, err := billpkg.FrozenUSDShareCents(bill)
	if err != nil {
		t.Fatal(err)
	}
	if amounts[0] != 33 || amounts[1] != 34 || amounts[2] != 33 {
		t.Fatalf("expected ordinal tie-break to award z the extra cent, got %#v", amounts)
	}
}

func TestAllocateUSDShareCents_UsesUTF8OrderForSupplementaryNames(t *testing.T) {
	bill := models.Bill{
		ExchangeRateSource: "frozen-fixture", ExchangeRateDate: "2026-11-03", CurrencyCode: "EUR",
		USDExchangeRate: 1.25,
		Total:           0.008,
		USDTotal:        0.01,
		PersonShares: []models.PersonShare{
			{PersonName: "😀", Total: 0.004},
			{PersonName: "Ａ", Total: 0.004},
		},
	}

	amounts, err := billpkg.FrozenUSDShareCents(bill)
	if err != nil {
		t.Fatal(err)
	}
	if amounts[0] != 0 || amounts[1] != 1 {
		t.Fatalf("expected UTF-8 order to award fullwidth A the cent, got %#v", amounts)
	}
}

func TestFinalizeTab_DoesNotScalePartialAssignmentsToFullBill(t *testing.T) {
	repo := newMockRepo()
	repo.tabs[1] = &models.Tab{
		ID: 1,
		Bills: []models.Bill{{
			ExchangeRateSource: "frozen-fixture", ExchangeRateDate: "2026-11-03", CurrencyCode: "EUR",
			USDExchangeRate: 1.25,
			Total:           80,
			USDTotal:        100,
			PersonShares:    []models.PersonShare{{PersonName: "Alice", Total: 8}},
		}},
	}
	repo.tabs[1].Members = []models.TabMember{{ID: 1, TabID: 1, DisplayName: "Alice"}, {ID: 2, TabID: 1, DisplayName: "Bob"}, {ID: 3, TabID: 1, DisplayName: "Cara"}}
	referenceMoneyFixture(t, repo.tabs[1], map[string]uint{"Alice": 1, "alice": 1, "Bob": 2, "Cara": 3})
	settlements, err := grossSettlements(1, repo.tabs[1].Bills, repo.tabs[1].Members)
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
		{ExchangeRateSource: "frozen-fixture", ExchangeRateDate: "2026-11-03", CurrencyCode: "EUR", USDExchangeRate: 1.25, Total: 20, USDTotal: 25},
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
	if err := validStoredSnapshot(models.Tab{ID: 1, Finalized: true}, nil); !errors.Is(err, mutation.Review) {
		t.Fatalf("missing legacy snapshot must require review: %v", err)
	}
}
func TestFinalizeTabForwardsAtomicCommandAndError(t *testing.T) {
	repo := newMockRepo()
	repo.finalizeErr = mutation.Review
	_, err := NewTabService(repo).FinalizeTab(context.Background(), FinalizeCommand{Access: TabAccess{TabID: 7, TabToken: "tab"}})
	if !errors.Is(err, mutation.Review) || repo.finalizedID != 7 {
		t.Fatalf("atomic command/error lost: %v", err)
	}
}

func TestFinalizeTab_NoBills(t *testing.T) {
	repo := newMockRepo()

	repo.tabs[1] = &models.Tab{
		ID:        1,
		Finalized: false,
		Bills:     []models.Bill{},
	}

	_, err := grossSettlements(1, repo.tabs[1].Bills)
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

	err := svc.UpdateBillItemAssignmentsBatch(context.Background(), AssignmentCommand{Access: TabAccess{TabID: 3}, BillID: 9, Updates: []BillItemAssignmentsUpdate{{ItemID: 12, Assignments: assignments}}})
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

	shares, err := billpkg.BuildPersonShares(bill)
	if err != nil {
		t.Fatal(err)
	}
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

	member, _, err := svc.JoinTab(context.Background(), JoinCommand{Access: TabAccess{TabID: 1}, DisplayName: "Charlie"})
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

func TestFreshTabInitialCreator_Success(t *testing.T) {
	repo := newMockRepo()
	svc := NewTabService(repo)

	member, err := svc.CreateTab(context.Background(), &models.Tab{Name: "Fresh"}, "Alice")
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

func TestAddBillToTab_RequiresIndependentProof(t *testing.T) {
	for _, token := range []string{"", " ", "\t\n"} {
		repo := newMockRepo()
		err := NewTabService(repo).AddBillToTab(context.Background(), AttachBillCommand{TabID: 1, BillID: 99, TabToken: "tab", BillToken: token})
		if !errors.Is(err, ErrInvalidAttachment) || repo.addBillBillID != 0 {
			t.Fatalf("missing proof reached repository: %v", err)
		}
	}
	repo := newMockRepo()
	command := AttachBillCommand{TabID: 1, BillID: 99, TabToken: "tab", MemberToken: "member", BillToken: " source "}
	if err := NewTabService(repo).AddBillToTab(context.Background(), command); err != nil {
		t.Fatal(err)
	}
	if repo.addBillBillID != 99 || repo.addBillBillToken != " source " {
		t.Fatal("credentials changed")
	}
	repo.addBillErr = ErrSourceUnavailable
	if err := NewTabService(repo).AddBillToTab(context.Background(), command); !errors.Is(err, ErrSourceUnavailable) {
		t.Fatal(err)
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

	referenceMoneyFixture(t, tab, map[string]uint{"Alice": 1, "alice": 1, "Bob": 2, "bob": 2, "Cara": 3, "Dana": 4})
	balances, err := ReferenceNetBalances(tab)
	if err != nil {
		t.Fatal(err)
	}

	// Alice paid 100, owes 30 → net +70 (owed 70)
	// Bob paid 0, owes 40 → net -40 (owes 40)
	// Charlie paid 0, owes 30 → net -30 (owes 30)
	// Simplified: Bob→Alice $40, Charlie→Alice $30
	if len(balances) != 2 {
		t.Fatalf("expected 2 balances, got %d: %+v", len(balances), balances)
	}

	balanceMap := make(map[string]float64)
	for _, b := range balances {
		balanceMap[b.From.Label+"→"+b.To.Label] = b.Amount
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

	tab.Members = append(tab.Members, models.TabMember{ID: 3, TabID: 1, DisplayName: "Charlie"})
	referenceMoneyFixture(t, tab, map[string]uint{"Alice": 1, "alice": 1, "Bob": 2, "bob": 2, "Charlie": 3, "Cara": 3, "Dana": 4})
	balances, err := ReferenceNetBalances(tab)
	if err != nil {
		t.Fatal(err)
	}

	// Alice: paid 100, owes 50 → net +50
	// Bob: paid 60, owes 60 → net 0
	// Charlie: paid 0, owes 50 → net -50
	// Simplified: Charlie→Alice $50
	if len(balances) != 1 {
		t.Fatalf("expected 1 balance, got %d: %+v", len(balances), balances)
	}
	if balances[0].From.Label != "Charlie" || balances[0].To.Label != "Alice" {
		t.Errorf("expected Charlie→Alice, got %s→%s", balances[0].From.Label, balances[0].To.Label)
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

	referenceMoneyFixture(t, tab, map[string]uint{"Alice": 1, "alice": 1, "Bob": 2, "bob": 2, "Charlie": 3, "Cara": 3, "Dana": 4})
	balances, err := ReferenceNetBalances(tab)
	if err != nil {
		t.Fatal(err)
	}
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

	referenceMoneyFixture(t, tab, nil)
	balances, err := ReferenceNetBalances(tab)
	if !errors.Is(err, billpkg.ErrIdentityReview) || balances != nil {
		t.Fatal("missing payer must be unavailable, not zero transfers")
	}
	repo := newMockRepo()
	repo.tabs[tab.ID] = tab
	raw, readErr := NewTabService(repo).GetTab(tab.ID)
	if readErr != nil || raw.TotalStatus != "available" || raw.TotalAmount != 100 || raw.NetBalanceStatus != "identity_review_required" || raw.ReferenceBalances != nil || len(raw.Bills) != 1 {
		t.Fatal("unavailable net hid safe raw receipt/total")
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

	referenceMoneyFixture(t, tab, map[string]uint{"Alice": 1, "alice": 1, "Bob": 2, "bob": 2, "Charlie": 3, "Cara": 3, "Dana": 4})
	balances, err := ReferenceNetBalances(tab)
	if err != nil {
		t.Fatal(err)
	}
	if len(balances) != 1 {
		t.Fatalf("expected 1 balance, got %d: %+v", len(balances), balances)
	}
	if balances[0].From.Label != "Bob" {
		t.Errorf("expected From='Bob' (capitalized), got '%s'", balances[0].From.Label)
	}
	if balances[0].To.Label != "Alice" {
		t.Errorf("expected To='Alice', got '%s'", balances[0].To.Label)
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
			PaidByMemberID:     &payerID,
			ExchangeRateSource: "frozen-fixture", ExchangeRateDate: "2026-11-03", CurrencyCode: "EUR",
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

	referenceMoneyFixture(t, tab, map[string]uint{"Alice": 1, "alice": 1, "Bob": 2, "bob": 2, "Charlie": 3, "Cara": 3, "Dana": 4})
	balances, err := ReferenceNetBalances(tab)
	if err != nil {
		t.Fatal(err)
	}
	var sum float64
	amounts := map[string]float64{}
	for _, balance := range balances {
		if balance.To.Label != "Alice" {
			t.Fatalf("expected Alice to receive each payment, got %#v", balance)
		}
		sum += balance.Amount
		amounts[balance.From.Label] = balance.Amount
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
			PaidByMemberID:     &payerID,
			ExchangeRateSource: "frozen-fixture", ExchangeRateDate: "2026-11-03", CurrencyCode: "EUR",
			USDExchangeRate: 1.25,
			Total:           80,
			USDTotal:        100,
			PersonShares:    []models.PersonShare{{PersonName: "Bob", Total: 8}},
		}},
	}

	referenceMoneyFixture(t, tab, map[string]uint{"Alice": 1, "alice": 1, "Bob": 2, "bob": 2, "Charlie": 3, "Cara": 3, "Dana": 4})
	balances, err := ReferenceNetBalances(tab)
	if err != nil {
		t.Fatal(err)
	}
	if len(balances) != 1 || balances[0].From.Label != "Bob" || balances[0].To.Label != "Alice" || balances[0].Amount != 10 {
		t.Fatalf("expected only the assigned USD 10 to be owed, got %#v", balances)
	}
}

func ptrUint(v uint) *uint {
	return &v
}

// referenceMoneyFixture declares the intended IDs in the original numerical
// examples. The explicit binding map, never label matching at runtime, joins
// cross-bill parties. Omitted names remain separate bill-local guests.
func referenceMoneyFixture(t *testing.T, tab *models.Tab, bindings map[string]uint) {
	t.Helper()
	if tab.ID == 0 {
		tab.ID = 1
	}
	for i := range tab.Members {
		tab.Members[i].TabID = tab.ID
	}
	nextID := uint(1)
	for i := range tab.Bills {
		b := &tab.Bills[i]
		if b.ID == 0 {
			b.ID = uint(i + 1)
		}
		b.TabID = ptrUint(tab.ID)
		b.IdentityVersion, b.IdentityState = 2, "ready"
		b.ParticipantRows = nil
		for j := range b.PersonShares {
			s := &b.PersonShares[j]
			pid := nextID
			nextID++
			ordinal := int64(j)
			p := models.BillParticipant{ID: pid, BillID: b.ID, PersonID: pid, TabID: ptrUint(tab.ID), Label: s.PersonName, AllocationLabel: s.PersonName, IdentityVersion: 2, Ordinal: &ordinal}
			if id, ok := bindings[s.PersonName]; ok {
				found := false
				for _, m := range tab.Members {
					if m.ID == id {
						found = true
					}
				}
				if !found {
					t.Fatal("explicit financial fixture binding has no member")
				}
				p.MemberID = ptrUint(id)
				p.ApprovedByMemberID = ptrUint(id)
				kind := "source"
				p.ApprovalKind = &kind
				now := time.Date(2026, 11, 5, 0, 0, 0, 0, time.UTC)
				p.ApprovedAt = &now
			}
			b.ParticipantRows = append(b.ParticipantRows, p)
			s.ID = pid
			s.BillID = b.ID
			s.IdentityVersion = 2
			s.ParticipantID = &pid
		}
	}
}

func TestIdentity0003UnboundGuestsAndMissingPayers(t *testing.T) {
	t.Run("same_label_guests_remain_distinct", func(t *testing.T) {
		trip := &models.Tab{ID: 1, Members: []models.TabMember{{ID: 1, TabID: 1, DisplayName: "Alice"}, {ID: 2, TabID: 1, DisplayName: "Bob"}}, Bills: []models.Bill{{ID: 1, Total: 100, PaidByMemberID: ptrUint(1), PersonShares: []models.PersonShare{{PersonName: "Alice", Total: 30}, {PersonName: "Bob", Total: 40}, {PersonName: "Charlie", Total: 30}}}, {ID: 2, Total: 60, PaidByMemberID: ptrUint(2), PersonShares: []models.PersonShare{{PersonName: "Alice", Total: 20}, {PersonName: "Bob", Total: 20}, {PersonName: "Charlie", Total: 20}}}}}
		referenceMoneyFixture(t, trip, map[string]uint{"Alice": 1, "Bob": 2})
		rows, err := ReferenceNetBalances(trip)
		if err != nil || len(rows) != 2 {
			t.Fatalf("unbound guests were merged: %+v %v", rows, err)
		}
		seen := map[uint]float64{}
		for _, row := range rows {
			if row.From.Kind != "guest" || row.From.ParticipantID == 0 || row.To.Kind != "member" || row.To.MemberID != 1 {
				t.Fatal("transfer lost tagged scoped identity")
			}
			seen[row.From.BillID] = row.Amount
		}
		if seen[1] != 30 || seen[2] != 20 {
			t.Fatal("unbound same-label obligations changed")
		}
	})
	for _, kind := range []string{"missing", "dangling", "cross_tab"} {
		t.Run(kind, func(t *testing.T) {
			trip := &models.Tab{ID: 1, Members: []models.TabMember{{ID: 1, TabID: 1, DisplayName: "Payer"}}, Bills: []models.Bill{{ID: 1, Total: 10, PaidByMemberID: ptrUint(1), PersonShares: []models.PersonShare{{PersonName: "Guest", Total: 10}}}}}
			referenceMoneyFixture(t, trip, nil)
			switch kind {
			case "missing":
				trip.Bills[0].PaidByMemberID = nil
			case "dangling":
				trip.Bills[0].PaidByMemberID = ptrUint(999)
			case "cross_tab":
				trip.Members[0].TabID = 2
			}
			rows, err := ReferenceNetBalances(trip)
			if rows != nil || !errors.Is(err, billpkg.ErrIdentityReview) {
				t.Fatal("invalid payer became zero/partial net")
			}
			repo := newMockRepo()
			repo.tabs[1] = trip
			raw, err := NewTabService(repo).GetTab(1)
			if err != nil || raw.NetBalanceStatus != "identity_review_required" || raw.TotalAmount != 10 || len(raw.Bills) != 1 {
				t.Fatal("safe authorized raw receipt was lost")
			}
		})
	}
}
