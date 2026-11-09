# Managed delivery controls — phases G and F

One gate controls validation, the existing source publishers, and processed iOS
artifact delivery. Phase F implements origin receipts, exact existing-build promotion
and attached-build notes/cancellation. Targets remain disabled without valid external
policy and main-only environments. Source implementation is not hosted, signing,
ASC, device, credential-transition or production qualification. Initial hosted
PostgreSQL/whole acceptance remains RED; no delivery failure is waived here.

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
sum them into a distinct-test claim. Go literal selections use the full report-prefixed
runner ID when no display name exists. The tagged migration outcome family requires
all five exact children ([scoped evidence](../../docs/reviews/2026-11-06-migration-outcomes.md));
this does not qualify the real PgSleep/rollback gate. Assignment decoder families require
all70 exact child IDs in both backend and PostgreSQL report namespaces; their
standalone receiver-sequence parent is mandatory in both rows. Snapshot canonical-row
characterization is PostgreSQL-only. Existing-method fixtures independently declare
the literals and reject each omitted run+terminal pair with all families retained.
[Scoped results](../../docs/reviews/2026-11-06-assignment-snapshot.md) do not establish
SQL fidelity, performance recovery or a full gate. File/literal families do not statically infer
all expansions of Dart's runtime data loops. Runtime starts must all finish and
any reported skip/failure/zero/malformed or missing required family/registration
fails. No-test Go packages are allowed only with the actual `[no test files]`
signal and no running tests; they do not satisfy a mandatory case family.

The PostgreSQL service is an ephemeral pinned PG17.11 instance mapped to loopback,
with synthetic `billington_test` identity. The maintained harness still rejects
missing/nonloopback DSNs, wrong identity and caller schema/options. No application
harness or timing budget is changed. This row includes existing measured cases;
CI execution would not replace independent numerical or production qualification.

The row first builds both service binaries so the startup test's unchanged 60s build
bound measures a warm link, not a cold compile competing with eight race builds. It
sets `-timeout=20m` per package and a 30-minute job bound: the measured creation and
lifecycle cohorts need 5.5–9 minutes on hosted runners, which left no margin under
Go's 10-minute default. Samples, cohorts and operation targets are unchanged; see the
[timing evidence](../../docs/reviews/2026-11-09-pg-gate.md).

For local report validation, run the existing reports through the same helper once:

```bash
python3 ops/ci/delivery_gate.py validate-reports --row backend --reports go:"$REPORT_DIR/go-default.jsonl"
```

This emits a local summary without S/C/run binding, receipt or GitHub outputs and
cannot authorize publication. Use these exact row selections (`REPORT_DIR` absolute):

| Row | Kind and report basename(s), in order |
|---|---|
| automation | `cases:gate-tests.json cases:ruby.json cases:ios-python.json cases:ios-ruby.json` |
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
  Backend `additive_ddl_warm_reader` also bounds the serving predecessor (see transports).
- Exact `schema_registry_sha256`, matching `schema_epoch`, and positive integer
  `minimum_migration`; the source registry must remain a contiguous known prefix.
- Nonempty reviewed `external_clearance` evidence reference. This references the
  owner's external evidence; a string or source ancestry alone proves no adoption,
  live capability, old-reader/writer drain, account ownership or recovery state.

Backend/web keep their existing transports. The same authorization owner also
supports `ios-upload`, `ios-production` and `ios-notes`, each bound to its exact
main-dispatched caller. Their artifact/ASC checks below are additional requirements.
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

Before the hook request the helper reads `/health` once, because the new revision
migrates at startup while its predecessor still serves. It continues when the answer
is neither HTTP200 nor a JSON object (nothing serving; the service's own 5xx health
object still counts as serving), names S itself, or names a related revision whose
schema registry is at least as long as S's (no step to apply). Otherwise a schema
step is pending and the serving revision must descend from the backend capability
floor `additive_ddl_warm_reader`: the first main revision whose warm readers are
proven to survive additive DDL (`TestPostgresWarmServiceSurvivesAdditiveDDL`), set
by the owner like every other floor. A missing floor, an older, unknown or unrelated
serving revision, an unreadable `commit`, or no HTTP answer is rejected with no
waiver: stop that revision first. The deployed pre-registry revision cannot pass
while it serves ([evidence](../../docs/reviews/2026-11-09-reader-ddl.md)). This is one
observation before the request, not proof that a stopped service stays stopped, and
it says nothing about writers of the predecessor.

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
Linux wheel; CI asserts that interpreter before installation. This is
not an application dependency or a local installation. Dependabot maintains the
GitHub Actions ecosystem; every update still requires maturity/review evidence.

