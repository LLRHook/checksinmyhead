# Billington — Bug Tracker

Active work only. Format and rules: [`.cycle/TRACKERS.md`](.cycle/TRACKERS.md). Write with `python3 .cycle/trackers.py`, never by hand. Shipped and closed entries are removed; their record is `CHANGELOG.md`, Jira, and `python3 .cycle/trackers.py show <id>`.

## Open

### [BUG-1793644497] Require source-bill ownership for tab attachment
- [x] **Severity:** crit
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
- **Status:** fixed-pending-migration
- **Fix:** Source accepted: independent source/destination proof and scoped membership under tab-before-bill locks; no victim disclosure, stale standalone claim or attribution-changing retry. Authorization correction review0/0 and current retained regressions pass in root clean908 ordinary/1189 PG leaves (1614 distinct). Ready for integrated V&V migration only; deployment/public-client acceptance remains separate.
- **Docs:** docs/backend-api.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-02-authorization-corrections.md; docs/reviews/2026-11-05-scoped-source-acceptance.md
- **Log:**
  - 2026-11-05 Source acceptance: Driver reconciles completed scoped reviews/current clean committed-source proof; source criteria met, pending integrated V&V migration only. Historical handoffs remain in Git/dated notes. Deployment, public clients and whole acceptance are separate/RED.

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
- **Fix:** Auth/client evidence: docs/reviews/2026-11-03-client-validation-correction.md. Driver Flutter237 pass; re-review/public bridge/integrated gates pending. 2026-11-06 assignment decoding source preserves exact old value/presence/null/duplicate/error behavior. Source0/0; candidate73 plus corrected goldens81 PASS across two scoped rows; baseline73 and four intended-negative/healthy controls retained. Original setupRED remains; no precision, PG, performance or integrated acceptance.
- **Docs:** docs/backend-api.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-02-authorization-batch.md; docs/reviews/2026-11-02-authorization-corrections.md; docs/reviews/2026-11-03-client-v1-bridge.md; docs/reviews/2026-11-03-client-validation-correction.md; docs/reviews/2026-11-06-assignment-snapshot.md
- **Log:**
  - 2026-11-02 Validation: Driver-approved AUTH_CORRECTION_APPROVAL.md findings 1-3 implemented in 28eab76. Six safe before leaf failures; five temporary overlay variants yield 18 expected failing leaf cases. Extreme-denominator arithmetic tested only as bounded pure calculation, never HTTP. Real PostgreSQL covers safe money boundaries and calculation-error rollback. Five actual mobile-builder tests pass with --no-pub; this does not resolve locked acquisition. Keep in-progress; no CHANGELOG migration.
  - 2026-11-03 Validation: 43772a7 client slice: real widget/provider upload plus 30/31-rune entry/builder and validation checks; 228 Flutter/54 web pass, zero skips. See docs/reviews/2026-11-03-client-v1-bridge.md; broader acceptance unchanged.
  - 2026-11-06 Source: 2026-11-06 assignment decoding source preserves exact old value/presence/null/duplicate/error behavior. Source0/0; candidate73 plus corrected goldens81 PASS across two scoped rows; baseline73 and four intended-negative/healthy controls retained. Original setupRED remains; no precision, PG, performance or integrated acceptance.

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
- **Fix:** 11e6f67 tab intent/validation;7bddfa9 finite logs; corrections0/0 APPROVE. Root467/510; at276 native33/33 real MethodChannel/Drift lost201/reopen+synthetic loopback accepted Std0/Spec0; OSexit unavailable; PG wire retained. 42e23f87 retires unused uploader; root0/0 and fresh clean467/510 pass; local affected34 retained. .005/identity/precision/integrated/release remain open.
- **Docs:** docs/mobile-save-verification.md; docs/reviews/2026-11-04-mobile-save-{reopen,corrections,acceptance}.md; docs/backend-api.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-05-legacy-uploader-retirement.md; docs/reviews/2026-11-05-scoped-source-acceptance.md
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
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** PhaseG source722fa9f adds one six-row exact-S/C report gate, named protected publisher contracts, source/schema/capability floors and default-disabled external policy; alternate iOS writes fail closed. Root actual42methods/827records and S4 omission controls pass. Prior23-path review resolves S1/S2/S3/command; focused S4 review pending. PhaseF processed-build promotion, hosted check/settings/credential/old-writer/recovery clearance remain open. No deployment/global pass.
- **Docs:** ops/ci/README.md; VERIFICATION.md; docs/reviews/2026-11-05-delivery-gate.md

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
- [x] **Severity:** high
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
- **Status:** fixed-pending-migration
- **Fix:** Source accepted: module and both digest-pinned builders use Go1.27.3/GOTOOLCHAIN=local. Current final static Debian13/nonroot artifacts supersede historical Debian12/libssl findings. Root clean format/build/vet/tagged-vet,908 ordinary/1189 PG leaves and pinned govulncheck pass; zero reported vulnerabilities. Qualified artifact/source/toolchain identities are retained in foundation/static-runtime evidence. Hosted deployment and whole gates remain unverified.
- **Docs:** backend/README.md; docs/reviews/2026-11-02-go-dependency-maintenance.md; docs/reviews/2026-11-03-static-runtime.md; docs/reviews/2026-11-05-scoped-source-acceptance.md
- **Log:**
  - 2026-11-05 Source acceptance: Driver reconciles completed scoped reviews/current clean committed-source proof; source criteria met, pending integrated V&V migration only. Historical handoffs remain in Git/dated notes. Deployment, public clients and whole acceptance are separate/RED.

