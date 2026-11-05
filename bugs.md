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
- **Fix:** Auth/client evidence: docs/reviews/2026-11-03-client-validation-correction.md. Driver Flutter237 pass; re-review/public bridge/integrated gates pending.
- **Docs:** docs/backend-api.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-02-authorization-batch.md; docs/reviews/2026-11-02-authorization-corrections.md; docs/reviews/2026-11-03-client-v1-bridge.md; docs/reviews/2026-11-03-client-validation-correction.md
- **Log:**
  - 2026-11-02 Validation: Driver-approved AUTH_CORRECTION_APPROVAL.md findings 1-3 implemented in 28eab76. Six safe before leaf failures; five temporary overlay variants yield 18 expected failing leaf cases. Extreme-denominator arithmetic tested only as bounded pure calculation, never HTTP. Real PostgreSQL covers safe money boundaries and calculation-error rollback. Five actual mobile-builder tests pass with --no-pub; this does not resolve locked acquisition. Keep in-progress; no CHANGELOG migration.
  - 2026-11-03 Validation: 43772a7 client slice: real widget/provider upload plus 30/31-rune entry/builder and validation checks; 228 Flutter/54 web pass, zero skips. See docs/reviews/2026-11-03-client-v1-bridge.md; broader acceptance unchanged.

### [BUG-1793644499] Inject the frozen exchange-rate provider at startup
- [x] **Severity:** high
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
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Required shared Frankfurter pair provider is injected at actual API/legacy construction (ee125d1). Twelve receipt currencies, independent display, native USD identity, failure/no-write and immutable quote controls pass. Protocol review approves Standards0/Spec0; root hash-bound Go519/PG600 (751 distinct) plus final14 currency regressions pass. Source accepted pending integrated migration; no hosted/provider/public-binary claim.
- **Docs:** backend/README.md; docs/backend-api.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-03-currency-provider-phase1.md; docs/reviews/2026-11-04-foundation-checkpoint.md
- **Log:**
  - 2026-11-03 Verification: Actual-construction before: EUR503/no write; USD and injected EUR201 controls. After: Go511/PG586 passing leaves, overlap360/union737, zero skips/missing roots; affected gate retains one CLI timing flake. See phase evidence.

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
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** 11e6f67 fixes durable overlapping tab intent and per-row history/read feedback;7bddfa9 makes diagnostics finite. Root clean7bddfa9: Flutter467/510, prior458/500 retained and495 sources unchanged;3 scoped guard removals discriminate. PG/Drift recovery proof retained. Native app setup RED/0 cases; .005 alignment, independent review and combined/release gates remain open.
- **Docs:** docs/mobile-save-verification.md; docs/reviews/2026-11-04-mobile-save-reopen.md; docs/reviews/2026-11-04-mobile-save-corrections.md; docs/backend-api.md; docs/technical-overview.md; VERIFICATION.md
- **Log:**
  - 2026-11-03 Evidence: Driver fb6b4b9 actual provider penny capture: client Alex=.01/Sam=0; v1 server Alex=0/Sam=.01 with .005 raw details. No math change in 43772a7. Preserve server/historical contracts; deliberately align local/published allocation in currency/save scope. See docs/reviews/2026-11-03-client-v1-bridge.md.

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
- **File(s):** web-bill-viewer/{package.json,package-lock.json,README.md}; docs/reviews/2026-11-04-next1645-security-patch.md
- **Observation:** Baseline Next16.4.0 had alerts67–69 (GHSA-2464-fhr4-w9xw,GHSA-p3m5-59mp-jv5r,GHSA-673q-mjm6-r5xr). Maintained source now pins16.4.5; local affected checks pass. External alert closure and deployed version remain unverified.
- **Expected:**
  - Choose a current patched stable resolution after checking each maintainer advisory and current primary docs.
  - npm audit --audit-level=moderate and npm run build succeed; lint and all web tests pass.
  - All three alerts are individually resolved in GitHub after integration; do not import old screenshot-branch dependencies.
