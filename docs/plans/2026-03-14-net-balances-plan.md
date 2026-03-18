# Net Balances Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add net balance calculations to tabs so users can see "who owes whom" with minimized transactions.

**Architecture:** Add `PaidByMemberID` field to Bill model (defaults to `AddedByMemberID`). Backend computes net balances on tab GET and returns them in the response. Web frontend renders a new NetBalances component on the tab detail page.

**Tech Stack:** Go/Gin/GORM backend, Next.js/React/TypeScript frontend, existing hand-written mock test pattern.

---

### Task 1: Add PaidByMemberID to Bill Model

**Files:**
- Modify: `backend/pkg/models/bill.go:62-80`

**Step 1: Add field to Bill struct**

In `backend/pkg/models/bill.go`, add `PaidByMemberID` after `AddedByMemberID` (line 65):

```go
PaidByMemberID  *uint           `gorm:"index" json:"paid_by_member_id,omitempty"`
```

GORM AutoMigrate in `backend/pkg/database/postgres.go:36` will add the column automatically on next startup.

**Step 2: Verify it compiles**

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/backend && go build ./...`
Expected: success, no errors

**Step 3: Commit**

```bash
git add backend/pkg/models/bill.go
git commit -m "feat: add PaidByMemberID field to Bill model"
```

---

### Task 2: Default PaidByMemberID When Adding Bill to Tab

**Files:**
- Modify: `backend/internal/tab/repository.go:55-68`

**Step 1: Write the failing test**

In `backend/internal/tab/service_test.go`, add after `TestAddBillToTab_WithMember` (line 336):

```go
func TestAddBillToTab_SetsPaidByMemberID(t *testing.T) {
	repo := newMockRepo()
	imgQ := &mockImageQuerier{}

	repo.tabs[1] = &models.Tab{ID: 1}

	svc := NewTabService(repo, imgQ)
	memberID := uint(42)
	err := svc.AddBillToTab(1, 99, &memberID)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if repo.addBillPaidByMemberID == nil || *repo.addBillPaidByMemberID != 42 {
		t.Error("expected PaidByMemberID to default to memberID 42")
	}
}
```

Add `addBillPaidByMemberID *uint` capture field to `mockTabRepository` struct (after line 33).

Update `mockTabRepository.AddBill` to capture the paid_by_member_id. But wait — the current `AddBill` signature is `AddBill(tabID, billID, memberID)` and the repo sets `added_by_member_id`. We need the repo to also set `paid_by_member_id` to the same value.

**Step 2: Run test to verify it fails**

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/backend && go test -v -run TestAddBillToTab_SetsPaidByMemberID ./internal/tab/`
Expected: FAIL — `addBillPaidByMemberID` field doesn't exist yet

**Step 3: Update repository to set paid_by_member_id**

In `backend/internal/tab/repository.go`, modify `AddBill` (line 55-68):

```go
func (r *tabRepository) AddBill(tabID uint, billID uint, memberID *uint) error {
	updates := map[string]interface{}{"tab_id": tabID}
	if memberID != nil {
		updates["added_by_member_id"] = *memberID
		updates["paid_by_member_id"] = *memberID
	}
	result := r.db.Model(&models.Bill{}).Where("id = ?", billID).Updates(updates)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}
```

Update mock to capture paid_by_member_id:

In `mockTabRepository.AddBill` in service_test.go:

```go
func (m *mockTabRepository) AddBill(tabID uint, billID uint, memberID *uint) error {
	m.addBillTabID = tabID
	m.addBillBillID = billID
	m.addBillMemberID = memberID
	m.addBillPaidByMemberID = memberID // defaults to same as adder
	return m.addBillErr
}
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/backend && go test -v -run TestAddBillToTab ./internal/tab/`
Expected: PASS (both the new test and the existing `TestAddBillToTab_WithMember`)

**Step 5: Commit**

```bash
git add backend/internal/tab/repository.go backend/internal/tab/service_test.go
git commit -m "feat: default PaidByMemberID to adding member when adding bill to tab"
```

---

### Task 3: Implement ComputeNetBalances in Tab Service

**Files:**
- Modify: `backend/internal/tab/service.go`
- Modify: `backend/internal/tab/service_test.go`
- Create: `backend/pkg/models/net_balance.go`

**Step 1: Create NetBalance model**

Create `backend/pkg/models/net_balance.go`:

```go
package models

// NetBalance represents a directed debt: From owes To the given Amount.
type NetBalance struct {
	From   string  `json:"from"`
	To     string  `json:"to"`
	Amount float64 `json:"amount"`
}
```

