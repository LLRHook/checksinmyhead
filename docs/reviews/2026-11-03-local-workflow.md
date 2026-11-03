# Local workflow implementation — 2026-11-03

Scope: BUG-1793644513/4514 and only the local-default slice of FEAT-1793644504.
Started from matching local/remote `fb6b4b99e8a1726c9334ba30a9042f8665ae3551`
on `chore/billington-foundation-program`, with a clean tracked tree. The original
untracked reviews, artifacts and Android directory were preserved. This is scoped
source verification; driver independent acceptance and integrated/security gates remain
open. BUG4513/4514 stay in-progress; FEAT4504 stays open. No CHANGELOG migration.

## Interface and ownership

One root Bash entrypoint remains. `./dev.sh setup` explicitly acquires the committed
resolution with npm ci, Flutter enforced lock and CocoaPods deployment mode. Toolchain
checks read Node24, npm11, Flutter3.41.5 and CocoaPods1.16.2 from maintained pins/docs.
Existing environment files are preserved and never evaluated as shell input. Startup
creates no env examples and installs nothing. `--no-mobile` omits all iOS/Flutter
requirements; default invocation retains the full stack and interactive hot reload/quit.
Flutter's own pod acquisition request is guarded because --no-pub alone cannot prevent it.

Prerequisite/configuration failure has diagnostic-only EXIT handling. Runtime cleanup is
installed after prerequisites/ownership state exists. It stops exact container IDs
started/restarted by this run, including partial Compose failure/interruption, in reverse
order. Running pre-existing services are neither replaced nor stopped; stopped containers
are reused, so rebuilding changed source/config is an intentional make up operation.
Bash job control gives npm and Flutter owned process groups. TERM, bounded grace and KILL
cover npm's shell/Next descendants even if the npm leader exits. Signal handlers retain
130/143; cleanup is idempotent and retains original failure status. Ports are checked
without killing occupants. Web logs use a private mode0700 unique run directory.

Readiness inspects the selected container's actual health and checks loopback HTTP;
Next and selected simulator readiness are bounded rather than fixed startup sleeps.
Default bound is90s per stage, configurable only within1–180s. Simulator selection requires
an explicit available iOS UDID or the sole booted available device; ambiguity fails before
Docker startup. No arbitrary device selection, erase or simulator shutdown is used.

Make wrappers remain thin and use docker compose. Ordinary down includes the retained
legacy profile and preserves all volumes. There is no project/name/volume rename:
default project selection is unchanged and the volume key remains postgres_data.
Default config has only postgres/bill-service; legacy-web explicitly adds web-service
on its existing8081 URLs. Go source/templates/Dockerfiles/test coverage are unchanged.
This establishes no external-consumer or cloud-retirement claim.

The sole production helper is the destructive test reset boundary. It requires an
explicit isolated billington-test-* / billington-vv-* project and owner token. Every
container/network/volume must match Compose project, io.billington.test-owner and
io.billington.test-data=synthetic labels. All mounts must be owned volumes/tmpfs.
No deletion occurs until the complete inventory passes twice. Exact IDs are used,
volumes are rechecked and Docker refuses still-used volumes. No broad down -v or force
bypass can select ordinary data. Python stdlib fixtures add no dependency/service/cache.

## Before-proof, controls and final execution

Driver before-proof remains unchanged under scratch
`billington-structure-evidence/local-workflow-baseline-13be27b/`; result SHA256
`0a7a10d7530ce67eb929bb3671d5970cf93a219a167eaaf99b765242ab923c36`.
The exact pinned Makefile at13be27b erased its uniquely owned real PostgreSQL volume:
sentinel1 before, absent after restart. Two byte-identical dev.sh stub runs showed
shutdown on missing Flutter before startup and npm exit42 with its diagnostic discarded.
Root already removed that fixture. These are executed expected-before failures,
not grep-derived claims or successful fixed-source tests.

New raw evidence: ignored `.vv/local-gate/local-workflow/` in this repository.