### [BUG-1793644504] Finalize tabs within one retry-safe transaction
- [x] **Severity:** high
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
- **Repro / Notes:** Actual pre-fix PostgreSQL HTTP regression failed four assertions (paid 6->5.50, child/time changes, retry 400 and changed result); seven removed-control overlays fail executed assertions. Raw evidence: .vv/local-gate/atomic-lifecycle/. Historical pre-acceptance evidence.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Stored RETURNING/count guards and typed complete-row reader retain atomic retries; source/S1 reviews, 50 focused cases and control failures pass. 2026-11-09 gate repair: main runs 42365246558/42359772172 hit Go's default 600s alarm in tab with no failed assertion. Test-only lifecycleDigest replaces two 9 MB snapshots per measured sample (canonical snapshot kept on each cohort's first sample; digest characterization test with two failing controls), the row prebuilds both service binaries, and uses -timeout=20m with a 30-minute job. Samples, cohorts and operation targets unchanged. Local full eight-package row 1554 passing terminals, 0 fail/skip. Hosted PR run 42697731004: all six rows pass; PostgreSQL 1554 terminals, tab 595.4s and creation 560.0s (about half of the 1200s bound), startup 6.4s, no latency miss (large fresh p95 689-698ms<750ms, maximum creation p95 0.80-1.11s<2s). Thin large-tab margin on slow runners and capacity budgets belong to FEAT-1793644502; artifact, integrated V&V and rollout acceptance remain separate.
- **Docs:** docs/backend-api.md; backend/README.md; VERIFICATION.md; ops/ci/README.md; docs/reviews/{2026-11-03-atomic-lifecycle,2026-11-03-unicode-share-ambiguity,2026-11-05-scoped-source-acceptance,2026-11-05-row-materialization,2026-11-05-complete-row-conversion}.md; docs/reviews/2026-11-06-assignment-snapshot.md; docs/reviews/2026-11-09-pg-gate.md
- **Log:**
  - 2026-11-05 Contrary execution: run42012762828 mandatory8 PG fails snapshot equality across two lifecycle parents/five currency children; first/stored CreatedAt803580958/803580000ns. Other five rows pass; Required delivery checks fails. Reopen in-progress; no flake/rerun waiver. See committed gate note and retained raw job log.
  - 2026-11-05 Integration: Loader source0/0, physical build/vet/scanner coverage pass;1734 selected leaves retained. No numerical waiver.
  - 2026-11-06 Source: 2026-11-06 test-only snapshot ordering uses unique numeric id while preserving nine whole-record sets and unknown fields. Source0/0 and four complete variant compiles; actual snapshot PG characterization/mutation controls UNRUN. Latest04e1 tested merge524b startup60s/cmd+tab600s and maxUSD2.114s>2s remain RED; first large block715.9ms does not complete3cohorts.

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
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Backend reference/read/proof reviews pass. C/D74dd source reviews0/0; web98, affected Flutter14/analyze and owned HTTP/PG mobile+browser49 pass; integrated as ordered commits after9244ad0. Full d6 Flutter RED (two I/O errors; separate classification passes). Atomic fresh-self UNMET; supported create-unbound/request/creator-or-source approval only. Current artifact/numerical/native/public/rollout and whole gates open.
- **Docs:** docs/backend-api.md; docs/reviews/2026-11-05-{participant-identity-behavior,identity-review-corrections,row-materialization,client-identity-integration}.md; docs/technical-overview.md; mobile/test/live/README.md
- **Log:**
  - 2026-11-05 Verification: Three unique P2 review gaps corrected;14 failing before cases/12 controls,26 after pass;5 independent removals discriminate. Correction review pending;broader B gate RED.
  - 2026-11-05 Integration: Manager/source check: POST participants is unbound-only; original plan60/approval33-34 fresh-self capability UNMET. Creator/source flow remains; frozen0003 unchanged.

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
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Tab-list removal now identifies this device and acknowledges actual Drift success. The manager returns bool and refuses synced/finalized bill-list removal; their cards omit removal swipes/instructions. Local-only active removal keeps history; cancel/DB failure retains the card. Before tests reproduced synced mutation/swipe; final Flutter480/524 preserves467/510 originals, with13 focused cases including file-backed reopen and an independent local view. Real owned API/PG graph stays USD128 and genuine Leave remains separate. No shared-delete, signed/two-device or release claim; independent/root pending.
- **Docs:** docs/privacy.md; VERIFICATION.md; docs/reviews/2026-11-05-public-web.md

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
- **Fix:** Production45s unchanged. 7positives/5controls PASS; 3460Flutter567visible/573canonicalPASS. d6fullRED/classification2PASS retained; native/memory/B/spend/provider/whole open.
- **Docs:** mobile/README.md; docs/{backend-api,technical-overview,mobile-ocr-verification}.md; docs/reviews/2026-11-04-{mobile-tls-integration,mobile-tls-acceptance,backend-native-acceptance}.md; docs/reviews/2026-11-05-{ocr-timer-fixture,client-identity-integration}.md; docs/reviews/2026-11-06-{receipt-deadline-fixtures,combined-flutter-acceptance}.md
- **Log:**
  - 2026-11-04 History: M2 clean362/17native/all359prior APPROVE; backend1146/OCR3600: prior M2/A2/native dated records (Docs).
  - 2026-11-04 Acceptance: Mobile7e36 source APPROVE0/0/reviewer NOT RUN; root392 CI commands and retained-report reconciliation pass; raw parser failure/missing source-after receipt retained. See mobile-tls-acceptance.
  - 2026-11-04 Limits: Runtime1.619804>1.5 RED/flaky; assignment JSON RED. At7e36 native Pods blocked;863dd qualification is separate/pending review. FD stable/RSS nonplateau; no global pass or closure.
  - 2026-11-05 Verification: CI42096155322 timer fixture flaky; controlled fix/full513 pass; cancel-removal assertion fails. PG/full gates RED.

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
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Source-policy slice prepared: maintained /privacy-policy implements all23 adopted V2 paragraphs, summary/contact and retained no-sale commitment, with qualified Anthropic/hosting retention, secure-storage distinctions, save/retry, local/online deletion and manual payments. Inventory updated; Settings changes only canonical full-policy URL. Route must be served before its client ships. Actual effective date, mailbox control, released workflow/provider/account evidence, public labels/store destinations and legacy host remain OPEN; no publication/compliance/binary-parity claim.
- **Docs:** docs/privacy.md; web-bill-viewer/src/app/(public)/privacy-policy/page.tsx; web-bill-viewer/README.md; docs/reviews/2026-11-05-public-web.md

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
- **Fix:** Provider/replay frozen/display/zero contracts retained. Mobile corrections independently0/0 APPROVE; root clean467/510. At276 maintained Runner33/33 exact-key/snapshot process-reopen and EUR25/USD31.25 with synthetic loopback is independently accepted Std0/Spec0; OSexit unavailable. .005, identity0003, versioned JPY and combined/signed rollout remain open.
- **Docs:** docs/mobile-save-verification.md; docs/reviews/2026-11-04-mobile-save-{reopen,corrections,acceptance}.md; docs/backend-api.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-05-scoped-source-acceptance.md
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
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Editable maintained source is web-bill-viewer/src/app/(public)/; the external-only source note is historical. Receipt-led home uses the labeled USD128 example and direct numeric Store CTAs. Copy limits payment to external Venmo/shared details and manual status. Web77 cases preserve72 originals; real Go/PG HTTP/RSC127,12 error controls and headed desktop/narrow/theme/navigation evidence retained with browser limits. Legacy host remains untouched; independent/root and release acceptance pending.
- **Docs:** README.md; web-bill-viewer/README.md; docs/reviews/2026-11-05-public-web.md