**Step 2: Write the failing tests**

In `backend/internal/tab/service_test.go`, add:

```go
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
	// Everyone paid exactly what they owe
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
	// Bills with nil PaidByMemberID are skipped
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
	// "alice" in person_shares should match member "Alice"
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
	// Should use display name casing: "Bob" not "bob"
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

func ptrUint(v uint) *uint {
	return &v
}
```

**Step 3: Run tests to verify they fail**

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/backend && go test -v -run TestComputeNetBalances ./internal/tab/`
Expected: FAIL — `ComputeNetBalances` doesn't exist

**Step 4: Implement ComputeNetBalances**

In `backend/internal/tab/service.go`, add after the imports:

```go
import (
	"math"
	"sort"
	// ... existing imports
)

// ComputeNetBalances calculates simplified "who owes whom" for a tab.
func ComputeNetBalances(tab *models.Tab) []models.NetBalance {
	// Build member ID → display name lookup
	memberNames := make(map[uint]string)
	for _, m := range tab.Members {
		memberNames[m.ID] = m.DisplayName
	}

	// Track display name preferences (case-insensitive → best casing)
	displayNames := make(map[string]string)
	for _, m := range tab.Members {
		key := strings.ToLower(m.DisplayName)
		displayNames[key] = m.DisplayName
	}

	// Compute net position per person
	nets := make(map[string]float64) // lowercase name → net amount

	for _, bill := range tab.Bills {
		if bill.PaidByMemberID == nil {
			continue
		}

		payerName, ok := memberNames[*bill.PaidByMemberID]
		if !ok {
			continue
		}
		payerKey := strings.ToLower(payerName)
		displayNames[payerKey] = payerName

		// Payer contributed the full bill total
		nets[payerKey] += bill.Total

		// Each person owes their share
		for _, share := range bill.PersonShares {
			key := strings.ToLower(share.PersonName)
			nets[key] -= share.Total
			if _, exists := displayNames[key]; !exists {
				displayNames[key] = share.PersonName
			}
		}
	}

	// Separate into creditors and debtors
	type entry struct {
		name   string
		amount float64
	}

	var creditors, debtors []entry
	for key, net := range nets {
		rounded := math.Round(net*100) / 100
		if rounded > 0.01 {
			creditors = append(creditors, entry{displayNames[key], rounded})
		} else if rounded < -0.01 {
			debtors = append(debtors, entry{displayNames[key], -rounded})
		}
	}

	// Sort descending by amount for greedy matching
	sort.Slice(creditors, func(i, j int) bool { return creditors[i].amount > creditors[j].amount })
	sort.Slice(debtors, func(i, j int) bool { return debtors[i].amount > debtors[j].amount })

	// Greedy settlement minimization
	var balances []models.NetBalance
	ci, di := 0, 0
	for ci < len(creditors) && di < len(debtors) {
		amt := math.Min(creditors[ci].amount, debtors[di].amount)
		amt = math.Round(amt*100) / 100
		if amt > 0 {
			balances = append(balances, models.NetBalance{
				From:   debtors[di].name,
				To:     creditors[ci].name,
				Amount: amt,
			})
		}
		creditors[ci].amount -= amt
		debtors[di].amount -= amt
		if creditors[ci].amount < 0.01 {
			ci++
		}
		if debtors[di].amount < 0.01 {
			di++
		}
	}

	return balances
}
```

**Step 5: Run tests to verify they pass**

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/backend && go test -v -run TestComputeNetBalances ./internal/tab/`
Expected: all 5 tests PASS