## Local proof and remaining boundaries

`python3 ops/ci/test_delivery_gate.py` runs only synthetic helper, report, YAML
wiring, tiny Git and local transport fixtures. It blocks network connects and
allows only file Git transport; it does not run the application, PG, Flutter,
Next or ASC suites. The Python/Ruby adapters test tiny synthetic runner programs.
See [VERIFICATION](../../VERIFICATION.md) for the actual app commands and reports;
produce reports in the same run, never rerun the app merely to count it.

The same module applies GitHub's documented context-availability table and
reusable-call contract to every workflow (`validate_workflow_syntax`). GitHub refuses
a whole file, on every push, when an expression names a context its key lacks:
`runner` exists only inside steps, so origin's three runner-temp paths are step env,
never job env. This is a source check, not GitHub's parser: hosted proof is a push
that creates no failed run for the file ([evidence](../../docs/reviews/2026-11-09-delivery-workflows.md)).

NOT CI-CONFIRMED: native/signed binaries, processed ASC origin/eligibility receipts,
whole GUI/a11y journeys, image build/scan identity, whole security, real providers,
schema adoption/drain/restore, hosted deployment identity and field performance.
The general offline validator checks syntax/wiring only. Its top-level concurrency
warnings on reusables do not account for noncancelling per-environment mutation
jobs. No hosted integration, secret transition, settings/ruleset change, workflow
activation, queue action, signing/upload, ASC write, hook invocation, mirror push
or Render/Vercel control-plane action is authorized by this document.

## Processed iOS artifact authority

The three existing entry points reuse resolve/checks/required with `scope=all`.
`testflight.yml` calls `ios-origin.yml`; App Store and notes call `ios-promote.yml`.
Only main dispatch can enter their protected jobs. Release tags validate without
secrets. All three mutation paths share the noncancelling `ios-upload` group;
`ios-upload` is the signing environment, `ios-production` the ASC-only environment.
Each caller forwards exactly its declared required named secrets. Both use
`DELIVERY_ASC_KEY_ID`, `DELIVERY_ASC_ISSUER_ID`, `DELIVERY_ASC_API_KEY_P8`; origin
alone also uses `DELIVERY_BUILD_CERTIFICATE_BASE64`, `DELIVERY_P12_PASSWORD`,
`DELIVERY_PROVISIONING_PROFILE_BASE64`. No legacy fallback is read. Token permissions
are `contents: read`, with `actions: read` only for authenticated evidence. Convenience TestFlight tag emission is deliberately retired by the November 5
driver decision: exact immutable receipts carry the required identity. This is
an authority simplification, not a deferred provenance feature. Existing historical
tags are retained; tag events/inputs remain checks-only candidate data and never
constitute receipt proof. No tag/ref creation or GitHub refs-write owner exists;
release, settings and provider-control writes remain outside this contract.

Every entry obtains fresh main and calls the original `delivery_gate.authorize`:
S/C/all/run/attempt/report-manifest binding, control/source/schema/capability floors
and external clearance are unchanged. The authenticated current attempt's actual
six gate jobs and both collectors must also be successful; status attached to C
alone does not establish testing S. CLI callers cannot supply a local origin JSON.
`asc_delivery.rb` is the only ASC mutation entry point, obtaining its context from
the C-owned Python verifier. The direct legacy scripts cannot arm the transport.
The process-local write session restricts methods, app-scoped resource identities,
relationships and attributes. Screenshots, description, keywords, privacy, icon and
other marketing metadata have no permitted write shape. API diagnostics are finite,
redirects refused, reads/pagination/polling bounded, JWTs refreshed before expiry,
and mutations never implicitly retried.

Each iOS target's existing floor/clearance policy additionally identifies `app_id`,
`bundle_id`, exact `toolchain` and `artifact_download_hosts`. Toolchain has `flutter`
(3.41.5), `cocoapods` (1.16.2), exact `xcode` output, `sdk` version (at least 26) and
an exact versioned `/Applications/Xcode_…app/Contents/Developer` path. No latest SDK
fallback is used. Download hosts are an external reviewed list of exact HTTPS
storage hosts, constrained to GitHub Actions/Azure blob suffixes; arbitrary hosts,
userinfo, fragments and credential forwarding are refused. Upload alone also needs
`previous_source`, an ancestral released source for the AGENTS marketing and source
build increment check. Policy supplies no invented release baseline or eligibility.

