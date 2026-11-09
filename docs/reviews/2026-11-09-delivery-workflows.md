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

### Expected, bullet by bullet

1. Failed tests or scans block backend and web publication for that revision: met in
   source. Hosted run 42365246558 (main `5e877e3`) shows it once: `Gate postgres`
   failed, both collectors failed, `publish-backend` and `publish-web` were skipped.
   Policy was also unset, so that run does not isolate the gate edge.
2. TestFlight and App Store use the common gate with no untested rebuild: met in
   source (one origin build of the gated S; promotion and notes reuse the proven
   processed build). Native signing, ASC and hosted execution are NOT RUN.
3. Render and Vercel automatic deployment: **BLOCKED**, control planes not readable
   here. Observed only: production `/health` reports `81a564f` on November 9, after
   main pushes `22eb43d` and `5e877e3`. Both pushes had a failed CI, so this cannot
   tell "auto-deploy off" from "deploy after checks pass". The mirror
   `dhaliwalg/checksinmyhead` returns 404 to this token.
4. Negative gate-path tests and exact-SHA health proof are reviewable; nothing was
   deployed, dispatched or re-run.

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

### Owner checks that keep the ticket open

- Render service for `billington-api`: Auto-Deploy mode and branch; whether the
  deploy hook is the only trigger; pull-request previews.
- Vercel project: which repositories are connected, production branch, deploy on
  push, deploy hooks; who and which keys can push to the mirror.
- Create the four environments restricted to `main` and move the `DELIVERY_*` secrets
  into them; decide the fate of the legacy repository-level signing and ASC secrets
  and of the `victorwake-testflight-runner` workflow.
- Add `Required delivery checks` to the main ruleset once main is green.
- Set `RELEASE_POLICY` only with reviewed floors and clearance; then observe one
  gated publication and its exact-SHA health readback.
