# Managed delivery controls — phase G

This code defines validation and the existing backend-hook/viewer-mirror routes.
It does not establish deployment readiness. Signed TestFlight upload, App Store
promotion, notes edits and cancellation/resubmission are unavailable until phase F.
The signed-IPA composite exits unsuccessfully. The existing Ruby ASC request
transport rejects POST/PATCH/DELETE before authentication, including direct legacy
script invocations; its state/numbering algorithms remain for the separate phase.
`allow_cancel` remains an explicit boolean, default false, and cannot enable writes.

## One validation owner

`checks.yml` owns six mandatory rows: automation, local-workflow, backend,
PostgreSQL, mobile and web. Only `scope=all` is currently supported. PRs/main have
no path filters, all selected jobs are required, and `always()` collectors reject
missing, failed, cancelled, skipped or malformed results. No `continue-on-error`
or test-skip input exists. A narrow scope cannot emit the full required context.

`ci.yml` resolves full source **S** once. The checks workflow executes candidate
app code in `candidate/`; trusted helper/tests/manifest are from controller **C**
in `control/`. Every checkout asserts its full SHA and persists no credentials.
The two directories are distinct even when S=C. Release helpers never come from
an older S. For a PR C is the caller's test merge revision: validation has no
publication credentials. Privileged publication requires the main `ci.yml` caller.

The internal gate receipt binds S, C, `all`, run ID/attempt, the C-owned manifest
hash and all six successful report-summary hashes. Every collector and publisher
verifies that binding. This is a synchronous `needs` contract inside reviewed C;
it is **not** a signed artifact attestation and accepts no operator-supplied IPA or
ASC receipt. The outer proposed context is `Required delivery checks`; its actual
GitHub check name/App identity and ruleset enforcement still require observation.

The source-grounded manifest requires every ordinary Go top-level Test family and
every family in the exact eight-package integration row, including ordinary tests
selected again by that tagged command. It also requires current Python methods,
Ruby methods, Dart test files/literal registrations and web registrations/finite
table selectors. Review manifest changes with tests: a candidate S cannot replace
C's manifest or policy. Its reference SHA records inventory provenance, not a
release floor. Numeric totals from historical runs are never eligibility rules.

Adapters retain every Go package/test terminal (parents and subtests), Flutter
runner ID, Vitest assertion ordinal/title, Python method invocation/subtest and
Ruby class/method invocation. Those record counts are not interchangeable with
leaf-only counts. Default/tagged overlap is retained separately per row; do not
sum them into a distinct-test claim. File/literal families do not statically infer
all expansions of Dart's runtime data loops. Runtime starts must all finish and
any reported skip/failure/zero/malformed or missing required family/registration
fails. No-test Go packages are allowed only with the actual `[no test files]`
signal and no running tests; they do not satisfy a mandatory case family.

The PostgreSQL service is an ephemeral pinned PG17.11 instance mapped to loopback,
with synthetic `billington_test` identity. The maintained harness still rejects
missing/nonloopback DSNs, wrong identity and caller schema/options. No application
harness or timing budget is changed. This row includes existing measured cases;
CI execution would not replace independent numerical or production qualification.

For local report validation, run the existing reports through the same helper once:

```bash
python3 ops/ci/delivery_gate.py validate-reports --row backend --reports go:"$REPORT_DIR/go-default.jsonl"
```

This emits a local summary without S/C/run binding, receipt or GitHub outputs and
cannot authorize publication. Use these exact row selections (`REPORT_DIR` absolute):

| Row | Kind and report basename(s), in order |
|---|---|
| automation | `cases:gate-tests.json cases:ruby.json` |
| local-workflow | `cases:local-workflow.json` |
| backend | `go:go-default.jsonl` |
| postgres | `go:go-postgres.jsonl` |
| mobile | `flutter:flutter.jsonl` |
| web | `vitest:vitest.json` |

## Managed entry points and policy

PRs and direct backend tags validate only. Main pushes gate once, then select
backend/web publication from changed paths; shared delivery changes select both.
Backend manual/tag publication is selected by dispatching **ci.yml on main**, with
an exact full source SHA or `backend-vMAJOR.MINOR.PATCH` data input and target
`backend`, `web` or `both`. Default target is `checks`. `skip_deploy` retains the
existing backend verification-only meaning: no hook request under any outcome.
Direct feature/tag refs cannot acquire managed publication privileges.

Mutation jobs serialize without cancellation by `backend-production` and
`web-production`. Validation cancellation is limited to PRs; no workflow-level
cancellation can interrupt a publisher. Inside each mutation job, the helper
fetches fresh main and reauthorizes the exact gate/policy/source before transport.
A stale automatic run fails even if its gate was green. Manual older S requires
all source/control/schema/capability checks; there is no arbitrary historical-tag,
replay waiver or lower-floor rollback exception.

One nonsecret external `RELEASE_POLICY` is supplied via GitHub `vars`, separately
at resolution and inside the protected environment publication job. Unconfigured,
invalid or missing policy is disabled. Its safe initial value is:

```json
{"version":1,"enabled_targets":[],"control_floor":null,"targets":{}}
```

No checked-in policy or workflow input can override it. A target can pass only if
its external policy contains all of:

- `source_floor`, `schema_floor` and `control_floor`: full existing commit SHAs;
  control_floor <= C <= fresh main, source_floor/schema_floor <= S <= main by ancestry.
- Nonempty `capability_floors`: named full-SHA ancestors of S, with no caller waiver.
- Exact `schema_registry_sha256`, matching `schema_epoch`, and positive integer
  `minimum_migration`; the source registry must remain a contiguous known prefix.
- Nonempty reviewed `external_clearance` evidence reference. This references the
  owner's external evidence; a string or source ancestry alone proves no adoption,
  live capability, old-reader/writer drain, account ownership or recovery state.

Only backend/web are supported targets. iOS target names are rejected in code even
with apparently enabled policy or a success-shaped/altered artifact receipt.
Policy editors remain an external trust boundary; the helper cannot prove that a
GitHub `vars` value is the latest administrative intent during a running job.
External revocation/legacy queue drainage and credential scoping remain separate.

Actual mutation jobs declare environment-scoped names
`DELIVERY_RENDER_DEPLOY_HOOK_URL` and `DELIVERY_VERCEL_DEPLOY_KEY` and reject empty
values at runtime. Each reusable publisher declares its one named secret as
required, and its CI caller forwards that same name explicitly. The protected
environment supplies the value; required forwarding alone does not prove a
nonempty value or its scope. There is no legacy-name fallback or `secrets: inherit`;
publication secrets never reach checks. The environments must already enforce
main-only refs. Source declarations
do not create environments, relocate secrets, revoke old workflows or prove live
rules/settings. All tokens default to `contents: read`; no repository write grant
is needed for these two existing transports.

## Existing transports

Backend publication keeps `https://billington-api.onrender.com`. The helper parses
the hook privately, requires its credential and approved HTTPS host, preserves
safe query parameters, replaces `ref` with exact S, rejects image-hook overrides
and refuses redirects. It accepts documented HTTP200/202 with valid JSON, never
logs the URL, raw response or exception text, and retains the 900-second cold-start
allowance. Readback requires HTTP200, healthy JSON status and exact full commit S.
The unknown-bill probe requires 400/404; 200 fails, and 401/403 are not DB proof.
Verification-only never posts. This is the existing source rebuild route, not
byte-identical image promotion or independent binary provenance.

Web publication keeps `git@github.com:dhaliwalg/checksinmyhead.git`. It splits
explicit S with prefix `web-bill-viewer`, checks its tree against S's subtree,
requires the pinned official GitHub Ed25519 identity, and uses private temporary
key/known-host files with cleanup. Push uses the exact observed remote SHA in
`--force-with-lease=refs/heads/main:<SHA>`; an absent/ambiguous lease or race fails.
The returned mapping is S → subtree commit, with previous remote SHA. A push is
source delivery to the mirror; it proves no Vercel production deployment or
byte-identical artifact promotion.

Existing action majors use verified immutable release SHAs older than 14 days.
Flutter's nested mutable SDK/pub cache actions are disabled explicitly, as are Go
and Node's optional caches. CI-only PyYAML6.0.3 is hash-locked to the CPython3.12
Linux wheel; CI asserts that interpreter before proposed installation. This is
not an application dependency or a local installation. Dependabot maintains the
GitHub Actions ecosystem; every update still requires maturity/review evidence.

## Local proof and remaining boundaries

`python3 ops/ci/test_delivery_gate.py` runs only synthetic helper, report, YAML
wiring, tiny Git and local transport fixtures. It blocks network connects and
allows only file Git transport; it does not run the application, PG, Flutter,
Next or ASC suites. The Python/Ruby adapters test tiny synthetic runner programs.
See [VERIFICATION](../../VERIFICATION.md) for the actual app commands and reports;
produce reports in the same run, never rerun the app merely to count it.

NOT CI-CONFIRMED: native/signed binaries, processed ASC origin/eligibility receipts,
whole GUI/a11y journeys, image build/scan identity, whole security, real providers,
schema adoption/drain/restore, hosted deployment identity and field performance.
The general offline validator checks syntax/wiring only. Its top-level concurrency
warnings on reusables do not account for noncancelling per-environment mutation
jobs. No hosted integration, secret transition, settings/ruleset change, workflow
activation, queue action, signing/upload, ASC write, hook invocation, mirror push
or Render/Vercel control-plane action is authorized by this document.

Phase F must separately implement exact successful origin run+attempt, S/C,
IPA hash, ASC app/build/platform/version/processing eligibility and immutable
receipt verification before attaching the already processed TestFlight build.
No rebuild/latest fallback or needless build-number increment is allowed. Keep
the existing versioning/Runner/UI synchronization rules and explicit cancellation
consent; test processing/readback and source/binary compatibility separately.
Root owns independent review, a later application lease and all acceptance.
