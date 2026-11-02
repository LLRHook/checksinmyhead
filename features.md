# Billington — Feature Tracker

Active work only. Format and rules: [`.cycle/TRACKERS.md`](.cycle/TRACKERS.md). Write with `python3 .cycle/trackers.py`, never by hand. Shipped and closed entries are removed; their record is `CHANGELOG.md`, Jira, and `python3 .cycle/trackers.py show <id>`.

## Open

### [FEAT-1793644500] Give creators control over online shared-data lifecycle
- [ ] **Priority:** high
- **Area:** backend, privacy
- **File(s):** backend/internal/{bill,tab}/{handler,service,repository}.go; docs/privacy.md
- **Req:** TR privacy; TR fix 8; docs/reviews/2026-11-02-baseline.md
- **Depends on:** FEAT-1793644505
- **UI:** none
- **Why:** Tokens do not expire/revoke and online records require operator removal.
- **Approach:** Define creator-authorized revoke/rotate/delete behavior and retention with compatible links until explicitly revoked.
- **Library / dependency notes:** Use existing stack; verify current primary docs before any dependency. No new package selected.
- **Acceptance criteria:** (derived from the approved review remediation scope)
  - Creator credentials authorize lifecycle changes; collaborators and unrelated bearer links cannot revoke/delete.
  - Revoked/rotated links stop authorizing access; deletion honors documented retention and dependencies.
  - Two-client tests distinguish local removal from online removal and preserve audit/rollback evidence where appropriate.
- **Test plan:** Backend PostgreSQL route/transaction tests and mobile/web lifecycle walkthrough; prepare policy wording and old-link compatibility evidence.
- **Out of scope:** Unrelated redesign, new framework, live destructive operations, unapproved publication.
- **Bump:** minor
- **Status:** open

### [FEAT-1793644501] Record operational ownership and recovery evidence
- [ ] **Priority:** med
- **Area:** operations
- **File(s):** docs/technical-overview.md; deployment/recovery reference; external Render/Neon/Railway/Vercel/Anthropic accounts
- **Req:** TR fixes 12,17; SR provider ownership; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **UI:** none
- **Why:** Live DB vendor, budgets, backups, alerts, mirror ownership and Railway consumers cannot be inferred from source.
- **Approach:** Maintain one concise owner/service inventory and tested recovery reference; inspect external settings read-only before any cutover.
- **Library / dependency notes:** Use existing stack; verify current primary docs before any dependency. No new package selected.
- **Acceptance criteria:** (derived from the approved review remediation scope)
  - Identify actual current services/owners, consumers, spend/budgets and data location without credentials in docs.
  - Restore a backup to isolated PostgreSQL and verify alerting plus error/scan-success/cost measurements.
  - Railway/old database/mirror retirement remains blocked until consumers, data preservation and rollback are proven.
- **Test plan:** Read-only account evidence and isolated restore drill; report unavailable access explicitly. No cloud retirement is authorized by this ticket alone.
- **Out of scope:** Unrelated redesign, new framework, live destructive operations, unapproved publication.
- **Bump:** minor
- **Status:** open

### [FEAT-1793644502] Measure and bound large-tab API work
- [ ] **Priority:** med
- **Area:** backend, performance
- **File(s):** backend/internal/tab/{repository,service}.go; docs/scaling-considerations.md
- **Req:** TR performance; TR fix 17; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **UI:** none
- **Why:** Tab reads eagerly load bills/items/shares; warm/cold latency and realistic capacity were not established.
- **Approach:** Measure query count, payload and latency at realistic tab sizes; propose budgets before optimizing the owning read boundary.
- **Library / dependency notes:** Use existing stack; verify current primary docs before any dependency. No new package selected.
- **Acceptance criteria:** (derived from the approved review remediation scope)
  - Record volume, warm/cold latency distribution, payload bytes, query count and environment for tab reads.
  - Approve numerical budgets with sample/noise floors; fail or abstain explicitly when measurements are insufficient.
  - Bound the measured hot path without breaking response compatibility; compare before/after with meaningful regression cases.
- **Test plan:** PostgreSQL realistic-volume fixtures and API measurements; no cache or new service is preselected.
- **Out of scope:** Unrelated redesign, new framework, live destructive operations, unapproved publication.
- **Bump:** minor
- **Status:** open