### [BUG-1793644518] Exclude private bearer-link pages from indexing
- [x] **Severity:** med
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
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** b1ec44fb generic resource-free metadata, noindex/nofollow, no-referrer and explicit no-store reads. Independent Standards0/Spec0 APPROVE; fresh root clean Node24/npm11 acquisition/lint/72tests/build/audit pass. Lead HTTP9/browser destination evidence retained. Source accepted pending integrated migration; public deployment unverified, no hosting changes.
- **Docs:** web-bill-viewer/README.md; docs/reviews/2026-11-04-private-viewer-privacy.md; docs/reviews/2026-11-05-scoped-source-acceptance.md
- **Log:**
  - 2026-11-04 Verification: Approved private-viewer scope implemented; before/removal controls and local browser destination headers retained. No hosting/release action; wider gates remain RED.

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
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Source722fa9f pins reviewed action SHAs/SSH host identity, read-only default permissions, bounded jobs and serialized noncancelling publishers. Source mechanical validator0errors/6 retained top-level-concurrency warnings; actual42method/827record contracts pass. Protected jobs carry concurrency; unavailable iOS paths cannot mutate. Hosted enforcement/credential/queue controls and focused post-integration review remain unverified.
- **Docs:** ops/ci/README.md; VERIFICATION.md; docs/reviews/2026-11-05-delivery-gate.md

### [BUG-1793652308] Make the Flutter 3.41.5 committed lock reproducible
- [x] **Severity:** med
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
- **Status:** fixed-pending-migration
- **Fix:** Source accepted: pub-generated characters1.4.1/matcher0.12.19/material_color_utilities0.13.0/test_api0.7.10 and checksums remain unchanged since c376ef25. Fresh root clean Flutter3.41.5 enforced acquisition/analyze/format pass with480 visible tests and524 complete starts/terminals; all owner identities/multiplicities retained and committed inputs unchanged. Later scoped CocoaPods repair is separate. Whole/device/release gates remain open.
- **Docs:** mobile/README.md; docs/reviews/2026-11-02-flutter-lock-reproducibility.md; docs/reviews/2026-11-05-scoped-source-acceptance.md
- **Log:**
  - 2026-11-05 Source acceptance: Driver reconciles completed scoped reviews/current clean committed-source proof; source criteria met, pending integrated V&V migration only. Historical handoffs remain in Git/dated notes. Deployment, public clients and whole acceptance are separate/RED.

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
- [x] **Severity:** med
- **Area:** backend, dependencies, security
- **File(s):** backend/go.mod; backend/go.sum
- **Observation:** At 95553f7 the required x/net v0.60.0 and x/crypto v0.57.0 match GO-2026-6860, GO-2026-6866 and GO-2026-5932. A fresh November 3 govulncheck JSON run confirms three module-only findings, zero imported-package or reachable-symbol findings. These are inventory findings, not proven application exploitability.
- **Expected:** Resolve x/net v0.62.0 plus its minimum graph delta and approved x/crypto v0.58.1-0.20261009181718-2f1f834330b2 boundary (or a verified containing stable tag). No OpenPGP submodule/replacement or unrelated upgrade. All three module records clear; both production graphs remain OpenPGP-free; actual backend CI and isolated PostgreSQL race selection pass uncached without skipped tests.
- **Req:** SECURITY_INVENTORY_APPROVAL.md Module decision; GO-2026-5932; GO-2026-6860; GO-2026-6866
- **Depends on:** none; GO-2026-6809 toolchain repair remains BUG-1793644503
- **Repro / Notes:** https://vuln.go.dev/ID/GO-2026-5932.json ; https://vuln.go.dev/ID/GO-2026-6860.json ; https://vuln.go.dev/ID/GO-2026-6866.json . Upstream crypto 2f1f834330b2 adds only openpgp/go.mod; this separates unsafe unused OpenPGP, not repaired cryptography. Raw .vv/local-gate/security-inventory/baseline-vuln.log. Fingerprint: required-go-modules-net-html-crypto-openpgp-20261103. No suppression or overall acceptance.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Source accepted: approved x/net0.62.0/x/crypto pseudo-version boundary and minimum graph delta retained; independent inventory review0/0. Current root pinned govulncheck reports no vulnerabilities, with clean908 ordinary/1189 PG leaves and production graph/build proof retained. No OpenPGP module/replacement or unrelated dependency upgrade. No deployment or whole security pass.
- **Docs:** docs/reviews/2026-11-03-go-module-inventory.md; docs/reviews/2026-11-03-static-runtime.md; docs/reviews/2026-11-05-scoped-source-acceptance.md
- **Log:**
  - 2026-11-05 Source acceptance: Driver reconciles completed scoped reviews/current clean committed-source proof; source criteria met, pending integrated V&V migration only. Historical handoffs remain in Git/dated notes. Deployment, public clients and whole acceptance are separate/RED.