A future authorized origin builds S once with C's action and pinned toolchain,
locked Dart/Pods acquisition and original Runner-only manual-signing seam. Candidate
checkout, source/Runner/Settings versions and lock bytes must agree. The next ASC
number preserves numeric/dotted tuple rules, including strict operator validation.
An upload rerun is refused: reconcile any prior upload and authorize a new origin
explicitly. Do not retry an ambiguous shell/transport failure into another upload.
Project/export, owned profile and keychain cleanup are attempted independently,
preserving a primary failure if restoration also fails. Command groups are closed
and joined after successful and failed parent exits; cleanup requires observed
absence within its deadline. Preexisting profiles are never overwritten. The
primary IPA bundle must uniquely report the expected bundle/platform/version/build.
The signer copies the inspected byte snapshot. Its hash is forwarded to upload and
receipt creation; upload validates a private copy and records a local hash witness.
Changed bytes or a missing witness block the receipt. This witness is not an ASC
API byte attestation. altool validation and one upload are followed by positive exact ASC app,
platform, marketing/build, `VALID`, `APP_STORE_ELIGIBLE`, nonexpired eligibility and
readback. A delivery UUID or process exit alone cannot create promotion evidence.
TestFlight What's New is scoped to that build and read back when requested.

Two immutable ZIP artifacts are uploaded without overwrite or workspace globs:
`ios-ipa-S-RUN-ATTEMPT` contains only `candidate.ipa`; `ios-origin-S-RUN-ATTEMPT`
contains only `receipt.json`. The receipt records S/C/all/gate/run/attempt, source
and actual binary metadata/hash, toolchain, lock hashes, verified ASC identities
and the already-uploaded IPA artifact ID/digest/name. It cannot contain its own
artifact digest; promotion obtains that independently from authenticated metadata.
Retention is requested for 90 days, subject to repository settings/deletion. Missing
or expired evidence blocks promotion with an actionable evidence requirement.

Promotion/notes require explicit source, origin run AND attempt and ASC build ID.
The verifier reads that exact successful attempt, exhausts bounded job/artifact
pagination, requires every gate/upload job's success and exact C/run/attempt,
and correlates artifact creation with the selected upload job's time window.
GitHub artifact metadata has no attempt field: reviewed workflow naming, receipt
binding and the actual job window supply that additional conservative binding.
It selects exactly one immutable named receipt, checks archive size/digest/ZIP
members, then fetches its exact IPA ID and checks digest, actual IPA metadata/hash,
source/lock/gate/toolchain/current-floor bindings. Redirected downloads receive no
GitHub auth headers, cookies or token; a second redirect is rejected. Current
manifest/toolchain compatibility is required; legacy evidence is never implicitly
grandfathered. A policy change that makes old evidence incompatible requires a
reviewed explicit decision, not a latest artifact/build fallback.

Ruby then re-reads the exact ASC build and its actual app/pre-release relationships
before release mutations. Promotion attaches that build, reads the attachment even
when staging without review, and retains editable/rejected-version reuse and the
three-step submission/readback flow. It cannot allocate a number, sign, build or
upload. Notes require the attached proven build before edits/cancel/resubmit and
afterward. Locked review with default `allow_cancel=false` performs no write/cancel;
explicit consent permits bounded cancellation/unlock and optional same-build
resubmission. Verification-only performs GET eligibility checks with in-memory JWT
signing, without credential files, signing, upload, tags or ASC writes.

The lasting offline selections are `test_ios_artifact.py` (actual helper/ZIP/API/
workflow/signing-lifecycle fixtures) and `asc_delivery_test.rb` (actual ASC/state/
entry-point fixtures), registered additively in the automation manifest/reports.
The original five Ruby methods/nine assertions and every prior app family/pattern,
including both exact public render names and repeated registrations, remain.
Native signing/toolchain execution, real authenticated GitHub/ASC behavior, device
journeys, environment/secret/queue transitions and external enforcement are NOT RUN.
No production action is authorized by these source controls.

Run the additional automation report commands from the repository root with the
same absolute `REPORT_DIR` used by VERIFICATION (CPython3.12 and maintained Ruby):

```bash
CASE_REPORT="$REPORT_DIR/ios-python.json" python3 ops/ci/unittest_report.py ops/ci/test_ios_artifact.py
CASE_REPORT="$REPORT_DIR/ios-ruby.json" ruby -r "$PWD/ops/ci/minitest_report.rb" .github/scripts/asc_delivery_test.rb
```

These are integrated source controls. Offline host qualification uses synthetic
transports; Linux wheel acquisition, native signing and live GitHub/ASC delivery
remain NOT RUN. The initial hosted PostgreSQL failure and current B numerical,
runtime, resource and whole-release RED gates remain open. Integration evidence:
[November 5 note](../../docs/reviews/2026-11-05-ios-delivery-integration.md).