**Step 6: Run all tab tests to ensure no regressions**

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/backend && go test -v -race ./internal/tab/`
Expected: all tests PASS

**Step 7: Commit**

```bash
git add backend/pkg/models/net_balance.go backend/internal/tab/service.go backend/internal/tab/service_test.go
git commit -m "feat: implement ComputeNetBalances with greedy settlement minimization"
```

---

### Task 4: Enrich Tab GET Response with Net Balances

**Files:**
- Modify: `backend/pkg/models/tab.go:7-19`
- Modify: `backend/internal/tab/service.go:40-53`

**Step 1: Add NetBalances field to Tab struct**

In `backend/pkg/models/tab.go`, add after `TotalAmount` (line 13):

```go
NetBalances []NetBalance `gorm:"-" json:"net_balances"`
```

The `gorm:"-"` tag means it's not stored in the database — computed on read, just like `TotalAmount`.

**Step 2: Compute net balances in GetTab**

In `backend/internal/tab/service.go`, modify `GetTab` (lines 40-53) to add net balance computation:

```go
func (s *tabService) GetTab(id uint) (tab *models.Tab, err error) {
	tab, err = s.repo.GetById(id)
	if err != nil {
		return nil, err
	}
	// Recalculate total from bills and strip bill access tokens
	var total float64
	for i := range tab.Bills {
		total += tab.Bills[i].Total
		tab.Bills[i].AccessToken = ""
	}
	tab.TotalAmount = total
	tab.NetBalances = ComputeNetBalances(tab)
	return tab, nil
}
```

**Step 3: Verify it compiles and tests pass**

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/backend && go test -v -race ./internal/tab/`
Expected: all tests PASS

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/backend && go build ./...`
Expected: success

**Step 4: Commit**

```bash
git add backend/pkg/models/tab.go backend/internal/tab/service.go
git commit -m "feat: enrich tab GET response with computed net_balances"
```

---

### Task 5: Add Net Balance Types to Web Frontend

**Files:**
- Modify: `web-bill-viewer/src/lib/api.ts`

**Step 1: Add TypeScript interfaces**

In `web-bill-viewer/src/lib/api.ts`, add after the `TabMember` interface (line 76):

```typescript
export interface NetBalance {
  from: string;
  to: string;
  amount: number;
}
```

Update the `Tab` interface to include `net_balances`:

```typescript
export interface Tab {
  id: number;
  name: string;
  description: string;
  bills: Bill[];
  total_amount: number;
  finalized: boolean;
  finalized_at: string | null;
  created_at: string;
  net_balances: NetBalance[];
}
```

Also add `paid_by_member_id` to the `Bill` interface:

```typescript
export interface Bill {
  id: number;
  name: string;
  subtotal: number;
  tax: number;
  tip_amount: number;
  tip_percentage: number;
  total: number;
  date: string;
  payment_methods: PaymentMethod[];
  items: BillItem[];
  person_shares: PersonShare[];
  paid_by_member_id?: number;
}
```

**Step 2: Verify it compiles**

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/web-bill-viewer && npx tsc --noEmit`
Expected: success

**Step 3: Commit**

```bash
git add web-bill-viewer/src/lib/api.ts
git commit -m "feat: add NetBalance type and update Tab/Bill interfaces"
```

---

### Task 6: Create NetBalances Web Component

**Files:**
- Create: `web-bill-viewer/src/components/NetBalances.tsx`

**Step 1: Create the component**

Create `web-bill-viewer/src/components/NetBalances.tsx`:

```tsx
"use client";

import { NetBalance } from "@/lib/api";
import { buildVenmoPayUrl } from "@/lib/venmo";
import { SiVenmo } from "react-icons/si";
import { FaArrowRight } from "react-icons/fa6";

interface NetBalancesProps {
  balances: NetBalance[];
  finalized: boolean;
  venmoId?: string | null;
  currentMemberName?: string | null;
}

export default function NetBalances({
  balances,
  finalized,
  venmoId,
  currentMemberName,
}: NetBalancesProps) {
  if (balances.length === 0) return null;

  const currentKey = currentMemberName?.toLowerCase();

  // Split into "your" balances and "other" balances
  const yourBalances = currentKey
    ? balances.filter(
        (b) =>
          b.from.toLowerCase() === currentKey ||
          b.to.toLowerCase() === currentKey
      )
    : [];
  const otherBalances = currentKey
    ? balances.filter(
        (b) =>
          b.from.toLowerCase() !== currentKey &&
          b.to.toLowerCase() !== currentKey
      )
    : balances;

  const renderBalance = (balance: NetBalance, showVenmo: boolean) => {
    const isYouFrom = currentKey && balance.from.toLowerCase() === currentKey;
    const isYouTo = currentKey && balance.to.toLowerCase() === currentKey;

    const fromLabel = isYouFrom ? "You" : balance.from;
    const toLabel = isYouTo ? "You" : balance.to;

    return (
      <div
        key={`${balance.from}-${balance.to}`}
        className="bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl px-5 py-4 shadow-sm dark:shadow-none dark:border dark:border-[var(--border-dark)] flex items-center justify-between"
      >
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-full bg-red-100 dark:bg-red-900/30 flex items-center justify-center font-semibold text-sm text-red-600 dark:text-red-400">
            {fromLabel[0]}
          </div>
          <span className="font-medium text-[var(--accent)] dark:text-white">
            {fromLabel}
          </span>
          <FaArrowRight className="text-[var(--text-secondary)] text-xs" />
          <div className="w-9 h-9 rounded-full bg-emerald-100 dark:bg-emerald-900/30 flex items-center justify-center font-semibold text-sm text-emerald-600 dark:text-emerald-400">
            {toLabel[0]}
          </div>
          <span className="font-medium text-[var(--accent)] dark:text-white">
            {toLabel}
          </span>
        </div>
        <div className="flex items-center gap-3">
          <div className="text-xl font-bold font-mono text-[var(--accent)] dark:text-white">
            ${balance.amount.toFixed(2)}
          </div>
          {showVenmo && venmoId && isYouFrom && (
            <button
              onClick={() => {
                window.location.href = buildVenmoPayUrl(
                  venmoId,
                  balance.amount.toFixed(2),
                  "Tab settlement - " + balance.to
                );
              }}
              className="h-10 px-4 bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white font-semibold rounded-xl flex items-center justify-center hover:opacity-90 transition-opacity border-none cursor-pointer"
            >
              <SiVenmo size={32} />
            </button>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="mb-6">
      {yourBalances.length > 0 && (
        <>
          <div className="mb-3 px-1">
            <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">
              Your Balances
            </h2>
          </div>
          <div className="space-y-3 mb-6">
            {yourBalances.map((b) => renderBalance(b, finalized))}
          </div>
        </>
      )}

      {otherBalances.length > 0 && (
        <>
          <div className="mb-3 px-1">
            <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">
              {yourBalances.length > 0 ? "All Balances" : "Balances"}
            </h2>
          </div>
          <div className="space-y-3">
            {otherBalances.map((b) => renderBalance(b, false))}
          </div>
        </>
      )}
    </div>
  );
}
```

