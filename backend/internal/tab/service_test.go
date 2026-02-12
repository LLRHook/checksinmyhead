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

	// Capture calls
	addBillTabID    uint
	addBillBillID   uint
	addBillMemberID *uint
	finalizedID     uint
	createdSettlements []models.TabSettlement
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

func (m *mockTabRepository) Update(tab *models.Tab) error  { return m.updateErr }
func (m *mockTabRepository) Delete(id uint) error          { return m.deleteErr }

func (m *mockTabRepository) AddBill(tabID uint, billID uint, memberID *uint) error {
	m.addBillTabID = tabID
	m.addBillBillID = billID
	m.addBillMemberID = memberID
	return m.addBillErr
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

// ── Mock ImageQuerier ───────────────────────────────────────────

type mockImageQuerier struct {
	images []models.TabImage
	err    error
}

func (m *mockImageQuerier) GetByTabID(tabID uint) ([]models.TabImage, error) {
	return m.images, m.err
}

// ── Tests ───────────────────────────────────────────────────────

func TestFinalizeTab_Success(t *testing.T) {
	repo := newMockRepo()
	imgQ := &mockImageQuerier{images: []models.TabImage{}}

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

	svc := NewTabService(repo, imgQ)
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

func TestFinalizeTab_AlreadyFinalized(t *testing.T) {
	repo := newMockRepo()
	imgQ := &mockImageQuerier{}

	repo.tabs[1] = &models.Tab{
		ID:        1,
		Finalized: true,
		Bills:     []models.Bill{{ID: 1}},
	}

	svc := NewTabService(repo, imgQ)
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
	imgQ := &mockImageQuerier{}

	repo.tabs[1] = &models.Tab{
		ID:        1,
		Finalized: false,
		Bills:     []models.Bill{},
	}

	svc := NewTabService(repo, imgQ)
	_, err := svc.FinalizeTab(1)
	if err == nil {
		t.Fatal("expected error for tab with no bills")
	}
	if err.Error() != "tab has no bills" {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestFinalizeTab_UnprocessedImages(t *testing.T) {
	repo := newMockRepo()
	imgQ := &mockImageQuerier{
		images: []models.TabImage{
			{ID: 1, TabID: 1, Processed: true},
			{ID: 2, TabID: 1, Processed: false},
		},
	}

	repo.tabs[1] = &models.Tab{
		ID:        1,
		Finalized: false,
		Bills:     []models.Bill{{ID: 1, Total: 50, PersonShares: []models.PersonShare{{PersonName: "Alice", Total: 50}}}},
	}

	svc := NewTabService(repo, imgQ)
	_, err := svc.FinalizeTab(1)
	if err == nil {
		t.Fatal("expected error for unprocessed images")
	}
	if err.Error() != "all images must be marked as processed before finalizing" {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestJoinTab_Success(t *testing.T) {
	repo := newMockRepo()
	imgQ := &mockImageQuerier{}
	svc := NewTabService(repo, imgQ)

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
	imgQ := &mockImageQuerier{}
	svc := NewTabService(repo, imgQ)

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
	imgQ := &mockImageQuerier{}

	repo.tabs[1] = &models.Tab{ID: 1}

	svc := NewTabService(repo, imgQ)
	memberID := uint(42)
	err := svc.AddBillToTab(1, 99, &memberID)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if repo.addBillTabID != 1 {
		t.Errorf("expected tabID 1, got %d", repo.addBillTabID)
	}
	if repo.addBillBillID != 99 {
		t.Errorf("expected billID 99, got %d", repo.addBillBillID)
	}
	if repo.addBillMemberID == nil || *repo.addBillMemberID != 42 {
		t.Error("expected memberID 42 to be passed through")
	}
}

func TestGetMembers_Success(t *testing.T) {
	repo := newMockRepo()
	imgQ := &mockImageQuerier{}

	repo.members = []models.TabMember{
		{ID: 1, TabID: 5, DisplayName: "Alice", Role: "creator", JoinedAt: time.Now()},
		{ID: 2, TabID: 5, DisplayName: "Bob", Role: "member", JoinedAt: time.Now()},
		{ID: 3, TabID: 9, DisplayName: "Eve", Role: "member", JoinedAt: time.Now()},
	}

	svc := NewTabService(repo, imgQ)
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
