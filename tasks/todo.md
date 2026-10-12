# Investigation Plan

## Codebase-wide KISS cleanup (proposed)

### Goal and guardrails

- Reduce avoidable complexity and duplication across `backend/`, `mobile/`, and `web-bill-viewer/` without changing product behavior or deleting supported features.
- Treat all pre-existing dirty changes as user work: do not revert, reformat wholesale, or fold unrelated feature changes into cleanup.
- Prefer small, independently verifiable refactors; remove dead code only when references and runtime paths confirm it is unused.
- Use existing UI patterns and `ui_prompt.md`; avoid visual redesign.

### Audit and implementation stages

- [x] Inventory module boundaries, repeated helpers/flows, dead code candidates, oversized files, error-handling inconsistencies, and dependency/build complexity in each platform.
- [x] Establish baseline checks per platform and record confirmed cleanup candidates with impact/risk before editing.
- [x] Refactor the highest-value, lowest-risk duplication in one platform-sized slice at a time; preserve API contracts, stored data, deep links, and UI behavior.
- [x] Add or adapt focused tests for each behavior-sensitive refactor; remove only demonstrably dead code/dependencies.
- [x] Run formatting, static analysis, unit tests, and production builds for touched platforms; inspect the final diff for behavior drift and formatting-only churn.
- [x] Record outcomes, deferred candidates, and verification in this section.

### Review checkpoint

- Complexity: broad and potentially risky if treated as a one-shot rewrite. The safer approach is an audit followed by small cross-platform slices, with explicit stop points when a candidate changes behavior or public contracts.
- Approved by the product owner before implementation.

## Review

- Web viewer: consolidated bill/trip item-assignment requests so authorization headers, stale-write conflicts, payload shape, and error handling have one implementation. Consolidated bill/tab authorized reads while preserving their resource-specific error messages. Moved the generic money formatter into the currency module and retained its previous API-module export for compatibility.
- Flutter: removed the duplicate receipt-currency selector. The remaining selector owns rate loading and validation; the trip-currency preview remains separate because it represents a different conversion.
- No dead dependencies or backend code were removed: the audit showed that both backend rate APIs and the older preview are still reachable from product flows. Large files were not split just to reduce line counts; deeper decomposition needs a separate behavior-focused target.
- Verification: Flutter analyzer and all 187 tests passed; Go tests and `go vet ./...` passed; web Biome lint, TypeScript, all 28 Vitest tests, and production build passed. `git diff --check` passed.

## Continued KISS pass