- **Req:** TR engineering 5; TR fix 4; SR three Dependabot alerts; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Historical alerts: https://github.com/LLRHook/checksinmyhead/security/dependabot/67 and IDs68/69. Follow current primary advisories before integration/release. No deployed exploitability result.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** e4af0a7 pins Next16.4.5 with11 root/Next/env/SWC lock entries; React/DOM19.3.0,sharp0.35.5 and overrides retained. Lead and independent root clean Node24.22.2/npm11.19.1 acquisition,lint,54tests (0skip),build,audit pass; audit0. Root Standards0/Spec0. Keep in-progress for alert/deployed closure.
- **Docs:** web-bill-viewer/README.md; docs/reviews/2026-11-04-next1645-security-patch.md. Historical November2 dependency evidence is preserved.
- **Log:**
  - 2026-11-04 Validation: Primary-source discrepancies and npm/Vite warnings retained in dated evidence. Prior Flutter/runtime follow-ups belong to BUG-1793652308/2309. No hosting mutation, deployment, alert closure or whole security/integrated/release pass claimed.
  - 2026-11-04 Maintenance: Condense inherited oversized tracker through official writer; historical fields remain in Git and dated reports.

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
- **File(s):** backend/internal/{bill,tab}/{handler,service,repository}.go; bill/{accounting,assignments}.go; tab/{commands,settlement}.go; backend/pkg/mutation/; related tests
- **Observation:** FinalizeTab reads tab, creates settlements and marks finalized in separate operations. Competing assignment mutations check state outside the common boundary.
- **Expected:**
  - Lock/read, settlement snapshot creation and finalized state commit or roll back together on PostgreSQL.
  - Concurrent/retried finalize returns the same snapshot with no duplicate settlement rows.
  - Assignment, attachment and competing writes check finalized state inside the transaction.
  - PostgreSQL failure injection and finalize/edit race tests preserve original bills, links and totals.
- **Req:** TR engineering 6; TR fix 7; SR atomic finalization; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Actual pre-fix PostgreSQL HTTP regression failed four assertions (paid 6->5.50, child/time changes, retry 400 and changed result); seven removed-control overlays fail executed assertions. Raw evidence: .vv/local-gate/atomic-lifecycle/. Independent review/driver acceptance pending.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Atomic lifecycle and competing writes implemented; original accounting review approved. Corrected the P2 Unicode ambiguity guard with one EqualFold name projection under existing locks. Twelve HTTP/PG regressions pass after seven expected before failures. Driver fresh af43655:414 default/557 PG leaves,635 distinct,zero failures/skips; build/vet/format/govulncheck and scoped scanners pass; six-query paid budget retained. Independent correction review pending; signed-client/deployment and integrated gates remain.
- **Docs:** docs/backend-api.md; docs/technical-overview.md; backend/README.md; VERIFICATION.md; docs/reviews/2026-11-03-atomic-lifecycle.md; docs/reviews/2026-11-03-unicode-share-ambiguity.md

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
- **File(s):** backend/cmd/{bill-service,web-service}/main.go; backend/pkg/safehttp/; backend/internal/bill/{create_request,assignment_request,handler,assignments}.go; backend/internal/tab/handler.go; backend/internal/receipt/
- **Observation:** A1/fd26598 corrections and backend c3c95cc3 F1/F2/F3 source have scoped APPROVE Standards0/Spec0 (reviewer NOT RUN); root clean1146 passed. Max50k assignment latency, runtime flake and hosted/integrated gates stay RED/open.
- **Expected:**
  - Creation body/collection limits, finite input checks, and server deadlines are enforced with explicit errors.
  - Trusted proxy configuration is verified so client-IP quotas cannot be bypassed by caller headers.
  - Slow/oversized/malformed and creation-burst tests stay within approved limits and preserve normal traffic.
- **Req:** TR engineering 9; TR fix 12; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Dated A1, optimization and correction notes retain before/after inputs, raw hashes, case IDs, controls and measurements. No budget/limit waiver; invalid/capped/saturated requests must reject without waiting for body remainder.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** c3c95cc3 owns receipt DNS/TCP/TLS/final-Flush/idle cleanup and locked quota time; source F1/F2/F3 accepted. Root clean1146 retains predecessor IDs. Runtime RED/flaky: web1.619804s vs<1.5s, despite75/75 completion raw0. Max50k p95=27.033/27.143/27.420ms vs10ms remains RED/unrerun; no waiver.
- **Docs:** backend/README.md; docs/{backend-api,technical-overview,backend-ocr-verification}.md; docs/reviews/2026-11-04-backend-native-acceptance.md; prior native/A1/A2 dated history retained; VERIFICATION.md unchanged.
- **Log:**
  - 2026-11-04 History: A1/A2 dated api-a1, api-a1-review-corrections and ocr-a2-backend notes; docs/reviews/2026-11-04-ocr-native-ownership-integration.md.
  - 2026-11-04 Acceptance: sourcec3c95cc3/evidence554cd4ca F1/F2/F3 APPROVE0/0; reviewer NOT RUN, root clean1146. OCR3600 targets met; runtimeflaky/assignment/global RED. Raw scanner1/0confirmed;207schemas absent/336originals intact.

