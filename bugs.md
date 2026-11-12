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
- **Fix:** 11e6f67 tab intent/validation;7bddfa9 finite logs; corrections0/0 APPROVE. Root467/510; at276 native33/33 real MethodChannel/Drift lost201/reopen+synthetic loopback accepted Std0/Spec0; OSexit unavailable; PG wire retained. 42e23f87 retires unused uploader; root0/0 and fresh clean467/510 pass; local affected34 retained. 2026-11-09: save_journey_test adds a one-row EUR journey (Done, share, retry, restart, attachment), a Done retry through the actual handler and eight quote-state cases; pending native-USD receipts no longer report a pending USD conversion. Local full Flutter row 603/603, analyze clean. Remains: owner decision on the odd-cent rule (device and server place cents differently; options in docs/reviews/2026-11-09-mobile-save-journey.md); precision and identity under BUG-1793644515/BUG-1793644505; integrated, native and release evidence.
- **Docs:** docs/mobile-save-verification.md; docs/reviews/2026-11-04-mobile-save-{reopen,corrections,acceptance}.md; docs/backend-api.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-05-legacy-uploader-retirement.md; docs/reviews/2026-11-05-scoped-source-acceptance.md; docs/reviews/2026-11-09-mobile-save-journey.md
- **Log:**
  - 2026-11-03 Evidence: Driver fb6b4b9 actual provider penny capture: client Alex=.01/Sam=0; v1 server Alex=0/Sam=.01 with .005 raw details. No math change in 43772a7. Preserve server/historical contracts; deliberately align local/published allocation in currency/save scope. See docs/reviews/2026-11-03-client-v1-bridge.md.
  - 2026-11-09 Decision: Odd-cent difference is wider than the .005 tie: server rounds subtotal/tax/tip separately in label order (10.00+0.01+0.01 split evenly publishes 5.00/5.02; device shows 5.01/5.01). Not aligned: every fix changes visible amounts. Options 1-4 and recommendation (device adopts server rule) in the 2026-11-09 note.
  - 2026-11-09 Sighting: Simulator inspection on iPhone 17 (iOS 27.2) found the tab's Add existing bill picker labelled a saved EUR 25.00 receipt as $25.00 while Recent Bills and Bill Details showed EUR 25.00. The picker now formats with the receipt's currency; regression test 'actual tab selector labels each saved receipt in its own currency' failed first with '11/9/2026 • $25.00'.

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
- **Fix:** Source: phase G (722fa9f) and phase F (fc98e85) are in: one six-row exact-S/C gate, named protected publishers, floors and default-disabled external policy; iOS origin and promotion reuse the gate with no rebuild. Focused S4 review done 2026-11-09 on current source with real reports: web 102 cases = 102 selections; mobile 599 records, one registration (four native IO modes) matched no selection and is now required (4 intended reds first); 134 loop expansions and 6 hooks stay the documented limit. Second finding fixed: the graph test accepted checks.yml without govulncheck, npm audit, vet, gofmt, mod verify, analyze, lint or build, or with masked, skipped, re-shelled or reordered commands; validate_graph now pins each row's command lines, shell, run steps and job keys (19 mutations, all accepted before). 43 gate, 17 iOS, 5+18 Ruby methods pass; automation row 1,452 records. Hosted run 42365246558: failed Gate postgres, both collectors failed, both publishers skipped (policy also unset). REMAINS, hence in-progress: (1) BLOCKED: Render Auto-Deploy mode, branch and hook, and Vercel connected repositories, production branch and mirror writers need owner inspection; observed only /health=81a564f after two failed-CI main pushes, mirror 404. (2) 0 environments: backend-production, web-production, ios-upload, ios-production must exist main-only with DELIVERY_* secrets. (3) Main ruleset requires no status check. (4) RELEASE_POLICY unset (0 variables): no gated publication or exact-SHA readback observed. (5) Legacy uploader victorwake-testflight.yml on branch victorwake-testflight-runner uses repository-level ASC and signing secrets. (6) Native signing, ASC and hosted iOS qualification NOT RUN. (7) Owner decision: enforce a manifest-versus-source inventory. No deployment, dispatch, re-run or setting change.
- **Docs:** ops/ci/README.md; VERIFICATION.md; docs/reviews/2026-11-05-delivery-gate.md; docs/reviews/2026-11-09-delivery-workflows.md

