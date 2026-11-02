# Billington — Bug Tracker

Active work only. Format and rules: [`.cycle/TRACKERS.md`](.cycle/TRACKERS.md). Write with `python3 .cycle/trackers.py`, never by hand. Shipped and closed entries are removed; their record is `CHANGELOG.md`, Jira, and `python3 .cycle/trackers.py show <id>`.

## Open

### [BUG-1793644497] Require source-bill ownership for tab attachment
- [ ] **Severity:** crit
- **Area:** backend, security
- **File(s):** backend/internal/tab/{handler,service,repository}.go; backend/internal/tab/{handler,repository}_test.go
- **Observation:** The handler permits an empty bill_token; repository AddBill only filters ownership when nonempty. A destination tab token does not authorize the source bill.
- **Expected:**
  - Omitted, empty, wrong, and another bill token cannot attach or expose a source bill.
  - Valid source ownership attaches only from an allowed current tab state; retries preserve ownership.
  - Handler-through-repository negative tests cover sibling attachment paths using isolated fixtures.
- **Req:** TR engineering 1; TR fix 1; SR P0 attachment; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Read AddBillToTab and AddBill at baseline. Review reproduced synthetic victim receipt/payment disclosure; re-run as a failing regression, never against customer IDs.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Transactional attachment remains implemented: independent source/destination proof, authenticated membership attribution, tab-before-bill locks, stable retries and stale standalone guards. Correction 28eab76 preserves these controls; 316 Go leaf cases and 157 integration-tagged tab leaf cases (16 PostgreSQL-specific), zero failures/skips. docs/reviews/2026-11-02-authorization-corrections.md records scope and proof. Full acceptance remains RED for recorded Flutter locked-acquisition and retained-image findings; independent driver review pending.
- **Docs:** docs/backend-api.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-02-authorization-batch.md; docs/reviews/2026-11-02-authorization-corrections.md
- **Log:**
  - 2026-11-02 Validation: Approved authorization corrections preserve all attachment controls. Current race/real-PostgreSQL suites have zero skips; 21 task-owned generated schemas removed and shared fixture retained. Source 28eab76; in-progress retained for independent acceptance and separate full-gate blockers.

### [BUG-1793644498] Restrict public bill creation to authorized input
- [ ] **Severity:** crit
- **Area:** backend, security
- **File(s):** backend/internal/bill/{handler,service}.go; backend/pkg/models/bill.go; backend/internal/bill/{handler,service}_test.go
- **Observation:** CreateBill binds models.Bill, allowing client-supplied tab/payer/nested accounting state without tab authorization.
- **Expected:**
  - Explicit request DTO ignores or rejects server-owned tab, payer, IDs, paid and derived share fields.
  - Unauthorized creation cannot mutate another or finalized tab; authorized attach remains compatible.
  - Finite totals, collection/body bounds, percentages and derived accounting agree; legitimate discount items remain supported.
  - Repository integration tests prove privileged-input rejection and valid old-client creation.
- **Req:** TR engineering 2; TR fix 2; SR P0 creation; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** POST synthetic negative total with victim tab_id against isolated DB, as in review reproduction. Review sibling create/update routes. UI/client compatibility must be demonstrated.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Correction 28eab76 validates raw per-person components and aggregate obligations before cent allocation, prevents tolerance denominator amplification, checks cent/int64 arithmetic and bounds remainder work by participant count. Creation prepares once before separate display/frozen quoting. Historical display-provider validation restored, including all twelve mobile choices and ZAR; receipt policy unchanged. Nested share tests require successful clean controls; ten actual builder fixtures assert every person and item detail. Safe before failures and five control-removal failures recorded; 316 Go and 157 integration-tagged tab leaf cases pass with zero skips. Full acceptance remains RED for recorded Flutter locked-acquisition and retained-image findings; independent review pending.
- **Docs:** docs/backend-api.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-02-authorization-batch.md; docs/reviews/2026-11-02-authorization-corrections.md
- **Log:**
  - 2026-11-02 Validation: Driver-approved AUTH_CORRECTION_APPROVAL.md findings 1-3 implemented in 28eab76. Six safe before leaf failures; five temporary overlay variants yield 18 expected failing leaf cases. Extreme-denominator arithmetic tested only as bounded pure calculation, never HTTP. Real PostgreSQL covers safe money boundaries and calculation-error rollback. Five actual mobile-builder tests pass with --no-pub; this does not resolve locked acquisition. Keep in-progress; no CHANGELOG migration.

