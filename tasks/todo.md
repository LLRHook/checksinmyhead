# Investigation Plan

- [x] Map the tabs finalize/share flow in mobile and web
- [x] Verify whether local SQLite is still used and where
- [x] Trace finalize API behavior and math calculations
- [x] Patch the root cause of the bug
- [x] Run targeted tests for the affected flow

## Review

- Finalize/share now waits on backend tab creation and bill sync instead of racing local state.
- Mobile Drift SQLite is still in use for local cache/history, but backend finalize math comes from Postgres.
- `flutter analyze lib/screens/tabs` passed.
- `GOCACHE=/private/tmp/go-build go test ./internal/tab ./internal/bill` passed.

# Lazy Mode Plan

- [x] Add a creator entry point for "I'm Lazy" in the mobile landing flow
- [x] Reuse the existing receipt parsing and bill creation flow for lazy-mode bill generation
- [x] Add backend support for updating item assignments and recalculating shares on a shared lazy bill
- [x] Add a friend-facing web claim page on the tab viewer that fits the existing design language
- [x] Add tests for assignment recalculation and the new lazy-mode API behavior
- [x] Run targeted verification for the mobile, backend, and web changes

## Review

- Added an `I'm Lazy` shortcut on the mobile landing screen that skips participant setup and routes into the existing bill parsing flow.
- Lazy-mode summaries now create a tab-backed share link, upload the parsed bill with no upfront shares, and hand friends a collaborative claim page.
- The tab viewer now keeps the lazy board active until every item is fully claimed, then falls back to the normal totals/payment view.
- Backend now recalculates person shares from item assignments and the targeted backend, Flutter, and web tests passed.

# Lazy Mode Receipt Flow Redesign

## Product decisions

- [x] Keep lazy mode tab-backed and collaborative; do not introduce a second bill-sharing model.
- [x] Replace the claim dashboard with a receipt-style item picker and one primary CTA.
- [x] Removed from scope: the creator should claim their own items in the app before publishing the lazy link, so no web owner-assumption dialog is needed.
- [x] Add an owner item-selection step in the lazy app flow; owner-selected items are excluded from the shared viewer payload.
- [x] Show the bill receipt, including subtotal, tax, tip, and total, on the landing state; remove the lazy-mode explainer banner and parser-origin copy.
- [x] Let a person select items, split an item across people, then move to a focused final-pay screen.
- [x] Show Venmo as the primary integrated payment action and other payment methods as regular details.
- [x] Add explicit “Mark as paid”; after payment, the person’s selected items become locked/crossed out and the remaining balance reflects unpaid shares.
- [x] Handle concurrent edits with optimistic item versions and a database row lock; stale writes return a conflict and never overwrite newer assignments.

## Implementation plan

- [x] Extend the backend item-assignment contract with an item version/updated-at precondition and a paid-assignment representation needed to lock settled items.
- [x] Add the backend payment mutation needed by lazy-mode final pay, with authorization/ownership checks where the existing anonymous-token model allows them.
- [x] Refactor the tab page/sidebar so lazy mode has a normal receipt preview and compact payment details; do not add a web owner-assumption interaction.
- [x] Replace `LazyBillBoard` with a receipt picker: checkbox selection, split affordance, unavailable/paid states, conflict refresh, and a single continue CTA.
- [x] Add the lazy final-pay state with subtotal/tax/tip detail, Venmo action, external payment details, and mark-paid return behavior.
- [x] Remove lazy-mode-only repetitive summaries and parser-origin language while preserving normal tab/bill viewer behavior.
- [ ] Add focused frontend and backend tests for totals, identity persistence, paid locking, stale assignment conflicts, and the existing flow regressions.
- [x] Run formatting, type checks, unit tests, Go race tests, production build, and browser verification at mobile and desktop widths.

## Review

- Scope is medium-to-ambitious because it changes a collaborative state machine and payment lifecycle, not just styling.
- The safest first version keeps the existing anonymous member/token model and uses optimistic concurrency rather than adding long-lived locks or websockets.
- If the product later needs partial payment of a split item by different people, the item-assignment payment model should be extended separately; this pass treats an item as settled once its complete assignment is paid.
- Owner claims are made in the app before sharing. The web flow is for the remaining unclaimed items, which keeps the shared receipt smaller and removes ambiguity about the bill creator.

## Verification review

- Web: Biome lint, 16 Vitest tests, TypeScript, production build, and route smoke test passed.
- Backend: `go test ./internal/tab ./internal/bill` passed after adding conditional assignment writes and member-owned lazy share-paid mutation.
- Mobile: `flutter analyze lib/screens/quick_split/bill_summary` passed.
- Browser smoke test reached the token-gated tab route successfully; a live bill-token fixture was not available for interaction testing.
- Remaining follow-up: add dedicated unit coverage for the new lazy UI/state helpers and exercise two real browser sessions against a seeded lazy bill.

# App Store Review Readiness

- [x] Remove stale references to the previous product identity from the app.
- [x] Make the current release version `1.4.0` and add canonical release notes.
- [x] Make TestFlight notes describe the visible Lazy Mode workflow and payment behavior.
- [x] Make the App Store release workflow fall back to repository release notes when an annotated tag has no message.
- [x] Add reviewer-facing walkthrough and clarify that there are no hidden/reviewer-only features.

# Backend Production Deployment Repair

- [ ] Align Render Docker build images with the Go version required by `backend/go.mod`.
- [ ] Verify the production health endpoint and Render rollout after merging the fix.
- [ ] Confirm whether a Render deploy hook secret is needed or Git auto-deploy is the intended path.