- [x] Share tab ID/token validation between full tab reads and lightweight authorization reads without changing which service lookup each route uses.
- [x] Share creator authorization between tab settings and finalization while preserving route-specific errors and legacy memberless-tab behavior.
- [x] Remove redundant typed catch branches in tab management where they performed the exact same handling as the fallback.
- [x] Remove exception handling around `double.tryParse` and delete the unused currency-setter alias; retain invalid-input-to-zero behavior with a regression test.
- [x] Consolidate three paid-status PATCH request implementations and cover member-token forwarding.
- [x] Make subset-generation tests call the production helper instead of maintaining a copied implementation.
- [x] Consolidate saved/suggested group loading without changing query order or fallback behavior.
- [x] Remove the duplicate recent-bill share-text implementation and route it through the shared formatter; remove its unused `BuildContext` parameter and explanatory noise comments.
- [x] Consolidate identical bill/tab public-domain resolution into one backend config helper.
- [x] Reuse the web bill API client in its retrying viewer instead of duplicating authorization and response decoding.
- [x] Centralize standard mobile request-error translation for bill upload, tab creation/attachment/leave/join/finalize, settlement updates/reads, and member/tab reads; keep custom exchange-rate errors distinct.
- [x] Remove an unused bill-item serialization parameter and redundant currency-formatter commentary.
- [x] Share payment-identifier formatting between both payment-settings save flows, with focused formatting coverage.
- [x] Remove the unused recent-people argument and redundant comments around simple formatting/storage operations.
- [x] Replace repetitive web aggregation-test fixtures with small shared Bill/Tab/PersonShare builders without reducing edge-case coverage.
- [x] Remove unreferenced `BillCalculations.generatePersonShares` and `generateBillItems`; those conversions already live on `RecentBillModel` and the detail UI never called these methods.
- [x] Remove the unused Flutter `cupertino_icons` package after confirming no code references its icon set; retain platform/database plugins used by the app.
- [x] Delete eight empty Go placeholder files that declared event/payment packages without implementations, callers, routes, or deployable services; recheck module tidiness.
- [x] Remove unused `participants` and `birthdayPerson` parameters from bill-summary amount calculation APIs and callers; rename the misleading zero-share test to reflect what it actually verifies.
- [x] Share the database group-member insertion loop between saved groups, suggested groups, and membership updates.
- [x] Remove field-by-field and self-describing comments from `RecentBillModel`, keeping the one meaningful currency-audit note and runtime fallback behavior.
- [x] Share the duplicate exact-100% split calculation used by assignment balancing and even assignment creation; remove the unused item parameter from the calculation API.
- [x] Share item-assignment total/unassigned/final-share recalculation between normal reassignment and birthday-person removal.
- [x] Remove method-by-method comments and narration from settings/preferences storage where the code already states the behavior.
- [x] Remove the tab package's bill-share pass-through wrapper and call the bill package's exported share builder directly.
- [x] Import the shared web currency formatter from its owning currency module and remove the API module's compatibility re-export.
- [x] Remove `PreferencesService`'s stateless singleton wrapper; retain its existing constructor API.
- [x] Share the repeated paying-participant count used by all three birthday-aware even-split paths.
- [x] Flatten unassigned-amount splitting so item/no-item paths share one final calculation and remove narration comments from the assignment engine.
- [x] Collapse identical database-error returns and share the final item timestamp update in tab assignment persistence.
- [x] Remove table/method narration from the Drift database file while retaining migration and behavior rationale comments.
- [x] Centralize bearer/query access-token precedence for bill, trip, and bill-page handlers; cover both precedence paths.
- [x] Share pending-bill upload serialization and URL persistence between batch and single-bill retries while retaining their different failure handling.
- [x] Remove parameter-by-parameter and self-narrating comments from the recent-bills manager while keeping trip-import/retry contracts.
- [x] Remove unused birthday/custom-tip parameters from recent-bill persistence and its three callers; retain them in the calculation and sharing models.
- [x] Drop narration comments from bill creation/response handling while retaining security and calculation rationale.
- [x] Share the repeated person-name-to-ID lookup in group creation and membership replacement.
- [x] Change bill-attachment and settlement-update API methods to `Future<void>` because callers only await success/failure.
- [x] Reuse the existing payment-identifier modal for both settings entry points; removed the duplicated 225-line form while preserving each caller's save behavior.
- [x] Remove unused animation-controller setup and ticker-provider mixins from both trip screens; neither controller was ever read or started.
- [x] Remove the payment settings sheet's unused ticker-provider mixin; it owns no animation controller.
- [x] Remove the tutorial overlay's unused ticker-provider mixin; its page transitions use `PageController` directly.
- [x] Build the tab settlement display-name indexes in one member pass; preserve the existing case-insensitive lookup and overwrite order.
- [x] Continue auditing remaining high-complexity business/UI flows; only refactor where behavior is testable and the simplification is real.

## Full audit and single-PR pass (active)