| Row | Exact command / selection | Actual result |
|---|---|---|
| Shell syntax | `/bin/bash -n dev.sh`; `bash -n dev.sh` | Both0; macOS Bash3.2.57 and Bash5.3.15 |
| Python syntax | `python3 -m py_compile scripts/reset_local_test.py scripts/test_local_workflow.py scripts/verify_local_lifecycle.py` |0; Python3.13.5 |
| Stub CLI/reset | `python3 scripts/test_local_workflow.py` | Final42 tests0 failures0 skips; `stubs-exact-source.log` |
| Terminal addition | `python3 scripts/test_local_workflow.py StartupTests.test_interactive_flutter_owns_terminal_for_quit` |1 additional test passes; synthetic q reaches foreground Flutter; `stubs-tty.log` |
| Real lifecycle | `python3 scripts/verify_local_lifecycle.py --postgres-image sha256:3b0cda93be7c8dba2ed484d19393d93845dc3dafb88973e248ba8e6d99d784e1 --output .vv/local-gate/local-workflow/lifecycle-final` |5 grouped assertions pass; cleanup complete |
| Existing Ruby | `ruby .github/scripts/asc_release_test.rb` |5 runs9 assertions0 failures/errors/skips; no App Store access |
| Ruby syntax | `ruby -c .github/scripts/asc_api.rb`, `asc_next_build.rb`, `asc_release.rb`, `asc_update_notes.rb` | Four0/Syntax OK |
| Tracker/static | `python3 .cycle/trackers.py install`; `python3 .cycle/trackers.py lint`; `git diff --check` |0 errors/warnings, clone hooks retained |

43 distinct stub tests cross the public CLI/helper seam. They execute real owned child/
grandchild processes but stub all Docker, curl, npm acquisition, Flutter, CocoaPods and
simulator effects. Cases include pinned setup/preserved env/absent state, useful exit42/
43/44/45 diagnostics, quiet validation, occupied ports, bounded health/HTTP/simulator
failure, partial-up signals, pre-existing running/stopped/unhealthy services, repeated
TERM/INT cleanup, status0/130/143, cleanup errors, runtime web failure, private logs,
no-mobile isolation, simulator ambiguity/selection and blocked implicit pod install.
The reset suite exercises normal project/wrong resource ownership/unconfirmed data,
foreign/bind mounts and successful exact-resource deletion. A synthetic dotenv shell
payload never executes. No real mobile app/device mutation occurs in these tests.

First stub run:37/38 passed, one harness assertion failed because macOS canonicalized
/var to /private/var. Normalizing the fixture path fixed it; targeted retest passed.
`stubs-first.log`, `stubs-retest-path.log` and intermediate42-pass logs are retained.
This was a fixture-path comparison, not a source lifecycle failure. Documentation size
checks initially failed during expansion; compacted prose preserves all baseline rows,
D1–D5 and Last verified, and the final file is20408 bytes (<20KiB).

Final real fixture: project `billington-test-local-74c9c74284dc`, owner `55489fca-d6ab-4879-8a30-77916db10a16`;
volume `billington-test-local-74c9c74284dc_postgres_data`. Immutable pre-installed PostgreSQL image:
`sha256:3b0cda93be7c8dba2ed484d19393d93845dc3dafb88973e248ba8e6d99d784e1`. It uses a new synthetic database and no host ports.
The actual Makefile down is executed through a CLI adapter restricted to precisely this
fixture; the adapter asserts exact compose/profile/down arguments. After ordinary down,
the existing volume survives and its sentinel count stays1 on restart. Normal project
and wrong-owner reset both fail with the sentinel still1. A second project volume missing
the synthetic label blocks the entire reset before any deletion; its exact ownership is
checked before removing that temporary control volume. Correct owned reset succeeds,
then a new database has no sentinel. Final owned containers, volume and network are absent.
The first successful fixture `billington-test-local-744e9f138090` was also fully removed.

`lifecycle-final/result.json` retains every command/exit, five assertions, input hashes
and cleanup proof; numbered stdout/stderr retain expected reset rejections. Before/after
protected-resource snapshots match exactly: existing Docker volume names and container
IDs/states, including running shared billington-driver-pg-20261102, are unchanged.
Source identities for this gate:

```json
{
  "dev.sh": "58977ed929cf2a113860b7d00abc6f7c3b6bba05fefe40ad7b4747ba80a52094",
  "backend/Makefile": "f8ed6d5116e3f9a72ed9aaed935703880c35dfca55604d5ab7a97c75260258d9",
  "backend/docker-compose.yml": "174d730d28a9576f253ecb66985836111f96da76f7bf4c85505e22a9e6a60ff7",
  "scripts/reset_local_test.py": "cc807c9a5f689b54e4d34fd11a688e04d77006c2f582596a54ffd50707e2282d",
  "scripts/test_local_workflow.py": "3d5f37bf3aac0d7a1f2333eee3a6e0c7261e5b3af318b0ee7ee6dd2d5025a171",
  "scripts/verify_local_lifecycle.py": "e368d4cf571daf7afefd07994e640ade02352feb7d42ec6f476572e737c74a4b"
}
```