### [BUG-1793644499] Inject the frozen exchange-rate provider at startup
- [ ] **Severity:** high
- **Area:** backend, currency
- **File(s):** backend/cmd/bill-service/main.go; backend/internal/bill/service.go; backend/internal/exchange/client.go; backend/internal/bill/service_test.go
- **Observation:** main constructs NewBillService(repo) without its optional provider; non-USD lookup fails before persistence.
- **Expected:**
  - Actual application construction supplies the required frozen-rate provider for supported non-USD currencies.
  - A construction-level test with a fake provider exercises EUR quote and bill creation; USD keeps identity rate.
  - Provider failure yields a recoverable response with no incorrect bill persisted; date/source remain immutable.
- **Req:** SR currency composition; SR P1 provider; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Trace main.go:31 to GetUSDExchangeRate nil provider; the review temporary composition repro returned 503 for EUR. Do not require live provider access to prove wiring.
- **Bump:** patch
- **Status:** open

### [BUG-1793644500] Persist one currency-correct bill through save retries
- [ ] **Severity:** high
- **Area:** mobile, persistence
- **File(s):** mobile/lib/screens/quick_split/bill_summary/widgets/bottom_bar.dart; mobile/lib/screens/recent_bills/models/recent_bill_manager.dart; mobile/lib/database/database.dart; mobile/test/unit/database/currency_storage_test.dart
- **Observation:** Done first saves without currency (USD default), then again after upload with authoritative currency. Duplicate check distinguishes currencies; failure can claim nothing saved after a row exists.
- **Expected:**
  - One stable local record keeps original currency/amounts across Done, share, retry, restart and tab attachment.
  - Quote pending/verified/failure state and UI messages agree with durable persistence.
  - Failed or repeated uploads remain retryable without duplicate remote/local receipt or wrong-USD upload.
  - Flow-level Drift tests reproduce EUR double-write and failure sequencing through the real orchestration seam.
- **Req:** TR engineering 3; TR fixes 5,11,19; SR save operation; docs/reviews/2026-11-02-baseline.md
- **Depends on:** BUG-1793644499
- **Repro / Notes:** Trace bottom_bar initial/second save and Drift duplicate rule. Review reproduced USD+EUR rows. Extract one save operation with bounded UI changes rather than cosmetic file splitting.
- **Bump:** patch
- **Status:** open

### [BUG-1793644501] Require the complete revision gate before publication
- [ ] **Severity:** high
- **Area:** ci, delivery
- **File(s):** .github/workflows/{ci,deploy-backend,sync-web-viewer,testflight,app-store-release}.yml; .github/actions/build-signed-ipa/action.yml
- **Observation:** CI 40807658877 has failed backend/web security steps while backend 40807658842 and web sync 40807658799 succeeded for baseline SHA.
- **Expected:**
  - Failed applicable tests or scans prevent backend and web production publication for that exact revision.
  - TestFlight/App Store publication uses all relevant checks with no untested rebuild masquerading as checked.
  - Render/Vercel automatic deployment settings are inspected and gated or recorded BLOCKED; config alone is insufficient.
  - Negative gate-path tests and exact-SHA health proof are reviewable; no deployment is triggered by this fix task.
- **Req:** TR engineering 4; TR fix 3; SR GATE/SCAN/RELEASE; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Read the three linked Actions runs and gate configs. Preserve exact-commit health validation. Scope exception: one release-gate contract spans existing publishers; separate deployables do not justify independent bypasses.
- **Bump:** patch
- **Status:** open

### [BUG-1793644502] Resolve the three current Next.js security alerts
- [ ] **Severity:** high
- **Area:** web, dependencies
- **File(s):** web-bill-viewer/package.json; web-bill-viewer/package-lock.json; web-bill-viewer/README.md; docs/reviews/2026-11-02-web-dependency-maintenance.md
- **Observation:** Next resolves 16.4.0. Open alerts #67 (GHSA-2464-fhr4-w9xw), #68 (GHSA-p3m5-59mp-jv5r), #69 (GHSA-673q-mjm6-r5xr) affect the same lockfile.
- **Expected:**
  - Choose a current patched stable resolution after checking each maintainer advisory and current primary docs.
  - npm audit --audit-level=moderate and npm run build succeed; lint and all web tests pass.
  - All three alerts are individually resolved in GitHub after integration; do not import old screenshot-branch dependencies.