### [BUG-1793644508] Bound receipt inference spending and limiter memory
- [ ] **Severity:** med
- **Area:** backend, security
- **File(s):** backend/internal/receipt/; mobile/lib/services/receipt*.dart; mobile/lib/screens/quick_split/bill_entry/{models,widgets}/
- **Observation:** Backend F1/F2/F3 and mobile M1 source APPROVE0/0; reviewers NOT RUN. Root Go1146/mobile392. Native863dd handoff24 assertions awaits review. Memory plateau/B/replica spending remain open.
- **Expected:**
  - Expired limiter keys are pruned; global concurrency/spend limits have bounded memory and documented multi-process semantics.
  - Quota/provider failure returns recoverable errors with no hidden paid retry loop.
  - Clock-controlled expiration/burst/concurrency tests prove caps; hosting/provider budgets are confirmed or explicitly blocked.
- **Req:** TR engineering 9; TR fix 12; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Backend before-proof: 8 failures/4 controls; A2a1093Go/75runtime. Mobile original5 failures/1control; M2 immutable-base and final-await removal failures retained. Synthetic loopback only; no paid inference/customer data.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Use paired/budget8 attempt-owned TLS relay and joined teardown; preserve M2/body/state. Host392 retains362+21TLS+9guards; removal controls discriminate. Independent source0/0 accepted; native/resource/B/spending/provider/old-writer/physical/signed/integrated/release remain open.
- **Docs:** mobile/README.md; docs/{backend-api,technical-overview,mobile-ocr-verification}.md; docs/reviews/2026-11-04-{mobile-tls-integration,mobile-tls-acceptance,backend-native-acceptance}.md; prior M2/A2 records; VERIFICATION unchanged.
- **Log:**
  - 2026-11-04 History: M2 clean362/17native/all359prior APPROVE; backend1146/OCR3600: prior M2/A2/native dated records (Docs).
  - 2026-11-04 Acceptance: Mobile7e36 source APPROVE0/0/reviewer NOT RUN; root392 CI commands and retained-report reconciliation pass; raw parser failure/missing source-after receipt retained. See mobile-tls-acceptance.
  - 2026-11-04 Limits: Runtime1.619804>1.5 RED/flaky; assignment JSON RED. At7e36 native Pods blocked;863dd qualification is separate/pending review. FD stable/RSS nonplateau; no global pass or closure.

### [BUG-1793644509] Redact credentials and payment data from SQL logs
- [x] **Severity:** med
- **Area:** backend, privacy
- **File(s):** backend/pkg/database/; backend/internal/bill/handler.go; backend/internal/tab/handler.go; backend/internal/web/handler.go; backend/pkg/safehttp/
- **Observation:** Slow/error GORM logger emits interpolated SQL values; routine query-free HTTP logging does not remove that risk.
- **Expected:**
  - Error and slow SQL paths expose no bearer tokens or payment handles; useful operation/timing context remains.
  - Tests exercise failures and slow queries with synthetic sensitive values and prove logs redact them.