- [x] Establish the exact pre-audit diff and preserve all existing edits; the product owner explicitly authorized packaging the existing changes with the audit in one PR.
- [x] Audit all 29 first-party Go production files across service entry points, bill, currency, exchange, receipt, tab, version policy, web, config, database, models, and security.
- [x] Audit first-party `mobile/lib` production modules across entry/onboarding, services, models, bill entry/summary, participants, assignment, recent bills, settings, tabs, and shared widgets; exclude generated Drift output.
- [x] Audit all first-party production files under `web-bill-viewer/src` across routes/layout, components, hooks, and API/currency/Venmo utilities.
- [x] Trace remaining mobile API error-wrapper candidates to their callers; defer unification because the current flows deliberately handle failures differently and need targeted HTTP seam tests first.
- [x] Implement only small behavior-preserving simplifications with focused regression coverage where behavior is affected.
- [x] Run full backend, mobile, and web verification appropriate to the final diff, including lint/type checks/builds where available.
- [x] Review the complete staged PR file set against the original worktree baseline; all existing changes are intentionally included per the product owner's one-PR direction, generated build output is excluded, and `git diff --cached --check` passes.
- [x] Create one branch and one PR containing the authorized complete audit changes; PR: https://github.com/LLRHook/checksinmyhead/pull/144.

### Full-pass review outcomes

- Backend audit reviewed all 29 Go production files. Removed unused repository operations and an uncalled currency helper; kept bill and tab assignment persistence separate because their authorization and paid-share rules differ.
- Mobile audit covered production entry flows, services/models, bill entry and summary, participants, assignment, recent bills, settings, tabs, and shared widgets. Removed an unused tax/tip calculation map; deferred UI decomposition and error-wrapper unification without dedicated flow tests.
- Web audit reviewed all production route, component, hook, and library files. Shared identical tab-collection GET handling while preserving its empty-list fallback. Deferred header markup unification and lazy-board decomposition due UI/flow coupling.
- Updated Next.js/React and compatible web dependencies; upgraded 47 Flutter packages within constraints and patch/minor Go modules within existing major versions. Did not cross the app-links or SQLite plugin major-version boundaries.

### Audit scope and limits

- Review every first-party production source file under `backend/`, `mobile/lib/`, and `web-bill-viewer/src/`; exclude generated code, vendored dependencies, and build output.
- Do not claim files were reviewed merely because a directory was inventoried. Track reviewed module groups and record candidates/no-change conclusions as each group is read.
- Existing worktree changes predate this full pass and remain protected. If an existing change is unrelated to the audit, do not silently fold it into the PR; establish its ownership and scope before packaging.
- The existing line-count inventory (~45k lines including generated Drift output) is a map, not proof of review. Generated output is excluded from the review target.

### Verification