### [BUG-1793725849] Keep panic recovery logs free of private requests and panic values
- [x] **Severity:** med
- **Area:** backend, security
- **File(s):** backend/cmd/{bill-service,web-service}/main.go; backend/pkg/safehttp/; Gin recovery middleware
- **Observation:** Pinned13be27b actual middleware chain: debug recovery logged synthetic query capability and X-Member-Token; release recovery logged synthetic private panic text (3 confidentiality failures, 2 controls). Source defaults to debug; production GIN_MODE is unknown.
- **Expected:**
  - Recovery emits a finite diagnostic and generic500 without raw request/query/header or panic text in debug and release.
  - Preserve ordinary query-free request logging and recovery semantics.
  - Executed synthetic taint tests prove query, member/Authorization header and panic secrecy with positive500/logging controls.
- **Req:** SR sensitive data/provider confidentiality; docs/reviews/2026-11-03-local-workflow.md
- **Depends on:** none
- **Repro / Notes:** Historical driver PANIC_LOGGING_BASELINE.md at13be27b:5leaves/3failed/2controls/0skips, retained in docs/reviews/2026-11-03-local-workflow.md. A1 d60bedc actual production routers/TCP/removed-control proof is in docs/reviews/2026-11-04-api-a1.md and committed evidence; source accepted; deployed mode unverified. No real leak or production-mode claim; distinct from SQL-specific BUG-1793644509.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Source accepted: both actual routers share finite recovery and opaque Server.ErrorLog; no raw request/query/header/body/panic formatting. Independent HTTP corrections review0/0 and current root clean Go suite retain debug/release taint, disconnect/partial/RST/fallback and removal controls. Ordinary query-free logging preserved. Listener/JSON/OCR/performance scope remains separately open; no deployed confidentiality or whole-security certification.
- **Docs:** backend/README.md; docs/backend-api.md; VERIFICATION.md; docs/reviews/2026-11-04-api-a1.md; docs/reviews/2026-11-04-api-a1-review-corrections.md; docs/reviews/2026-11-05-scoped-source-acceptance.md
- **Log:**
  - 2026-11-05 Source acceptance: Driver reconciles completed scoped reviews/current clean committed-source proof; source criteria met, pending integrated V&V migration only. Historical handoffs remain in Git/dated notes. Deployment, public clients and whole acceptance are separate/RED.

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
- [x] **Severity:** med
- **Area:** mobile, security, logging
- **File(s):** mobile/lib/screens/recent_bills/models/recent_bill_manager.dart; mobile/test/save_tab_review_correction_test.dart
- **Observation:** Five persistence error sinks interpolate original errors. A real SQLite BEFORE UPDATE rejection caused synthetic receipt URL/name write parameters to reach the captured application diagnostic.
- **Expected:** Failed persistence operations log finite operation labels only, never driver text, SQL parameters, receipt names or source capabilities. Existing return/control behavior and original rows remain unchanged. A real SQLite rejection regression proves confidentiality and preserved state.
- **Req:** Security finite-diagnostic boundary; scoped Semgrep follow-up to mobile save review; BUG-1793644509 covers the separate backend sinks
- **Depends on:** none
- **Repro / Notes:** At source11e6f67, logging-before.jsonl executes9 cases:8 pass and1 intended confidentiality assertion fails. Synthetic in-memory Drift only; no customer data or external request. Five raw sinks were confirmed by source inspection.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** 7bddfa9 replaces five raw persistence-error interpolations with finite labels. Real SQLite rejection:1 intended confidentiality failure/8 healthy before,9 pass after; rows unchanged. Root clean467/510 retains all prior cases/495 sources. Independent Standards0/Spec0 APPROVE; scoped source criterion accepted, whole security/integrated acceptance remains RED.
- **Docs:** docs/mobile-save-verification.md; docs/reviews/2026-11-04-mobile-save-{corrections,acceptance}.md; mobile/lib/screens/recent_bills/models/recent_bill_manager.dart

### [BUG-1793852257] Recognize the current ledger in static runtime verification
- [x] **Severity:** med
- **Area:** verification, runtime
- **File(s):** scripts/verify_static_runtime.py; backend/README.md
- **Observation:** The maintained fresh-ledger predicate requires only version1 although the committed registry applies1,2. An actual final-image campaign stopped at check45 with the valid ledger; a separately approved exact1,2 adapter completed75/75.
- **Expected:** Fresh-ledger verification selects versions ORDER BY version and requires exactly1,2. Missing/extra versions fail; all remaining predicates, compiler selection, limits and timing budgets remain unchanged.
- **Req:** FEAT-1793644506 integrated verification; committed migrations registry1,2
- **Depends on:** none
- **Repro / Notes:** Compare scripts/verify_static_runtime.py at43aba14 with backend/migrations/registry.go. Retained replay0002 runtime45 failure and75 completion are separate from this source-only correction. No fresh canonical container run is claimed.
- **Bump:** patch
- **Status:** fixed-pending-migration
- **Fix:** Foundation0003 changes only ordered ledger1,2 to1,2,3. Owner exact final images passed75/75 canonical runtime checks with the acquisition-only compiler-cache adapter under root activation; other predicates/timeouts unchanged. Original45 stale-ledger failure and web1.619804s/<1.5 flake stay RED; earlier canonical1,2 runtime was NOT RUN. At76cb5fbb independent0/0 and root clean908/1189=1614 distinct/178input binding accept A source/evidence only; root did not rerun runtime. Cached-reader HIGH/OPEN BUG-1793861425 and wider gates remain RED.
- **Docs:** backend/README.md; VERIFICATION.md; docs/reviews/2026-11-05-identity-foundation.md; docs/reviews/2026-11-05-scoped-source-acceptance.md; exact ledger expectation tracks registry additions.

