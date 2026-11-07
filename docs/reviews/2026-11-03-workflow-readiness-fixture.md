# Workflow readiness fixture correction — November 3, 2026

Base: `f558642603bae09dc4af56b55f4d1a21c6126eb7`. The currency lead retained a
failed ordinary Flutter-quit test: it returned124 at API readiness, before Flutter
started. Its one permitted rerun passed; the original affected gate correctly
remained RED. The failure is not evidence that the real API or Flutter failed.

The ordinary fixture selected a two-second readiness budget, shorter than the CLI's
three-second maximum for its API probe. A controlled healthy2.1-second mock response
reproduces the same false negative in the quit/cleanup test. Two controls still pass:
an API HTTP failure retains its status, and pre-existing running services are preserved.
All commands/services are synthetic, with real Bash/owned child processes. This
demonstrates test coupling; the original intermittent run had no scheduling trace,
so its specific environmental delay remains unknown.

The fixture now gives ordinary lifecycle cases five seconds per stage. The lasting
quit case includes that2.1-second healthy API response. The health, web and simulator
timeout cases explicitly use one second, as do the existing blocked-probe cases.
Their failure/status/cleanup assertions remain. No product deadline, retry, probe,
cleanup behavior, assertion or test case was removed or relaxed.

Execution:

- Before:3 cases,1 expected quit assertion failure and2 passing controls;0 errors/skips.
- After: `python3 scripts/test_local_workflow.py` passes all55 distinct cases,
  with0 failures/errors/skips. This is one complete run after the fixture correction,
  not a loop accepting a passing retry.
- Runtime source remains unchanged from the independently approved workflow correction
  at79a8568. The currency lead's Go737-distinct-case and runtime69-check evidence keeps
  its original implementation pin and attribution; this test-only change is not a new
  Go, image or device execution.

Raw records: driver's `billington-structure-evidence/readiness-fixture-f558642/`
(`before.log`, `before-result.json`, `after.log`, `after-result.json`). The original
currency-stage failure/rerun remain under `.vv/local-gate/currency-provider-phase1/`.
The test design correction requires independent review; full integrated/security and
device acceptance remain open. No CHANGELOG migration or deployment occurred.

Doc impact: this note and scoped BUG-1793644514 evidence; user startup instructions
and API/architecture contracts remain unchanged because runtime behavior is unchanged.