### [BUG-1793644502] Resolve the three current Next.js security alerts
- [x] **Severity:** high
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
- **Status:** fixed-pending-migration
- **Fix:** e4af0a7 pins Next16.4.5 with11 root/Next/env/SWC lock entries; React/DOM19.3.0,sharp0.35.5 and overrides retained. Lead and independent root clean Node24.22.2/npm11.19.1 acquisition,lint,54tests (0skip),build,audit pass; audit0. Root Standards0/Spec0. Keep in-progress for alert/deployed closure.
- **Docs:** web-bill-viewer/README.md; docs/reviews/2026-11-04-next1645-security-patch.md. Historical November2 dependency evidence is preserved.
- **Log:**
  - 2026-11-04 Validation: Primary-source discrepancies and npm/Vite warnings retained in dated evidence. Prior Flutter/runtime follow-ups belong to BUG-1793652308/2309. No hosting mutation, deployment, alert closure or whole security/integrated/release pass claimed.
  - 2026-11-04 Maintenance: Condense inherited oversized tracker through official writer; historical fields remain in Git and dated reports.
  - 2026-11-09 Verification: PASS at e0a2c18: npm ls next = next@16.4.5; npm ci, biome lint (55 files), vitest 102 pass/0 fail/0 skip (ticket's 54 is outdated), next build, npm audit --audit-level=moderate 0 vulnerabilities; read-only gh: open Dependabot alerts 0; alerts 67, 68, 69 state=fixed (fixed_at 2026-11-07); revert check not run: dependency pin, no regression test; unproven: deployed version; not run here: hosted deployment check
  - 2026-11-09 Verification: 2026-11-09: next@16.4.5 resolved; npm audit 0; Dependabot alerts 67, 68 and 69 are fixed and 0 alerts are open (read-only GitHub API). The deployed viewer version stays unverified because the maintained pages are not served yet.

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
- **Fix:** Backend reference/read/proof reviews pass. C/D74dd source reviews0/0; web98, affected Flutter14/analyze and owned HTTP/PG mobile+browser49 pass; integrated as ordered commits after9244ad0. The two d6 Flutter I/O errors were real-deadline races, corrected test-only on 2026-11-06; full row at e0a2c18 passes 593/593 visible cases in 5 of 5 local runs. Added same-name debt (unit, 3 subtests) and fresh-participant (PostgreSQL) negatives with removal controls. Remains: owner decision on atomic fresh-self (docs/reviews/2026-11-09-fresh-self-decision.md; supported flow is create-unbound/request/creator-or-source approval), and the artifact/numerical/native/public/rollout and whole gates.
- **Docs:** docs/backend-api.md; docs/reviews/2026-11-05-{participant-identity-behavior,identity-review-corrections,row-materialization,client-identity-integration}.md; docs/reviews/2026-11-09-fresh-self-decision.md; docs/technical-overview.md; mobile/test/live/README.md
- **Log:**
  - 2026-11-05 Verification: Three unique P2 review gaps corrected;14 failing before cases/12 controls,26 after pass;5 independent removals discriminate. Correction review pending;broader B gate RED.
  - 2026-11-05 Integration: Manager/source check: POST participants is unbound-only; original plan60/approval33-34 fresh-self capability UNMET. Creator/source flow remains; frozen0003 unchanged.
  - 2026-11-09 Decision: Fresh-self needs an owner decision: A accept supported flow and amend plan (recommended), B one-step self-add for creator/source only (no migration), C for every member (0004, epoch 2). Not implemented.
  - 2026-11-10 Sighting: 2026-11-10 V&V (5e877e36d968, D5 upgrade from production 81a564f): after migrations 0001-0003, GET /api/tabs/:id on legacy tabs returns 409 client_upgrade_required to clients that send no X-Billington-Identity-Version header (released v2.0.11+36 and App Store 1.4.0 send none). With header 2 it returns 200, but net_balances is null and net_balance_status is identity_review_required. On legacy graph1 tabs, member share-paid and name-only lazy claims return 409 identity_review_required (header 1 and 2), and docs/backend-api.md documents no review endpoint. Bills, members and settlements otherwise read identically. Local evidence: .vv/worktrees/vv-5e877e3/.vv/d5/logs/05c-compare.txt, 05e-legacy-writes.txt.

### [BUG-1793644506] Label local bill and tab removal accurately
- [x] **Severity:** med
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
- **Status:** fixed-pending-migration
- **Fix:** Tab-list removal now identifies this device and acknowledges actual Drift success. The manager returns bool and refuses synced/finalized bill-list removal; their cards omit removal swipes/instructions. Local-only active removal keeps history; cancel/DB failure retains the card. Before tests reproduced synced mutation/swipe; final Flutter480/524 preserves467/510 originals, with13 focused cases including file-backed reopen and an independent local view. Real owned API/PG graph stays USD128 and genuine Leave remains separate. No shared-delete, signed/two-device or release claim; independent/root pending.
- **Docs:** docs/privacy.md; VERIFICATION.md; docs/reviews/2026-11-05-public-web.md
- **Log:**
  - 2026-11-09 Verification: PASS: 13 named Dart tests in mobile/test/local_tab_removal_test.dart (local removal retains receipt, synced removal refused, no swipe on synced bill, rejected delete keeps Drift row, cancel no mutation, failed removal feedback, file-backed reopen, independent local view; Remove from this device wording in lib/screens/tabs/tabs_screen.dart) at e0a2c18; full mobile suite 593 visible pass/0 fail/0 skip; revert check not run: not in required set; unproven: two-device agreement and authorized server delete for creator actions (no test or API route exercised); not run here: signed/two-device/native
  - 2026-11-09 Verification: Native check (iPhone 17, iOS 27.2): swiping a tab offers 'Remove from this device?' and states that the shared tab, bills, recorded totals and other people's access remain online; Cancel keeps it; a confirmed removal of a throwaway tab is gone after relaunch while the other tab stays; a synced or finalized bill inside a tab offers no removal swipe. A two-device comparison was not run. Screenshots: .vv/ui-inspection-20261109/main/A6-*.png.

### [BUG-1793644507] Bound public API request resources
- [ ] **Severity:** med
- **Area:** backend, security
- **File(s):** backend/cmd/{bill-service,web-service}/main.go; backend/pkg/safehttp/; backend/internal/bill/{create_request,assignment_request,handler,assignments}.go; backend/internal/tab/handler.go; backend/internal/receipt/
- **Observation:** A1/fd26598 corrections and backend c3c95cc3 F1/F2/F3 source have scoped APPROVE Standards0/Spec0 (reviewer NOT RUN); root clean1146 passed. 2026-11-09: the name-based 50,000-assignment update meets its 10 ms p95 on the unchanged a1perf harness. Still open: the static runtime harness is flaky, the identity-version-2 update route is not measured, and hosted/integrated gates are unverified.
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
- **Fix:** sweep/abuse-bounds: name-based assignment updates bind in one streaming pass (safehttp.DecodeJSONStream/DecodeArrayFrom on stdlib encoding/json/v2 with v1 options; plain arrays bound directly, every other array through the previous encoding/json path), sized command slices, one name set and allocation-free ASCII identity keys in validation. Unchanged a1perf harness, two executions: max_mutation_50000 p95 5.980/6.197/6.739 and 6.048/6.176/5.998 ms vs 10 ms (base same day 34.004/32.071/32.088); all nine paths, burst and retention pass; 10.59 MB and 2,149 allocations per request (35.34 MB and 109,668). No target, input, sample count or percentile changed; no waiver. OPEN: static runtime harness 3 of 4 runs 75/75 with web-db-unavailable 1.033-1.045 s vs <1.5 s (1.619804 s not reproduced), run 3 failed bill-runtime-probe dns_cancellation; identity-version-2 route still buffered, about 26 ms per 50,000 by one-off benchmark; hosted proxy allowlist/topology and integrated run unverified.
- **Docs:** backend/README.md; docs/{backend-api,technical-overview,backend-ocr-verification,backend-replay-verification}.md; docs/reviews/2026-11-09-assignment-update-decode.md; docs/reviews/2026-11-04-backend-native-acceptance.md; prior native/A1/A2 dated history retained; VERIFICATION.md unchanged.
- **Log:**
  - 2026-11-04 History: A1/A2 dated api-a1, api-a1-review-corrections and ocr-a2-backend notes; docs/reviews/2026-11-04-ocr-native-ownership-integration.md.
  - 2026-11-04 Acceptance: sourcec3c95cc3/evidence554cd4ca F1/F2/F3 APPROVE0/0; reviewer NOT RUN, root clean1146. OCR3600 targets met; runtimeflaky/assignment/global RED. Raw scanner1/0confirmed;207schemas absent/336originals intact.
  - 2026-11-09: Sweep: 50k update p95 5.98-6.74 ms vs 10 ms on unchanged harness (was 32-34); Go row 1544 pass, only TestServiceHealthcheckMode/bill-service fails (port 8080 held by another container); integration bill/bill-service/tab 1296 pass; 21 guard-removal controls fail by assertion. Runtime harness 3/4 green, run 3 bill-runtime-probe FAIL retained. See docs/reviews/2026-11-09-assignment-update-decode.md.

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
- **Fix:** Production45s unchanged. 7positives/5controls PASS; 3460Flutter567visible/573canonicalPASS. d6fullRED/classification2PASS retained. 2026-11-09 sweep/abuse-bounds, tests only: TestHandlerFailuresMakeOneProviderAttempt proves one provider POST per client request for provider 429/529/500/401/400/unusable-200 and none for peer-quota denials, with finite errors and Retry-After. Five guard removals fail by assertion. The 2026-11-05 cancel-removal failure is the intended control: 49/49 on source, 46 pass/3 fail with only _timer.cancel() removed. Multi-process semantics are documented (limits multiply across replicas; no durable or global allowance). OPEN: hosting/provider budgets BLOCKED on owner confirmation; durable/global spending allowance B needs a product decision; mobile retained-memory plateau NOT RUN (harness not in repository); native/signed-client qualification and the integrated run.
- **Docs:** mobile/README.md; docs/{backend-api,technical-overview,mobile-ocr-verification,backend-ocr-verification}.md; docs/reviews/2026-11-04-{mobile-tls-integration,mobile-tls-acceptance,backend-native-acceptance}.md; docs/reviews/2026-11-05-{ocr-timer-fixture,client-identity-integration}.md; docs/reviews/2026-11-06-{receipt-deadline-fixtures,combined-flutter-acceptance}.md
- **Log:**
  - 2026-11-04 History: M2 clean362/17native/all359prior APPROVE; backend1146/OCR3600: prior M2/A2/native dated records (Docs).
  - 2026-11-04 Acceptance: Mobile7e36 source APPROVE0/0/reviewer NOT RUN; root392 CI commands and retained-report reconciliation pass; raw parser failure/missing source-after receipt retained. See mobile-tls-acceptance.
  - 2026-11-04 Limits: Runtime1.619804>1.5 RED/flaky; assignment JSON RED. At7e36 native Pods blocked;863dd qualification is separate/pending review. FD stable/RSS nonplateau; no global pass or closure.
  - 2026-11-05 Verification: CI42096155322 timer fixture flaky; controlled fix/full513 pass; cancel-removal assertion fails. PG/full gates RED.
  - 2026-11-09: Sweep: limiter table bound and single provider attempt proven by two new Go tests (receipt package 221 named records pass under -race; Go row 1553 pass, only TestServiceHealthcheckMode/bill-service fails on occupied port 8080). Mobile receipt_service_test 49/49; cancel-removal control 3 expected failures, source restored. Budgets blocked on owner; allowance B undecided; memory plateau NOT RUN. See docs/reviews/2026-11-09-receipt-limits.md.

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
- **Fix:** Repository slice reconciled to released behavior on 2026-11-09: public binary 1.4.0 (source 5ca1dc6 / tag v1.4.0+23) and deployed API commit 81a564f (from GET /health). Maintained /privacy-policy is scoped to 1.4.0 and the running service, with later-build statements marked Not yet released. Source Settings notice no longer promises removal on uninstall or limits online storage to shared bills. docs/privacy.md separates released, not-yet-released and OPEN; docs/app-privacy-label.md holds prepared label answers against Apple's current data types, purposes, linkage and tracking (not submitted). Proven: 3 new web tests (2 failed on the old page) and 1 new widget test (failed on the old text); web lint, 105 tests and build; public-route verifier 6 cases 0 failed; flutter analyze and 594 cases; gate 42 methods. REMAINS, owner or external: the public label still shows Data Not Collected and the 1.4.0 in-app text still says data never leaves the device until a label submission and a new public binary; the store policy link is the legacy host; the maintained route returns 404 on its host; effective date, mailbox control, Anthropic account terms, production configuration and retention, stored 1.4.0-era tab photos and the public build number are OPEN; owner decision needed on an explicit correction of the 1.4.0 in-app text in the policy. No publication, legal-compliance or binary-parity claim.
- **Docs:** docs/privacy.md; docs/app-privacy-label.md; web-bill-viewer/README.md; web-bill-viewer/src/app/(public)/privacy-policy/page.tsx; docs/reviews/2026-11-05-public-web.md
- **Log:**
  - 2026-11-09 Sighting: Public recheck: store label Data Not Collected; store policy link getbillington.vercel.app/privacy-policy (200); billingtonapp.vercel.app / and /privacy-policy 404; API /health commit 81a564f; 1.4.0 Settings text says data never leaves the device while Done uploads every bill.

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
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Documentation reconciled on 2026-11-09, history labeled and linked rather than deleted. README: already used /privacy-policy; now states that /privacy was removed on purpose (PR #149), records the dated hosting state and no longer lists production deployment as not done. backend/roadmap.md: labeled historical record with a status block and 17 labeled sections; Railway shown as abandoned with links to 26109fb and its revert 7b97d03. backend/README.md: new Production and history section (Render, managed delivery gate, Railway abandoned); its Compose inventory was already correct. docs/backend-api.md: route index of all 31 registered routes (6 were not named literally) plus lifecycle limits. docs/technical-overview.md: model sketches now carry lazy, payer and currency fields; fire-and-forget wording replaced by the durable save owner; lifecycle limits and an invite section stating custom scheme only, no Universal Links (no Associated Domains entitlement since 5c684e8) and no deferred invite. docs/market-analysis.md: historical status block and labeled sections. Proven: DocumentationContractTests.test_operational_docs_label_history_and_match_routes_and_signed_capabilities failed on the old docs and fails again when any one of the six documents is restored; gate 44 methods OK; web lint, 110 tests and build. REMAINS, owner or device: the intended public privacy destination (the store links the legacy host, source Settings links the unserved maintained route) is an owner decision; invite behavior is stated from source and entitlements, not from an installed signed build (FEAT-1793644507); Railway resources, database vendor, backups and alerts are unverified (FEAT-1793644501).
- **Docs:** README.md; backend/README.md; backend/roadmap.md; docs/backend-api.md; docs/technical-overview.md; docs/market-analysis.md

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
- **Fix:** Provider/replay frozen/display/zero contracts retained. Mobile corrections independently0/0 APPROVE; root clean467/510. At276 maintained Runner33/33 exact-key/snapshot process-reopen and EUR25/USD31.25 with synthetic loopback is independently accepted Std0/Spec0; OSexit unavailable. 2026-11-09: one currency support matrix in docs/backend-api.md, owned by TestProductionCurrencySupportMatrix (5 subtests); TestPostgresDisplayConversionNeverRewritesFrozenQuote proves stored receipts unchanged under a moving rate, outage, trip display change and finalization; mobile trip display conversion test added. Tests and docs only; currency set and provider unchanged. Remains: owner decision on whole-yen JPY accounting (options in docs/reviews/2026-11-09-currency-matrix.md); odd-cent rule under BUG-1793644500; identity under BUG-1793644505; combined/signed rollout.
- **Docs:** docs/mobile-save-verification.md; docs/reviews/2026-11-04-mobile-save-{reopen,corrections,acceptance}.md; docs/backend-api.md; docs/technical-overview.md; VERIFICATION.md; docs/reviews/2026-11-05-scoped-source-acceptance.md; docs/reviews/2026-11-09-currency-matrix.md
- **Log:**
  - 2026-11-03 Scope: Approved one-adapter/no-TTL decision supersedes old dual-provider/cache proposal. Keep open: display provenance0002; mobile rate decoder/quote state/save/replay/Keychain; required versioned JPY step. Global security/integrated acceptance RED.
  - 2026-11-09 Decision: JPY is still split in hundredths. Whole-yen accounting is a versioned change to the frozen creation contract plus a migration and three clients: not implemented. Options 1-3 in the 2026-11-09 note; recommended: keep and document now, versioned step as its own feature. PEN needs no decision (approved set, both selectors, provider).

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
- **Fix:** Maintained source web-bill-viewer/src/app/(public)/ rechecked against each Expected bullet on 2026-11-09. Already met and now pinned: header, hero and closing actions link straight to https://apps.apple.com/app/id6746379502 (GET ends at the US listing, 200); the hero is a labeled USD example whose items, tax, tip and three shares add up to 128.00 with proportional tax and tip. Fixed: the payment note now says what each named service does (Venmo opens the Venmo app from a shared page; Zelle, Cash App and Apple Pay are details only) and that nothing is processed or confirmed, matching the viewer (only venmo.ts builds a link). Proven: 5 tests in public-claims.test.ts (payment test failed on the old copy; six deliberate breaks of the other four were all detected); web lint, 110 tests and build; gate web row accepted; public-route verifier 6 cases 0 failed; real Tab presses on a local production build gave 14 stops at 1280 px and 13 at 375 px in document order with visible focus; outbound links returned 200. REMAINS, hosted and external: the maintained pages are not served (billingtonapp.vercel.app/ returns 404), and the legacy getbillington.vercel.app home page still sends its primary download to #download, links the store through a /spliq/ slug and claims one-tap deep links to Venmo, Zelle, Apple Pay and Cash App; that host is separately owned and was not touched. Browser check was one engine, home page only, no device or screen reader.
- **Docs:** web-bill-viewer/README.md
- **Log:**
  - 2026-11-09 Verification: Headed browser check of the maintained pages on the local stack at 1440 and 375 px: Billington branding only; 'Get Billington for iOS' reaches apps.apple.com id6746379502 in one click; the hero shows a labelled USD 128.00 example split; payment copy limits itself to the Venmo handoff, shown details and manual paid status; 14 desktop and 13 mobile links are keyboard reachable with a visible focus ring. Screenshots: .vv/ui-inspection-20261109/web/C1-*.png.

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
- [x] **Severity:** med
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
- **Status:** fixed-pending-migration
- **Fix:** Verified on the nine current workflows (2026-11-09). Pins: five actions by full SHA, each an upstream release tag (checkout v5.1.0, setup-go v6.5.0, setup-node v5.0.0, flutter-action v2.23.0, upload-artifact v7.0.2; newest October 7). Tokens: contents read everywhere, actions read on five iOS jobs only. Mirror host key equals GitHub's published Ed25519 key. Every job has a 5 to 60 minute timeout; the PostgreSQL row keeps 30. Validator validate-pipeline.py re-run: 0 errors, 8 warnings before, 5 after. Three warnings were real: testflight, app-store-release and update-release-notes had no group, so repeated dispatches validated in parallel; each now has a per-ref-and-event group that never cancels a run in progress. Five retained warnings are the reusable workflows (checks, deploy-backend, sync-web-viewer, ios-origin, ios-promote): intended, because a called workflow's group is evaluated in its caller's context and can cancel the caller; their mutation jobs serialize on literal noncancelling job groups. ci.yml cancels in progress only for pull requests (hosted runs 42290401669 and 42289112203 cancelled so). New GraphTests.test_execution_settings_are_pinned_bounded_serialized_and_read_only pins groups, tokens, timeouts and action pins with 36 mutations, 14 accepted before (cancelling a running main run, removing a group, a reusable top-level group, a 360-minute timeout, a write token on the resolver). 44 gate, 17 iOS, 5+18 Ruby methods pass; automation row 1,490 records. Diff adds three concurrency blocks and tests only; no trigger, condition, secret or publisher changed and publication stays disabled. Not observed: GitHub's parse of the three edited entry files and real queueing between two dispatches (nothing dispatched); environments, ruleset and credential scope are tracked in BUG-1793644501.
- **Docs:** ops/ci/README.md; VERIFICATION.md; docs/reviews/2026-11-05-delivery-gate.md; docs/reviews/2026-11-09-delivery-workflows.md

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
  - 2026-11-09 Verification: PARTIAL at e0a2c18: static checks pass for both Dockerfiles (static-debian13:nonroot@sha256:25ac8f0c...8329, CGO_ENABLED=0, USER 65532:65532, exec-form HEALTHCHECK); backend/internal/healthcheck: TestProbeResponses 10/10, TestProbeRejectsRedirect, TestProbeTimeout, TestProbeTransportFailure pass, TestServiceHealthcheckMode/web-service pass but TestServiceHealthcheckMode/bill-service FAILED with 'listen tcp 127.0.0.1:8080: bind: address already in use' (environmental, port 8080 held by another project's Docker, not a code verdict); revert check not run: infra/image ticket; unproven: bill-service --healthcheck entrypoint mode on this machine, nonroot runtime, DB TLS, DNS, Docker health outage/recovery, image scans; not run here: scripts/verify_static_runtime.py (no billington-bill:validation or billington-web:validation images for this commit and no BILLINGTON_RUNTIME_TEST_POSTGRES_IMAGE set), hosting NSS

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
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Current readers need no code change: the complete explicit projections already keep cached statements valid. New TestPostgresWarmServiceSurvivesAdditiveDDL proves it on PG17.11: one observed warm PID returns 15 byte-identical API/HTML reads from cached statements (0 prepares, 0 errors) and its writers still commit after a separate session adds a column to all 9 tables; a SELECT * discriminator on that connection fails once with 0A000 then recovers; 7 single-site projection removals each fail the test with a real 500. Mechanism: once per cached statement per pooled connection, self-recovering, no restart. Exact deployed 81a564f binaries across the real adopt+0002+0003 migration: 10/84 sequential and 23/280 burst 500s, then 35/35 OK; terminating idle sessions or restarting gives 0 failures. The delivery gate now rejects a schema-step publish while a revision below capability floor additive_ddl_warm_reader answers /health (46 gate methods pass). REMAINS, external: stop the hosted 81a564f service before the first publish, observe what the host answers for a stopped service and whether its hook starts one, and set that floor in RELEASE_POLICY. Not repaired: bills the old writer creates after 0003 are rejected (409) by the current unversioned reader.
- **Docs:** docs/reviews/2026-11-09-reader-ddl.md; backend/README.md; docs/technical-overview.md; ops/ci/README.md
- **Log:**
  - 2026-11-10 Sighting: 2026-11-10 V&V (5e877e36d968, D5): the production binary 81a564f starts and serves against the upgraded schema (ledger 0001-0003) without refusing. Its AutoMigrate changed nothing, and verify still passes. Bills it writes after the upgrade carry identity_version=1/legacy_review with participant_id NULL, and the new reader returns 409 to header-1 clients for them (an unmerged branch tracks this as BUG-1794264953). The warm new reader kept serving (health 200) throughout. This is an observation, not overlap proof. Local evidence: .vv/worktrees/vv-5e877e3/.vv/d5/logs/08-*.

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
- [x] **Severity:** med
- **Area:** mobile, ui, layout
- **File(s):** mobile/lib/screens/quick_split/item_assignment/item_assignment_screen.dart; mobile/lib/screens/quick_split/bill_entry/bill_entry_screen.dart; mobile/lib/screens/tabs/tab_detail_screen.dart; mobile/test/side_inset_layout_test.dart
- **Observation:** On a native iPhone Duo simulator (Xcode 27.2, iOS 27.1) the Closed display reports right 84pt and bottom 34pt insets. The Scaffold bodies of Assign Items, Enter Bill Details and Tab detail have no horizontal SafeArea, so content runs under the status column: the Assigned amount reads $1 and then the column. Open landscape shows the same collision. Landing, Onboarding and Bill Details already use SafeArea and stay clear.
- **Expected:** Body content stays between the system side insets on every display. The Assigned amount is fully visible, amounts and calculations do not change, the progress bar still shows the assigned share, and displays without side insets keep their full-width layout.
- **Req:** none (found by native Duo capture for App Store screenshots)
- **Depends on:** none
- **Repro / Notes:** Closed pose in Device Hub, Quick Split, four people, $122 with items, Continue to Assign Items. Before evidence: /tmp/appshot-quality-20261105/capture/ios27.2/raw/iphone-duo-outer-1398x2034/03-assign.png. Regression test: mobile/test/side_inset_layout_test.dart. SafeArea alone left the progress bar reading full screen width, so at 50% it overstated the share by 42pt on the Closed display; the bar now sizes from its track.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Horizontal SafeArea/track-relative fill: final19/analyze0 and combined3460 Flutter567visible/573canonicalPASS. Native/default-font/integrated capture pending; separate Finalize overflow not fixed.
- **Docs:** DESIGN_SYSTEM.md; docs/reviews/2026-11-06-{layout-insets,combined-flutter-acceptance}.md; exact19 canonical cases. Separate Finalize short-height overflow remains open.
- **Log:**
  - 2026-11-09 Verification: PASS: 13 named Dart tests in mobile/test/side_inset_layout_test.dart (Assign Items right/left/wide inset keeps text and progress bar, same amounts with or without insets, full width on phone/tablet; Enter Bill Details and Tab detail inset and full-width groups) at e0a2c18; full mobile suite 593 visible pass/0 fail/0 skip; flutter analyze no issues; revert check failed as intended (item_assignment_screen.dart SafeArea left/right disabled: 3 of 6 Assign Items tests failed, file restored, tree clean; Entry and Tab not individually reverted); unproven: none in-repo; not run here: native Duo/default-font capture, separate Finalize overflow
  - 2026-11-09 Verification: Native check on an owned iPhone Duo simulator (iOS 27.1, Closed pose, right status column) with a debug build of 083567a: Enter Bill Details, Assign Items and Tab detail keep their content clear of the column; with half of 122.00 assigned the Assigned amount reads $61.00 in full, 50%, and the bar ends halfway. The Open/landscape pose could not be selected from the command line and was not captured. Screenshots: .vv/ui-inspection-20261109/layout/b2-*.png. The tutorial dialog on Assign Items still extends under the column (BUG filed separately).

### [BUG-1793935715] Keep the Finalize confirmation usable on short displays
- [x] **Severity:** med
- **Area:** mobile, ui, layout
- **File(s):** mobile/lib/screens/tabs/tab_detail_screen.dart (_FinalizeConfirmSheet)
- **Observation:** The retained native capture handoff reports 14px and 21px Finalize sheet overflows on short displays. Current source still caps a non-scroll Column at 70% screen height. The horizontal-body fix does not change this sheet; current native reproduction remains pending.
- **Expected:** All settlement preview rows and Cancel/Finalize actions remain reachable without overflow on short displays and default/large text; keep money, confirmation and finalization behavior unchanged.
- **Req:** none (separate retained native capture finding; DESIGN_SYSTEM.md responsive layout)
- **Depends on:** none
- **Repro / Notes:** Frozen /tmp/appshot-quality-20261105/capture/frozen-layout-milestone/HANDOFF.md, Separate findings; BEFORE frames are f4abc78, not current native proof. Open Tab detail > Finalize on a short display. Source caps maxHeight at 0.7 and uses an unscrollable Column. Body inset tests use textscale0.5 and do not qualify this modal. No fix or new native execution claimed.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** The Finalize sheet now scrolls its heading and settlement rows together and pins Cancel/Finalize below them (scrollbar thumb while scrollable). The 70% height limit stays; displays shorter than about 630 pt may use up to 440 pt or their full height. Above 1.5x text the amount sits under its name and shrinks to fit; action labels shrink instead of wrapping. The modal call moved unchanged into showFinalizeConfirmSheet. Row order, labels, amounts, true/false/null results and the finalize request are unchanged. Proof: mobile/test/finalize_confirm_sheet_test.dart 19 pass (320x568, 375x667, 568x320, 812x375 with side insets at text scale 1.0/2.0/3.0 with 12 rows; real Tab detail Finalize sends one POST, Cancel/dismiss none); 16 of 19 failed with RenderFlex overflow on the previous layout. NOT DONE: native simulator/device capture on a short display (widget-test evidence only).
- **Docs:** DESIGN_SYSTEM.md (Interaction patterns); mobile/test/finalize_confirm_sheet_test.dart
- **Cross-ref:** BUG-1793927492 (separate horizontal body issue, not this sheet)

### [BUG-1793958334] Retain migration producer evidence when activity observation fails
- [x] **Severity:** med
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
- **Status:** fixed-pending-migration
- **Fix:** Test-only outcome holder (already merged) retains the single producer result and cause independently of the activity observer, treats an unreceived or closed channel as unresolved, logs finite evidence and reads rollback only after a join. 2026-11-09 real PostgreSQL qualification, no source change: unmodified TestPostgresMigrationParentDeadline (500 ms caller, 10 s observer, 15 s join, whole-batch rollback, recovery) passes 22 of 22 local -race runs and in hosted Gate postgres runs 42364117584 (0.79s) and 42365246558 (0.95s) on identical backend/migrations bytes; helper family 5/5. Five temporary real-PG controls all fail as required with finite evidence: no pg_sleep, witness absent, observer error (worker DeadlineExceeded retained, rollback empty), unjoined 15.07s (no rollback read), observer timeout 25.11s. Not run here: full eight-package row, integrated protocol. Evidence: docs/reviews/2026-11-09-migration-deadline.md.
- **Docs:** docs/reviews/2026-11-09-migration-deadline.md; docs/reviews/2026-11-06-migration-outcomes.md; ops/ci/README.md; VERIFICATION.md
- **Cross-ref:** FEAT-1793644505
- **Log:**
  - 2026-11-06 Verification: R02 pure helper qualification: four complete compiles/list selections pass, five clean helper leaves pass and all three source removals fail their intended assertions with healthy siblings. Manager independent verification1e3271a4; reportfc98d254. Only seven evidence-field alignment lines changed under gofmt; no test rerun for whitespace. Real500ms/PgSleep/rollback/recovery and historical170s/198.64s/full gates remain open.
  - 2026-11-06 Verification: Local integration static checks: gofmt0 with seven spacing-only evidence fields; complete offline controller42methods/916 method+subtest records PASS including all five exact-child omissions and existing mobile/web named selections; official tracker lint0errors/0warnings. Only PG family+five anchored namespaced child IDs added; ordinary/backend obligations and all inherited fields preserved. Current real PG/full/native gates remain unqualified.
  - 2026-11-09 Verification: Real PostgreSQL qualification executed: parent-deadline test 22/22 local under -race and passing in hosted runs 42364117584 and 42365246558; all seven failure families plus helper 21/21; five temporary controls fail with the expected finite evidence. No test or production source changed.

### [BUG-1793996842] Preserve saved participant colors and readable identity ink
- [x] **Severity:** med
- **Area:** mobile, ui, identity
- **File(s):** mobile/lib/screens/recent_bills/components/participants_card.dart; mobile/lib/screens/quick_split/participant_selection/participant_selection_sheet.dart; mobile/lib/screens/quick_split/item_assignment/utils/color_utils.dart; mobile/lib/screens/quick_split/item_assignment/widgets/participant_avatar.dart; mobile/test/screenshot_quality_test.dart
- **Observation:** At a021, Bill Details derives avatar colors from amount rank instead of the saved occurrence; auto-added owners omit saved custom color, and shared items take the first assignee color. Selected light-theme text/avatar callsites do not derive ink from their actual composited surface. This is a source-confirmed defect; current widget/native behavior is not yet qualified.
- **Expected:** Preserve saved colors for single-person and intentionally same-color rosters, receipt ordinals/refs and recorded values. Bill Details initials use composited ink in both themes; changed light-theme callsites reuse AppTheme.foregroundOn, with other dark branches unchanged. Shared items use the existing neutral palette; auto-added owners reuse saved custom color but receive fresh occurrence refs. Require the exact screenshot_quality_test.dart literals: Bill Details identity uses each saved roster color, not the amount rank; Bill Details identity preserves a single saved roster color; Bill Details identity keeps saved colors when multiple people choose the same color; Person color ink every palette color reads on white and on its own row tint; Person color ink keeps ink that already reads; Person color ink avatar ink meets normal text contrast on every palette color; Person color ink a shared item never takes one person's color; Participant visual controls auto-added owner keeps saved color with fresh occurrence refs. Actual widget and native/capture proof remains pending.
- **Req:** FEAT-1793644509; DESIGN_SYSTEM.md participant occurrence/color guidance
- **Depends on:** none; existing saved occurrence and theme owners
- **Repro / Notes:** Read a021 SortedParticipantsCard rank color selection, participant sheet auto-add and ColorUtils.getDominantColor. Distinct from BUG-1793898429 Settings-only ink. Private R02 formatter/analyzer0; widget loader failed before all106 cases. Offline controller R03 verifies literal-enforcement fixtures only; raw2129dd79/manager8fde2490, not Flutter or screenshot acceptance.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Adopt the exact reviewed nine-lib/T1 source subset with saved-color provenance and existing composited-ink ownership. Automatic Linux mobile is the selected functional route;588 canonical records EXPECTED only. No native, physical accessibility,95-quality or release acceptance.
- **Docs:** docs/reviews/2026-11-06-ui-quality-candidate.md; DESIGN_SYSTEM.md; mobile/README.md
- **Cross-ref:** FEAT-1793644509 (acceptance and status unchanged)
- **Log:**
  - 2026-11-09 Verification: PASS: 8 required literals present and passing in mobile/test/screenshot_quality_test.dart (3 Bill Details identity, 4 Person color ink, Participant visual controls auto-added owner keeps saved color with fresh occurrence refs) at e0a2c18; full mobile suite 593 visible pass/0 fail/0 skip; revert check not run: multi-file source change; unproven: that changed light-theme callsites reuse AppTheme.foregroundOn (source review only, no test asserts it); not run here: native/capture, accessibility
  - 2026-11-09 Verification: Native check (iPhone 17, iOS 27.2): six people keep the avatar colour they were given when added, in Bill Details after save and after force-quit and relaunch. Screenshots: .vv/ui-inspection-20261109/main/A2-*.png, A3-07-relaunch-detail.png.

### [BUG-1793996843] Show four actual assignees before avatar overflow
- [x] **Severity:** med
- **Area:** mobile, ui, layout
- **File(s):** mobile/lib/screens/quick_split/item_assignment/widgets/item_card.dart; mobile/test/screenshot_quality_test.dart
- **Observation:** At a021, ItemCard limits its collapsed assignee stack to three avatars whenever more than three people are assigned, so a four-person item shows three initials plus +1. The source geometry also uses 12pt steps for 20pt avatars. No current widget/native result is asserted.
- **Expected:** Four assignees show all four real avatars without +1; above four, show three real avatars and the correct remaining-person count. Preserve receipt ordinals/refs, assignments, amounts, toggles and other app behavior. Require exact literals Assignee stack shows four people instead of a +1 and Assignee stack summarises everyone past four. Default/enlarged-text widget and later pinned native/capture proof remain pending.
- **Req:** FEAT-1793644509; DESIGN_SYSTEM.md participant occurrence/color guidance
- **Depends on:** none; existing saved occurrence and theme owners
- **Repro / Notes:** Read a021 ItemCard._buildAssigneeAvatars displayPeople and overflow conditions. No existing tracker covers this source defect; unrelated Settings targets and Finalize overflow remain separate. All106 affected widget cases are unstarted; R03 offline omission checks are delivery-gate controls only.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Adopt exact reviewed hasOverflow >4 and four-slot stack geometry, preserving the full assigned list. No runtime, physical-device,95-quality or screenshot recovery claim.
- **Docs:** docs/reviews/2026-11-06-ui-quality-candidate.md; DESIGN_SYSTEM.md; mobile/README.md
- **Cross-ref:** FEAT-1793644509 (acceptance and status unchanged)
- **Log:**
  - 2026-11-06 CI proof correction: Automatic CI42289112203/mobile128137633416 at a962 failed the overflow test global A finder after four CircleAvatar and +2 checks passed: it matched the11px avatar and18px other item content. This is a test-proof scope defect, not a demonstrated production UI defect. Apply exact09e54ebc correction to scope all ABC/+2/noD finders to CircleAvatar descendants, retaining every assertion and literal ID; no local test/formatter or retry. Corrective source-triggered CI acceptance remains pending; status in-progress and native/capture/quality limits unchanged. See docs/reviews/2026-11-06-ui-quality-candidate.md.
  - 2026-11-09 Verification: PASS: both required literals present and passing (Assignee stack shows four people instead of a +1; Assignee stack summarises everyone past four) in mobile/test/screenshot_quality_test.dart at e0a2c18; full mobile suite 593 visible pass/0 fail/0 skip; revert check failed as intended (item_card.dart hasOverflow >4 to >3: shows four people test failed, file restored, tree clean); unproven: enlarged-text avatar behaviour, preservation of toggles/amounts beyond the two named tests; not run here: native/capture
  - 2026-11-09 Verification: Native check (iPhone 17, iOS 27.2): an item assigned to four people shows four real avatars and no +1; an item assigned to six shows three avatars and +3. Screenshot: .vv/ui-inspection-20261109/main/A2-04-assigned.png.

### [BUG-1794045425] Preserve accounting availability for accepted fractional receipts
- [x] **Severity:** high
- **Area:** backend, accounting
- **File(s):** backend/internal/bill/accounting.go; backend/internal/bill/creation_repository.go; backend/internal/bill/accounting_creation_regression_test.go
- **Observation:** SPEC-001: actual CreateBill accepts 18.50 subtotal + 2.775 tip /21.275 total but saved21.28 fails the stricter frozen-share audit; documented one-cent tolerance also reproduces.
- **Expected:** Use the maintained accounting tolerance at creation and frozen allocation; genuinely partial claims are never scaled up. Reject malformed, overallocated or invalid foreign evidence before persistence; preserve valid legacy/fresh-reference inputs.
- **Req:** docs/backend-api.md accounting and identity contracts; docs/technical-overview.md durable history/read-failure contracts
- **Depends on:** none; independent postmerge regression
- **Repro / Notes:** Real creation + persistence-preflight regressions failed before the fix; affected bill/tab -race row now532 named PASS. Actual PG/finalization/whole V&V remain pending.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Implemented aligned creation/frozen-share tolerance and pre-insert share audit; manager combined-scope source review accepted. Actual affected bill/tab Go race row:532 named PASS, with original red regressions retained. Status remains in-progress; real PostgreSQL persistence/finalization, current CI and integrated V&V remain pending.
- **Docs:** docs/reviews/2026-11-07-postmerge-money-client-regressions.md
- **Log:**
  - 2026-11-09 Verification: PASS: 4 named Go tests incl 22 subtests (TestCreationRoundingRemainsAccountable 6/6 incl documented_one_cent_tolerance; TestCreationInsertAuditsShares 9/9 incl partial_below_half_cent, overallocated, malformed_foreign_audit, legacy_full, fresh_reference_input; TestCreationRejectsToleranceAmplificationBeforeProviders; TestCreationToleranceHTTPBeforeProviders) in backend/internal/bill at e0a2c18; PG-tagged ./internal/bill also 66 top-level pass/0 fail/0 skip; revert check failed as intended (accounting.go tolerance to .005: 3 RoundingRemainsAccountable subtests failed, file restored, tree clean); unproven: none; not run here: current CI, integrated V&V
  - 2026-11-09 Status: 2026-11-09 sweep: real PostgreSQL selections and hosted CI run for PR #173 (all six rows, PostgreSQL included) pass with this fix; status moved to fixed-pending-migration for the integrated V&V run.

### [BUG-1794045426] Keep negative cent remainders off zero obligations
- [x] **Severity:** med
- **Area:** backend, accounting
- **File(s):** backend/internal/bill/shares.go; backend/internal/bill/creation_correction_test.go; backend/internal/bill/accounting_creation_regression_test.go
- **Observation:** SPEC-002: real creation derives Alice tax=-0.01 for the .10/30 +1.01 tax split, or rejects a valid zero-total participant split.
- **Expected:** Debit only positive balances in existing claim/name priority, preserve signed discount lines and zero participants, bound work independently of cent count, and reject insufficient/invalid balances rather than persist negatives.
- **Req:** docs/backend-api.md accounting and identity contracts; docs/technical-overview.md durable history/read-failure contracts
- **Depends on:** none; independent postmerge regression
- **Repro / Notes:** Both real creation triggers failed before correction. Positive/negative priority controls, huge bounded counts, signed-discount creation and independent small one-cent oracle pass in the affected Go row. Existing historical negative rows are not rewritten.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Implemented bounded negative-cent deductions from eligible positive balances in claim/name order, preserving zero shares and signed discounts. Manager combined-scope source review accepted; affected Go race532 PASS includes bounded-count and independent small-oracle controls. No historical amount rewrite. Status remains in-progress; real PG/current CI/integrated V&V remain pending.
- **Docs:** docs/reviews/2026-11-07-postmerge-money-client-regressions.md
- **Log:**
  - 2026-11-09 Verification: PASS: 3 named Go tests (TestCreationRemaindersPreserveZeroShares 2/2; TestCentRemaindersPreserveClaimAndNameOrder 7/7; TestRemainderDistributionIsBoundedForExtremeCounts 8/8) plus TestCreationRoundingRemainsAccountable/signed_discount_remains_accountable in backend/internal/bill at e0a2c18; revert check failed as intended (shares.go naive cyclic decrement: 8 subtests failed across the three tests, file restored, tree clean); unproven: none; not run here: current CI, integrated V&V
  - 2026-11-09 Status: 2026-11-09 sweep: real PostgreSQL selections and hosted CI run for PR #173 (all six rows, PostgreSQL included) pass with this fix; status moved to fixed-pending-migration for the integrated V&V run.

### [BUG-1794045427] Import complete Trip history atomically at capacity
- [x] **Severity:** high
- **Area:** mobile, persistence, tabs
- **File(s):** mobile/lib/database/database.dart; mobile/lib/screens/recent_bills/models/recent_bill_manager.dart; mobile/lib/screens/tabs/tab_detail_screen.dart; mobile/test/tab_import_capacity_test.dart
- **Observation:** SP-1: real Drift31-row import evicts an earlier returned ID; later existing target is evicted, and parse failure leaves prior refresh committed. Read failures can silently look empty or escape into permanent loading.
- **Expected:** Retain cap30 and all pending/referenced/current-pass IDs. Import plus local tab-ID checkpoint commits together or rolls back. Every read/cache/parse failure clears loading, offers retry and withholds partial balance/finalize claims.
- **Req:** docs/backend-api.md accounting and identity contracts; docs/technical-overview.md durable history/read-failure contracts
- **Depends on:** none; independent postmerge regression
- **Repro / Notes:** Before-fix real Drift and widget assertions fail; after-fix related Flutter116 visible PASS, including30/31, separate pending/referenced history, checkpoint rollback and error/retry controls. No migration or remote receipt deletion.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Implemented atomic complete Trip import plus local-ID checkpoint, protected incoming/pending/referenced history, and finite loading/error/retry with no partial balances. Manager combined-scope review accepted. Retained affected Flutter116 PASS; later completion-witness correction separately passes10 focused cases, without repeating116. Status remains in-progress; current CI/real PG/integrated V&V remain pending.
- **Docs:** docs/reviews/2026-11-07-postmerge-money-client-regressions.md
- **Log:**
  - 2026-11-09 Verification: PASS: 10 named Dart tests in mobile/test/tab_import_capacity_test.dart (30/31 cap, pending/referenced history, later existing target, malformed rollback, read-error retry, checkpoint rollback, invalid IDs, retry without partial balances) at e0a2c18; full mobile suite 593 visible pass/0 fail/0 skip; revert check failed as intended (database.dart _makeReceiptRoom ignores protectedReceiptIds: 5 of 10 failed, file restored, tree clean); unproven: none; not run here: real PG, current CI
  - 2026-11-09 Verification: Native check (owned iPhone 17 simulators, iOS 27.2, local stack): a fresh install joined a 30-receipt trip and showed 30 bills, 765.00 and balances, unchanged after relaunch. Joining a 31-receipt trip afterwards ended loading with the cache message and 'Retry current history', showed no partial list, balances or Finalize, repeated the message on retry, and left the 30-receipt trip intact. On another device the earlier bills and the tab referencing one of them survived the refused import. Screenshots: .vv/ui-inspection-20261109/recheck/E2-*.png, E3-*.png.

### [BUG-1794045428] Stamp durable receipts at their actual insertion time
- [x] **Severity:** med
- **Area:** mobile, persistence
- **File(s):** mobile/lib/database/database.dart; mobile/test/receipt_timestamp_test.dart
- **Observation:** SP-4: omitted createdAt uses the historical Drift9 table literal1793912155 rather than receipt insertion time.
- **Expected:** New durable receipts have an explicit insertion timestamp when omitted; explicit timestamps/existing handles remain unchanged. Do not backfill historical rows under this fix.
- **Req:** docs/backend-api.md accounting and identity contracts; docs/technical-overview.md durable history/read-failure contracts
- **Depends on:** none; independent postmerge regression
- **Repro / Notes:** The maintained historical-schema SQLite fixture fails before the fix and passes afterward within the affected Flutter row. Schema version10 and migration files remain unchanged.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Implemented explicit new durable-receipt insertion timestamp, preserving existing handles and historical rows without migration/backfill. Manager combined-scope source review accepted; historical Drift9-default regression passes in retained affected Flutter116 row. No repeat row after test-only witness correction. Status remains in-progress; current CI/real PG/integrated V&V remain pending.
- **Docs:** docs/reviews/2026-11-07-postmerge-money-client-regressions.md
- **Log:**
  - 2026-11-09 Verification: PASS: 1 named Dart test (new receipt uses insertion time instead of historical table default) in mobile/test/receipt_timestamp_test.dart at e0a2c18; revert check failed as intended (database.dart insertReceipt without copyWith createdAt: test failed at line 22, file restored, tree clean); unproven: explicit createdAt preserved (no named test; only the omitted-createdAt path is asserted) and existing-handle unchanged (not asserted by this test); not run here: current CI
  - 2026-11-09 Verification: Added the two missing proofs to mobile/test/receipt_timestamp_test.dart: an explicit createdAt is stored unchanged, and presenting an existing creation handle returns its row and rewrites nothing. Two revert checks fail as intended (always-overwrite: expected 2020-01-02 03:04:05, got now; no existing-handle return: UNIQUE constraint on creation_handle).
  - 2026-11-09 Status: 2026-11-09 sweep: real PostgreSQL selections and hosted CI run for PR #173 (all six rows, PostgreSQL included) pass with this fix; status moved to fixed-pending-migration for the integrated V&V run.

### [BUG-1794045429] Retain browser join input across refreshed bill graphs
- [x] **Severity:** med
- **Area:** web, identity
- **File(s):** web-bill-viewer/src/components/LazyBillBoard.tsx; web-bill-viewer/src/components/__tests__/LazyBillSession.test.ts
- **Observation:** SP-2: participant-array refresh re-runs a combined selection/suggestion/recovery effect, erasing typed or deliberately empty join input and repeating membership recovery.
- **Expected:** Selection follows current participant graph; suggestion seeding follows bill/tab identity; recovery follows tab/token identity. Successful recovery clears only its own warning and preserves unrelated errors.
- **Req:** docs/backend-api.md accounting and identity contracts; docs/technical-overview.md durable history/read-failure contracts
- **Depends on:** none; independent postmerge regression
- **Repro / Notes:** Exact manager patch b6c3240d: baseline4/4 intended failures, fixed4/4 PASS, maintained web102/102. Integrated actual component hook/handler4/4 PASS plus TypeScript/Biome0; no browser-pixel or service claim.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Integrated exact manager SP-2 selection/suggestion/recovery ownership correction; manager combined-scope source review accepted. Integrated actual component/handler4 PASS, TypeScript/Biome0; retained manager whole-web102 row remains separate evidence. Status remains in-progress; full current CI, real PG and integrated V&V remain pending.
- **Docs:** docs/reviews/2026-11-07-postmerge-money-client-regressions.md
- **Log:**
  - 2026-11-09 Verification: PASS: 4 named Vitest tests in web-bill-viewer/src/components/__tests__/LazyBillSession.test.ts at e0a2c18; whole web suite 102 pass/0 fail/0 skip; revert check failed as intended (suggestion effect re-keyed on bill.participants: 2 of 4 failed, file restored, tree clean; recovery-ownership test not isolated by that revert); unproven: none; not run here: browser pixels, current CI
  - 2026-11-09 Status: 2026-11-09 sweep: real PostgreSQL selections and hosted CI run for PR #173 (all six rows, PostgreSQL included) pass with this fix; status moved to fixed-pending-migration for the integrated V&V run.
  - 2026-11-09 Verification: Headed browser check on the local stack: on a tab page with a lazy receipt, 'Samantha Q' typed into 'What should we call you?' survived a participant added through the API and the page's own 10-second refresh; a cleared field stayed empty; no recovery warning. A full browser reload discards unsubmitted text, which the ticket does not cover. Screenshots: .vv/ui-inspection-20261109/web/C4b-*.png.

### [BUG-1794258285] Repair the invalid iOS origin workflow file
- [ ] **Severity:** med
- **Area:** ci, delivery
- **File(s):** .github/workflows/ios-origin.yml; ops/ci/test_delivery_gate.py; ops/ci/test_ios_artifact.py
- **Observation:** GitHub rejects ios-origin.yml on every push since fc98e85 (2026-11-05): run 42365245707 on main 5e877e3 reports `Invalid workflow file: .github/workflows/ios-origin.yml#L1 (Line: 60, Col: 16): Unrecognized named-value: 'runner'. Located at position 1 within expression: runner.temp`, repeated for Line 61 and Line 62. Job-level env IPA_DIR/RECEIPT_DIR/ASC_RECEIPT use the runner context, which GitHub does not provide at jobs.<job_id>.env. The run has zero jobs; main runs 42359771109 and 42365245707 and every branch push fail the same way. The 42 controller methods pass on this file, so no offline control sees it.
- **Expected:**
  - ios-origin.yml parses: every expression uses only the contexts GitHub documents for its workflow key, and a controller test fails on the current file.
  - A push to main no longer creates a failed run for ios-origin.yml (hosted, observable only after merge).
  - testflight.yml still calls ios-origin.yml with the same inputs and six named secrets; the three paths keep their values for the steps that read them.
  - No iOS path in this workflow graph can sign or upload while RELEASE_POLICY is unset: the origin job stays main-dispatch-only and authorizes before toolchain, signing or upload.
- **Req:** none (found in the 2026-11-09 sweep; SR GATE/RELEASE; TR engineering 4)
- **Depends on:** none
- **Repro / Notes:** `gh run view 42365245707`; `gh api repos/LLRHook/checksinmyhead/actions/runs/42365245707` (event push, conclusion failure, no jobs); the run page annotation carries the message above. Context table: docs.github.com Actions contexts reference, Context availability. actionlint is not installed here. Until fixed, a TestFlight dispatch cannot start its reusable origin job either.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** in-progress
- **Fix:** Source fix complete; hosted confirmation open. The three runner.temp paths moved, values unchanged, from job env to the env of the steps that read them (signed-IPA action, upload, receipt). New GraphTests.test_workflow_expressions_use_only_documented_contexts applies GitHub's context-availability table and reusable-call contract to all nine workflows: it fails on the e0a2c18 file with Unrecognized named-value 'runner' at jobs.origin.env.IPA_DIR and passes now (28 rejected mutations, 4 accepted controls). validate_ios_graph binds each path to its reading steps and the authority step third and unconditional (7 mutations); each iOS target refuses empty, absent or disabled RELEASE_POLICY before any authenticated read. 43 gate, 17 iOS and 5+18 Ruby methods pass; automation row 1,422 records, 0 failed or skipped. testflight.yml call, inputs and six secrets unchanged. REMAINS: GitHub's own parse is unobserved until the first push carrying this file; accept when that push creates no failed ios-origin.yml run, then set fixed-pending-migration. actionlint not installed; nothing dispatched.
- **Docs:** ops/ci/README.md; docs/reviews/2026-11-09-delivery-workflows.md

### [BUG-1794331908] Show member devices that a shared tab was finalized
- [x] **Severity:** high
- **Area:** mobile, tabs
- **File(s):** mobile/lib/screens/tabs/tab_manager.dart; mobile/lib/screens/tabs/tab_detail_screen.dart; mobile/test/member_tab_finalization_test.dart; ops/ci/case_manifest.json; docs/technical-overview.md
- **Observation:** After the creator finalized a shared tab, a member's device kept showing it as open: no finalized badge, no settlements, and Add Receipt still opened bill entry. This persisted after re-fetch and after kill/relaunch on iPhone 17e (iOS 27.2); the creator's device was correct. The only writer of the local finalized flag is the creator's finalizeTab() path (tab_manager.dart:227); remote refresh never imports the server's finalized state.
- **Expected:** Every member device shows a tab as finalized once the server reports it finalized: the badge and settlements are shown, and receipt entry is closed.
- **Req:** VERIFICATION.md Stage 3 (trip attach, refresh mobile/web, finalize); docs/backend-api.md Finalization & Settlements
- **Depends on:** none
- **Repro / Notes:** Local evidence (gitignored) from the 2026-11-10 V&V run of 5e877e36d968, worktree .vv/worktrees/vv-5e877e3: .vv/gui-walkthrough/ios/17e-08..10 and NOTES.md. Steps: creator and member join the same tab on two simulators; creator finalizes; on the member device pull/refresh, then force-quit and relaunch.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Persist literal server finalized=true during member refresh, before membership or receipt processing, and on new and existing-member joins; never clear finalized from stale or failed reads. A re-join of a tab already on the device keeps the saved tab when the tab read fails. Use the existing server settlement history and refuse receipt entry on a finalized tab: Add Receipt re-reads the saved state first, the add-existing picker re-checks after a selection, and the receipt owner sees persisted finalization for pending attachments. mobile/test/member_tab_finalization_test.dart: 14 fake-API, real-Drift and widget cases cover refresh, exact settlements, offline file reopen, stale, failed and malformed reads, a stale open screen, removed membership, joins (literal true only; failed tab read), the picker race, pending saves and creator behavior. Full mobile suite at this change: 640 passed, none failed or skipped.
- **Docs:** docs/technical-overview.md documents server-confirmed one-way finalization, server settlements and receipt-entry guards; HTTP contract and Drift schema unchanged.

### [BUG-1794331909] Keep the landing and Join a Tab screens usable at accessibility text sizes
- [x] **Severity:** high
- **Area:** mobile, a11y
- **File(s):** mobile/lib/screens/landing_screen.dart; mobile/lib/screens/tabs/tabs_screen.dart
- **Observation:** At the accessibility-extra-extra-extra-large content size (iPhone 17e, iOS 27.2) the landing screen overflows: RenderFlex overflow stripes, the bottom ~202 px is cut off and Tabs/Recent Bills are unreachable. The Join a Tab title also overflows (WCAG 1.4.4).
- **Expected:** Both screens reflow or scroll at every supported text size, with all controls reachable.
- **Req:** VERIFICATION.md Stage 3 (iOS large text); WCAG 2.2 1.4.4
- **Depends on:** none
- **Repro / Notes:** Local evidence (gitignored) from the 2026-11-10 V&V run of 5e877e36d968, worktree .vv/worktrees/vv-5e877e3: .vv/gui-walkthrough/ios/17e-01-landing-ax-xxxl.png, 17e-03-invite-landed.png. Steps: xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large, then launch the debug app.
- **Bump:** patch
- **Assignee:** Victor Ivanov
- **Status:** fixed-pending-migration
- **Fix:** Preserve the landing column spacing with a scrollable SliverFillRemaining and wrap its action labels; constrain the shared Join a Tab title and scroll its form above the keyboard within safe insets. Cover both toolbar and invite entry with 54 widget regressions on 320x568 and 390x844 displays at every iOS scale from 1 to 53/17, including keyboard and invalid/valid submit boundaries.
- **Docs:** none; existing design, architecture and API documentation remains accurate; no contract or copy changes.
- **Cross-ref:** FEAT-1793644512

### [BUG-1794331910] Reject NUL characters in names with 400 instead of 500
- [ ] **Severity:** med
- **Area:** backend, api, validation
- **File(s):** backend/internal/bill/create_request.go; backend/internal/tab/handler.go; backend/internal/tab/participants.go
- **Observation:** A name containing U+0000 returns 500 {"error":"an internal error occurred"}. Affected fields: bill, item and participant names on POST /api/bills, the tab name on POST /api/tabs, and display_name on POST /api/tabs/:id/join. Other control characters are accepted. No database text leaks into the response.
- **Expected:** Input validation rejects NUL (and any text PostgreSQL cannot store) with the documented 400 error format before it reaches the database.
- **Req:** docs/backend-api.md Error Format and HTTP resource policy; VERIFICATION.md Stage 4 (malformed input)
- **Depends on:** none
- **Repro / Notes:** Local evidence (gitignored) from the 2026-11-10 V&V run of 5e877e36d968, worktree .vv/worktrees/vv-5e877e3: .vv/stage4-adv/evidence-nul-500.jsonl. curl -X POST localhost:8080/api/tabs -H 'Content-Type: application/json' -H 'X-Billington-Identity-Version: 2' -d '{"name":"a\u0000b","creator_display_name":"VV"}' returns 500.
- **Bump:** patch
- **Status:** open

### [BUG-1794331911] Fix web viewer accessibility gaps on private bill pages
- [ ] **Severity:** med
- **Area:** web, a11y
- **File(s):** web-bill-viewer/src/app/globals.css; web-bill-viewer/src/components/PersonShare.tsx; web-bill-viewer/src/components/RecordedShares.tsx
- **Observation:** On /b Quick Split pages: the per-row expand buttons have no accessible name (WCAG 4.1.2). Secondary text (--text-secondary #86868b) measures 3.33, 3.62 and 4.35:1 on the page surfaces (1.4.3). Headings skip from h1 to h3 (1.3.1). Private pages share the generic 'Billington' title (2.4.2). Keyboard order and focus rings were fine.
- **Expected:** Named controls, text contrast of at least 4.5:1, sequential heading levels and descriptive page titles on private bill and tab pages.
- **Req:** VERIFICATION.md Stage 3 (browser keyboard/focus/contrast); WCAG 2.2 AA
- **Depends on:** none
- **Repro / Notes:** Local evidence (gitignored) from the 2026-11-10 V&V run of 5e877e36d968, worktree .vv/worktrees/vv-5e877e3: .vv/gui-walkthrough/web/01, web/12 and NOTES.md (headed Chrome via agent-browser). axe and 320 px reflow were not run.
- **Bump:** patch
- **Status:** open
- **Cross-ref:** FEAT-1793644512

### [BUG-1794331912] Show half-cent bill totals the same way their shares add up
- [ ] **Severity:** med
- **Area:** mobile, web, accounting
- **File(s):** mobile/lib; web-bill-viewer/src/components; backend/pkg/models/bill.go
- **Observation:** A bill whose stored total is 24.885 renders as $24.88 on the phone summary, in Recent Bills and on the web page. Its shares sum to $24.89, and the containing tab total shows $24.89. Money is carried as float64/double end to end, so a half-cent total rounds down in display.
- **Expected:** One cent-exact total per bill (whole cents), so every surface shows the same total that the shares and tab sum to.
- **Req:** VERIFICATION.md Stage 5 (conserved cent totals)
- **Depends on:** none
- **Repro / Notes:** Local evidence (gitignored) from the 2026-11-10 V&V run of 5e877e36d968, worktree .vv/worktrees/vv-5e877e3: .vv/gui-walkthrough/NOTES.md (bill 66); $10 item split 3.33x3. Related symptom on an unmerged branch: BUG-1794264955 (device vs published odd cents).
- **Bump:** patch
- **Status:** open

### [BUG-1794331913] Align the VERIFICATION.md recipe with CI and the local viewer
- [ ] **Severity:** med
- **Area:** docs, ci, tests
- **File(s):** VERIFICATION.md
- **Observation:** Appendix A never sets CORS_ORIGINS, so the 3100 viewer's browser calls to the 8080 API fail CORS preflight (403) and the Stage 3 browser journeys cannot run on a fresh stack. The Gate and iOS Python rows use plain python3, while CI uses a hash-locked CPython 3.12 venv; the PyYAML hash is for Ubuntu x86_64 only. The iOS row gives the report commands only as a link. The PG DSN example omits the password CI uses. Row D5 says 'follow FEAT-1793644505', which will not resolve once that entry migrates.
- **Expected:** The recipe runs end to end on a fresh stack: the viewer origin is allowed, interpreter/dependency parity with CI is stated (including the macOS wheel exception), the commands are inline, and the D5 row points at the durable procedure in backend/README.md.
- **Req:** protocol-v-and-v command fidelity; VERIFICATION.md Stage 0/2/3
- **Depends on:** none
- **Repro / Notes:** Local evidence (gitignored) from the 2026-11-10 V&V run of 5e877e36d968, worktree .vv/worktrees/vv-5e877e3: .vv/stage1-review/command-fidelity.md, doc-sync.md; .vv/gui-walkthrough/cors.override.yml was needed to run the viewer journeys.
- **Bump:** patch
- **Status:** open

### [BUG-1794331914] Stop telling clients to retry participant additions on bills with paid shares
- [ ] **Severity:** low
- **Area:** backend, api
- **File(s):** backend/internal/bill/identity.go
- **Observation:** POST /api/bills/:id/participants on a bill with any paid share returns 409 identity_revision_conflict ('refresh and try again') even at the current expected_revision. The block itself is documented (unpaid eligibility), but no retry can succeed.
- **Expected:** A distinct, non-retryable error code/message stating that participants cannot be added after a share is paid.
- **Req:** docs/backend-api.md Participant-reference contract
- **Depends on:** none
- **Repro / Notes:** Local evidence (gitignored) from the 2026-11-10 V&V run of 5e877e36d968, worktree .vv/worktrees/vv-5e877e3: .vv/stage4-adv/evidence-paid-add-participant.jsonl. Create a wire2 bill, PATCH a share paid, then POST participants with the current expected_revision.
- **Bump:** patch
- **Status:** open

### [BUG-1794331915] Apportion tax and tip the same way for partial claims on every route
- [ ] **Severity:** low
- **Area:** backend, accounting
- **File(s):** backend/internal/bill
- **Observation:** With 2 x 49.5% claims on a 40.00/4.00/6.00 bill, the non-lazy assignment route derives 24.80 each (49.60) while the lazy claim route derives 24.75 each (49.50). Sending either projection back is rejected with 400 invalid bill content. The mobile client blocks more than 0.01 unassigned, so only API clients reach this.
- **Expected:** One documented apportionment rule for partial assignments across routes, matching the mobile formula.
- **Req:** docs/backend-api.md Bills / Reference claims
- **Depends on:** none
- **Repro / Notes:** Local evidence (gitignored) from the 2026-11-10 V&V run of 5e877e36d968, worktree .vv/worktrees/vv-5e877e3: .vv/stage4-adv/evidence-partial-apportion.jsonl.
- **Bump:** patch
- **Status:** open

### [BUG-1794331916] Document that receipt uploads are typed by content, not the declared MIME type
- [ ] **Severity:** low
- **Area:** docs, api
- **File(s):** docs/backend-api.md; backend/internal/receipt/handler.go
- **Observation:** docs/backend-api.md:782 lists accepted MIME types, but the service detects the type from the bytes and ignores the declared part type. PNG bytes declared text/plain are parsed, and an image/svg+xml part is reported as 'unsupported image type: text/plain'.
- **Expected:** The API reference states that the type is detected from content and what error each mismatch returns.
- **Req:** docs/backend-api.md Receipt Parsing
- **Depends on:** none
- **Repro / Notes:** Local evidence (gitignored) from the 2026-11-10 V&V run of 5e877e36d968, worktree .vv/worktrees/vv-5e877e3: .vv/stage4-adv/summary.md (class L).
- **Bump:** patch
- **Status:** open

### [BUG-1794331917] Fail the local workflow SIGINT tests with a clear prerequisite when SIGINT is ignored
- [ ] **Severity:** low
- **Area:** tests, tooling
- **File(s):** scripts/test_local_workflow.py; scripts/test_local_workflow_probes.py
- **Observation:** When the parent process ignores SIGINT (e.g. rows started under '( ... ) &' in a non-interactive shell, where Python reports SIG_IGN), test_int_keeps_status130, test_int_during_blocked_simulator_probe_reaps_descendants and test_tty_driver_int_interrupts_foreground_flutter fail with timeouts or rc 0. With SIGINT at its default, the same row passes 55/55.
- **Expected:** The tests restore the default SIGINT disposition for their children, or fail immediately with an explicit prerequisite message.
- **Req:** VERIFICATION.md Stage 2 (no environment-dependent failures)
- **Depends on:** none
- **Repro / Notes:** Local evidence (gitignored) from the 2026-11-10 V&V run of 5e877e36d968, worktree .vv/worktrees/vv-5e877e3: .vv/local-gate/s2-local-workflow.run1-sigint-ignored.log versus s2-local-workflow-rerun.log. ( python3 ops/ci/unittest_report.py scripts/test_local_workflow.py ) & wait
- **Bump:** patch
- **Status:** open

### [BUG-1794331918] Resume or explain membership when rejoining a tab removed from this device
- [ ] **Severity:** low
- **Area:** mobile, ux, identity
- **File(s):** mobile/lib/screens/tabs/tab_manager.dart
- **Observation:** After 'Remove from this device', opening the same invite link again created a second member (role member) for the same person instead of resuming the stored membership. Everyone in the tab then sees a duplicate person. The API returns the existing membership (200) when a valid member token is supplied, and docs/privacy.md says local removal need not erase stored credentials.
- **Expected:** If the device still holds the member credential, rejoin resumes that membership; otherwise the app says that joining again adds a new member.
- **Req:** docs/privacy.md Local removal; docs/backend-api.md POST /api/tabs/:id/join
- **Depends on:** none
- **Repro / Notes:** Local evidence (gitignored) from the 2026-11-10 V&V run of 5e877e36d968, worktree .vv/worktrees/vv-5e877e3: .vv/gui-walkthrough/ios/43 and NOTES.md (member 58).
- **Bump:** patch
- **Status:** open

### [BUG-1794331919] Disambiguate same-named people in web tab balances
- [ ] **Severity:** low
- **Area:** web, ux
- **File(s):** web-bill-viewer/src/components/NetBalances.tsx
- **Observation:** The web tab BALANCES list shows rows such as 'Alex -> Alex' and 'Vic Sim17 -> Vic Sim17' for distinct people with the same display name, with no reference or suffix to tell them apart.
- **Expected:** Balance rows distinguish same-named members (for example with the participant reference or a stable suffix), as the identity contract requires for two people called Alex.
- **Req:** VERIFICATION.md D1 (two distinct people called Alex); BUG-1793644505 expectations
- **Depends on:** none
- **Repro / Notes:** Local evidence (gitignored) from the 2026-11-10 V&V run of 5e877e36d968, worktree .vv/worktrees/vv-5e877e3: .vv/gui-walkthrough/web/16.
- **Bump:** patch
- **Status:** open
- **Cross-ref:** BUG-1793644505

### [BUG-1794331920] Keep the Add Receipt button off the last per-person rows
- [ ] **Severity:** low
- **Area:** mobile, ui
- **File(s):** mobile/lib/screens/tabs/tab_detail_screen.dart
- **Observation:** On the tab detail screen the floating Add Receipt button covers the last Per Person rows, and the empty state lowercases the tab name.
- **Expected:** Scrollable content clears the floating button, and the empty state shows the tab name as entered.
- **Req:** VERIFICATION.md Stage 3 (GUI walkthrough)
- **Depends on:** none
- **Repro / Notes:** Local evidence (gitignored) from the 2026-11-10 V&V run of 5e877e36d968, worktree .vv/worktrees/vv-5e877e3: .vv/gui-walkthrough/ios/17e-10, ios/22.
- **Bump:** patch
- **Status:** open

### [BUG-1794501894] Configure delivery so main can publish and the iOS upload workflow can run
- [ ] **Severity:** high
- **Area:** delivery, ci, release
- **File(s):** .github/workflows/ci.yml; .github/workflows/testflight.yml; ops/ci/delivery_gate.py; ops/ci/README.md
- **Observation:** The repository has no Actions variable RELEASE_POLICY, no ios-upload environment and no DELIVERY_* secrets; only the legacy secret names exist and the workflows read no legacy fallback. Every push to main therefore skips publish-backend and publish-web, and testflight.yml cannot authorize. On 2026-11-12 production API /health reported commit 81a564f while main was 124 commits ahead, including the Go 1.27.4 fix for GO-2026-6859.
- **Expected:** RELEASE_POLICY defines the web, backend and ios-upload targets with their floors and external clearance as ops/ci/README.md specifies; the ios-upload environment and the DELIVERY_* secrets exist; a push to main with the policy enabled publishes, and /health reports the published commit.
- **Req:** none; ops/ci/README.md delivery requirements (driver run simplify-1111, FINDING-1)
- **Depends on:** none
- **Repro / Notes:** gh api repos/LLRHook/checksinmyhead/actions/variables returns total_count 0; environments total_count 0. CI runs 43243346772 to 43254449850 on main: publish-backend and publish-web skipped; the resolve job log shows RELEASE_POLICY empty. Deploying the backend is tied to the old-client compatibility bugs BUG-1793644505 and BUG-1793644511.
- **Bump:** patch
- **Status:** open

### [BUG-1794501895] Web route verifier fails 24 of 55 rows because RSC probes do not follow 307 redirects
- [ ] **Severity:** med
- **Area:** verification, web
- **File(s):** scripts/verify_web_routes.py
- **Observation:** Against an owned synthetic API, scripts/verify_web_routes.py exits 1 with 31 of 55 rows passing and 24 failing (136 failed checks). Every failing row is an RSC probe that receives an existing 307 redirect and does not follow it. The result is identical before and after PR #178.
- **Expected:** The verifier follows or expects the redirect, so all 55 rows pass against a correct viewer and a failure means a real route defect.
- **Req:** none; VERIFICATION.md web route verification (driver run simplify-1111, FINDING-2)
- **Depends on:** none
- **Repro / Notes:** Found by lead L5 while proving the web viewer simplification; before and after runs are recorded in the run directory under evidence/L5. Not re-run by the driver.
- **Bump:** patch
- **Status:** open

### [BUG-1794501896] go.mod marks pgx/v5 indirect although the backend imports it directly
- [ ] **Severity:** low
- **Area:** backend, dependencies
- **File(s):** backend/go.mod; backend/pkg/mutation/errors.go
- **Observation:** go mod tidy moves github.com/jackc/pgx/v5 v5.10.0 from the indirect require block to the direct one, with no version or go.sum change. backend/pkg/mutation/errors.go imports the module directly. CI runs go mod verify, not tidy, so nothing fails.
- **Expected:** go mod tidy leaves backend/go.mod unchanged.
- **Req:** none (driver run simplify-1111, FINDING-3)
- **Depends on:** none
- **Repro / Notes:** cd backend && go mod tidy && git diff go.mod shows the one-line move. Left out of PR #181 to keep the Go 1.27.4 bump to four lines.
- **Bump:** patch
- **Status:** open

### [BUG-1794501898] No test catches removal of receipt socket cleanup or the bill total tolerance guard
- [ ] **Severity:** med
- **Area:** backend, tests, money
- **File(s):** backend/internal/receipt/provider_dial.go; backend/internal/bill/create_request.go
- **Observation:** Mutation probes run at two revisions of the backend survive with every test passing: removing the dial-path socket AfterFunc in internal/receipt (M3), making the socket close asynchronous there (D2), and loosening or removing the subtotal and total tolerance check in internal/bill/create_request.go near line 451 (B5, B5b). A fifth probe that removes one of two identical no-store header assignments also survives and changes nothing.
- **Expected:** Each of the three behaviours has a test that fails when it is removed: socket cancellation on the dial path, synchronous socket close, and rejection of a bill whose assigned shares exceed its subtotal or total.
- **Req:** none; docs/backend-api.md bill creation validation (driver run simplify-1111, FINDING-4)
- **Depends on:** none
- **Repro / Notes:** Found by reviewer L9 on PR #179; 21 probes, 16 caught, 5 surviving at both base and head. Probe scripts and results are in the run directory under evidence/L9 (scripts/, mutations.txt, mutations2.txt, mutations3.txt). The tolerance guard protects money totals, so a regression there would pass CI.
- **Bump:** patch
- **Status:** open

### [BUG-1794501899] Record the Render service build settings for the backend in the repository
- [ ] **Severity:** low
- **Area:** delivery, docs
- **File(s):** ops/ci/README.md; backend/README.md
- **Observation:** Nothing in the repository states which runtime, Dockerfile path or build context Render uses for the backend. That production builds from backend/services/bill-service/Dockerfile is inferred from the source deploy hook and the documented build context. /health reports the commit, not the toolchain, so a toolchain bump cannot be shown to reach production from repository evidence.
- **Expected:** The current docs record the Render runtime, Dockerfile path and build context, and how to confirm the deployed toolchain.
- **Req:** none (driver run simplify-1111, FINDING-5)
- **Depends on:** none
- **Repro / Notes:** Found by reviewer L12 on PR #181; see ops/ci/delivery_gate.py publish path and ops/ci/README.md deploy section.
- **Bump:** patch
- **Status:** open

### [BUG-1794501900] Lifecycle and static-runtime harnesses cannot run under an isolated resource prefix
- [ ] **Severity:** low
- **Area:** verification, tooling
- **File(s):** scripts/verify_local_lifecycle.py; scripts/verify_static_runtime.py; backend/internal/healthcheck/entrypoints_test.go
- **Observation:** scripts/verify_local_lifecycle.py and scripts/verify_static_runtime.py hard-code billington-* resource names and the reset guard rejects any other prefix, so a supervised agent that must not touch the developer's local database volumes cannot execute them. Separately, TestServiceHealthcheckMode/bill-service binds host port 8080 and fails on a machine where another service already owns it; four agents hit this in unisolated host runs.
- **Expected:** Both harnesses accept a resource prefix (and the reset guard honours it), and the healthcheck test does not depend on a fixed host port.
- **Req:** none; VERIFICATION.md local lifecycle rows (driver run simplify-1111, FINDING-6)
- **Depends on:** none
- **Repro / Notes:** Reported by leads L1 and L8 (harness prefix) and L1, L4, L11, L12 (port 8080). Because of this the two harnesses were edited by PR #177 but never executed end to end.
- **Bump:** patch
- **Status:** open

### [BUG-1794501902] make down leaves an orphan legacy web-service container from before PR #177
- [ ] **Severity:** low
- **Area:** backend, local-dev
- **File(s):** backend/Makefile; backend/docker-compose.yml
- **Observation:** A developer who had the optional legacy-web Compose profile running before pulling PR #177 keeps an orphan web-service container after make down, because the service definition no longer exists. No data is lost and the stack still starts.
- **Expected:** Either the upgrade note tells developers to run docker compose down --remove-orphans once, or the down target removes orphans without removing data volumes.
- **Req:** none (driver run simplify-1111, FINDING-7)
- **Depends on:** none
- **Repro / Notes:** Found by reviewer L4 on PR #177 and judged non-blocking. One docker compose down --remove-orphans clears it.
- **Bump:** patch
- **Status:** open

### [BUG-1794264953] Read receipts an old writer creates after identity migration 0003
- [ ] **Severity:** high
- **Area:** backend, persistence, rollout
- **File(s):** backend/internal/bill/repository.go; backend/migrations/0003_participant_identity.sql; docs/reviews/2026-11-09-reader-ddl.md
- **Observation:** With the deployed pre-registry revision 81a564f built from history and the real adopt+0002+0003 migration applied under it, a bill that old writer creates after 0003 gets the column defaults (label='', no ordinal). The current reader then returns 409 client_upgrade_required for that two-participant bill on the unversioned and wire1 contracts; wire2 reads it as legacy_review. Bills created before the migration read 200. Restart and connection replacement do not change this.
- **Expected:** A receipt written by a predecessor during or after the schema step stays readable by every supported client contract, or the rollout provably excludes old writers before 0003 and that exclusion is checked. No historical row is rewritten without a reviewed backfill.
- **Req:** FEAT-1793644505 migration/read compatibility; BUG-1793861425 follow-up
- **Depends on:** BUG-1793861425
- **Repro / Notes:** docs/reviews/2026-11-09-reader-ddl.md, section on overlap. Synthetic PG17.11 owned schemas only. The delivery gate now refuses a schema step while such a revision answers /health, which avoids the case when the owner stops the old service first; this ticket covers the data path itself.
- **Bump:** patch
- **Status:** open

### [BUG-1794264955] Make the device and published per-person amounts agree on odd cents
- [ ] **Severity:** med
- **Area:** mobile, backend, accounting
- **File(s):** mobile/lib/screens/quick_split (allocation); backend/internal/bill/{shares,accounting}.go; docs/reviews/2026-11-09-mobile-save-journey.md
- **Observation:** The phone floors totals and gives leftover cents in entry order; the server rounds subtotal, tax and tip separately and assigns remainders in label order. For 10.00 + 0.01 tax + 0.01 tip split evenly between Alex and Sam the phone shows 5.01 and 5.01 while the server stores Alex 5.00 and Sam 5.02 (one-off prepareCreation probe, not committed). The earlier half-cent case in BUG-1793644500's log is one instance of the same difference.
- **Expected:** For every accepted receipt the amounts shown on the phone before publishing equal the published per-person amounts, with one documented rule and a shared fixture run by Go and Dart. Published and historical receipts are not rewritten. A symmetric split of a symmetric receipt differs by at most one cent between people.
- **Req:** BUG-1793644500 Expected (currency-correct bill across save); docs/reviews/2026-11-03-client-v1-bridge.md
- **Depends on:** owner decision: device adopts the server rule (recommended), a versioned server rule, or show published amounts after publish
- **Repro / Notes:** Options and costs: docs/reviews/2026-11-09-mobile-save-journey.md. The 5.00/5.02 server result needs a committed regression test before any change.
- **Bump:** patch
- **Status:** open
- **Log:**
  - 2026-11-09 Sighting: Simulator inspection (iPhone 17, iOS 27.2, local stack at 083567a): a USD 128.00 receipt for six people showed Alex 44.81 and Pat 6.39 on the phone (saved and after relaunch); after attaching it to a tab and finalizing, the settlement rows read Alex 44.80 and Pat 6.40. Totals stayed 128.00. Screenshots: .vv/ui-inspection-20261109/main/A2-06-shares.png and A5-12-relaunch-finalized.png.

### [BUG-1794264956] Remove or gate the second TestFlight uploader outside the delivery gate
- [ ] **Severity:** high
- **Area:** ci, security, delivery
- **File(s):** branch victorwake-testflight-runner: .github/workflows/victorwake-testflight.yml; repository secrets ASC_KEY_ID, ASC_ISSUER_ID, ASC_API_KEY_P8, BUILD_CERTIFICATE_BASE64, P12_PASSWORD
- **Observation:** Branch victorwake-testflight-runner carries victorwake-testflight.yml (bundle com.victorivanov.victorwake), triggered by a push to that branch or by dispatch. It reads repository-level App Store Connect and signing secrets and uploads to TestFlight without the six-row gate, the RELEASE_POLICY check or a protected environment. Last runs: failure on 2026-10-29, success on 2026-07-06.
- **Expected:** No workflow on any branch can sign or upload with this repository's credentials outside the gated publishers: the branch workflow is removed or moved to its own repository, and signing/ASC secrets live only in main-restricted environments. Read-only GitHub API checks show no such workflow and no repository-level signing secret.
- **Req:** BUG-1793644501 Expected (no publication outside the gate); SR GATE/RELEASE
- **Depends on:** owner action in GitHub settings; nothing in this repository's main branch can remove another branch's workflow or a secret
- **Repro / Notes:** docs/reviews/2026-11-09-delivery-workflows.md. Read-only: gh api repos/LLRHook/checksinmyhead/actions/workflows; gh api repos/LLRHook/checksinmyhead/actions/secrets. Nothing was dispatched or changed.
- **Bump:** patch
- **Status:** open

### [BUG-1794264957] Reject runner cases that the gate manifest does not select
- [ ] **Severity:** med
- **Area:** ci, delivery
- **File(s):** ops/ci/delivery_gate.py; ops/ci/case_manifest.json; ops/ci/test_delivery_gate.py
- **Observation:** Nothing compares ops/ci/case_manifest.json with the source it describes. A new Go, Dart or web test that nobody registers still runs and passes, but the gate does not require it, so deleting or skipping it later is not detected. The 2026-11-09 S4 review found one such unselected loop (receipt_native_io_test.dart, four modes).
- **Expected:** The report adapters reject a runner case or family that no manifest selection matches, per row, with a controller test that fails when a registration is removed. Existing families keep passing unchanged.
- **Req:** BUG-1793644501 Expected (all relevant checks); ops/ci/README.md source-grounded manifest
- **Depends on:** none
- **Repro / Notes:** docs/reviews/2026-11-09-delivery-workflows.md, manifest drift. Requiring every loop expansion (134 mobile records) is the stricter alternative.
- **Bump:** patch
- **Status:** open

### [BUG-1794264959] Decide the fate of the tab photo upload that released 1.4.0 still offers
- [ ] **Severity:** med
- **Area:** backend, product, compatibility
- **File(s):** backend (tab image routes removed after 1.4.0); mobile 1.4.0 release source; docs/privacy.md
- **Observation:** The public App Store build 1.4.0 has a tab receipt-photo upload. The deployed API answers GET /api/tabs/1/images with 404 while GET /api/tabs/1 answers 403, so the route is absent in the deployed revision. Whether photos uploaded earlier are still stored is unknown.
- **Expected:** An owner decision is recorded: either the released client's photo flow is served again, or it is declared retired, with the user-visible failure in 1.4.0 known and the retention or deletion of earlier photos stated in docs/privacy.md from production evidence.
- **Req:** BUG-1793644510 (disclosures match released behavior); TR release availability
- **Depends on:** owner evidence about stored photos in production
- **Repro / Notes:** docs/reviews/2026-11-09-privacy-disclosures.md (read-only GETs on 2026-11-09). Find the 1.4.0 source from mobile/pubspec.yaml history.
- **Bump:** patch
- **Status:** open

### [BUG-1794264960] Keep a long tab name inside the Tab detail app bar
- [ ] **Severity:** low
- **Area:** mobile, ui, layout
- **File(s):** mobile/lib/screens/tabs/tab_detail_screen.dart (app-bar title Row)
- **Observation:** The Tab detail title is an unflexed Text(_currentTab.name) inside a Row. A 21-character tab name overflowed the row by 47 px on a 320-wide display in a widget test run.
- **Expected:** Tab names up to the accepted maximum length ellipsize or wrap inside the app bar at 320, 375 and 390 widths and at large text sizes, with no RenderFlex overflow and the actions still reachable; a widget test covers it.
- **Req:** DESIGN_SYSTEM.md responsive layout
- **Depends on:** none
- **Repro / Notes:** Pump TabDetailScreen at 320x568 with a 21-character name; see docs/reviews/2026-11-09-finalize-sheet-layout.md.
- **Bump:** patch
- **Status:** open

### [BUG-1794264961] Make the runtime probe's DNS cancellation check deterministic
- [ ] **Severity:** med
- **Area:** verification, runtime
- **File(s):** scripts/runtime-probe/main.go; scripts/verify_static_runtime.py
- **Observation:** In four static runtime harness runs on images built from the sweep branch, three passed 75/75 and one stopped at check 28: bill-runtime-probe reported dns_cancellation false after 256 ms. Another run passed the same assertion at 256 ms, so elapsed time was not the failing term. The probe does not record which term failed; it appears to read the lookup context's error immediately after the resolver returns.
- **Expected:** The probe records each term of the cancellation assertion and passes or fails for a stated reason; repeated runs on the same images give the same result. Timing bounds stay as they are.
- **Req:** BUG-1793652309 runtime verification; VERIFICATION.md static image harness
- **Depends on:** none
- **Repro / Notes:** docs/reviews/2026-11-09-assignment-update-decode.md, static runtime runs. The cause is inferred from source, not captured. The earlier web 1.619804s > 1.5s miss did not recur (1.033-1.045s).
- **Bump:** patch
- **Status:** open

### [BUG-1794264963] Measure and bound the participant-reference assignment update at maximum size
- [ ] **Severity:** low
- **Area:** backend, performance
- **File(s):** backend/internal/bill/{assignment_request,assignments}.go; backend/cmd/bill-service (a1perf harness)
- **Observation:** Requests with X-Billington-Identity-Version: 2 still use the buffered decoder. The harness does not measure that route. A one-off benchmark of the same 500 x 100 shape with participant_id (1.86 MB body, not committed) took 26.2-27.2 ms and 21.0 MB per request, against 5.8-6.0 ms for the name-based route after BUG-1793644507.
- **Expected:** The harness measures the participant-reference route at the maximum accepted size against an approved target, and the route meets it or the miss is recorded as RED. No public error, limit or ordering changes.
- **Req:** BUG-1793644507 Expected (bounded request resources); FEAT-1793644502
- **Depends on:** owner approval of a target for this route
- **Repro / Notes:** docs/reviews/2026-11-09-assignment-update-decode.md. No target exists for this route today, so nothing is red; this ticket asks for the measurement.
- **Bump:** patch
- **Status:** open

### [BUG-1794264964] Let the healthcheck mode test run when port 8080 is busy
- [ ] **Severity:** low
- **Area:** tests, tooling
- **File(s):** backend/internal/healthcheck/healthcheck_test.go; backend/cmd/{bill-service,web-service}/main.go
- **Observation:** TestServiceHealthcheckMode/bill-service listens on the fixed address 127.0.0.1:8080 because the binary's --healthcheck mode probes that address. When another process holds the port the ordinary Go row fails locally with: listen tcp 127.0.0.1:8080: bind: address already in use. On 2026-11-09 this was the only failure in go test -race ./... (1553 pass, 2 fail); the same package passes in a container with its own network namespace and in hosted CI.
- **Expected:** The ordinary Go row gives the same result whether or not port 8080 is free on the host, without weakening what the test proves about the shipped --healthcheck contract (for example by running the probe subprocess in a way that does not need the host port, or by failing with an explicit prerequisite message).
- **Req:** VERIFICATION.md Stage 2 (no environment-dependent failures)
- **Depends on:** none
- **Repro / Notes:** Hold 127.0.0.1:8080, then cd backend && go test -race -count=1 ./internal/healthcheck. Container control: docker run the pinned golang builder image with the same command.
- **Bump:** patch
- **Status:** open

### [BUG-1794265789] Build the iOS simulator app under Xcode 27.2
- [ ] **Severity:** med
- **Area:** mobile, ios, tooling
- **File(s):** mobile/ios/Podfile; mobile/ios/Runner.xcodeproj/project.pbxproj; mobile/README.md
- **Observation:** With Xcode 27.2 (27B52) and Flutter 3.41.5, flutter build ios --simulator --debug fails twice. First, Xcode treats pod deployment targets 12.0 and 13.0 as errors (supported range 15.0 to 27.2.x; __DIAGNOSE_INVALID_DEPLOYMENT_TARGET_AS_ERROR = YES) and the build stops after 2.9s. With FLUTTER_XCODE_IPHONEOS_DEPLOYMENT_TARGET=15.5 it then fails in Thin Binary: Flutter.framework does not contain architectures "arm64 x86_64" although lipo lists both. Adding FLUTTER_XCODE_ARCHS=arm64 and FLUTTER_XCODE_ONLY_ACTIVE_ARCH=YES builds Runner.app.
- **Expected:** The documented simulator build command produces Runner.app on the current Xcode without environment overrides: pods carry a supported deployment target (for example through the Podfile post_install), and the architecture check passes or the documented command selects the simulator architecture. mobile/README.md states the supported Xcode range. The device release build and Podfile.lock versions are unchanged.
- **Req:** AGENTS.md iOS builds; VERIFICATION.md Stage 0 (debug flutter run in mobile)
- **Depends on:** none
- **Repro / Notes:** cd mobile && flutter pub get --enforce-lockfile && flutter build ios --simulator --debug on Xcode 27.2. Logs retained in .vv/sweep/ios-build{,2,3}.log of the 2026-11-09 sweep. The 2026-11-04 lock qualification used SDK 26.2, where this did not occur. Hosted TestFlight runners were not checked.
- **Bump:** patch
- **Status:** open

### [BUG-1794273307] Keep the Assign Items tutorial dialog clear of the side status column
- [ ] **Severity:** low
- **Area:** mobile, ui, layout
- **File(s):** mobile/lib/screens/quick_split/item_assignment (tutorial overlay)
- **Observation:** On an iPhone Duo simulator in its Closed pose (iOS 27.1, right status column), the automatic 'Step 1 of 5 / Expand Items' tutorial dialog on Assign Items is centred on the full display, so its right edge and corner extend under the status column. The screen body behind it respects the side inset after BUG-1793927492.
- **Expected:** The tutorial dialog and its close and Next controls stay between the system side insets on displays that have them, and keep their current position on displays without side insets; a widget test with a right view padding covers it.
- **Req:** DESIGN_SYSTEM.md responsive layout; BUG-1793927492 follow-up
- **Depends on:** none
- **Repro / Notes:** Duo Closed pose, Quick Split with four people, subtotal 122 with items, Continue to Assign Items on first use. Screenshot: .vv/ui-inspection-20261109/layout/b2-tutorial.png (2026-11-09 sweep).
- **Bump:** patch
- **Status:** open

### [BUG-1794274030] Open a trip whose receipts exceed the device history limit
- [ ] **Severity:** med
- **Area:** mobile, persistence, tabs, product
- **File(s):** mobile/lib/database/database.dart (maxRecentBills, _makeReceiptRoom); mobile/lib/screens/tabs/tab_detail_screen.dart
- **Observation:** The device keeps at most 30 receipts, counted across all tabs. A member who opens a trip with 31 receipts sees 'History is full of pending or referenced receipts. Current history could not be cached; balances need review.' with a Retry that repeats the message; no receipts, balances or Finalize are available for that trip on the device. The same happens for a smaller trip when receipts referenced by other tabs already fill the limit: on a device with one other referenced receipt, a 31-receipt trip failed, and a 30-receipt trip opened only on a fresh install. This is the atomic refusal BUG-1794045427 specifies, so nothing is corrupted, but the trip cannot be used in the app.
- **Expected:** An owner decision on the product rule: either a tab's receipts are readable on the device regardless of the recent-history limit (the limit applies only to unreferenced history), or the limit is stated to the user before joining with a way forward. Whatever is chosen keeps BUG-1794045427's atomic import and never shows partial balances.
- **Req:** BUG-1794045427 follow-up; docs/technical-overview.md durable history contract
- **Depends on:** owner product decision
- **Repro / Notes:** Local synthetic stack, 2026-11-09: seed a tab with 31 receipts through the API, open billington://tab/<id>?t=<token> on a simulator and join. Screenshots: .vv/ui-inspection-20261109/recheck/E3-cache-error.png, layout/b3-capacity-loaded.png. The API returned all 31 receipts for the same tab.
- **Bump:** patch
- **Status:** open