The TTY test was added after the42-case run without changing implementation behavior;
its separate run makes43 distinct passing cases, not two full-suite counts added together.
The shell/config/Ruby/fixture rows are scoped local gates, not all CI or integrated V&V.
No application/dependency/lock/migration/publication code changed, so unrelated Go,
Flutter and web suites were not rerun. Legacy Go coverage/build definitions are retained;
prior driver Go evidence is recorded separately below if reconciled. ShellCheck is not
installed and was not run. Real full-stack/mobile startup and real locked acquisition
were not run; installed Node25.9.0 differs from required24 and is now refused explicitly.
There are no selected stub/fixture test skips. No production/customer DB/provider request,
hosting login/settings/deploy/hook/rollback or global configuration change occurred.

## Documentation impact

| Living document | Keys / change |
|---|---|
| README.md | Explicit setup, no-mobile, ownership, readiness, simulator, logs, safe shutdown and profile |
| backend/README.md | Compose subcommand, thin make commands, guarded reset and exact regression commands |
| mobile/README.md | Deployment-only pods, selected device, no-pub/guarded startup |
| web-bill-viewer/README.md | Locked setup, actual3100 port and retained legacy profile |
| docs/technical-overview.md | Default local renderer and retained explicit legacy viewer |
| VERIFICATION.md | Full baseline/Last verified retained; local test row and labelled guarded Appendix A |
| bugs.md/features.md | Official writer only; scoped Fix/Implementation/Docs; acceptance remains open |

Historical backend/roadmap.md remains a history record (as its header states). Existing
API/provider environment contracts are unchanged. No claim about legacy external users,
currency-provider cleanup, cloud resources, runtime/dependency acceptance or whole-product
security follows from this local workflow gate.

## Authorized tracker-only reconciliation

This second logical change adds no server fix. Official `.cycle/trackers.py` alone
minted BUG-1793725849 (medium panic recovery confidentiality) and BUG-1793725850
(medium OCR redirect/API-key boundary). A pre-write search found no equivalent redirect
or panic ticket; these do not duplicate SQL-specific BUG4509 or general OCR spend BUG4508.
BUG4507/4508 retain open status with corrected before-proof and existing protections.
BUG4513/4514 remain in-progress. Atomic BUG4504/FEAT4506, authentication and runtime/
dependency acceptance statuses are unchanged. No CHANGELOG migration or PR comment.

FEAT-1793644505 returns to shipped-pending-migration under the driver's explicit
reconciliation authorization. Independent CATALOG_CORRECTION_REVIEW.md approves the exact
13be27bd6c2ec763c21e7ce1cbc44719f5f90e69 correction, zero Standards/Spec findings,
with reviewer execution NOT RUN. Report SHA256:
6bc7c93356966aec935558ba55bca7fcfe0c680c2a9d94034b21df47cbbe5e3f, matching
PENDING_REVIEW_DISPOSITIONS.json. Its scoped approval retains frozen v1/migration payloads,
ledger history and one-query readiness; it does not establish production adoption.
Earlier469-case original proof, v2's504 distinct cases,20 executed before failures,
22 targets and four protection-removal controls remain in the prior dated migration/
catalog notes and raw records. This reconciliation does not rewrite those records.

Fresh driver gate: scratch billington-structure-evidence/atomic-clean-fb6b4b9/result.json,
source fb6b4b99e8a1726c9334ba30a9042f8665ae3551, clean committed driver execution
November3 16:37:30–16:40:55UTC, Go1.27.3. Commands recorded there: go build ./...;
go vet ./...; format check; go test -race -count=1 -json ./...;
go test -race -count=1 -tags=integration -json ./internal/bill ./internal/tab
./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres;
go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./.... Default414 and tagged545 passing
leaves overlap336, yielding623 distinct, zero failures/skips/missing/duplicate terminals
or cached streams. All182 owned schemas were checked absent; its driver worktree was
removed. I verified retained records/input hashes against the unchanged backend source,
without creating a checkout or rerunning these suites. This supports only the authorized
catalog status reconciliation; accounting/identity/replay/integrated acceptance is not closed.

### Panic confidentiality before-proof (new BUG-1793725849)

Source:13be27b. Driver `verify_recovery_log_baseline.py` added its diagnostic test to
an isolated backend archive and ran `go test -race -count=1 -json ./pkg/safehttp -run
'^TestDriverRecoveryCapabilities$'`. Actual RequestLogger + gin.Recovery produced five
leaves: three failed confidentiality assertions, two passing controls, zero skips or
missing terminals; exit1 is expected before-state. The debug-mode request dump emitted
a synthetic query capability and X-Member-Token. Release recovery emitted synthetic
private panic text. Authorization redaction and release request omission controls pass;
all cases returned500 and normal request logging stayed query-free. Source defaults to
debug because neither entrypoint selects a mode; actual production GIN_MODE is unknown.
No real panic/credential leak is claimed. Release mode alone cannot protect raw panic
content. Preserve the separate completed SQL logger/request database-error sanitizer.
Later acceptance requires finite safe recovery diagnostics plus generic500 in both modes,
with executed query/header/panic taint controls and ordinary request logging preserved.