- **Req:** TR engineering 9; TR fix 12; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Read logger Trace around lines 68-99. Existing HTTP-query sanitization is already shipped and must be preserved.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Suppress SQL/bind/driver text with finite operation/table/error/SQLSTATE metadata. Sanitize startup and all 22 request-error sinks without changing typed errors or status decisions. Six logger controls and nine HTTP failure controls prove confidentiality; independent correction review approved with zero findings.
- **Docs:** backend/README.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-02-sql-log-secrecy.md; docs/reviews/2026-11-03-request-log-secrecy.md
- **Log:**
  - 2026-11-02 Verification: Scoped logging gate: default Go 116 top-level/356 leaf cases; tagged tab PostgreSQL 52 top-level/157 leaf (overlaps default), zero failures/skips. All six overlay control removals fail executed assertions. Gitleaks/Semgrep/gosec zero candidates. Migration/readiness FEAT-1793644505 and overall security/integrated acceptance remain incomplete/RED.
  - 2026-11-03 Review: Independent review confirmed existing bill/tab/legacy-web request logs bypassed SQL-log sanitization. Reopened for a finite-metadata correction; nine HTTP confidentiality cases failed before the fix and three not-found controls passed.
  - 2026-11-03 Verification: Driver correction:385 default/413 PostgreSQL leaves pass uncached (481 distinct), zero failures/skips;12 HTTP cases pass, nine before failures; scoped scanners zero. Independent re-review pending; full program RED.

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
- [x] **Severity:** med
- **Area:** tooling
- **File(s):** backend/Makefile; dev.sh; backend/docker-compose.yml
- **Observation:** Pinned13be27b exact make down invoked down -v on an owned real PostgreSQL fixture; its volume and sentinel were lost. Source fix implemented; independent driver acceptance pending.
- **Expected:**
  - Ordinary stop/down preserves existing volume and survives restart with a synthetic sentinel.
  - Destructive reset is a separate explicit operation restricted to confirmed isolated test data.
  - Documented stop/start commands agree with scripts; no existing developer data is reset.
- **Req:** SR local database operations; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Retained executed before-proof and fixed sentinel/restart/reset journey: docs/reviews/2026-11-03-local-workflow.md. Normal project and wrong/unconfirmed ownership reject before deletion; shared driver PG/normal volumes preserved.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Ordinary down preserves volumes; guarded reset deletes only exact confirmed synthetic resources. Independent source review at79a8568 approves the correction with0 Standards/Spec findings; clean55CLI and5realPG assertion groups support driver acceptance. Integrated migration remains pending.
- **Docs:** README.md; backend/README.md; mobile/README.md; web-bill-viewer/README.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-03-local-workflow.md; docs/reviews/2026-11-03-local-workflow-correction.md
- **Log:**
  - 2026-11-03 Review: Driver accepts scoped source correction after REVIEW_CORRECTIONS_REVIEW.md (SHA2562e0560d359b8593541381d0d5e9e99078f48e6b3ddecea14516381e2c63f80c8): all15paths and388input hashes reconciled;5realPGgroups pass. No production/data-recovery or integrated V&V claim.

### [BUG-1793644514] Make local dependency startup reproducible
- [x] **Severity:** med
- **Area:** tooling
- **File(s):** dev.sh; backend/Makefile; scripts/{reset_local_test,test_local_workflow,verify_local_lifecycle}.py; local workflow docs
- **Observation:** Exact13be27b stub runs executed shutdown on missing Flutter before stack startup and discarded npm failure detail while retaining exit42. The original failures and readiness-fixture correction remain recorded.
- **Expected:**
  - Use locked npm ci in explicit setup; normal startup avoids unnecessary installs and exposes failures.
  - Prerequisite/runtime errors identify the failed stage; docs and CI use compatible package/toolchain commands.
  - Shell/static checks plus isolated success/failure startup smoke prove behavior without touching existing DB.
