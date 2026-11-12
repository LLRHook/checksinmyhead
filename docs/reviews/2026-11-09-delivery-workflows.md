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

## Complete revision gate (BUG-1793644501)

### Focused S4 review

S4, as the [November 5 note](2026-11-05-delivery-gate.md) records it, is that review's
residual finding: a registration that the manifest does not require (then two public
render cases) can disappear while its row stays green. The raw review files are in task
scratch and were not available here. This review compared the manifest
with reports produced here from the current source, using the unchanged adapters.

| Row | Runner records | Selections | Result |
|---|---|---|---|
| web (`npm test`, JSON) | 102 in 11 files | 102 | One selection per case. Both public render cases are required. |
| mobile (`flutter test --no-pub`, JSON) | 599 in 51 files | 455 | All satisfied; four cases matched no selection. |
| local-workflow | 55 | 55 families | Equal. |
| Go, static | 226 default, 242 tagged families | same | Equal; four tests under `a1perf`, `a2perf` and `replayperf` tags belong to neither row. |
| automation, static | 83 methods | 83 families | Equal. |

Finding 1 (fixed): `mobile/test/receipt_native_io_test.dart` registers four named
modes in one loop with a conditional title (`cancellation`, `source-error`,
`cleanup-error`, `reentrant`). No selection matched any of them. The manifest now
requires each; the regression produced four intended failures against the old
manifest. The real mobile report still validates (459 selections).

Documented limit, unchanged: 134 mobile records are further expansions of a data loop
whose registration is required once, and six are `setUpAll`/`tearDownAll` hooks.
Nothing compares the manifest with the source inventory, so a new registration is
required only once someone adds it. That is an owner decision, not changed here.

### Scan commands were not part of the contract

Finding 2 (fixed): the graph test accepted a `checks.yml` without `govulncheck`,
`npm audit`, `go vet`, `gofmt`, `go mod verify`, `flutter analyze`, lint or build, with
a scan masked by `|| true`, with `set +e`, with a skipped or re-shelled command step,
with a step that overwrites the report, or with a job `env`. The original defect was
failed security steps that did not stop publication, so this control needed a test.
`validate_graph` now pins every row's command lines, shell, run-step list and job
keys. Nineteen mutations, all accepted before, are rejected.

### Hosted state read on 2026-11-09 (GET only)

- Repository variables: 0. `RELEASE_POLICY` is unset, so every target is disabled.
- Environments: 0. `backend-production`, `web-production`, `ios-upload` and
  `ios-production` do not exist; GitHub creates an unprotected environment on first use.
- Ruleset `protect main` (4951594): no force push, no deletion, pull request with zero
  approvals. It requires no status check, so `Required delivery checks` does not
  block a merge.
- A second TestFlight uploader exists outside this graph:
  `victorwake-testflight.yml` on branch `victorwake-testflight-runner` (bundle
  `com.victorivanov.victorwake`), triggered by a push to that branch or by dispatch,
  reading repository secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_API_KEY_P8`,
  `BUILD_CERTIFICATE_BASE64` and `P12_PASSWORD`. Last runs: failure on October 29,
  success on July 6.

## Workflow execution settings (BUG-1793644519)

Checked on the nine current workflow files and the composite action.

| Setting | Current state | Evidence |
|---|---|---|
| Action pins | Five actions, each a 40-character SHA | GitHub API: the SHAs are tags `actions/checkout` v5.1.0, `actions/setup-go` v6.5.0, `actions/setup-node` v5.0.0, `subosito/flutter-action` v2.23.0, `actions/upload-artifact` v7.0.2; newest commit October 7. |
| Token | `contents: read` in every workflow; `actions: read` added on five iOS jobs only | Controller test. |
| Mirror host identity | Pinned Ed25519 key, `StrictHostKeyChecking=yes` | Equals the key GitHub publishes at `GET /meta`. |
| Timeouts | Every job, 5 to 60 minutes | Controller test; PostgreSQL row keeps 30. |
| Concurrency | See below | Controller test. |

The validator is the bootstrap pipeline validator (`validate-pipeline.py --provider
github`). Before: **0 errors, 8 warnings** in 9 files (the earlier six, plus the two
reusable iOS workflows added since). After: **0 errors, 5 warnings**.

Three warnings were real and are fixed. `testflight.yml`, `app-store-release.yml` and
`update-release-notes.yml` are entry workflows with no group, so repeated dispatches
each ran the full six-row validation in parallel. Each now has its own group per ref
and event with `cancel-in-progress: false`: runs queue, and a running one, which may
be uploading or writing to App Store Connect, is never cancelled.

Five warnings stay, one per reusable workflow, and are intended:

- `checks.yml`: validation only. Its caller's group governs it, and cancelling the
  caller cancels its rows. GitHub evaluates a called workflow's group in the caller's
  `github` context, where a matching group cancels the caller.
- `deploy-backend.yml`, `sync-web-viewer.yml`: one mutation job each, serialized by
  the literal noncancelling job groups `backend-production` and `web-production`.
- `ios-origin.yml`, `ios-promote.yml`: one mutation job each, sharing the literal
  noncancelling job group `ios-upload`.

`ci.yml` keeps `controller-<ref>-<event>` and cancels in progress only for pull
requests. Hosted runs 42290401669 and 42289112203 were cancelled that way on
November 6. A newer main push never cancels a running main run.

New `GraphTests.test_execution_settings_are_pinned_bounded_serialized_and_read_only`
pins all of the above with 36 mutations. Fourteen were accepted before this change,
among them cancelling a main run in progress, removing a group, a top-level group in
a reusable workflow, a 360-minute timeout and a write token on the resolver job.

The diff adds three `concurrency` blocks and tests. No trigger, condition, secret,
permission or publisher changed; publication stays disabled without `RELEASE_POLICY`.

NOT OBSERVED: GitHub's parse of the three edited entry files, and queueing between two
real dispatches. Nothing was dispatched.
