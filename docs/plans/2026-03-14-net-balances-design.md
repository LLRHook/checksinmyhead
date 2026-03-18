# Net Balances — Design Document

**Date:** 2026-03-14
**Status:** Approved

## Problem

When multiple people add bills to a shared tab, the system tracks per-person totals (what each person owes) but not who paid each bill. Without knowing who fronted the money, we can't compute "Bob owes Alice $5."

## Solution

Add a `paid_by_member_id` field to bills, compute net balances on the backend, and return simplified settlement data in the tab API response.

## Data Model

- Add `paid_by_member_id` (nullable FK → `tab_members.id`) to `bills` table
- Defaults to the adding member's ID when a bill is added to a tab
- Can be changed via bill update endpoint
- Only tab members are valid values (FK constraint)
- Migration backfills existing tab bills: `paid_by_member_id = added_by_member_id`

## Net Balance Algorithm

**Step 1 — Compute each person's net position:**

For each bill in the tab:
- Payer (via `paid_by_member_id`) "contributed" the full bill total
- Each person in `person_shares` "owes" their share total

Aggregate across all bills:
```
net[person] = total_they_paid - total_they_owe
```

**Step 2 — Minimize transactions (greedy):**

1. Separate into creditors (positive net) and debtors (negative net)
2. Sort both by amount descending
3. Match biggest debtor with biggest creditor
4. Settle the smaller amount, reduce both, repeat

## API Changes

**No new endpoints. No new tables.**

Tab GET response gains a `net_balances` field:
```json
{
  "net_balances": [
    {"from": "Bob", "to": "Alice", "amount": 15.50}
  ]
}
```

Computed on read by a new `ComputeNetBalances(tab)` function in the tab service. Works both pre and post finalization (finalization locks bill data, so computed values are stable).

Bill creation/update request and response include `paid_by_member_id`.

## UI Changes (Tab Detail Screen)

**Recognized members (have `member_token`):**
- "Your Balances" section at top — only balances involving the current user
- "View all balances" expandable below with the full neutral list

**Non-members (visiting via share link):**
- "Balances" section — full neutral list (e.g., "Alice owes Bob $15.50")

**Pre-finalization:** balances update live as bills are added
**Post-finalization:** same data, plus Venmo deep links next to each entry

New section appears between member list and bill list on the tab detail page.

## Known Limitations

- Debtor matching uses case-insensitive name matching between `person_share.person_name` and member `display_name`. Consistent with existing `computeTabPersonTotals` behavior. A future improvement could link person_shares to member IDs directly.
- Bills with null `paid_by_member_id` are excluded from net balance calculations (should not occur after migration + default behavior).

## Edge Cases

- Payer not in person_shares (paid but didn't eat) → net math works, their owe is $0
- Everyone's net is $0 → empty array returned
- Single bill → degrades to "each person owes the payer their share"