### [BUG-1793861425] Drain cached readers before additive DDL or preserve stable read projections
- [ ] **Severity:** high
- **Area:** backend, persistence, availability
- **File(s):** backend/internal/bill/repository.go; backend/pkg/database/postgres.go; backend/migrations/0003_participant_identity.sql
- **Observation:** Four immutable prefix1/2 bill/web binaries read the same HTTP-created graph200 before0003 and500 in warm processes afterDDL; restarted readers pass4/4. A separate same-connection SELECT-star control exposes0A000 afterDDL and succeeds on a fresh connection.
- **Expected:** Supported migration/read strategy preserves authorized visible fields or proves reader exclusion/connection replacement beforeDDL. No live-overlap or old-writer safety claim from restart success.
- **Req:** FEAT-1793644505 migration/read compatibility; driver IDENTITY0003_FOUNDATION_COMPATIBILITY_DECISION_20261105.json
- **Depends on:** none
- **Repro / Notes:** PG17.11 owned synthetic schemas, exact immutable prefix1/2 archives; raw phase-isolation failures, restarted4/4 and scalar1/1 control in identity0003-foundation-20261105/. HTTP sanitized logs expose unknown database class; scalar0A000 strongly supports mechanism, not direct HTTP error disclosure. Follow up with separately reviewed stable projections/connection strategy and real PG/final-binary proof; no blind mutation retry. See docs/reviews/2026-11-05-identity-foundation.md.
- **Bump:** patch
- **Status:** open

### [BUG-1793898428] Make Settings accent choices labeled and reachable at small widths
- [x] **Severity:** med
- **Area:** mobile, accessibility
- **File(s):** mobile/lib/screens/settings/settings_screen.dart
- **Observation:** At13c871c, actual Settings host checks find10 unlabeled color tap nodes and38.4x38.4 targets at320 width, below the iOS44 minimum;390-wide positive control passes.
- **Expected:** Every preset/custom choice has a unique descriptive label, button/selected semantics and one effective tap action.
  At320/390 widths targets meet platform minimum without overlap/overflow; preserve all palette values, selection/picker and preference behavior.
  Lasting actual-widget guideline and selection/persistence tests pass; direct device VoiceOver remains separate.
- **Req:** FEAT-1793644512; TR UX/a11y and fix20; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Source-pinned Flutter3.41.5/Dart3.11.3 Settings/AppTheme host proof: light/dark,320/390; healthy fixture passes. docs/reviews/2026-11-05-settings-accessibility.md retains before failures, independent approval,33 new regressions and8 removal controls. Physical VoiceOver/signed-client coverage is separate.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Integrate named responsive accent choices with selected semantics,>=48 targets and one effective persistence action. Actual513 cases/558 terminals and33 exact gate obligations pass; prior independent9-case host fixture/eight removal controls and Standards0/Spec0 review are retained. Device AT remains separate.
- **Docs:** DESIGN_SYSTEM.md; docs/reviews/2026-11-05-settings-accessibility.md
- **Cross-ref:** FEAT-1793644512

### [BUG-1793898429] Keep Settings text readable on accent and panel surfaces
- [x] **Severity:** med
- **Area:** mobile, accessibility
- **File(s):** mobile/lib/screens/settings/settings_screen.dart; mobile/lib/config/theme.dart; mobile/lib/screens/settings/widgets/payment_method_item.dart
- **Observation:** At13c871c, all8 Settings host scenarios fail4.5 text contrast: body2.88/helper2.37/payment action4.17/contact3.24. White/white70 on base/panel surfaces is affected in both themes.
- **Expected:** Choose readable foreground against actual Settings base/panel/button/selected-payment-row surfaces; preserve user accent and existing flows.
  Actual widget checks pass default/presets and representative bright/dark custom accents plus enlarged text.
  Reuse one small foreground seam, expose options label and retain callbacks/persistence; no new package/cache/theme system or global unrelated restyle.
- **Req:** FEAT-1793644512; TR UX/a11y and fix20; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **Repro / Notes:** Root actual24 application guideline evaluations completed before the fix; all failed scenarios have healthy controls. Candidate QA covers populated payment rows, presets and bright/dark custom accents; independent original diagnostic passes9/9. See docs/reviews/2026-11-05-settings-accessibility.md. Host proof does not establish physical/public-binary accessibility.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Use one effective-surface foreground owner for Settings and populated payment rows, preserving accents/actions. Actual513/558 mobile and mandatory-case omission checks pass; prior contrast/2x/populated-row and8 meaningful guard controls retained. Full app/device accessibility stays open.
- **Docs:** DESIGN_SYSTEM.md; docs/reviews/2026-11-05-settings-accessibility.md
- **Cross-ref:** FEAT-1793644512