Raw recovery/{result.json,before.jsonl,before.stderr} is under scratch
billington-structure-evidence/receipt-resources-baseline-13be27b/.
Compiled test SHA256:c6abf499b82d8c587f951789bab683196358f2d43972e6dc8fb4a0bec1cd1886.
Diagnostic input `recovery_log_baseline_test.go` SHA256:
ce298c03ae96b0fb79d2bd924f41cf7f2eb9968b2f369210854386ee750ddfa0.
PANIC_LOGGING_BASELINE.md SHA256:
582630dc2344396988039df22891274e30722390c378dfd033ff0413b1fd98d6.

### Ingress/OCR before-proof (open BUG4507/4508; new BUG-1793725850)

Source:13be27b. `verify_receipt_resource_baseline.py` archived actual handler, limiter,
Service and default factory, then used only synthetic JPEG/key values and local mocked
RoundTrippers: `go test -race -count=1 -json ./internal/receipt -run
'^TestDriverReceiptResources$'`. Twelve leaves, eight expected failures, four passing
controls, zero skips/missing terminals; exit1 is retained before-state, not a green gate.

| Failed predicate | Driver observation / limits |
|---|---|
| Spoofed forwarded IP cannot reset quota |11 same-peer requests with changed X-Forwarded-For reached provider; eleventh200 |
| Expired keys removed |256 old entries remained beside a new key |
| Caller cancellation prevents provider work | Already-canceled caller started1 request without canceled context |
| Process concurrency bounded |6 simultaneous calls, above proposed target2 |
| Response byte budget |3MiB fully read, above proposed2MiB |
| Oversized upload returns413 | Existing10MiB byte guard returned400 |
| Provider redirect denied | Mocked cross-origin307 generated request2 carrying synthetic x-api-key |
| Internal parse error omits content | Synthetic receipt text appeared in error.Error(); handler still hid it |

Controls: ordinary valid image/response succeeds; same-IP request11 is rejected; actual
10MiB upload byte guard prevents provider work; explicit trusted proxy maps the expected
client. The main-equivalent router/default proxy policy was reproduced in-process, not a
launched binary. No real provider redirect or key disclosure, production load/spend,
population memory measurement or account-wide budget is established. Proposed2-in-flight/
2MiB thresholds are test targets requiring later numeric-policy approval, not current policy.
The focused redirect bug requires denial, at most one attempt and finite content-free
errors with local controls; server/provider code is untouched in this batch.

Existing protections must remain: bill1MiB body,500 items,100 people/shares,
5000 assignments and finite money; receipt10MiB body, provider30s timeout,
10/min same-peer quota; mobile capture1500px/quality75 and45s send timeout. CreateTab
still binds unbounded JSON, and both service entrypoints use http.ListenAndServe without
configured deadlines. Receipt response streaming is outside the mobile send-only timeout.
BUG4507 no longer claims universal absence of body/collection protections. BUG4508 records
remaining expiry/cancellation/concurrency/response/global-bound gaps; process-only limits
must not become dollar-spend claims. Provider/account budgets remain unverified.

Raw result.json, before.jsonl, before.stderr, source-hashes.json and the formatted archived
test live in scratch billington-structure-evidence/receipt-resources-baseline-13be27b/.
Compiled test SHA256:fa38721b1e38f071e03d9a322cb2708176728d5eb9fbfe43fd77a2ba924f33a4.
Diagnostic input `receipt_resource_baseline_test.go` SHA256:
614454ad359d69ca143f7a47486fb735cbf9b94570a0152e1c5929485a09206c.
INGRESS_OCR_BASELINE.md SHA256:
179d7038bbf459f9767c95a815ed977d5f6db91996a4988e9f764c9beb1e8dcc.
I checked the recorded Go test terminals without rerunning or contacting any provider.

Tracker write/provenance records: .vv/local-gate/local-workflow/tracker-reconciliation-writes.json,
reconciliation-ids.json and reconciliation-scope-check.json. Only the five authorized
entry contents change in this second group (three existing, two new); the official writer
also inserts the required blank separator before newly appended entries. An initial
scope-check assertion counted that separator as an existing-entry edit; comparing entry
content after trimming separators verifies that every other entry is unchanged. Touched
entries remain below2500 bytes (maximum2394). No independent acceptance is inferred from
these administrative updates.