- **Req:** TR engineering 5; TR fix 4; SR three Dependabot alerts; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Alerts: https://github.com/LLRHook/checksinmyhead/security/dependabot/67 , /68 , /69. Patched 16.4.1 was reported at inspection; recheck at implementation. Exploitability in live deployment was not tested.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Pin Next 16.4.4 and raise sharp override floor to ^0.35.5; update only matching Next/env/SWC lock entries, retaining sharp 0.35.5 and React/ReactDOM 19.3.0. npm ci, lint, 52 tests, production build and full npm audit pass with zero findings, versus three advisory records before. Full gate remains RED due existing Flutter lock drift and retained-image findings; external alerts and deployed identity are unverified before integration.
- **Docs:** web-bill-viewer/README.md; docs/reviews/2026-11-02-web-dependency-maintenance.md. Existing matrix CLI interfaces unchanged; no API/UI/schema/financial contract or historical record changed.
- **Log:**
  - 2026-11-02 Approval: Driver-approved DEPENDENCY_PHASE_APPROVAL.md at f1d62374 permits exact stable Next patch and sharp security floor. Official stable registry, engine/peer API documentation, maintainer advisories and sharp release reverified November 2. Next 16.4.4; sharp already resolves 0.35.5. React and unrelated locks retained. November 3 announced security release requires a fresh check before integration/release.
  - 2026-11-02 Validation: Web-specific acceptance commands all pass. In-progress retained for complete driver acceptance: enforced Flutter lock acquisition fails twice and companion Docker scans report unresolved package/policy findings. No missing scanner, production deployment, external alert closure or full runtime protocol is counted as a pass. Driver owns clean independent validation and integration.
  - 2026-11-02 Follow-up: Approved RUNTIME_LOCK_APPROVAL.md follow-ups: BUG-1793652308 owns four-entry Flutter lock reproducibility; BUG-1793652309 owns supported minimal/nonroot runtime and same-binary probe. Original dependency evidence remains a dated record. No Go advisory is reclassified as OpenSSL.

### [BUG-1793644503] Patch the Go build toolchain for GO-2026-6809
- [ ] **Severity:** high
- **Area:** backend, dependencies
- **File(s):** backend/go.mod; backend/services/bill-service/Dockerfile; backend/services/web-service/Dockerfile; backend/.dockerignore; backend/README.md; docs/reviews/2026-11-02-go-dependency-maintenance.md
- **Observation:** Module and builder images align on Go 1.27.2, which the review scan reports affected by GO-2026-6809.
- **Expected:**
  - Current official Go security guidance determines the patched module/toolchain and builder pins.
  - go build ./..., go vet ./..., go test -race ./..., and the pinned govulncheck command succeed.
  - Release evidence identifies the built binary toolchain and source revision.
- **Req:** TR engineering 5; TR fix 4; SR toolchain; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** https://pkg.go.dev/vuln/GO-2026-6809 ; patch 1.27.3 was identified by review, not a claim of live interception. The old version-alignment chore is shipped; this is the remaining security patch.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Module and both digest-pinned builders select Go 1.27.3 with GOTOOLCHAIN=local; retained Debian 12 runtime is digest-pinned; minimal context exclusions verified using Docker. Build/vet/format, 272 Go leaf cases, 147 tab integration leaf cases (11 PostgreSQL-specific), both linux/amd64 Docker builds and zero-reachable govulncheck pass. Full acceptance remains RED: enforced Flutter lock acquisition fails and Trivy reports retained-image/package findings; no unconditional security/deployment claim.
- **Docs:** backend/README.md; docs/reviews/2026-11-02-go-dependency-maintenance.md. No API/schema changes; dated historical records, VERIFICATION.md and publication workflows unchanged.
- **Log:**
  - 2026-11-02 Approval: Driver-approved DEPENDENCY_PHASE_APPROVAL.md at f1d62374 permits Go 1.27.3, aligned digest-pinned builders/runtime base, minimal context exclusions and full local compatibility/security checks. Official go.dev feed, advisory and registry identities reverified November 2. No application-module, API, schema, runtime distribution or publication changes.
  - 2026-11-02 Validation: Local implementation evidence recorded. In-progress retained: locked Flutter acquisition fails twice for four SDK-required entries; both retained images have root/no-healthcheck policy findings plus 1 HIGH/22 MEDIUM/14 LOW/7 UNKNOWN package findings each. Driver proposal: separate four-entry Flutter lock alignment and verified Debian 12 package/non-root follow-up. Independent review, hosting identities and full protocol remain pending; no new finding waived or source/publication gate closed.
  - 2026-11-02 Follow-up: Approved RUNTIME_LOCK_APPROVAL.md follow-ups: BUG-1793652308 owns Flutter lock reproducibility; BUG-1793652309 owns Debian13 base-nossl/nonroot/probe repair, superseding the earlier Debian12 hold after verified deprecation. GO-2026-6809 remains the distinct Go standard-library advisory. See docs/reviews/2026-11-02-go-dependency-maintenance.md and DEPENDENCY_REVIEW.md.