### [BUG-1793927492] Side status column covers content on Assign, Entry and Tab screens
- [ ] **Severity:** med
- **Area:** mobile, ui, layout
- **File(s):** mobile/lib/screens/quick_split/item_assignment/item_assignment_screen.dart; mobile/lib/screens/quick_split/bill_entry/bill_entry_screen.dart; mobile/lib/screens/tabs/tab_detail_screen.dart; mobile/test/side_inset_layout_test.dart
- **Observation:** On a native iPhone Duo simulator (Xcode 27.2, iOS 27.1) the Closed display reports right 84pt and bottom 34pt insets. The Scaffold bodies of Assign Items, Enter Bill Details and Tab detail have no horizontal SafeArea, so content runs under the status column: the Assigned amount reads $1 and then the column. Open landscape shows the same collision. Landing, Onboarding and Bill Details already use SafeArea and stay clear.
- **Expected:** Body content stays between the system side insets on every display. The Assigned amount is fully visible, amounts and calculations do not change, the progress bar still shows the assigned share, and displays without side insets keep their full-width layout.
- **Req:** none (found by native Duo capture for App Store screenshots)
- **Depends on:** none
- **Repro / Notes:** Closed pose in Device Hub, Quick Split, four people, $122 with items, Continue to Assign Items. Before evidence: /tmp/appshot-quality-20261105/capture/ios27.2/raw/iphone-duo-outer-1398x2034/03-assign.png. Regression test: mobile/test/side_inset_layout_test.dart. SafeArea alone left the progress bar reading full screen width, so at 50% it overstated the share by 42pt on the Closed display; the bar now sizes from its track.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Horizontal SafeArea/track-relative fill: final19/analyze0 and combined3460 Flutter567visible/573canonicalPASS. Native/default-font/integrated capture pending; separate Finalize overflow not fixed.
- **Docs:** DESIGN_SYSTEM.md; docs/reviews/2026-11-06-{layout-insets,combined-flutter-acceptance}.md; exact19 canonical cases. Separate Finalize short-height overflow remains open.

### [BUG-1793935715] Keep the Finalize confirmation usable on short displays
- [ ] **Severity:** med
- **Area:** mobile, ui, layout
- **File(s):** mobile/lib/screens/tabs/tab_detail_screen.dart (_FinalizeConfirmSheet)
- **Observation:** The retained native capture handoff reports 14px and 21px Finalize sheet overflows on short displays. Current source still caps a non-scroll Column at 70% screen height. The horizontal-body fix does not change this sheet; current native reproduction remains pending.
- **Expected:** All settlement preview rows and Cancel/Finalize actions remain reachable without overflow on short displays and default/large text; keep money, confirmation and finalization behavior unchanged.
- **Req:** none (separate retained native capture finding; DESIGN_SYSTEM.md responsive layout)
- **Depends on:** none
- **Repro / Notes:** Frozen /tmp/appshot-quality-20261105/capture/frozen-layout-milestone/HANDOFF.md, Separate findings; BEFORE frames are f4abc78, not current native proof. Open Tab detail > Finalize on a short display. Source caps maxHeight at 0.7 and uses an unscrollable Column. Body inset tests use textscale0.5 and do not qualify this modal. No fix or new native execution claimed.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** open
- **Docs:** docs/reviews/2026-11-06-combined-flutter-acceptance.md; frozen layout handoff
- **Cross-ref:** BUG-1793927492 (separate horizontal body issue, not this sheet)

### [BUG-1793958334] Retain migration producer evidence when activity observation fails
- [ ] **Severity:** med
- **Area:** tests, backend, migrations
- **File(s):** backend/migrations/failure_observation_test.go; backend/migrations/failure_postgres_test.go
- **Observation:** At8371 TestPostgresMigrationParentDeadline calls waitActivity before receive. A missing-PgSleep Fatal can prevent inspection of an already buffered producer result, leaving the actual cause/join and rollback evidence unresolved. This is a test-proof defect; production cause and recovery are unproved.
- **Expected:**
  - Retain one actual producer result and original cause independently of observer error; never treat an unreceived/closed channel as nil success.
  - Missing PgSleep still fails; preserve real500ms caller,10s observer,15s one-time join, whole-batch rollback and recovery requirements.
  - Record finite outcome evidence and attempt bounded rollback observation only after the worker joined; keep real PG qualification open until executed.
- **Req:** FEAT-1793644505; VERIFICATION.md migration cancellation/rollback proof
- **Depends on:** none; diagnostic correction uses the existing migration contract
- **Repro / Notes:** Source trace at8371 failure_postgres_test.go waitActivity before receive; retained PG missing-witness failure is not a causal production diagnosis. Source-reviewed fe039511/13926a96 and R02 fd34a40e compile four variants first; five pure helper leaves pass and three removals fail intended assertions with healthy siblings. Report fc98d254; independent verification1e3271a4. No real PG rerun.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Reviewed test-only outcome holder and bounded evidence path adopted; Go formatting changes only alignment spaces on seven evidence fields. Pure helper/control proof passes; real500ms/PgSleep/rollback/recovery and prior170s/198.64s/full gates remain unqualified.
- **Docs:** docs/reviews/2026-11-06-migration-outcomes.md; ops/ci/README.md; VERIFICATION.md
- **Cross-ref:** FEAT-1793644505
- **Log:**
  - 2026-11-06 Verification: R02 pure helper qualification: four complete compiles/list selections pass, five clean helper leaves pass and all three source removals fail their intended assertions with healthy siblings. Manager independent verification1e3271a4; reportfc98d254. Only seven evidence-field alignment lines changed under gofmt; no test rerun for whitespace. Real500ms/PgSleep/rollback/recovery and historical170s/198.64s/full gates remain open.
  - 2026-11-06 Verification: Local integration static checks: gofmt0 with seven spacing-only evidence fields; complete offline controller42methods/916 method+subtest records PASS including all five exact-child omissions and existing mobile/web named selections; official tracker lint0errors/0warnings. Only PG family+five anchored namespaced child IDs added; ordinary/backend obligations and all inherited fields preserved. Current real PG/full/native gates remain unqualified.

