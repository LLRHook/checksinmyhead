# Maintained iOS lock and local native qualification — November 4, 2026

BUG-1793813173. Base `7e36d8afff04b1cf2add57050190370750fd88b7`, existing
`chore/billington-foundation-program` checkout and PR159. The prepared sole-writer
lease and exact base were verified before mutation. Root approved the generated-lock
repair and bounded local qualification; no dependency/SDK/application/project change
or release action was authorized. Independent readers retain their immutable pins.

## Generated resolution

Fresh `flutter pub get --enforce-lockfile` passed, while fresh
`pod install --deployment` failed with `A app_links / A package_info_plus`.
One ordinary `pod install` with CocoaPods1.16.2 repaired the existing graph. No
`pod update`, repository update, lock deletion or manual checksum editing was used.
[CocoaPods documents](https://guides.cocoapods.org/using/pod-install-vs-update.html)
that install preserves locked versions while resolving missing entries;
[deployment mode](https://guides.cocoapods.org/terminal/commands.html#pod_install)
disallows lock changes. Installed podspecs and the exact pub lock were inspected first.

All native-lock deltas:

| Delta | Reason |
|---|---|
| Add app_links6.4.1, Flutter dependency, local path and checksum | Already locked Flutter app_links6.4.1; native podspec6.4.1 |
| Add package_info_plus0.4.5, Flutter dependency, local path and checksum | Native podspec0.4.5 shipped by already locked Flutter package_info_plus10.2.2 |
| share_plus checksum `50da8cb5…` → `eccd7beb…` | Existing Flutter13.3.1 generates this normalized local podspec checksum; native0.0.1 version unchanged |

The CocoaPods-generated local JSON specs match all three final checksums. An initial
diagnostic against Ruby podspec files produced different file-format checksums; those
are retained separately and were never substituted into the lock. All other native
versions/checksums, sqlite3 3.52.0 and Podfile/CocoaPods version stay exact. Pub lock,
registrant, project, source plist, entitlements, application code and app2.0.11+36 remain
unchanged. Package versions were verified against
[app_links6.4.1](https://pub.dev/packages/app_links/versions/6.4.1) and
[package_info_plus10.2.2](https://pub.dev/packages/package_info_plus/versions/10.2.2).

## Actual gates

Host Flutter3.41.5/Dart3.11.3, CocoaPods1.16.2, Xcode26.3 build17C529.
Actual selected iOS/device/simulator SDK is26.2 build23C57; the simulator runtime
label26.3 reports26.3.1 build23D8133. No toolchain/global configuration update.

| Command / row | Actual result |
|---|---|
| Enforced pub acquisition, first and final | exit0; committed pub lock unchanged |
| `pod install` | exit0; existing sqlite source downloaded; generated delta above |
| `pod install --deployment`, twice after repair and final | all exit0; resulting lock unchanged |
| `flutter analyze` | exit0, no issues |
| Affected production/test `dart format --output=none --set-exit-if-changed` | exit0, unchanged |
| Literal CI `flutter test` + structured `flutter test --machine` | both exit0; structured392 visible PASS, zero failures/skips |
| Maintained debug simulator build, explicit `--no-codesign --no-pub` | exit0; actual Runner workspace/artifact |
| Maintained release/device build, explicit `--no-codesign --no-pub` | exit0; unsigned arm64 AOT artifact; never installed/launched |
| Task-local debug simulator artifact | exit0; actual maintained workspace and production package imports |
| Actual simulator transport harness | 24/24 PASS, zero failed/skipped;29 ownership observations |

The host machine stream has429 starts/429 terminals:392 visible and37 hidden
successes, **31 loaders + six lifecycle hooks**. All392 canonical suite/name
occurrences, including repeated labels, match the root's retained exact-base run.
This corrects the older handoff's33/four taxonomy without editing that frozen note or
claiming the root's parser reconciliation reran tests. Backend/web suites were not
rerun: all128 backend inputs and336 protected originals remain exact.

The first default Flutter simulator invocation emitted provisioning-allowance flags.
Its own process group was stopped; Flutter exited0 during shutdown, so it is not
successful-build evidence. Qualifying builds explicitly disable signing and those
allowances. No signing-account/keychain/provisioning action was requested separately.
Raw command, stop attempt and build logs remain available.

## Owned simulator and transport evidence

Exactly one simulator was created: `Billington iOS Lock QA 20261104-v1`,
`B532C6EB-4133-42D3-98A4-85EBB77E738E`, iPhone17, runtime above. The task-local
entrypoint was compiled inside the maintained project; no new project/package,
production behavior change or normal-app launch. Its real `ReceiptIoClient` and
`ReceiptApiService` modules have SHA256:

- client `6194394782da0cf4f3373155f3425a0e1fc4d79c0296dc867b7222f52de33cc8`
- service `c8a1bb3215be92e54647d628caa152627be4b1dee2f8bceac168056156d5d841`

The artifact manifest binds these modules, parser/config/lock/project hashes,
formatted harness, synthetic PEM, kernel/native file hashes and Mach-O UUIDs.
The harness uses existing test seams for loopback URLs, short2s deadlines, observation
and synthetic trust; default45s/public release configuration stays unchanged.

Executed native assertions cover default-client HTTP503 + explicit successful retry,
synthetic-trust TLS503 + retry, default/platform-context rejection of the synthetic CA,
hostname rejection with the synthetic CA, complete actual ClientHello stalls and
HTTP headers/body stalls under deadline/cancel/dispose, disconnect before fixture
cleanup, held native teardown, allfour M2 held-input modes, TLS302/303/307 refusal,
exact wire POST counts and three additional bounded TLS retry cycles. Both certificate
controls require an actual HandshakeException and zero HTTP requests. No trust bypass,
global trust change, production/provider/customer request or external server is used.

Raw app-written JSON retains24 case terminals, durations and29 zero-after-join
socket/task/pump/listener/pending-accept observations. Eight host lsof/ps snapshots
bind the actual Runner PID and show only loopback TCP. **Console diagnostics are
incomplete:** the supervisor and app stdout paths collided, and app Dart print events
were not retained; an owned-PID unified-log query returned no events. ClientHello-byte,
wire-count and detailed certificate-error values are enforced by the bound assertions,
not independently retained console/packet records. No extra simulator was created to
replace that evidence. Native launch warnings about LaunchImage/restoration are retained;
all case assertions completed. The task-local analyzer reports six intentional
visibleForTesting-use warnings and six style infos; the production analyzer is clean.

Maintained source has no new ATS/network permission. Flutter's built debug plist adds
its usual VM-service Bonjour/local-network debugging strings; release has neither.
Loopback HTTP/TLS success establishes the observed socket behavior only: no physical
local-network prompt, ATS policy matrix, backgrounding, external default-trusted TLS,
public signed client or provider compatibility certification.

RSS353,222,656→361,267,200 bytes across this short debug run is not a plateau.
FD snapshots include engine/fixtures and process startup. The prior host RSS/heap
resource gate remains **PARTIAL/RED**; no old resource harness or threshold was rerun
or changed. No battery/energy/capacity/production-SLO claim.

The app exited itself. Only the created simulator was shut down/deleted; all prior
simulator names/states/lastBootedAt values were preserved. Task-local harness files
are removed after restoring generated config to `lib/main.dart`; original Android,
artifacts, ordinary data/volumes and prior reports stay intact.

## Evidence, scanning and documentation

Raw evidence lives only in scratch `ios-lock-qualification-20261104/`: commands,
logs, source/protected hashes, exact lock diff, fixture provenance, host case Counter,
app-written native JSON, artifact bindings, lsof observations and cleanup receipts.
This was an existing-checkout affected run, not a clean-checkout/integrated protocol.
Pinned Semgrep1.183.0 exits1 with six candidates (five synthetic-key detections and
one task-harness print); Gitleaks8.30.1 exits1 with three synthetic-key candidates.
Owner triage confirms zero production findings/credentials, with no suppressions;
raw reports, tool/rule hashes and fresh PKI provenance are retained. Independent
review remains pending; this is no whole-security green claim. Publication identities
are recorded in the final scratch handoff.

Doc impact (keys: native lock, deployment acquisition, simulator prerequisite,
unsigned builds, transport qualification; tracked living docs searched):

| File | Class | Action |
|---|---|---|
| mobile/README.md | stale-by-change | Replace open native-lock blocker with bounded native qualification and remaining limits |
| docs/mobile-ocr-verification.md | affected procedure | Document reviewed lock repair, explicit no-sign builds, artifact binding and console limits |
| docs/technical-overview.md; docs/backend-api.md; VERIFICATION.md | still accurate / broader procedure | Unchanged; simulator/public certification and integrated gates remain separate |
| Prior dated evidence | frozen | Unchanged |

BUG-1793813173 remains in-progress for root review/clean committed validation. No ticket
closure/migration, CHANGELOG or Last verified update. Physical-device coverage is
**NOT RUN**. Independent review, broader security/resource/runtime/assignment,
signed-client/release and integrated acceptance remain root-owned; **whole acceptance RED**.