- Backend: `go test ./...` and `go vet ./...` passed after the handler refactor and focused tests.
- Mobile: `flutter analyze` and all 189 tests passed after removing dead parsing catches, deduplicating group loading, sharing recent-bill formatting, and testing the production subset helper.
- Web: Biome, TypeScript, and all 29 tests passed after routing the bill viewer through the shared API client. The latest production build attempt stopped when Turbopack tried to spawn a CSS worker that binds a port (`Operation not permitted`); the same build passed earlier in this cleanup, before the last API-only refactor.
- Backend: `go test ./...` and `go vet ./...` passed again after extracting the shared app-domain config.
- Mobile: `flutter analyze` and all 189 tests passed again after centralizing standard request-error translation across the tab API methods with identical timeout/network/unexpected-error behavior.
- Mobile: `flutter analyze` and all 190 tests passed after deduplicating payment-method normalization used by both settings flows.
- Mobile: `flutter analyze` and all 190 tests passed again after removing the unused recent-people parameter and low-value comments.
- Web: test fixture consolidation removed over 300 lines of repetitive setup; Biome, TypeScript, and all 29 tests passed.
- Mobile: `flutter analyze` and all 190 tests passed after removing the two unreferenced bill-calculation methods.
- Mobile: dependency resolution, analyzer, and all 190 tests passed after removing the unused icon dependency.
- Backend: removed empty event/payment package placeholders; `go test ./...`, `go vet ./...`, and `go mod tidy -diff` all pass.
- Mobile: `flutter analyze` and all 190 tests pass after removing unused calculation parameters and correcting their test description.
- Mobile: `flutter analyze` and all 190 tests pass after unifying repeated group-member insertion logic.
- Mobile: `flutter analyze` and all 190 tests pass after moving bill upload onto the shared standard API error translator.
- Mobile: `flutter analyze` and all 190 tests pass after trimming redundant model documentation.
- Mobile: `flutter analyze` and all assignment utility tests pass after sharing the exact percentage split helper; settings documentation cleanup also passes the full 190-test suite.
- Mobile: `flutter analyze`, all 190 tests, and focused assignment tests pass after consolidating item-total recalculation; `git diff --check` passes.
- Backend: tab/bill tests and vet pass after removing the `buildPersonShares` wrapper.
- Web: Biome, TypeScript, and all 29 tests pass after removing the formatter re-export; direct type-only imports satisfy the React review checklist.
- Mobile: analyzer and all 190 tests pass after removing the unnecessary preferences singleton.
- Mobile: analyzer and assignment utility tests pass after consolidating birthday-aware participant counts.
- Mobile: analyzer and all assignment utility tests pass after flattening unassigned amount distribution and trimming redundant algorithm narration.
- Backend: tab package tests and vet pass after simplifying assignment persistence's identical error branches and timestamp update.
- Mobile: analyzer and all 190 tests pass after trimming redundant database comments.
- Mobile: corrected receipt parsing's generic fallback so invalid/unexpected responses are not mislabeled as network failures; analyzer and all 190 tests pass.
- Mobile: payment settings now use one identifier editor for both flows; `dart format`, `flutter analyze`, all 190 tests, and `git diff --check` pass.
- Mobile: removed two unused tab-screen animation controllers; analyzer and all 190 tests pass.
- Mobile: removed an unused ticker-provider mixin from payment settings; analyzer and `git diff --check` pass.
- Mobile: removed an unused ticker-provider mixin from the tutorial overlay; full analyzer and all 190 tests pass.
- Backend: combined the two member-name index passes in net-balance calculation; focused tab tests and vet pass.
- Backend: full `go test ./...`, `go vet ./...`, and `go mod tidy -diff` pass after compatible module updates.
- Mobile: `flutter pub get`, analyzer, and all 190 tests pass after 47 compatible package upgrades.
- Web: Biome, TypeScript, all 33 tests, and `npm audit --omit=dev` pass after dependency upgrades; the audit reports zero production vulnerabilities.
- Web production build passes with `next build --webpack`, including generated route types. Default Turbopack remains blocked in this sandbox when its CSS worker binds a port.
- Backend production packages also pass `go build ./...` after module upgrades. iOS native build is unavailable because this checkout is not configured for iOS (`Application not configured for iOS`).
- Full audit review: all backend, mobile, and web first-party production module groups have been read. Deferred web header unification and the dense lazy-bill UI flow because changes would need UI/flow design review or dedicated integration coverage.
- Backend: removed unused repository API methods and the uncalled `Bill.USDValue`; receipt upload no longer binds an unused multipart header.
- Web: settlement/member list loading now shares one helper; regression cases cover both endpoints, auth headers, successful decoding, and the existing non-OK fallback.
- Mobile: removed a calculated-but-never-read tax/tip map from assignment recalculation.
- Next.js latest registry release check: 16.4.0; `package.json` and lockfile use 16.4.0. Remaining web outdated reports are newer major versions or versions incompatible with the supported Node 24 runtime.
- Backend: all Go tests and vet pass after centralizing access-token extraction in `safehttp`.
- Mobile: analyzer and all 190 tests pass after deduplicating the two pending-upload flows.
- Mobile: comment-only cleanup of recent-bill management retains the passing analyzer and 190-test verification from this slice.
- Mobile: analyzer and all 190 tests pass after removing unused recent-bill persistence parameters.
- Backend: full Go tests/vet from the token-helper pass remain applicable; this last change only removes redundant comments.
- Mobile: analyzer and focused group-manager tests pass after sharing person-ID lookup.
- Mobile: analyzer and all 190 tests pass after removing unused boolean API results.
- `git diff --check` passed. All pre-existing feature changes remain preserved.
- No deployed environments or stored data were changed.