### [BUG-1793996842] Preserve saved participant colors and readable identity ink
- [ ] **Severity:** med
- **Area:** mobile, ui, identity
- **File(s):** mobile/lib/screens/recent_bills/components/participants_card.dart; mobile/lib/screens/quick_split/participant_selection/participant_selection_sheet.dart; mobile/lib/screens/quick_split/item_assignment/utils/color_utils.dart; mobile/lib/screens/quick_split/item_assignment/widgets/participant_avatar.dart; mobile/test/screenshot_quality_test.dart
- **Observation:** At a021, Bill Details derives avatar colors from amount rank instead of the saved occurrence; auto-added owners omit saved custom color, and shared items take the first assignee color. Selected light-theme text/avatar callsites do not derive ink from their actual composited surface. This is a source-confirmed defect; current widget/native behavior is not yet qualified.
- **Expected:** Preserve saved colors for single-person and intentionally same-color rosters, receipt ordinals/refs and recorded values. Bill Details initials use composited ink in both themes; changed light-theme callsites reuse AppTheme.foregroundOn, with other dark branches unchanged. Shared items use the existing neutral palette; auto-added owners reuse saved custom color but receive fresh occurrence refs. Require the exact screenshot_quality_test.dart literals: Bill Details identity uses each saved roster color, not the amount rank; Bill Details identity preserves a single saved roster color; Bill Details identity keeps saved colors when multiple people choose the same color; Person color ink every palette color reads on white and on its own row tint; Person color ink keeps ink that already reads; Person color ink avatar ink meets normal text contrast on every palette color; Person color ink a shared item never takes one person's color; Participant visual controls auto-added owner keeps saved color with fresh occurrence refs. Actual widget and native/capture proof remains pending.
- **Req:** FEAT-1793644509; DESIGN_SYSTEM.md participant occurrence/color guidance
- **Depends on:** none; existing saved occurrence and theme owners
- **Repro / Notes:** Read a021 SortedParticipantsCard rank color selection, participant sheet auto-add and ColorUtils.getDominantColor. Distinct from BUG-1793898429 Settings-only ink. Private R02 formatter/analyzer0; widget loader failed before all106 cases. Offline controller R03 verifies literal-enforcement fixtures only; raw2129dd79/manager8fde2490, not Flutter or screenshot acceptance.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Adopt the exact reviewed nine-lib/T1 source subset with saved-color provenance and existing composited-ink ownership. Automatic Linux mobile is the selected functional route;588 canonical records EXPECTED only. No native, physical accessibility,95-quality or release acceptance.
- **Docs:** docs/reviews/2026-11-06-ui-quality-candidate.md; DESIGN_SYSTEM.md; mobile/README.md
- **Cross-ref:** FEAT-1793644509 (acceptance and status unchanged)

### [BUG-1793996843] Show four actual assignees before avatar overflow
- [ ] **Severity:** med
- **Area:** mobile, ui, layout
- **File(s):** mobile/lib/screens/quick_split/item_assignment/widgets/item_card.dart; mobile/test/screenshot_quality_test.dart
- **Observation:** At a021, ItemCard limits its collapsed assignee stack to three avatars whenever more than three people are assigned, so a four-person item shows three initials plus +1. The source geometry also uses 12pt steps for 20pt avatars. No current widget/native result is asserted.
- **Expected:** Four assignees show all four real avatars without +1; above four, show three real avatars and the correct remaining-person count. Preserve receipt ordinals/refs, assignments, amounts, toggles and other app behavior. Require exact literals Assignee stack shows four people instead of a +1 and Assignee stack summarises everyone past four. Default/enlarged-text widget and later pinned native/capture proof remain pending.
- **Req:** FEAT-1793644509; DESIGN_SYSTEM.md participant occurrence/color guidance
- **Depends on:** none; existing saved occurrence and theme owners
- **Repro / Notes:** Read a021 ItemCard._buildAssigneeAvatars displayPeople and overflow conditions. No existing tracker covers this source defect; unrelated Settings targets and Finalize overflow remain separate. All106 affected widget cases are unstarted; R03 offline omission checks are delivery-gate controls only.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Adopt exact reviewed hasOverflow >4 and four-slot stack geometry, preserving the full assigned list. No runtime, physical-device,95-quality or screenshot recovery claim.
- **Docs:** docs/reviews/2026-11-06-ui-quality-candidate.md; DESIGN_SYSTEM.md; mobile/README.md
- **Cross-ref:** FEAT-1793644509 (acceptance and status unchanged)
- **Log:**
  - 2026-11-06 CI proof correction: Automatic CI42289112203/mobile128137633416 at a962 failed the overflow test global A finder after four CircleAvatar and +2 checks passed: it matched the11px avatar and18px other item content. This is a test-proof scope defect, not a demonstrated production UI defect. Apply exact09e54ebc correction to scope all ABC/+2/noD finders to CircleAvatar descendants, retaining every assertion and literal ID; no local test/formatter or retry. Corrective source-triggered CI acceptance remains pending; status in-progress and native/capture/quality limits unchanged. See docs/reviews/2026-11-06-ui-quality-candidate.md.

### [BUG-1794045425] Preserve accounting availability for accepted fractional receipts
- [ ] **Severity:** high
- **Area:** backend, accounting
- **File(s):** backend/internal/bill/accounting.go; backend/internal/bill/creation_repository.go; backend/internal/bill/accounting_creation_regression_test.go
- **Observation:** SPEC-001: actual CreateBill accepts 18.50 subtotal + 2.775 tip /21.275 total but saved21.28 fails the stricter frozen-share audit; documented one-cent tolerance also reproduces.
- **Expected:** Use the maintained accounting tolerance at creation and frozen allocation; genuinely partial claims are never scaled up. Reject malformed, overallocated or invalid foreign evidence before persistence; preserve valid legacy/fresh-reference inputs.
- **Req:** docs/backend-api.md accounting and identity contracts; docs/technical-overview.md durable history/read-failure contracts
- **Depends on:** none; independent postmerge regression
- **Repro / Notes:** Real creation + persistence-preflight regressions failed before the fix; affected bill/tab -race row now532 named PASS. Actual PG/finalization/whole V&V remain pending.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Implemented aligned creation/frozen-share tolerance and pre-insert share audit; manager combined-scope source review accepted. Actual affected bill/tab Go race row:532 named PASS, with original red regressions retained. Status remains in-progress; real PostgreSQL persistence/finalization, current CI and integrated V&V remain pending.
- **Docs:** docs/reviews/2026-11-07-postmerge-money-client-regressions.md

