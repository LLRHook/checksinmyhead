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

# Tab Roster & Receipt Flow Revamp

## Product decisions

- [ ] A tab owns a reusable roster of people for the trip/event.
- [ ] The roster is persisted locally and synced to the backend so the tab remains coherent across devices.
- [ ] Tab roster people are separate from anonymous collaboration members; joining a shared tab does not silently add someone to the expense roster.
- [ ] Creating a receipt from a tab starts the existing receipt-entry flow, then asks who participated in that specific stop before assignment.
- [ ] The per-receipt participant list is preselected from the tab roster, with people removable for that receipt only.
- [ ] The existing normal item-assignment flow and lazy-mode flow remain the calculation/claim engines after the new participant step.
- [ ] Existing bills can still be attached to a tab, but “Add receipt” becomes the primary action.
- [ ] A receipt must retain its own participant snapshot so later roster edits do not rewrite historical bills.

## Implementation plan

- [ ] Add a participant roster representation to local `Tabs` storage and `AppTab`, including schema migration, serialization, and unit coverage.
- [ ] Extend backend tab data/update support with a sanitized roster payload, repository persistence, and API tests.
- [ ] Build a reusable tab roster editor using the existing participant/recent-people/group components and make it available during tab creation and tab detail editing.
- [ ] Replace the tab detail primary add flow with “Add receipt”; pass tab context through bill entry, assignment, and summary so the completed bill is saved and synced into that tab.
- [ ] Add a focused per-receipt participant selection step: roster preselected, removable people, empty-state validation, and immutable participant snapshot passed to the bill flow.
- [ ] Preserve normal assignment and lazy mode behavior, adapting lazy mode to the selected receipt participants without introducing a second sharing model.
- [ ] Keep the existing “attach existing bill” path as a secondary action and prevent duplicate attachment.
- [ ] Add focused mobile tests for roster persistence, per-receipt removal, snapshot behavior, tab receipt navigation, and regression coverage for normal/lazy flows.
- [ ] Add backend tests for roster update/auth/sanitization and run Flutter formatting, analyzer, targeted tests, Go tests, and a manual tab-flow smoke test.

## Review checkpoint

- Complexity: medium-to-ambitious. The UI is straightforward, but tab context must survive multiple existing navigation layers and historical receipts must not change when the roster changes.
- Main risk: lazy mode currently uses an empty participant list by design. The implementation must preserve its existing collaborative claim semantics while using the selected roster only as the tab’s intended participant context.
- No implementation has started for this feature; awaiting product-owner approval of the scope above.

# Billington 2.0 — Collaborative Trips & Multi-Currency

## 2.0.2 release hardening — complete

- [x] Make repeated tab joins idempotent per installation.
- [x] Await existing-bill attachment sync and surface failures.
- [x] Add leave-tab and invalid/expired invite handling.
- [ ] Verify production currency-provider configuration without exposing the API key.
- [x] Add focused regression tests and document the two-device smoke test.

### Review

- Repeated invite taps now reuse the existing local tab, and the backend accepts a persisted member token idempotently.
- Existing-bill attachment awaits every backend write and reports partial sync failures instead of silently claiming success.
- Remote members can leave from the tab menu; creators cannot accidentally leave their own tab.
- Invalid or expired invite responses now explain the failure in the join UI.
- The exchange-rate key remains server-only and is documented in `backend/README.md`; production secret configuration still needs to be confirmed in the deployment provider.
- Two-device smoke test remains a manual launch check: create a tab on device A, invite device B, join, add a bill from each device, edit the same item to confirm conflict handling, mark a settlement paid, then leave on device B.

## 2.0.3 collaboration hardening

- [x] Prevent settlement updates from crossing tab boundaries and require a member credential for collaborative writes.
- [x] Pull a joined tab's backend bills into the local receipt cache so its dashboard is genuinely shared across devices.
- [x] Keep failed bill attachments retryable instead of showing them as attached locally.
- [x] Preserve the owner's selected display currency when a member joins.
- [x] Guard malformed cached bill IDs and prevent imported trip-cache receipts from being attached to another tab.
- [x] Run mobile and backend regression suites, review the final diff, then ship as 2.0.3.

### Verification review

- `flutter analyze` passed and all 176 Flutter tests passed.
- `go test ./internal/tab ./internal/bill ./internal/currency` passed with an isolated Go cache.
- A local unsigned iOS build could not start because this workstation's Xcode installation and CocoaPods setup are incomplete; the signed CI/TestFlight runner remains the authoritative iOS build verification.