### [FEAT-1793644503] Simplify Vercel publishing source ownership
- [ ] **Priority:** med
- **Area:** delivery
- **File(s):** .github/workflows/sync-web-viewer.yml; external Vercel project settings; deployment/rollback reference
- **Req:** SR Vercel source/mirror; docs/reviews/2026-11-02-baseline.md
- **Depends on:** BUG-1793644501, FEAT-1793644501
- **UI:** none
- **Why:** Web subtree is force-pushed to a second repository; provider ownership/configuration is unverified.
- **Approach:** Plan direct source from web-bill-viewer in this repository after validating account access, complete gate and rollback.
- **Library / dependency notes:** Use existing stack; verify current primary docs before any dependency. No new package selected.
- **Acceptance criteria:** (derived from the approved review remediation scope)
  - Confirm existing domain, environment, consumers and account permissions; inaccessible mirror is not assumed deleted.
  - A preview preserves old /b and /t URLs and is bound to the approved revision/gate.
  - Prove rollback before retiring mirror/key; record actual source-build artifact exceptions.
- **Test plan:** Read-only configuration inventory then preview and rollback evidence under separate cutover authorization.
- **Out of scope:** Unrelated redesign, new framework, live destructive operations, unapproved publication.
- **Bump:** minor
- **Status:** open

### [FEAT-1793644504] Retire obsolete backend viewer scaffolding safely
- [ ] **Priority:** low
- **Area:** backend, tooling
- **File(s):** backend/cmd/web-service/; backend/internal/web/; backend/services/web-service/Dockerfile; backend/docker-compose.yml; backend/migrations/docker-compose.yml; README.md
- **Req:** SR legacy viewer/placeholder; docs/reviews/2026-11-02-baseline.md
- **Depends on:** FEAT-1793644501
- **UI:** none
- **Why:** Local stack starts both Go HTML and Next.js viewers; empty migrations Compose file does not manage schema.
- **Approach:** Prove old-link/deployment consumers then remove obsolete viewer/config and empty placeholder together with related documentation.
- **Library / dependency notes:** Use existing stack; verify current primary docs before any dependency. No new package selected.
- **Acceptance criteria:** (derived from the approved review remediation scope)
  - Confirm external/old link consumers and compatibility before removal; keep current Next.js routes working.
  - Remove proved-unused Go viewer, Compose service, image and empty migration placeholder; no second active renderer remains.
  - Build/test surviving API and Next.js viewer and smoke old-link handling; avoid unrelated file deletion.
- **Test plan:** Reference search, deploy inventory and local build/API/viewer smoke; removal count is evidence, not a correctness metric.
- **Out of scope:** Unrelated redesign, new framework, live destructive operations, unapproved publication.
- **Bump:** minor
- **Status:** open

### [FEAT-1793644505] Define ordered PostgreSQL migration readiness
- [ ] **Priority:** high
- **Area:** backend, persistence
- **File(s):** backend/pkg/database/postgres.go; backend/pkg/models/; backend/migrations/; docs/technical-overview.md
- **Req:** SR ORDER; SR schema ownership; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **UI:** none
- **Why:** Startup AutoMigrate/backfill has no ordered rollout policy and ignores backfill error.
- **Approach:** Define ordered expand/backfill/contract and recovery policy using existing database/ORM before schema-sensitive fixes.
- **Library / dependency notes:** Use existing stack; verify current primary docs before any dependency. No new package selected.
- **Acceptance criteria:** (derived from the approved review remediation scope)
  - Failed migration/backfill prevents serving schema-dependent requests; errors remain visible.
  - Apply migration from prior released schema on isolated PostgreSQL and verify old data and compatibility.
  - Review backfill idempotency, rollback/restore and deployment ordering; select a tool only if justified.
- **Test plan:** PostgreSQL upgrade/retry/failure tests from prior schema; never use existing developer or production data as destructive fixtures.
- **Out of scope:** Unrelated redesign, new framework, live destructive operations, unapproved publication.
- **Bump:** minor
- **Status:** open