### [BUG-1793644504] Finalize tabs within one retry-safe transaction
- [ ] **Severity:** high
- **Area:** backend, persistence
- **File(s):** backend/internal/tab/{service,repository}.go; backend/pkg/models/tab_settlement.go; backend/internal/tab/{service,repository}_test.go
- **Observation:** FinalizeTab reads tab, creates settlements and marks finalized in separate operations. Competing assignment mutations check state outside the common boundary.
- **Expected:**
  - Lock/read, settlement snapshot creation and finalized state commit or roll back together on PostgreSQL.
  - Concurrent/retried finalize returns the same snapshot with no duplicate settlement rows.
  - Assignment, attachment and competing writes check finalized state inside the transaction.
  - PostgreSQL failure injection and finalize/edit race tests preserve original bills, links and totals.
- **Req:** TR engineering 6; TR fix 7; SR atomic finalization; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Read FinalizeTab, CreateSettlements and Finalize. Structural risk is confirmed; review did not induce production concurrency failures.
- **Bump:** patch
- **Status:** open

### [BUG-1793644505] Authorize accounting by stable participant identity
- [ ] **Severity:** high
- **Area:** backend, mobile, web
- **File(s):** backend/internal/tab/{handler,service,repository}.go; backend/pkg/models/{bill,tab_member}.go; mobile/lib/models/person.dart; web-bill-viewer/src/lib/api.ts
- **Observation:** Paid-share authorization compares chosen member display name with share name; aggregation folds names case-insensitively and join permits collisions.
- **Expected:**
  - Two people named Alex retain separate ownership and debts; choosing another name cannot gain paid-state authority.
  - Persist stable references for assignments/shares and resolve legacy data through an explicit expand/migrate/compatibility plan.
  - Old bearer links and clients remain supported or have a reviewed migration; names remain editable display values.
  - Negative impersonation and duplicate-name tests cover reads, edits, balances, paid state and finalization.
- **Req:** TR engineering 7; TR fix 10; SR identity; docs/reviews/2026-11-02-baseline.md
- **Depends on:** FEAT-1793644505
- **Repro / Notes:** Read JoinTab, AddMember, UpdateBillPersonSharePaid and ComputeNetBalances. Shared contract exception: identity migration must cover producer/client compatibility in one root ticket; split implementation by migration phase if needed.
- **Bump:** patch
- **Status:** open

### [BUG-1793644506] Label local bill and tab removal accurately
- [ ] **Severity:** med
- **Area:** mobile, ux
- **File(s):** mobile/lib/screens/tabs/tab_manager.dart; mobile/lib/screens/tabs/tab_detail_screen.dart; mobile/lib/screens/tabs/tabs_screen.dart
- **Observation:** Local Drift removal/delete UI implies shared deletion although API has no detach/delete route.
- **Expected:**
  - Local-only actions explicitly say Remove from this device and explain retained online/shared totals.
  - Refresh/restart/two-device checks agree with the documented local-only behavior; destructive creator actions use authorized server behavior when provided.
- **Req:** TR engineering 8; TR fixes 8,11; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Trace removeBillFromTab/deleteTab and confirmation strings, then inspect registered API routes. Shared lifecycle is separate; do not falsely announce online deletion.
- **Bump:** patch
- **Status:** open

### [BUG-1793644507] Bound public API request resources
- [ ] **Severity:** med
- **Area:** backend, security
- **File(s):** backend/cmd/bill-service/main.go; backend/internal/{bill,tab,receipt}/handler.go
- **Observation:** Creation routes have no explicit JSON body/collection budgets or application rate limit; server uses http.ListenAndServe without deadlines.
- **Expected:**
  - Creation body/collection limits, finite input checks, and server deadlines are enforced with explicit errors.
  - Trusted proxy configuration is verified so client-IP quotas cannot be bypassed by caller headers.
  - Slow/oversized/malformed and creation-burst tests stay within approved limits and preserve normal traffic.
- **Req:** TR engineering 9; TR fix 12; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Read API startup, CreateBill/CreateTab and receipt limiter. External host controls are unverified; establish limits from real payload needs, without banning valid discounts.
- **Bump:** patch
- **Status:** open