## Product decisions — approved for implementation

- [x] Tabs become the primary collaborative product: a trip/event has members, shared bills, balances, and settlement actions in the mobile app.
- [x] The existing anonymous collaboration model remains account-less. Each installation gets a generated local identity/display name that can be edited; no hardware device identifier, password, or account is required for v2.
- [x] A shared link is an app invite/deep link. If the app is installed it opens the join flow; if it is not installed it shows a short install handoff and preserves the invite for after installation. The web page remains a lightweight fallback/status page, not the main editing experience.
- [x] Joining a tab creates or restores that installation's member token and shows “You’re part of [tab], owned by [creator]” inside the tab.
- [x] Any member can add a bill, assign people/items, view the running total, see net balances, and mark a settlement paid. The creator alone can rename/delete/finalize a tab.
- [x] Receipt photos are still allowed locally for AI scanning, but tab image uploads, receipt galleries, processed-image gates, and trip-memory behavior are removed from the product path unless a later product decision restores them.
- [x] Payments in v2 mean launching the payer/owner’s configured Venmo, Cash App, PayPal, or other payment link and recording “marked paid.” Real in-app money movement is out of scope.
- [x] Every bill stores its original ISO 4217 currency and the tab stores a selectable display currency, defaulting to USD. Support the provider's supported currencies rather than special-casing PEN; imported values remain auditable in the original currency, while converted values include the rate/date used.
- [x] Add currency selection during tab creation and in tab settings, plus currency selection/confirmation during standalone bill entry. A receipt's detected currency should be editable before save; never silently treat an unknown symbol as USD.

## Implementation plan

### 1. Currency-aware receipt parsing and conversion

- [x] Extend the receipt parser response with `currency_code`, `currency_symbol`, and a confidence/needs-review signal while retaining the original numeric amounts.
- [x] Update the AI prompt to recognize ISO codes and symbols, including `PEN`/`S/`/`S/ .`, distinguish soles from dollars, never silently convert a receipt, and flag ambiguous currency instead of guessing.
- [x] Add a currency confirmation step after scanning: detected currency, tab display currency, editable totals, and a clear conversion preview before saving.
- [x] Add a backend currency service with a provider interface, daily caching, timeout/error handling, and stored `rate`, `source`, and `rate_date` metadata on each converted bill.
- [x] Use ExchangeRate-API’s keyed endpoint from the backend only. The free plan supports multiple base/target currencies through standard/pair endpoints and 1,500 requests/month; cache daily because the provider updates daily. Do not commit the key or send it to Flutter.
- [ ] Add the secret `EXCHANGE_RATE_API_KEY` to the deployment environment and document the required account setup. The Docker wiring and `.env.example` are ready; if the key is unavailable, support a manual rate entry/fallback so a trip is not blocked.
- [x] Add currency formatting throughout mobile, backend JSON, and the tab viewer; web/backend/mobile are currency-aware.
- [ ] Test PEN → USD, USD → PEN, same-currency bills, missing/ambiguous currency, provider failure, cached rates, rounding, and historical bill immutability.

### 2. Backend tab collaboration model

- [ ] Audit and consolidate the existing tab/member/image/finalization APIs into one supported tab workflow; mark image upload/finalization endpoints deprecated before removing their UI.
- [ ] Add explicit member-owned bill creation or a transaction that creates a bill and attaches it to a tab, so members do not need a separate orphan bill/share-link flow.
- [ ] Persist the payer/member who paid each bill, the bill’s participant snapshot, currency metadata, creator/member attribution, and the payment handles explicitly published for that bill/tab.
- [ ] Keep payment handles scoped to a shared bill/tab rather than creating a global user directory. Local settings remain the source of truth until a user chooses to publish them; shared data may contain only the selected handle needed by collaborators.
- [ ] Return a tab summary containing members, bills, total by display currency, each member’s paid/owed/net amount, and minimized settlement suggestions (for example, A pays B).
- [ ] Add authorization rules: valid tab token for reads, member token for writes, creator-only destructive actions, finalized tabs immutable, and idempotent join behavior for a previously joined installation.
- [ ] Keep optimistic concurrency for collaborative edits; add conflict responses and refresh behavior for two people editing the same bill.
- [ ] Add Go tests for join idempotency, member attribution, cross-member bill creation, balance math, currency conversion persistence, permissions, finalization, and payment-state updates.