- **Req:** SR local startup; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Before records preserved; lasting stubbed setup/startup/health/signal/descendant/ownership/status tests and isolated real lifecycle: docs/reviews/2026-11-03-local-workflow.md. No real simulator/app mutation or secret-env reads.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Runtime correction at79a8568 and fixture follow-up at85fafc6 are independently approved (Standards0/Spec0 each). Ordinary5s fixture covers a healthy2.1s response; timeout cases retain1s. Driver clean55 CLI tests and five isolated real-PG lifecycle assertion groups pass. Pending integrated migration; full-stack/simulator startup is not claimed.
- **Docs:** README.md; backend/README.md; mobile/README.md; web-bill-viewer/README.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-03-local-workflow.md; docs/reviews/2026-11-03-local-workflow-correction.md; docs/reviews/2026-11-03-workflow-readiness-fixture.md
- **Log:**
  - 2026-11-03 Validation: Lead retained54pass/1readiness timing failure and its passing rerun. Driver controlled2.1s healthy API reproduces quit-test false negative under fixture2s; ordinary fixture5s and explicit1s timeout cases now55pass without retries. Runtime unchanged.

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
- **Depends on:** BUG-1793644499; BUG-1793644500; FEAT-1793644505 (ordered display metadata0002)
- **Repro / Notes:** Read exchange.LatestUSD vs currency.GetRate, supportedCurrencyCodes and CreateBill metadata. PEN behavior needs explicit reconciliation; do not silently expand currencies or replace providers.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Provider/replay frozen/display/zero contracts retained. Mobile final7bddfa9 includes save review corrections; root clean Flutter467/510 preserves prior458/500. Native class20 proof is separate; maintained app setup RED/0 cases. .005 alignment, identity0003, versioned JPY, independent correction review and combined/signed rollout remain open.
- **Docs:** docs/mobile-save-verification.md; docs/reviews/2026-11-04-mobile-save-reopen.md; docs/reviews/2026-11-04-mobile-save-corrections.md; docs/backend-api.md; docs/technical-overview.md; VERIFICATION.md
- **Log:**
  - 2026-11-03 Scope: Approved one-adapter/no-TTL decision supersedes old dual-provider/cache proposal. Keep open: display provenance0002; mobile rate decoder/quote state/save/replay/Keychain; required versioned JPY step. Global security/integrated acceptance RED.

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
- **File(s):** backend/services/{bill-service,web-service}/Dockerfile; backend/cmd/{bill-service,web-service}/main.go; backend/internal/healthcheck; backend/README.md; scripts/verify_static_runtime.py; scripts/runtime-probe/main.go
- **Observation:** Both f9f8fb86 runtime stages use deprecated base-debian12 as root without HEALTHCHECK. Retained images each contain libssl3 CVE-2026-84782 HIGH plus other disclosed findings; policy scans report DS-0002 HIGH and DS-0026 LOW.
- **Expected:**
  - Both linux/amd64 targets use signed supported static-debian13:nonroot at an exact index digest, CGO_ENABLED=0 in production and explicit USER 65532:65532; preserve Go 1.27.3, CA/tzdata/tmp/templates, startup modes and live readiness. November 3 conditional approval supersedes the original CGO/libc retention requirement; race/SQLite test builds keep CGO.
  - A shared same-binary --healthcheck runs before DB initialization, makes one bounded loopback request, rejects redirects/bad status/JSON/oversize/timeouts and logs no response content or credentials; Docker uses exec form with no helpers.
  - Both final ELF/buildinfo prove no dynamic libc need; production graphs have no native/SQLite/OpenPGP dependency. Actual nonroot read-only API/HTML, trusted PG TLS plus trust/hostname rejection, hosts/DNS/search/cancellation, public CA/timezone/tmp, one-query readiness and Docker health outage/recovery pass. Exact saved images are scanned unsuppressed with current DB timestamps; unknown hosting NSS remains a limitation.
- **Req:** RUNTIME_LOCK_APPROVAL.md deliverables 2-3; SECURITY_INVENTORY_APPROVAL.md Static runtime decision (November 3 supersedes retained CGO/libc); DEPENDENCY_REVIEW.md; docs/reviews/2026-11-02-go-dependency-maintenance.md
- **Depends on:** none; follow-up evidence from BUG-1793644503 (GO-2026-6809 is a distinct Go advisory)
- **Repro / Notes:** Baseline .vv/local-gate/dependencies/trivy-config.json and trivy-image-{bill,web}.json: each image 1 HIGH / 22 MEDIUM / 14 LOW / 7 UNKNOWN, root HIGH, missing healthcheck LOW. Current Distroless support policy deprecates Debian12; approval explicitly supersedes prior distribution hold. Probe remains liveness; migration owns DB readiness.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Retain the previously implemented nonroot/root-owned templates and bounded same-binary probes; after conditional proof, set CGO_ENABLED=0 in both production builds and pin signed static-debian13:nonroot index 25ac8f0c3b2334a9eb05452266bd4697864a8c8ef0ef71e5e6480d7f92868329. Final Go1.27.3 linux/amd64 ELF/buildinfo has no PT_INTERP/DT_NEEDED/libc; no libc/libssl package or QA executable in either image. Final 69-check runtime harness passes with no failures/skips and owned resource cleanup; healthy readiness is one query. Exact final Trivy scans exit0 at every severity0; current same-source CGO1 images each retain14MEDIUM/8LOW libc findings. Both final Dockerfiles27 successes/0 failures. Existing G114/BUG-1793644507, hosting NSS/deployment proof and full integrated acceptance remain open; no waiver, closure or global pass. Independent review pending; keep in-progress.
- **Docs:** backend/README.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-03-static-runtime.md. Current static/resolver contract and repeatable local harness documented; dated prior runtime/module notes, frozen baseline and CHANGELOG preserved.
- **Log:**
  - 2026-11-02 Validation: RUNTIME_LOCK_APPROVAL.md deliverables 2-3 explicitly supersede the Debian12 hold using current official deprecation/support docs. Runtime digest and amd64/arm64 manifests reverified before build; Cosign3.1.4 keyless verification exit0 with exact official issuer/identity and transparency-log proof. No CGO, framework, provider, schema, auth, cloud or publication change. Own TLS fixture resources/certificates fully cleaned; shared PG17.11 fixture retained. Lead scope=affected clean=no. Raw .vv/local-gate/runtime-lock/ records retain initial diagnostic failures, control experiments and final passing journeys; package findings and preexisting BUG-1793644507 remain unwaived.
  - 2026-11-03 Validation: November 3 SECURITY_INVENTORY_APPROVAL.md conditional static exception exercised: current supported signed index and unchanged Go security release reverified before final build; exact final images/binaries/scanner archive identities tied together. Local owned PG17.11 TLS/DNS fixtures prove actual production CGO0 behavior, one-query readiness, negative trust/host/authorization/ledger/DB controls and Docker health failure/recovery. Preserve three setup-failed harness iterations plus passing candidate-v4/final; no app source rewrite. Shared driver PG and normal volumes retained. Raw .vv/local-gate/security-inventory/ and dated note contain current counts/sizes/packages/signatures/ELF/commands and remaining limits.