## Post-merge CI fix and TestFlight release (active)

- [ ] Confirm the audit PR merge and resolve its failing backend race check in a focused follow-up.
- [ ] Bump the app version and build number consistently across Flutter, iOS, and the visible Settings label.
- [ ] Run backend, mobile, and relevant release checks; review the exact follow-up diff.
- [ ] Open a new PR, wait for required checks, and merge the verified release change.
- [ ] Trigger the TestFlight workflow from the merged release commit and confirm upload/processing status.

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

# Standalone Bills, Lazy Claiming, and Launch Hardening

## Product outcome

- A bill is a first-class shared object with its own `/b/{id}` viewer and token. Regular bills keep the existing shared-total and pay flow.
- Lazy mode remains a bill workflow: the creator needs no participant setup; the bill opens directly in the receipt item picker, then pay flow. A trip is a separate collection of bills at `/t/{id}` and is never created as a side effect of making a lazy bill.
- Existing Billington users can open the lazy bill in the app. Everyone else can claim items in the browser, with a small “Bill better with Billington” install prompt.
- Currency display has one active display choice controlled in Settings, avoiding simultaneous duplicate currency totals on the landing screen.
- App update enforcement has a centrally configured minimum supported version and a clear store link. The client must fail safely if version policy cannot be fetched.
- Review the public API, token access, input validation, deep links, and dependency/build configuration for security issues and fix confirmed findings in scope.

## Approved implementation plan

### Phase 1 — Separate bill and trip behavior (critical)

- [x] Trace existing bill and trip persistence, API contracts, deep-link parsing, and the lazy-mode creator/viewer flow; document the compatibility path for existing `/t/{id}` links.
- [x] Make shared bills standalone: add bill-level lazy claim state and guarded mutation endpoints, persist claims on the bill, and keep regular bill shares/payment display unchanged.
- [x] Update mobile lazy creation to skip participant setup, claim the creator’s items in-app when available, and publish a bill URL rather than creating a trip. A trip receives a bill only through an explicit attach/add-bill action.
- [x] Route lazy `/b/{id}` links into the receipt picker; make “Open in Billington” attempt the native app link and retain a working browser fallback, plus the compact install prompt.
- [x] Keep `/t/{id}` as the independent trip collection viewer, with each contained bill opening its own `/b/{id}` viewer.

### Phase 2 — Currency preference and viewer polish

- [x] Add a Settings display-currency preference (original receipt currency or USD equivalent) for recent-bill amounts and the bill-summary total; preserve original receipt amounts and conversion metadata.
- [x] Keep trip totals on the existing per-trip display-currency selector so mixed-currency aggregation remains explicit and accurate.
- [x] Add persistence tests for the preference.

### Phase 3 — Launch hardening

- [x] Add a version-policy endpoint/configuration and a minimum-version gate with update-store navigation; document the operator steps for raising the minimum.
- [x] Perform a focused security review across backend authorization/token checks, writes and validation, browser rendering/deep links, secrets, and dependencies; remediate confirmed issues and record remaining risks.
- [x] Add Phase 1 regression coverage for lazy claims, link routing, and read-only trip-token bill access; run the relevant mobile, web, and backend verification.
- [x] Add Phase 2/3 regression coverage for display-currency preference and minimum-version behavior.
- [x] Update API/product documentation and this review section with changed behavior, verification results, and follow-up items.

## Review checkpoint