**Step 2: Verify it compiles**

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/web-bill-viewer && npx tsc --noEmit`
Expected: success

**Step 3: Commit**

```bash
git add web-bill-viewer/src/components/NetBalances.tsx
git commit -m "feat: create NetBalances component with personalized and neutral views"
```

---

### Task 7: Integrate NetBalances into Tab Detail Page

**Files:**
- Modify: `web-bill-viewer/src/app/t/[id]/page.tsx`

**Step 1: Add NetBalances to the page**

In `web-bill-viewer/src/app/t/[id]/page.tsx`:

1. Add import at top (after line 12):
```tsx
import NetBalances from "@/components/NetBalances";
```

2. Get the current member's name. After the `venmoId` extraction (after line 96), add:
```tsx
  const memberToken = typeof window !== "undefined"
    ? null  // server component, member token comes from localStorage on client
    : null;
  // For server component, we pass null — the NetBalances component handles display
```

Actually, since this is a server component, we can't access localStorage. The member name needs to come from a different mechanism. We'll pass `null` for `currentMemberName` for now — the neutral view will show for everyone. The personalized view can be a future enhancement when we add client-side member detection.

3. Add the NetBalances component in the return JSX. Replace the section between lines 120-126:

```tsx
      {(tab.net_balances ?? []).length > 0 && (
        <NetBalances
          balances={tab.net_balances ?? []}
          finalized={tab.finalized}
          venmoId={venmoId}
          currentMemberName={null}
        />
      )}

      {tab.finalized && settlements.length > 0 ? (
        <SettlementCard settlements={settlements} venmoId={venmoId} tabId={id} token={token} />
      ) : (
        personTotals.length > 0 && (
          <TabPersonTotals personTotals={personTotals} venmoId={venmoId} />
        )
      )}
```

**Step 2: Verify it compiles**

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/web-bill-viewer && npx tsc --noEmit`
Expected: success

**Step 3: Commit**

```bash
git add web-bill-viewer/src/app/t/[id]/page.tsx
git commit -m "feat: integrate NetBalances component into tab detail page"
```

---

### Task 8: Run Full Backend Test Suite

**Step 1: Run all backend tests**

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/backend && go test -v -race ./internal/... ./pkg/...`
Expected: all tests PASS

**Step 2: Run frontend type check**

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/web-bill-viewer && npx tsc --noEmit`
Expected: success

**Step 3: Build frontend**

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/web-bill-viewer && npm run build`
Expected: success

---

### Task 9: Manual Verification

**Step 1: Start backend locally**

Run: `cd /Users/vapor/Documents/projs/checksinmyhead/backend && go run main.go`

**Step 2: Verify tab GET response includes net_balances**

Use curl or the running app to fetch a tab and confirm the `net_balances` field is present in the JSON response.

**Step 3: Verify web frontend renders balances**

Open a tab detail page in the browser and confirm the NetBalances section appears between members and the settlement/person totals sections.
