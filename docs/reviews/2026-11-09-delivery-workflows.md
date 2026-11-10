# Delivery workflows — 2026-11-09

Scope: BUG-1794258285, BUG-1793644501 and BUG-1793644519. Base `e0a2c18` on main
`5e877e3`. Source and offline evidence, plus read-only GitHub API reads. No workflow
was dispatched or re-run, no setting changed and nothing was published. Hosted
acceptance is stated per item and is not claimed here.

## Invalid iOS origin workflow (BUG-1794258285)

Every push since `fc98e85` (November 5) created a failed run named
`.github/workflows/ios-origin.yml` with zero jobs, on main and on every branch. Run
42365245707 (main `5e877e3`, event `push`) carries this annotation:

```text
Invalid workflow file: .github/workflows/ios-origin.yml#L1
(Line: 60, Col: 16): Unrecognized named-value: 'runner'. Located at position 1 within expression: runner.temp
(Line: 61, Col: 20): Unrecognized named-value: 'runner'. Located at position 1 within expression: runner.temp
(Line: 62, Col: 20): Unrecognized named-value: 'runner'. Located at position 1 within expression: runner.temp
```

Lines 60–62 were the job-level `env` entries `IPA_DIR`, `RECEIPT_DIR` and
`ASC_RECEIPT`. GitHub's context-availability table gives `jobs.<job_id>.env` the
contexts `github, needs, strategy, matrix, vars, secrets, inputs`; `runner` exists
only inside steps. `ios-promote.yml`, added in the same commit, names no runner
context and never failed. While the file was invalid, a TestFlight dispatch could not
have started its origin job either.

Fix: the three paths, with unchanged values, are now `env` of the steps that read
them: the signed-IPA action (`IPA_DIR`), the upload step (`ASC_RECEIPT`) and the
receipt step (`ASC_RECEIPT`, `RECEIPT_DIR`). The runner merges a calling step's `env`
into a composite action's steps (`CompositeActionHandler`, "Merge composite-step
env"), so `ios_sign.py` still receives `IPA_DIR`. Step count, order, inputs, secrets,
permissions and artifact paths are unchanged.

Controls added:

- `GraphTests.test_workflow_expressions_use_only_documented_contexts` encodes the
  documented table and the reusable-call contract (typed inputs, declared and required
  inputs/secrets, allowed call keys, callee token within the caller's). On the
  `e0a2c18` file it fails with `Unrecognized named-value: 'runner' at
  ios-origin.yml:jobs.origin.env.IPA_DIR`. It carries 28 rejected mutations and four
  accepted controls. `validate_graph` runs the same check.
- `validate_ios_graph` binds each path to its reading steps only, and requires the
  authority step third, unconditional, after two checkouts. Seven new mutations.
- `test_current_gate_main_and_floors_are_reauthorized_before_origin` now proves that
  each of the three iOS targets, accepted with a synthetic enabled policy, refuses an
  empty, absent or disabled `RELEASE_POLICY` before any authenticated read.

Result: 43 gate methods, 17 iOS helper methods, 5 and 18 Ruby methods pass; the
automation row validates 1,422 records, zero failed or skipped. actionlint is not
installed on this host; the table was read from GitHub's contexts reference.

NOT OBSERVED: GitHub's own parse of the corrected file. That needs the first push
that carries it; acceptance is no failed `ios-origin.yml` run for that push.
