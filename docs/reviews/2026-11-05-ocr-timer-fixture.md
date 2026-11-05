# OCR timer fixture correction — November 5, 2026

At source93699b9, GitHub Actions run42096155322 failed the mobile row in the existing success/owned-client cleanup test. Its error event followed test-start by60ms; the fixture supplied a20ms timeout and the service correctly reported expiration. This is a fixture scheduling assumption, not evidence of a production deadline defect. A single local classification run of the unchanged case passed; the hosted failure remains retained as flaky evidence.

The same test ID now holds logical elapsed time steady using the existing test seam, awaits abort-listener completion, and directly asserts cancellation of the one original45s operation timer. All original close-count, request-kind and redirect assertions remain. Independent test cleanup cancels any captured timer even when a guard-removal assertion fails. Final package formatting differs only in whitespace from the independently reviewed, full-suite-tested candidate. No production source, deadline, limits, dependency, SDK, UI or release setting changed.

Validation on pinned Flutter3.41.5/Dart3.11.3:

- Original focused classification:1 passing case. Corrected scratch case:1 pass.
- Exact task-only production control removes only timer.cancel. The corrected test fails its actual isActive assertion (true versus expectedfalse), with complete terminal and cleaned process group. This is not a setup failure.
- Maintained locked acquisition and analysis pass.
- Full maintained flutter test --no-pub --reporter=json:513 visible cases,558 starts/terminals, zero failures/skips/missing. All558 prior hosted occurrences survive with identical family/name/multiplicity. The unchanged canonical parser accepts519 non-loader records (513 cases plus6 lifecycle hooks), and all39 required mobile families validate.
- A baseline Flutter update-notice prelude was retained separately from JSON events. An initial root verifier confused558 runner terminals with519 canonical records; the raw reports stayed unchanged and no application rerun was needed.

The production receipt service hash remains c8a1bb3215be92e54647d628caa152627be4b1dee2f8bceac168056156d5d841. Full raw commands/reports, before/candidate/control blobs, source hashes and case reconciliation are retained under mobile-ocr-timer-fixture-correction-20261105/ in the active driver scratch.

Doc impact: living documentation remains accurate because product behavior and commands are unchanged. This dated evidence accompanies the test-only change; BUG-1793644508 remains in-progress for spendingB/resources and remaining qualification.

Local gate: GREEN scope=affected clean=no for locked acquisition, analysis and full Flutter tests. This does not repair the separate exact93699 PostgreSQL600s timeout/750ms miss, prove hosted recovery or qualify native/signed clients, current runtime artifacts, spending, resources or whole security/integrated/release. Those gates remain RED.