### [BUG-1793644508] Bound receipt inference spending and limiter memory
- [ ] **Severity:** med
- **Area:** backend, security
- **File(s):** backend/internal/receipt/{handler,service}.go; backend/cmd/bill-service/main.go
- **Observation:** Receipt quotas are process-local; inactive IP keys never expire and no global OCR concurrency/daily-spend cap is defined in source.
- **Expected:**
  - Expired limiter keys are pruned; global concurrency/spend limits have bounded memory and documented multi-process semantics.
  - Quota/provider failure returns recoverable errors with no hidden paid retry loop.
  - Clock-controlled expiration/burst/concurrency tests prove caps; hosting/provider budgets are confirmed or explicitly blocked.
- **Req:** TR engineering 9; TR fix 12; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Read receipt limiter map and provider request path. No claim is made about current provider-account budgets; choose numeric limits in the implementation plan.
- **Bump:** patch
- **Status:** open

### [BUG-1793644509] Redact credentials and payment data from SQL logs
- [x] **Severity:** med
- **Area:** backend, privacy
- **File(s):** backend/pkg/database/logger.go; backend/pkg/database/logger_test.go; backend/pkg/database/postgres.go; backend/pkg/safehttp/logging.go; backend/pkg/safehttp/logging_test.go
- **Observation:** Slow/error GORM logger emits interpolated SQL values; routine query-free HTTP logging does not remove that risk.
- **Expected:**
  - Error and slow SQL paths expose no bearer tokens or payment handles; useful operation/timing context remains.
  - Tests exercise failures and slow queries with synthetic sensitive values and prove logs redact them.
- **Req:** TR engineering 9; TR fix 12; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Read logger Trace around lines 68-99. Existing HTTP-query sanitization is already shipped and must be preserved.
- **Bump:** patch
- **Status:** fixed-pending-migration
- **Fix:** Suppress SQL text, bind values and arbitrary GORM messages; emit exact allowlisted operation/table/error/SQLSTATE metadata. Sanitize shared InitDB errors, preserve static missing-env guard, and reject slow-threshold overflow without echoing config. Race tests and six control-removal experiments verify leakage controls; auth and health CLI regressions preserved.
- **Docs:** backend/README.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-02-sql-log-secrecy.md
- **Log:**
  - 2026-11-02 Verification: Scoped logging gate: default Go 116 top-level/356 leaf cases; tagged tab PostgreSQL 52 top-level/157 leaf (overlaps default), zero failures/skips. All six overlay control removals fail executed assertions. Gitleaks/Semgrep/gosec zero candidates. Migration/readiness FEAT-1793644505 and overall security/integrated acceptance remain incomplete/RED.

### [BUG-1793644510] Reconcile public privacy disclosures with released behavior
- [ ] **Severity:** high
- **Area:** product, privacy
- **File(s):** docs/privacy.md; mobile/lib/screens/settings/settings_screen.dart; external App Store privacy label and marketing policy
- **Observation:** Review observed Data Not Collected in the public label while server-shared bills, payment handles, logs and receipt-provider processing exist.
- **Expected:**
  - Inventory the actual released binary and retained/shared/provider data against current Apple categories/purposes/linkage guidance.
  - Prepare consistent store label, policy, in-app text and support contact; verify selected public destinations.
  - Record external account/access limitations and owner decisions; do not claim publication or legal compliance without evidence.
- **Req:** TR privacy; TR fix 6; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Review source flows and https://apps.apple.com/us/app/billington/id6746379502 plus https://getbillington.vercel.app/privacy-policy. Recheck current public observations; provider retention and production configuration need owner evidence.
- **Bump:** patch
- **Status:** open

### [BUG-1793644511] Gate minimum app versions on public store availability
- [ ] **Severity:** high
- **Area:** product, release
- **File(s):** backend/internal/versionpolicy/handler.go; mobile/lib/services/version_policy_service.dart; external App Store Connect/storefront records
- **Observation:** Review saw minimum 2.0.3 while US listing showed 1.4.0; not all old clients implement the gate.
- **Expected:**
  - Each targeted storefront/supported OS offers a binary satisfying the policy before enforcement increases.
  - Actual installed public binary exercises live API, invite and payment compatibility; record version/build/storefront.
  - Policy outages fail open as designed; changing policy is not a server authorization fix.
- **Req:** TR release availability; TR fix 9; SR compatibility; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Read current policy endpoint/source and public listing. TestFlight success does not prove public distribution; private availability remains unverified.
- **Bump:** patch
- **Status:** open