### [BUG-1794045426] Keep negative cent remainders off zero obligations
- [ ] **Severity:** med
- **Area:** backend, accounting
- **File(s):** backend/internal/bill/shares.go; backend/internal/bill/creation_correction_test.go; backend/internal/bill/accounting_creation_regression_test.go
- **Observation:** SPEC-002: real creation derives Alice tax=-0.01 for the .10/30 +1.01 tax split, or rejects a valid zero-total participant split.
- **Expected:** Debit only positive balances in existing claim/name priority, preserve signed discount lines and zero participants, bound work independently of cent count, and reject insufficient/invalid balances rather than persist negatives.
- **Req:** docs/backend-api.md accounting and identity contracts; docs/technical-overview.md durable history/read-failure contracts
- **Depends on:** none; independent postmerge regression
- **Repro / Notes:** Both real creation triggers failed before correction. Positive/negative priority controls, huge bounded counts, signed-discount creation and independent small one-cent oracle pass in the affected Go row. Existing historical negative rows are not rewritten.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Implemented bounded negative-cent deductions from eligible positive balances in claim/name order, preserving zero shares and signed discounts. Manager combined-scope source review accepted; affected Go race532 PASS includes bounded-count and independent small-oracle controls. No historical amount rewrite. Status remains in-progress; real PG/current CI/integrated V&V remain pending.
- **Docs:** docs/reviews/2026-11-07-postmerge-money-client-regressions.md

### [BUG-1794045427] Import complete Trip history atomically at capacity
- [ ] **Severity:** high
- **Area:** mobile, persistence, tabs
- **File(s):** mobile/lib/database/database.dart; mobile/lib/screens/recent_bills/models/recent_bill_manager.dart; mobile/lib/screens/tabs/tab_detail_screen.dart; mobile/test/tab_import_capacity_test.dart
- **Observation:** SP-1: real Drift31-row import evicts an earlier returned ID; later existing target is evicted, and parse failure leaves prior refresh committed. Read failures can silently look empty or escape into permanent loading.
- **Expected:** Retain cap30 and all pending/referenced/current-pass IDs. Import plus local tab-ID checkpoint commits together or rolls back. Every read/cache/parse failure clears loading, offers retry and withholds partial balance/finalize claims.
- **Req:** docs/backend-api.md accounting and identity contracts; docs/technical-overview.md durable history/read-failure contracts
- **Depends on:** none; independent postmerge regression
- **Repro / Notes:** Before-fix real Drift and widget assertions fail; after-fix related Flutter116 visible PASS, including30/31, separate pending/referenced history, checkpoint rollback and error/retry controls. No migration or remote receipt deletion.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Implemented atomic complete Trip import plus local-ID checkpoint, protected incoming/pending/referenced history, and finite loading/error/retry with no partial balances. Manager combined-scope review accepted. Retained affected Flutter116 PASS; later completion-witness correction separately passes10 focused cases, without repeating116. Status remains in-progress; current CI/real PG/integrated V&V remain pending.
- **Docs:** docs/reviews/2026-11-07-postmerge-money-client-regressions.md

### [BUG-1794045428] Stamp durable receipts at their actual insertion time
- [ ] **Severity:** med
- **Area:** mobile, persistence
- **File(s):** mobile/lib/database/database.dart; mobile/test/receipt_timestamp_test.dart
- **Observation:** SP-4: omitted createdAt uses the historical Drift9 table literal1793912155 rather than receipt insertion time.
- **Expected:** New durable receipts have an explicit insertion timestamp when omitted; explicit timestamps/existing handles remain unchanged. Do not backfill historical rows under this fix.
- **Req:** docs/backend-api.md accounting and identity contracts; docs/technical-overview.md durable history/read-failure contracts
- **Depends on:** none; independent postmerge regression
- **Repro / Notes:** The maintained historical-schema SQLite fixture fails before the fix and passes afterward within the affected Flutter row. Schema version10 and migration files remain unchanged.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Implemented explicit new durable-receipt insertion timestamp, preserving existing handles and historical rows without migration/backfill. Manager combined-scope source review accepted; historical Drift9-default regression passes in retained affected Flutter116 row. No repeat row after test-only witness correction. Status remains in-progress; current CI/real PG/integrated V&V remain pending.
- **Docs:** docs/reviews/2026-11-07-postmerge-money-client-regressions.md

### [BUG-1794045429] Retain browser join input across refreshed bill graphs
- [ ] **Severity:** med
- **Area:** web, identity
- **File(s):** web-bill-viewer/src/components/LazyBillBoard.tsx; web-bill-viewer/src/components/__tests__/LazyBillSession.test.ts
- **Observation:** SP-2: participant-array refresh re-runs a combined selection/suggestion/recovery effect, erasing typed or deliberately empty join input and repeating membership recovery.
- **Expected:** Selection follows current participant graph; suggestion seeding follows bill/tab identity; recovery follows tab/token identity. Successful recovery clears only its own warning and preserves unrelated errors.
- **Req:** docs/backend-api.md accounting and identity contracts; docs/technical-overview.md durable history/read-failure contracts
- **Depends on:** none; independent postmerge regression
- **Repro / Notes:** Exact manager patch b6c3240d: baseline4/4 intended failures, fixed4/4 PASS, maintained web102/102. Integrated actual component hook/handler4/4 PASS plus TypeScript/Biome0; no browser-pixel or service claim.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Integrated exact manager SP-2 selection/suggestion/recovery ownership correction; manager combined-scope source review accepted. Integrated actual component/handler4 PASS, TypeScript/Biome0; retained manager whole-web102 row remains separate evidence. Status remains in-progress; full current CI, real PG and integrated V&V remain pending.
- **Docs:** docs/reviews/2026-11-07-postmerge-money-client-regressions.md