### 3. Mobile tab experience

- [ ] Replace the current tab detail hierarchy with a clear trip dashboard: tab name/owner, member row, total, “you owe/you’re owed,” balances, recent bills, and one primary “Add bill” action.
- [ ] Add “Add bill to this tab” as a first-class entry point that passes tab/member context through receipt scan, manual entry, participant selection, item assignment, and save/sync.
- [ ] Preserve “I’m Lazy” and Quick Split as fast paths for one-off dinners; offer “Save to tab” when appropriate without making those flows carry the full tab complexity.
- [ ] Add member management/join status, copy/share invite, leave tab, and creator controls. Use a generated install identity as the default name and let the user edit it.
- [ ] Add local persistence for the install identity and member tokens with recovery-safe behavior; never rely on a raw device ID or expose member tokens in logs.
- [ ] Add settlement UI that shows who owes whom, launches configured payment methods, and records payment status with confirmation and undo where safe.
- [x] Remove the tab image gallery, processed checklist, camera FAB, and image-driven finalization gate from the primary flow. Keep camera access only where needed for receipt parsing.

### 4. Invite/deep-link and web fallback

- [x] Define one canonical tab invite URL and configure iOS Universal Links plus the Billington URL scheme to open the iOS app directly.
- [ ] On cold install/open, retain the invite URL until onboarding completes, then show the join confirmation with tab name, owner, and the generated/editable display name.
- [x] Replace the web viewer’s join/edit ambiguity with a lightweight “Open in Billington” handoff, install CTA, read-only fallback summary, and clear explanation that edits happen in the app.
- [ ] Keep direct payment links and read-only browser access available for people who cannot install, but do not promise browser-based collaborative editing in v1.
- [ ] Add mobile/web smoke tests for installed, not-installed, expired/invalid invite, duplicate join, and returning member flows.

### 4b. Web presence and viewer overhaul

- [ ] Audit the public landing page, bill viewer, and tab viewer for stale 1.4/lazy-mode assumptions and a consistent Billington 2.0 message.
- [ ] Make tab pages read-only in the browser: show trip identity, owner, members, totals, net balances, original/converted currencies, payment handles, and last-updated state without browser mutations.
- [ ] Add a prominent, responsive “Open in Billington”/“Get the app to join” handoff that preserves the tab invite URL through installation.
- [x] Remove or gate browser join/claim/edit controls that conflict with the app-required collaboration model.
- [x] Replace hard-coded dollar formatting in every viewer component with currency-aware formatting and conversion context.
- [ ] Keep the existing visual language: warm brand accent, rounded cards, restrained hierarchy, dark mode, mobile-first responsive layout, accessible focus states, and no new visual system.
- [ ] Add web tests for read-only behavior, app handoff, currency display, invalid tokens, empty tabs, and payment-link rendering.

### 5. Polish, documentation, and launch verification

- [ ] Follow `ui_prompt.md` for the tab dashboard and join/add-bill flow; keep the existing fast paths visually distinct from the collaborative trip experience.
- [ ] Update roadmap, API docs, privacy docs, setup/deployment docs, and release notes to match the final supported model.
- [ ] Add migration/backfill behavior for existing tabs and bills, including default USD and legacy `$` formatting where currency is unknown.
- [ ] Run Flutter format/analyze/tests, Go race tests, web lint/typecheck/unit tests, production builds, and a two-device manual trip simulation.
- [ ] Verify production environment variables, database migrations, deep links, rate-cache behavior, payment links, and error states before calling v1 complete.
- [x] Verify the displayed app version, Flutter package version, iOS marketing version, build number, and release notes are consistent; remove stale installed/build artifacts before judging the Settings version.

## Review checkpoint

- Complexity: ambitious but bounded if v1 keeps account-less identity, daily exchange rates, external payment links, and one canonical tab model.
- Main risk: trying to become all of Splitwise at once. The proposed launch slice is shared trip accounting and settlement tracking; accounts, chat, real money movement, receipt archives, and historical exchange-rate reconstruction can follow in v2.
- Required product-owner confirmations: approve the v1 boundary above, create/provide the ExchangeRate-API key through a secure environment variable, and decide whether the web fallback should remain read-only or be removed entirely.