### [BUG-1793644512] Reconcile stale operational and product documentation
- [ ] **Severity:** med
- **Area:** docs
- **File(s):** README.md; backend/{README.md,roadmap.md}; docs/{technical-overview,backend-api,market-analysis}.md
- **Observation:** README still advertises removed /privacy; legacy roadmap presents Railway future deployment; market analysis has obsolete cost/local-only assumptions.
- **Expected:**
  - Correct stale privacy destination, current runtime/Compose inventory and abandoned Railway instructions with history links.
  - Authoritative architecture/API references match supported standalone/legacy tab behavior, currencies and lifecycle limitations.
  - Historical plans are labeled and linked; current operating instructions reference verified owners/commands instead of copied architecture.
  - Universal/deferred invite claims match signed-build capabilities; verify the intended marketing privacy destination.
- **Req:** TR marketing planning; SR documentation/privacy/history; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Revalidate PR #149 intentional privacy removal before restoring a route. This lead files pre-existing drift; later scoped implementation fixes it. tasks/todo history is reconciled separately.
- **Bump:** patch
- **Status:** open

### [BUG-1793644513] Preserve the database during ordinary local shutdown
- [ ] **Severity:** med
- **Area:** tooling
- **File(s):** backend/Makefile; dev.sh; backend/docker-compose.yml
- **Observation:** Makefile down is labeled Stop services but executes docker-compose down -v, deleting postgres_data.
- **Expected:**
  - Ordinary stop/down preserves existing volume and survives restart with a synthetic sentinel.
  - Destructive reset is a separate explicit operation restricted to confirmed isolated test data.
  - Documented stop/start commands agree with scripts; no existing developer data is reset.
- **Req:** SR local database operations; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Read Makefile down vs dev.sh cleanup. Verify lifecycle using a separately named Compose project, never the current developer volume.
- **Bump:** patch
- **Status:** open

### [BUG-1793644514] Make local dependency startup reproducible
- [ ] **Severity:** med
- **Area:** tooling
- **File(s):** dev.sh; README.md; web-bill-viewer/package-lock.json
- **Observation:** dev.sh runs npm install --silent with stderr discarded on every startup, hiding errors and mutating resolution.
- **Expected:**
  - Use locked npm ci in explicit setup; normal startup avoids unnecessary installs and exposes failures.
  - Prerequisite/runtime errors identify the failed stage; docs and CI use compatible package/toolchain commands.
  - Shell/static checks plus isolated success/failure startup smoke prove behavior without touching existing DB.
- **Req:** SR local startup; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Read dev.sh npm install and pod install stderr suppression. No new package is necessary.
- **Bump:** patch
- **Status:** open

### [BUG-1793644515] Separate frozen quotes from display conversion contracts
- [ ] **Severity:** med
- **Area:** backend, currency
- **File(s):** backend/internal/bill/{handler,service}.go; backend/internal/{exchange/client,currency/service}.go; backend/cmd/bill-service/main.go
- **Observation:** Two rate APIs have different contracts; main constructs display service twice, currencies differ (PEN absent from frozen set), and quote provenance fields are reused.
- **Expected:**
  - One approved support matrix names original currency, immutable USD valuation, temporary display conversion and failure semantics.
  - Historical original amounts and dated source/rate provenance cannot be overwritten by display conversion.
  - Reuse identical service/cache instances; retain distinct adapters where contracts differ.
  - Tests cover supported non-USD, same currency, ambiguous/PEN policy, outage/cache and historical immutability.
- **Req:** SR currency contracts; TR financial correctness; docs/reviews/2026-11-02-baseline.md
- **Depends on:** BUG-1793644499
- **Repro / Notes:** Read exchange.LatestUSD vs currency.GetRate, supportedCurrencyCodes and CreateBill metadata. PEN behavior needs explicit reconciliation; do not silently expand currencies or replace providers.
- **Bump:** patch
- **Status:** open

### [BUG-1793644516] Correct App Store branding and unsupported feature copy
- [ ] **Severity:** med
- **Area:** product, marketing
- **File(s):** external App Store metadata; docs/app-review-notes.md
- **Observation:** Expanded public description used Spliq twice and underexplained supported scan/share/claim behavior.
- **Expected:**
  - Prepared title/subtitle/description use Billington and reflect the actually released workflow and payment limitations.
  - Field lengths, availability and private keyword strategy are verified where accessible; unavailable conversion data remains ungraded.
- **Req:** TR store copy; TR fix 13; docs/reviews/2026-11-02-baseline.md
- **Depends on:** BUG-1793644511
- **Repro / Notes:** Review public US listing; recheck actual copy and released behavior before submitting changes. Source metadata alone does not update the public store.
- **Bump:** patch
- **Status:** open