### [BUG-1793714791] Clear unused advisory matches in the required Go module inventory
- [ ] **Severity:** med
- **Area:** backend, dependencies, security
- **File(s):** backend/go.mod; backend/go.sum
- **Observation:** At 95553f7 the required x/net v0.60.0 and x/crypto v0.57.0 match GO-2026-6860, GO-2026-6866 and GO-2026-5932. A fresh November 3 govulncheck JSON run confirms three module-only findings, zero imported-package or reachable-symbol findings. These are inventory findings, not proven application exploitability.
- **Expected:** Resolve x/net v0.62.0 plus its minimum graph delta and approved x/crypto v0.58.1-0.20261009181718-2f1f834330b2 boundary (or a verified containing stable tag). No OpenPGP submodule/replacement or unrelated upgrade. All three module records clear; both production graphs remain OpenPGP-free; actual backend CI and isolated PostgreSQL race selection pass uncached without skipped tests.
- **Req:** SECURITY_INVENTORY_APPROVAL.md Module decision; GO-2026-5932; GO-2026-6860; GO-2026-6866
- **Depends on:** none; GO-2026-6809 toolchain repair remains BUG-1793644503
- **Repro / Notes:** https://vuln.go.dev/ID/GO-2026-5932.json ; https://vuln.go.dev/ID/GO-2026-6860.json ; https://vuln.go.dev/ID/GO-2026-6866.json . Upstream crypto 2f1f834330b2 adds only openpgp/go.mod; this separates unsafe unused OpenPGP, not repaired cryptography. Raw .vv/local-gate/security-inventory/baseline-vuln.log. Fingerprint: required-go-modules-net-html-crypto-openpgp-20261103. No suppression or overall acceptance.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Pin x/net 0.62.0 and the explicitly approved x/crypto v0.58.1-0.20261009181718-2f1f834330b2 boundary; retain only necessary graph floors (sys/text/sync plus graph-only term/tools). Fresh govulncheck clears all three module-only records, imported0/reachable0. CGO1 default385/PG413 uncached leaf cases pass with fail0/skip0 (unique union481); preserve initial invalid-fixture run and scanner setup errors. No OpenPGP module/replacement, application/schema/framework change or global pass. Independent review pending; keep in-progress.
- **Docs:** docs/reviews/2026-11-03-go-module-inventory.md; no living docs quote changed module versions. Historical reviews/baseline and CHANGELOG preserved.
- **Log:**
  - 2026-11-03 Validation: SECURITY_INVENTORY_APPROVAL.md authorizes the exact crypto pseudo-version exception. Current official proxy/tag/commit/manifests/signed sums and Go stable feed reverified before resolution. Raw .vv/local-gate/security-inventory/ preserves actual counts, seven necessary graph version changes, no module additions/removals, fixture correction and all unsuppressed scanner results. Scoped source result only; independent review/integrated acceptance pending.

