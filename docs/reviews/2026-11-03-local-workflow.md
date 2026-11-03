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