- Complexity: ambitious. The root cause is an ownership-boundary issue: the current lazy flow is tab-backed, while the requested product has standalone bills that may optionally belong to a trip. Correcting it crosses mobile creation, backend persistence/authorization, and both web routes.
- Production sample `https://billingtonapp.vercel.app/t/19?t=9FKoLJzZnPz` confirms tab 19 contains one lazy bill with no participants; the page labels it “Created w/ Lazy Mode” and currently renders the trip handoff plus a static bill list.
- Git history confirms the interactive lazy receipt picker existed on the trip page before the 2.0 rewrite. The rewrite removed `LazyBillBoard` and replaced `JoinTabButton` with the read-only `AppHandoff`, which explains why item selection used to work and now does not.
- The current lazy creator also uploads the bill once before branching, then uploads it a second time when creating the trip. The first record is orphaned; this should be corrected as part of the flow fix.
- Proposed scope: preserve existing trip URLs and normal bill display; migrate only newly created lazy bills to bill-level state. Keep historical lazy tabs (including the supplied sample link) interactive based on their existing lazy marker, while normal trips remain read-only in the web viewer.
- Update enforcement recommendation: hard-block versions below a configured minimum only after release, with a clear store action and fail-open behavior for a temporary policy-service outage. The server remains authoritative for security; client-side version checks are not an authorization boundary.
- Design-system prerequisite: no `DESIGN_SYSTEM.md`, `APP_FLOW.md`, `PRD.md`, or frontend guidelines currently exist. Before visual implementation, record only the existing tokens/patterns needed by the affected screens; do not invent a new visual system.
- At the time this plan was written, product code was awaiting Phase 1 approval under `ui_prompt.md`.

## Phase 1 implementation review

- New lazy bills are stored as standalone `Bill` records with `lazy_mode=true`, use `/b/{id}`, and do not create a trip. Removed the extra upload that previously left an orphan bill.
- Added token-guarded bill-level item assignment writes with input validation, row locking, stale-version conflicts, share recalculation, and paid-item protection.
- Restored the old picker for lazy tabs created before this fix. The supplied `/t/19` sample remains interactive while normal trip links keep the read-only summary.
- Trip tokens can open an attached bill viewer read-only. Mutation endpoints still require the bill token.
- Native `billington://tab/...` links now parse correctly; bill links route into the app claim screen from both cold launch and while the app is already open. The creator is taken directly into their bill claim screen after sharing.
- Web tests (26), web lint, TypeScript, and production build passed. Full backend `go test ./...`, Flutter test suite (181), and `flutter analyze` passed.
- Production UI interaction was not exercised against the hosted API after code changes; deployment is still required before the supplied live URL reflects this implementation.
- Phase 1 complete; Phases 2 and 3 have now been implemented and verified below.

## Phase 2/3 implementation review

- Settings persists one recent-bill display preference (original currency or frozen USD equivalent); receipt line items remain in original currency for auditability. Trips retain the existing explicit per-trip display currency.
- Startup checks `GET /api/app/version-policy`; versions below the configured minimum receive a blocking App Store update screen. Network failures, timeouts, and malformed policy responses fail open. This is a compatibility gate only; API authorization remains server-side.
- Confirmed security issue: Gin's default logger appended `RawQuery`, which can contain share/member bearer credentials. Replaced it with a query-free request formatter and regression test.
- Confirmed security hardening: newly generated share/member tokens now use 256 bits of cryptographic randomness. Existing tokens remain valid and require no migration.
- `npm audit --omit=dev` is clean after compatible Next.js/sharp/source-map-js lockfile updates. `govulncheck` reports no reachable Go vulnerabilities; one vulnerability remains in a required module but no vulnerable symbol is called. Flutter's dependency set has no dedicated advisory scan configured in this repository.
- Full Go tests passed on Go 1.27.2 after updating the module and both Go builder images. Web tests (26), lint, typecheck, and production build passed; mobile analyzer and all 187 Flutter tests passed.
- Production deployment and in-store verification are still required before raising the minimum in production or confirming the hosted flow.