### [BUG-1793725849] Keep panic recovery logs free of private requests and panic values
- [ ] **Severity:** med
- **Area:** backend, security
- **File(s):** backend/cmd/{bill-service,web-service}/main.go; backend/pkg/safehttp/; Gin recovery middleware
- **Observation:** Pinned13be27b actual middleware chain: debug recovery logged synthetic query capability and X-Member-Token; release recovery logged synthetic private panic text (3 confidentiality failures, 2 controls). Source defaults to debug; production GIN_MODE is unknown.
- **Expected:**
  - Recovery emits a finite diagnostic and generic500 without raw request/query/header or panic text in debug and release.
  - Preserve ordinary query-free request logging and recovery semantics.
  - Executed synthetic taint tests prove query, member/Authorization header and panic secrecy with positive500/logging controls.
- **Req:** SR sensitive data/provider confidentiality; docs/reviews/2026-11-03-local-workflow.md
- **Depends on:** none
- **Repro / Notes:** Historical driver PANIC_LOGGING_BASELINE.md at13be27b:5leaves/3failed/2controls/0skips, retained in docs/reviews/2026-11-03-local-workflow.md. A1 d60bedc actual production routers/TCP/removed-control proof is in docs/reviews/2026-11-04-api-a1.md and committed evidence; independent acceptance/host proof pending. No real leak or production-mode claim; distinct from SQL-specific BUG-1793644509.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** A1 d60bedc replaces Gin raw recovery in BOTH actual production routers with one finite event/category/allowlisted-route recovery plus opaque Server.ErrorLog. Generic500 only before commitment; partial/disconnect/ErrAbortHandler/EPIPE/reset abort safely. Debug/release Error/Stringer/query/header/body/Location/stack taint controls,real TCP partial/kernel-RST/fallback controls and raw-recovery/ErrorLog removal assertions execute successfully; ordinary query-free logger preserved. No real/deployed leak claim. Independent review/clean/host verification pending; stays in-progress.
- **Docs:** docs/backend-api.md; docs/technical-overview.md; backend/README.md; docs/reviews/2026-11-04-api-a1.md; docs/reviews/evidence/2026-11-04-api-a1.json
- **Log:**
  - 2026-11-04 Validation: Shared source/actual constructor before evidence and final uncached Go/PG gates retained with hashes. Removed Gin recovery restores2failed confidentiality leaves; removed opaque ErrorLog fails parent secrecy/finite-event assertions after positive TCP leaves. Go may format before the opaque sink; no input is retained/forwarded by it. Scoped source/image scans and runtime75PASS,root acceptance pending.

### [BUG-1793725850] Deny OCR provider redirects across the API-key boundary
- [x] **Severity:** med
- **Area:** backend, security
- **File(s):** backend/internal/receipt/service.go; backend/internal/receipt/handler.go
- **Observation:** Fixed-origin redirect/confidentiality source accepted at c3c95cc3/evidence554cd4ca: Standards0/Spec0, reviewer NOT RUN, root clean1146. No real provider/key leak observed. Runtime/global RED are separate.
- **Expected:**
  - Deny redirects for the fixed provider endpoint; at most one outbound attempt and no cross-origin API-key forwarding.
  - Return finite generic provider/parse errors without raw receipt, response, key or Location text; retain timeout/cancellation and normal success.
  - Local mock transport tests cover307/other redirect controls, one-attempt behavior and safe errors without real provider calls.
- **Req:** SR sensitive data/provider confidentiality; docs/reviews/2026-11-03-local-workflow.md
- **Depends on:** none
- **Repro / Notes:** Original INGRESS_OCR_BASELINE.md plus actual local TLS 301/302/303/307/308, immediate302, tainted Location, stale pooled pre/post-write failures, no error-body read, early/late cancellation and finite errors. Counted wire POSTs rather than Do/dials. Corrected final redirect-removal overlay executes failed acceptance assertion; initial nil-body counterfactual panic excluded from assertion proof.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Driver accepts fixed-origin onePOST, stripped Location, finite errors and preserved cancellation/success at c3c95cc3/evidence554cd4ca. Independent0/0/reviewer NOT RUN; root clean1146 and actual Linux redirect/taint proof. Runtimeflaky/assignment/global remain RED; no deployed/physical/signed/integrated certification.
- **Docs:** backend/README.md; docs/{backend-api,technical-overview,backend-ocr-verification}.md; docs/reviews/2026-11-04-backend-native-acceptance.md; prior A2/native dated records retained.
- **Log:**
  - 2026-11-04 History: Original redirect-before/removal: docs/reviews/2026-11-04-ocr-a2-backend.md; docs/reviews/2026-11-04-ocr-native-ownership-integration.md.
  - 2026-11-04 Acceptance: Specific source requirements met; root driver approves fixed-pending-migration only. Root clean1146; reviewer NOT RUN/0findings. Runtime1.619804>1.5 RED/flaky;75/75 completion is not clearance. No closure/CHANGELOG migration.