### [BUG-1793644517] Correct marketing download and payment claims
- [ ] **Severity:** med
- **Area:** product, marketing
- **File(s):** external getbillington.vercel.app source (not present in this repository)
- **Observation:** Primary download goes to #download with a second click; splash hero provides little result proof; payment one-tap claims require per-client verification.
- **Expected:**
  - Primary consumer action reaches the App Store in one click and the hero shows a supported completed split or claim result.
  - Payment copy distinguishes deep links/details from processing or confirming transfers; check each named service.
  - Mobile/desktop keyboard navigation and outbound destination checks pass.
- **Req:** TR website; TR fix 15; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Revalidate https://getbillington.vercel.app/ before editing its separately owned source; source location/access is currently unverified. No new repository is authorized by this ticket alone.
- **Bump:** patch
- **Status:** open

### [BUG-1793644518] Exclude private bearer-link pages from indexing
- [ ] **Severity:** med
- **Area:** web, privacy
- **File(s):** web-bill-viewer/src/app/{layout.tsx,b/[id]/page.tsx,t/[id]/page.tsx}; web-bill-viewer/next.config.ts
- **Observation:** Private viewer metadata includes bill/tab names with no explicit noindex; caching/referrer behavior needs validation.
- **Expected:**
  - Bill/tab pages carry appropriate noindex/nofollow directives without publishing tokens or names into acquisition metadata.
  - Inspect caching, browser referrer and social-preview behavior with synthetic bearer links; preserve authorized access and token redaction.
  - Route-level tests prove directives on valid, invalid and missing-token pages.
- **Req:** TR SEO private links; TR fix 16; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Read generateMetadata and layout metadata at baseline; tokens remain authorization credentials. Defense in depth does not replace ownership fixes.
- **Bump:** patch
- **Status:** open