### [FEAT-1793644506] Exercise accounting transactions against PostgreSQL
- [ ] **Priority:** high
- **Area:** backend, tests
- **File(s):** backend/internal/{bill,tab}/*_test.go; backend/docker-compose.yml; VERIFICATION.md
- **Req:** TR fixes 7,19; SR integrated verification gaps; docs/reviews/2026-11-02-baseline.md
- **Depends on:** BUG-1793644504, BUG-1793644505
- **UI:** none
- **Why:** Current repository tests use SQLite and do not prove PostgreSQL row-lock/failure behavior.
- **Approach:** Add an explicit isolated PostgreSQL integration layer with reproducible fixtures and clear prerequisite/skip accounting.
- **Library / dependency notes:** Use existing stack; verify current primary docs before any dependency. No new package selected.
- **Acceptance criteria:** (derived from the approved review remediation scope)
  - Cover rollback, concurrent finalize/edit/paid/attach, retries and same-name ownership at PostgreSQL isolation boundaries.
  - Fail clearly if the required integration engine is absent; zero executed or skipped is never green.
  - Use isolated project/database names, deterministic synthetic data, and safe teardown preserving normal data.
- **Test plan:** A separately selected PostgreSQL integration command with actual execution/skip counts; document it in VERIFICATION.md when implemented.
- **Out of scope:** Unrelated redesign, new framework, live destructive operations, unapproved publication.
- **Bump:** minor
- **Status:** open

### [FEAT-1793644507] Verify complete mobile-to-browser collaboration journeys
- [ ] **Priority:** high
- **Area:** tests, mobile, web
- **File(s):** mobile/test/; web-bill-viewer/src/lib/__tests__/; VERIFICATION.md
- **Req:** TR fix 19; SR NOT CI-CONFIRMED; docs/reviews/2026-11-02-baseline.md
- **Depends on:** BUG-1793644497, BUG-1793644498, BUG-1793644500, BUG-1793644504, BUG-1793644505, FEAT-1793644506
- **UI:** none
- **Why:** Partial/unit suites miss the integrated receipt/save/share/claim/attach/finalize/paid flow and public app compatibility.
- **Approach:** Build repeatable synthetic journey fixtures and exercise app plus two browser/member contexts against one known revision.
- **Library / dependency notes:** Use existing stack; verify current primary docs before any dependency. No new package selected.
- **Acceptance criteria:** (derived from the approved review remediation scope)
  - Exercise normal and lazy receipt entry/review/save/share/claim/attach/finalize/paid with totals conserved.
  - Cover non-USD, failed verification/upload, retry/restart, duplicate names and stale edits without duplicate receipts or lost paid state.
  - Verify installed/not-installed/invalid/duplicate/returning invites and public binary/API compatibility; record exact artifact/version.
  - Record a real provider receipt corpus and payment handoff limits or mark those surfaces blocked.
- **Test plan:** Full local suites plus isolated stack GUI/API walkthrough and two-device launch check; shared journey exception crosses tiers because only end-to-end evidence proves it.
- **Out of scope:** Unrelated redesign, new framework, live destructive operations, unapproved publication.
- **Bump:** minor
- **Status:** open

### [FEAT-1793644508] Bind release evidence to tested artifacts
- [ ] **Priority:** med
- **Area:** delivery
- **File(s):** .github/workflows/{deploy-backend,testflight,app-store-release,sync-web-viewer}.yml; .github/scripts/asc_release.rb; deployment/rollback reference
- **Req:** SR ART; SR DELEG/POST/DOC; docs/reviews/2026-11-02-baseline.md
- **Depends on:** BUG-1793644501
- **UI:** none
- **Why:** Provider source builds and separate iOS workflows do not prove the same tested artifact is promoted; deploy/rollback evidence is incomplete.
- **Approach:** Record tested source/artifact identity, processed iOS build eligibility, provider exceptions and exact-SHA postflight/rollback.
- **Library / dependency notes:** Use existing stack; verify current primary docs before any dependency. No new package selected.
- **Acceptance criteria:** (derived from the approved review remediation scope)
  - Release record identifies source SHA, artifact digest/build and relevant gate result.
  - Reuse eligible processed iOS builds where supported; explain each provider rebuild exception explicitly.
  - Current deploy/rollback reference preserves exact-SHA health and meaningful journey smoke; shared inline logic is extracted only where justified.
- **Test plan:** Existing Ruby release tests and offline workflow/gate validation; inspect processed-build selection without dispatching publication.
- **Out of scope:** Unrelated redesign, new framework, live destructive operations, unapproved publication.
- **Bump:** minor
- **Status:** open

### [FEAT-1793644509] Prepare outcome-focused App Store screenshots
- [ ] **Priority:** med
- **Area:** product, marketing
- **File(s):** existing feat/billington-app-store-capture-workflow branch; artifacts/app-store/; store metadata
- **Req:** TR published/candidate screenshots; TR fix 14; docs/reviews/2026-11-02-baseline.md
- **Depends on:** BUG-1793644511
- **UI:** App Store assets: result, scan/review, browser claim, breakdown, trips, marked-paid states.
- **Why:** Published sequence emphasizes setup; candidate first two frames depend on one another and underplay scan/link/claim.
- **Approach:** Preserve existing screenshot work; prepare independently readable early frames after shipping-feature verification.
- **Library / dependency notes:** Use existing stack; verify current primary docs before any dependency. No new package selected.
- **Acceptance criteria:** (derived from the approved review remediation scope)
  - First three frames show a completed result, receipt review and browser participation supported by the released binary.
  - Each early frame works alone at store-thumbnail scale with readable amounts and truthful self-reported payment state.
  - Manifest/dimensions and synthetic data are verified; asset preparation is distinguished from App Store publication.
- **Test plan:** Visual review of full frames/contact sheets at store scale and screenshot pipeline validation on its existing branch.
- **Out of scope:** Unrelated redesign, new framework, live destructive operations, unapproved publication.
- **Bump:** minor
- **Status:** open

### [FEAT-1793644510] Add truthful marketing search and social metadata
- [ ] **Priority:** med
- **Area:** product, marketing
- **File(s):** external getbillington.vercel.app source (not present here)
- **Req:** TR technical SEO; TR fix 16; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **UI:** none
- **Why:** Public marketing page lacks canonical/social metadata and structured data; sitemap/robots returned 404 in review.
- **Approach:** Confirm durable canonical URL and prepare title, preview image/cards, SoftwareApplication data and discoverable sitemap.
- **Library / dependency notes:** Use existing stack; verify current primary docs before any dependency. No new package selected.
- **Acceptance criteria:** (derived from the approved review remediation scope)
  - Canonical/title/social cards and truthful structured data validate against public content.
  - Sitemap and intentional robots policy respond successfully; private bearer links stay excluded.
  - Search Console/index/ranking/Core Web Vitals claims are made only with actual access/field evidence.
- **Test plan:** Public HTML/header and metadata validation plus sitemap/robots requests; source/access confirmation precedes edits.
- **Out of scope:** Unrelated redesign, new framework, live destructive operations, unapproved publication.
- **Bump:** minor
- **Status:** open

### [FEAT-1793644511] Establish an evidence-based acquisition learning loop
- [ ] **Priority:** med
- **Area:** product, research
- **File(s):** docs/market-analysis.md; external aggregate App Store/campaign/cost records
- **Req:** TR marketing; TR fix 18; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **UI:** none
- **Why:** Current market assumptions omit hosted/AI cost and private conversion/retention evidence was unavailable.
- **Approach:** Refresh primary competitor/cost assumptions and choose small attributable experiments using aggregate metrics or opt-in research.
- **Library / dependency notes:** Use existing stack; verify current primary docs before any dependency. No new package selected.
- **Acceptance criteria:** (derived from the approved review remediation scope)
  - Name target use case and verified scan/support cost before committing acquisition budget.
  - Define attributable store visit/install/first split/first share/return metrics or opt-in interview equivalents.
  - State sample size, scope, uncertainty and abstention; unavailable CAC/revenue/retention remains ungraded.
- **Test plan:** Review primary product pages, aggregate funnel/cost records and one bounded experiment; no invasive analytics or new paid service is selected.
- **Out of scope:** Unrelated redesign, new framework, live destructive operations, unapproved publication.
- **Bump:** minor
- **Status:** open

### [FEAT-1793644512] Validate accessibility on supported iOS and web surfaces
- [ ] **Priority:** med
- **Area:** tests, accessibility
- **File(s):** mobile/lib/screens/; web-bill-viewer/src/components/; docs/app-review-notes.md
- **Req:** TR UX/a11y; TR fix 20; docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **UI:** Core receipt, assignment, share, claim, payment, trip and settings states.
- **Why:** Partial simulator tour and lost AXe semantics do not establish actual VoiceOver/device support.
- **Approach:** Run a direct assistive-technology and responsive pass on the supported journey before claiming store accessibility support.
- **Library / dependency notes:** Use existing stack; verify current primary docs before any dependency. No new package selected.
- **Acceptance criteria:** (derived from the approved review remediation scope)
  - Exercise VoiceOver, larger text, contrast, modal/keyboard focus and reduced motion on iPad and a small supported iPhone.
  - Exercise keyboard/focus/contrast on browser claim/pay flow at mobile and desktop widths.
  - File reproducible defects and align store claims to evidence; tool failures are recorded as automation limits.
- **Test plan:** Physical/simulator direct AT walkthrough and real browser GUI review with synthetic fixtures; no device-wide failure is assumed.
- **Out of scope:** Unrelated redesign, new framework, live destructive operations, unapproved publication.
- **Bump:** minor
- **Status:** open

### [FEAT-1793644778] Complete mobile settlement payment actions
- [ ] **Priority:** med
- **Area:** mobile, payments
- **File(s):** mobile/lib/screens/tabs/tab_detail_screen.dart; mobile/lib/services/api_service.dart; mobile/test/
- **Req:** Historical tasks/todo.md:476 (approved collaboration plan); docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **UI:** Trip settlement list, external payment handoff, paid confirmation/error/undo states.
- **Why:** The trip settlement screen exposes a paid toggle but no configured payment launch/confirmation flow. Existing payment helpers elsewhere do not finish this surface.
- **Approach:** Reuse existing external payment-link helpers and settlement API, preserving self-reported status and authorization.
- **Library / dependency notes:** Reuse existing stack; no new service/package chosen. Verify current primary docs before additions.
- **Acceptance criteria:** (derived from the approved historical plan)
  - Show who owes whom with configured supported payment links/details and a clear transfer-is-external explanation.
  - Paid-state confirmation, error feedback and safe undo agree with server state; failures are not silently treated as success.
  - Test configured/missing payment methods, failed mutation and refresh/restart without moving money in-app.
- **Test plan:** Focused mobile UI/service tests plus two-device settlement/payment handoff walkthrough; real provider availability is recorded separately.
- **Out of scope:** In-app transfers, accounts, new payment provider; unapproved publication or paid service.
- **Bump:** minor
- **Status:** open

### [FEAT-1793644779] Preserve tab invites across the install handoff
- [ ] **Priority:** med
- **Area:** mobile, web, ux
- **File(s):** web-bill-viewer/src/components/AppHandoff.tsx; mobile/lib/services/invite_link_service.dart; mobile/lib/main.dart; mobile/test/services/invite_link_service_test.dart
- **Req:** Historical tasks/todo.md:437,491 (approved collaboration plan); docs/reviews/2026-11-02-baseline.md
- **Depends on:** none
- **UI:** Web install/recover invite state and mobile post-onboarding join confirmation.
- **Why:** The existing web AppHandoff opens a scheme or the generic store URL; it does not demonstrate recovery of that specific invite after a new installation.
- **Approach:** Choose and document a compatible recovery flow using available platform capabilities; preserve bearer secrecy and provide an explicit recover/copy flow if automatic transfer is unavailable.
- **Library / dependency notes:** Reuse existing stack; no new service/package chosen. Verify current primary docs before additions.
- **Acceptance criteria:** (derived from the approved historical plan)
  - A not-installed user can recover the exact intended invite after installation through a verified supported flow.
  - Installed cold-start/onboarding and returning-member routing preserve the latest link; invalid links fail clearly.
  - Explain the supported handoff accurately; require explicit driver approval for any new paid service or dependency.
- **Test plan:** Real signed supported-device install/onboarding and returning-member walkthrough plus mobile/web link-state regressions; do not substitute local pending-queue tests for installation proof.
- **Out of scope:** In-app transfers, accounts, new payment provider; unapproved publication or paid service.
- **Bump:** minor
- **Status:** open