### [BUG-1793813173] Reconcile the maintained iOS lock with the existing Flutter plugin graph
- [x] **Severity:** med
- **Area:** mobile, ios, dependencies
- **File(s):** mobile/ios/Podfile.lock; mobile/README.md; docs/mobile-ocr-verification.md
- **Observation:** At7e36d8a, pod deployment rejected app_links/package_info_plus already in Flutter's locked graph but absent from Podfile.lock.
- **Expected:** The existing locked Flutter plugin graph acquires reproducibly through pod install --deployment, preserving all existing native versions/checksums and pubspec.lock. Build the maintained Runner workspace for debug simulator and unsigned device release where supported; qualify production receipt transport on one owned simulator using synthetic local fixtures and retain all392 canonical host cases. No package/SDK/project/application behavior upgrade.
- **Req:** none — root-approved IOS_LOCK_QUALIFICATION_BRIEF_20261104.md (2026-11-04)
- **Depends on:** none — existing Flutter lock correction BUG-1793652308 is distinct
- **Repro / Notes:** Enforced pub and pod deployment under Flutter3.41.5/CocoaPods1.16.2. Generated-only repair; preserve versions, existing devices and original artifacts. Full before/build/native/scanner evidence: docs/reviews/2026-11-04-ios-lock-qualification.md.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** 863dddc retains plugin versions/pub lock with approved checksum normalization. Owner392 host/24 native assertions and unsigned builds pass; root clean acquisition and8 phase/control assertions resolve native S1/S2. Wrapper1 and missing console/OSexit/source-after remain; resource/wholeRED.
- **Docs:** mobile/README.md; docs/mobile-ocr-verification.md; docs/reviews/2026-11-04-ios-lock-qualification.md; docs/reviews/2026-11-04-ios-native-phase-acceptance.md
- **Log:**
  - 2026-11-04 Validation: Root-approved bounded native-lock repair from exact7e36d8a; native24PASS with29 joined ownership observations and no new dependencies/versions. One owned simulator created and deleted; prior simulators preserved. Native console diagnostic capture incomplete; case JSON/artifact/source/lsof evidence retained. Raw Semgrep1/six candidates and Gitleaks1/three candidates are synthetic PKI/task logging, owner-confirmed0 with no suppressions; independent review pending. Existing host RSS/heap resource PARTIAL/RED, physical/public/signed-client NOT RUN, whole acceptance RED.

### [BUG-1793848441] Keep mobile persistence diagnostics free of receipt data
- [ ] **Severity:** med
- **Area:** mobile, security, logging
- **File(s):** mobile/lib/screens/recent_bills/models/recent_bill_manager.dart; mobile/test/save_tab_review_correction_test.dart
- **Observation:** Five persistence error sinks interpolate original errors. A real SQLite BEFORE UPDATE rejection caused synthetic receipt URL/name write parameters to reach the captured application diagnostic.
- **Expected:** Failed persistence operations log finite operation labels only, never driver text, SQL parameters, receipt names or source capabilities. Existing return/control behavior and original rows remain unchanged. A real SQLite rejection regression proves confidentiality and preserved state.
- **Req:** Security finite-diagnostic boundary; scoped Semgrep follow-up to mobile save review; BUG-1793644509 covers the separate backend sinks
- **Depends on:** none
- **Repro / Notes:** At source11e6f67, logging-before.jsonl executes9 cases:8 pass and1 intended confidentiality assertion fails. Synthetic in-memory Drift only; no customer data or external request. Five raw sinks were confirmed by source inspection.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** 7bddfa9 replaces five raw persistence-error interpolations with finite operation labels. A real SQLite rejection produces1 intended confidentiality failure with8 healthy controls before correction, then9 passes. Root clean Flutter467/510 preserves all prior cases and495 sources. Scoped scans/review recorded in dated correction evidence; independent acceptance remains pending.
- **Docs:** docs/mobile-save-verification.md; docs/reviews/2026-11-04-mobile-save-corrections.md; mobile/lib/screens/recent_bills/models/recent_bill_manager.dart