### [BUG-1793644519] Harden existing GitHub workflow execution settings
- [ ] **Severity:** med
- **Area:** ci, security
- **File(s):** .github/workflows/*.yml; .github/actions/build-signed-ipa/action.yml
- **Observation:** Validator reported 16 mutable action-pin errors plus web-sync permissions gap; sync disables strict SSH checking; timeouts/concurrency incomplete.
- **Expected:**
  - Pin reviewed actions by full SHA and declare least permissions; verify SSH host identity if mirror remains.
  - Apply bounded job timeouts and cancel superseded validation while serializing deployments/uploads safely.
  - Re-run the CI validator and verify diffs do not trigger or weaken publication.
- **Req:** SR PIN/GH1; SR TIME/concurrency; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Review mechanical 17 errors/9 warnings as grouped config findings, not 17 product vulnerabilities. Mirror retirement may remove its SSH path.
- **Bump:** patch
- **Status:** open

### [BUG-1793652308] Make the Flutter 3.41.5 committed lock reproducible
- [ ] **Severity:** med
- **Area:** mobile, dependencies
- **File(s):** mobile/pubspec.lock; mobile/README.md
- **Observation:** At f9f8fb86, Flutter 3.41.5 enforced acquisition exits 65: characters, matcher, material_color_utilities and test_api differ from the committed lock. Existing dependency evidence records the same failure twice.
- **Expected:**
  - Exactly the four SDK-controlled entries resolve to characters 1.4.1, matcher 0.12.19, material_color_utilities 0.13.0 and test_api 0.7.10 with pub-generated checksums.
  - Pinned Flutter enforced acquisition, analysis and actual tests pass without unrelated lock, manifest, application, SDK or CocoaPods drift. Driver independently validates a clean committed snapshot.
- **Req:** RUNTIME_LOCK_APPROVAL.md deliverable 1; DEPENDENCY_REVIEW.md; docs/reviews/2026-11-02-go-dependency-maintenance.md; docs/reviews/2026-11-02-web-dependency-maintenance.md
- **Depends on:** none; follow-up evidence from BUG-1793644502 and BUG-1793644503
- **Repro / Notes:** cd mobile && flutter pub get --enforce-lockfile under Flutter 3.41.5. Baseline .vv/local-gate/dependencies/flutter-pub{,-retry}.log reports Would change 4 dependencies, exit 65. CI enforcement belongs to BUG-1793644501.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Regenerate exactly four SDK-controlled records/checksums with Flutter 3.41.5 pub: characters 1.4.1, matcher 0.12.19, material_color_utilities 0.13.0, test_api 0.7.10. Enforced acquisition and analysis exit 0; 203 visible Flutter tests plus 21 hidden suite loads pass, zero failed/skipped. All other lock bytes, manifest, mobile source, generated databases, CocoaPods and workflow pins preserved. Lead scope=affected clean=no; retain in-progress for driver clean committed-snapshot acceptance and separate global/security gates.
- **Docs:** mobile/README.md; docs/reviews/2026-11-02-flutter-lock-reproducibility.md. Existing dated dependency evidence preserved; follows BUG-1793644502/4503. CI enforcement remains workflow-phase work.
- **Log:**
  - 2026-11-02 Validation: Official writer dry-run preview shown before apply; RUNTIME_LOCK_APPROVAL.md deliverable 1 authorizes this narrow correction. Official pinned Flutter manifests and pub enforcement docs verified before pub generated the resolution. Raw reports: .vv/local-gate/runtime-lock/. No clean-checkout claim or CHANGELOG migration.

### [BUG-1793652309] Use supported nonroot minimal service images with bounded local probes
- [ ] **Severity:** high
- **Area:** backend, security, containers
- **File(s):** backend/services/{bill-service,web-service}/Dockerfile; backend/cmd/{bill-service,web-service}/main.go; backend/internal/healthcheck; backend/README.md
- **Observation:** Both f9f8fb86 runtime stages use deprecated base-debian12 as root without HEALTHCHECK. Retained images each contain libssl3 CVE-2026-84782 HIGH plus other disclosed findings; policy scans report DS-0002 HIGH and DS-0026 LOW.
- **Expected:**
  - Both linux/amd64 targets use verified supported base-nossl-debian13:nonroot at an exact index digest and explicit USER 65532:65532, preserving Go 1.27.3 CGO/libc, CA/tzdata/tmp and legacy templates.
  - A shared same-binary --healthcheck runs before DB initialization, makes one bounded loopback request, rejects redirects/bad status/JSON/oversize/timeouts and logs no response content or credentials; Docker uses exec form with no helpers.
  - Actual nonroot API create/read and authorized legacy HTML pass with unique synthetic PostgreSQL data; DNS, trusted database TLS, public CA, timezone, read-only filesystem/tmp, identities/bytes/packages and unsuppressed scans are recorded. No HIGH/CRITICAL finding is silently retained.
- **Req:** RUNTIME_LOCK_APPROVAL.md deliverables 2-3; DEPENDENCY_REVIEW.md; docs/reviews/2026-11-02-go-dependency-maintenance.md
- **Depends on:** none; follow-up evidence from BUG-1793644503 (GO-2026-6809 is a distinct Go advisory)
- **Repro / Notes:** Baseline .vv/local-gate/dependencies/trivy-config.json and trivy-image-{bill,web}.json: each image 1 HIGH / 22 MEDIUM / 14 LOW / 7 UNKNOWN, root HIGH, missing healthcheck LOW. Current Distroless support policy deprecates Debian12; approval explicitly supersedes prior distribution hold. Probe remains liveness; migration owns DB readiness.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Pin both supported base-nossl-debian13:nonroot runtimes to verified signed index e6b0f82595aa1edde72c8054de7a9dca30f0f8f54820c37a167c0ddfc21c5c67; preserve Go 1.27.3 CGO/libc and root-owned application/templates, execute as 65532:65532. Shared bounded same-binary --healthcheck runs before DB setup, with exec-form Docker probes and no helper packages. Go full race 333 leaf, PostgreSQL 157 leaf and final expanded health 27 leaf cases pass with zero failures/skips; seven control removals fail as expected. Both final linux/amd64 builds and 20 nonroot TLS/DNS/CA/timezone/filesystem/API/HTML journey checks pass. Trivy final Dockerfiles 27 successes/0 failures each; no libssl or HIGH/CRITICAL packages. Each image still has 14 MEDIUM/8 LOW/3 UNKNOWN; unsuppressed image scans exit 1. Global/security gates remain RED/FAIL and clean driver acceptance pending; keep in-progress.
- **Docs:** backend/README.md; docs/technical-overview.md; docs/reviews/2026-11-02-runtime-lock-images.md. Dated dependency evidence and baseline preserved. Health remains liveness; later migration owns stronger DB readiness. Exact identities, before/after bytes/packages, signature, scanner/revert/journey evidence and diagnostic corrections recorded.
- **Log:**
  - 2026-11-02 Validation: RUNTIME_LOCK_APPROVAL.md deliverables 2-3 explicitly supersede the Debian12 hold using current official deprecation/support docs. Runtime digest and amd64/arm64 manifests reverified before build; Cosign3.1.4 keyless verification exit0 with exact official issuer/identity and transparency-log proof. No CGO, framework, provider, schema, auth, cloud or publication change. Own TLS fixture resources/certificates fully cleaned; shared PG17.11 fixture retained. Lead scope=affected clean=no. Raw .vv/local-gate/runtime-lock/ records retain initial diagnostic failures, control experiments and final passing journeys; package findings and preexisting BUG-1793644507 remain unwaived.
