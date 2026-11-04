# Mobile receipt TLS integration — November 4, 2026

**M1 relay source integrated; fresh host mobile gate passes 392/392. Resource acceptance is PARTIAL/RED; iOS artifact qualification is BLOCKED. Whole security/integrated/performance/device/release acceptance remains RED.** Root owns independent committed clean validation and final acceptance. This is implementation-owner evidence, not independent review or physical/signed-client proof.

## Pins and implementation

Exact starting/review base: `554cd4cae10aca6d12994adcd7261ff542691ba1`. Source/living-docs commit: `587d5aa9d6b94cb119ebc736b597fe4715e28a13`. Request `billington-mobile_tls_integration-20261104-v1` verified its exclusive source-writer lease and `sourceWrites=true` before mutation. The concrete driver adoption decision/brief authorize integration, endpoint hardening, bounded local qualification, tracker evidence and normal program-branch push. Author AND committer: Victor Ivanov <victor.n.ivanov@gmail.com>; hooks run normally.

Original mobile pin `5231926ae676fc2214b829a41b5b48bb49608fda`; M2 `957433ae39c2a23f761bc968eca54400936222b6`. Design manifest `63c20c6d47966b63f3383417710b21a692603aa16ef3c47fde70bf4f8ec07e5c`: **453/453** bindings verified. Proposal `c7e08058c4483aa0eb0e100669c2aaa5f46a9861ffaa7581f141bd6eda5a6224`; original service `b6d4f1694c5de6e67dcc4c6eaa7af5cd8726424b4a9969bbd8873deb12c73546`. Integrated service matches reviewed candidate `c8a1bb3215be92e54647d628caa152627be4b1dee2f8bceac168056156d5d841`. The new client hardens reviewed client `6109d08623f5be835e0709c92f16ff16650877ae7a7285e52282ba5075f16f65`; final hashes below.

Only two production paths change: `ReceiptIoClient`, and the service import/factory/awaited finish seam. One attempt-owned byte relay retains valid upstream/accepted handles while its local endpoint transfers to SDK TLS. Stop destroys valid handles; finish joins setup, accept/listener, pumps and endpoint close/done. Matching compares the initiated socket's actual address/port against the accepted endpoint's reciprocal addresses/ports. An early accept waits for actual local registration. At eight unmatched accepted endpoints the attempt stops finitely, with no fallback/retry. Listener delivery cancels synchronously on pairing/stop and its completion joins. Collections clear after teardown. The detached local facade leaves active ownership on TLS transfer; it is never relied on for termination.

Ordinary construction keeps context/hooks null, default SDK trust/hostname/SNI and SDK/http protocols, with HTTP debug support. No production log/bypass, global override, additional timer, parser, worker, cache or dependency. Public ReceiptApiService parse/cancel/dispose/forTesting remain. One 45s monotonic deadline, M2 upload ownership, body/error/Retry-After, parser/bill/widget behavior remain. Entire upload owner and body/error methods are byte-identical to base. Native DNS/staggered setup still has inherited SDK ownership limits; no universal three-FD cap or blanket OS quiescence is claimed. Transport remains DIRECT, without proxy support.

## Fresh integrated-source gate

Actual shared `mobile/` checkout, **Flutter 3.41.5 / Dart 3.11.3 / locked http 1.6.0**. No checkout/worktree/copied package or result reuse; ordinary compiler/package/native caches remain. Exact command arrays, cwd/UTC/PID/exits and before/after bindings are in scratch `commands/` and `logs/`.

| Own executed command | Result |
|---|---|
| `flutter pub get --enforce-lockfile` | exit 0; locks unchanged |
| `flutter analyze` (final) | exit 0; no issues |
| `flutter test --machine` (final) | exit 0; **392 visible passes**, 0 failures/skips/missing/orphan/duplicate IDs; **429 starts / 429 terminals**; 37 hidden successes: 33 loaders + four setup/teardown hooks |
| `git diff --check` | exit 0 |

Final raw test SHA-256: `cf57a828f1b5514b6eef833ddd2df45f91c7f1e2668098bdfdc9fb510522615a`. The first full run also passed; the final run follows assertion-only hardening-control improvements. No source/test changes follow it. Full gates use CI selection plus machine reporting only, without skips/filters. `Counter((relative suite, full name))` preserves **362 previous occurrences**, repeated labels included; additions are **21 TLS + nine pairing/resource guards**.

Prototype400 = 362 originals + 21 TLS + **17 duplicate adapter executions**. Repository392 = 362 + 21 + 9. No duplicate external native_candidate_test.dart is committed. No canonical case is dropped, renamed or skipped. Each historical duplicate maps to canonical `mobile/test/receipt_native_io_test.dart`, with identical names/assertions/multiplicities; changes are the reviewed client import/types/factories and send observer forwarding `JoinedReceiptClient.finish()` (plus formatting).

| Historical adapter and canonical case name (identical) | Occurrences |
|---|---:|
| native timeout closes actual upstream connection | 1 |
| native headers stall timeout terminates upstream and joins fixture cleanup | 1 |
| native headers stall cancel terminates upstream and joins fixture cleanup | 1 |
| native headers stall dispose terminates upstream and joins fixture cleanup | 1 |
| native body stall timeout terminates upstream and joins fixture cleanup | 1 |
| native body stall cancel terminates upstream and joins fixture cleanup | 1 |
| native body stall dispose terminates upstream and joins fixture cleanup | 1 |
| native cancellation stops a streaming upload and cancels its input subscription | 1 |
| native source-error joins its input subscription cleanup | 1 |
| native cleanup-error joins its input subscription cleanup | 1 |
| native reentrant joins its input subscription cleanup | 1 |
| native 302 never follows Location and counts only one wire POST | 1 |
| native 303 never follows Location and counts only one wire POST | 1 |
| native 307 never follows Location and counts only one wire POST | 1 |
| native failed POST is never retried and a deliberate manual retry sends one new POST | 1 |
| native compressed response enforces decoded 1MiB and closes stream | 1 |
| native dropped response after upload never replays a POST | 1 |

The 21 TLS additions preserve their original names and obligations: complete ClientHello then silence for deadline/cancel/dispose, settlement and real peer disconnect before fixture cleanup, late setup/post-TCP cancellation, held teardown join, trusted CA, actual bad-CA/hostname HandshakeExceptions, redirects, manual retry/dispose and HTTP. Canonical native cases retain all four held-input M2 modes (cancel/source-error/cleanup-error/reentrant), gzip, upload/header/body stalls, dropped response and one wire POST per explicit attempt. The retained 362 cover body/shape/quantity/state/widget guards. Nine additions exercise real competing first peers, honest accept before registration, eight-endpoint exhaustion before/after connect, cancellation/error and independent overlap.

## Before and final-source removal proofs

Separate task-owned single-module overlays select the final service/client by disclosed import adaptations; repository source is never mutated for controls. Exact removals/hashes: `variants/manifest.json`. All failures below are executed `isFailure=true` assertions, with healthy controls; no compile/setup failure counts. Finally releases gates, joins attempts/peers and removes owned fixture directories.

| Executed control | Intended assertion failures | Healthy passes |
|---|---:|---:|
| Exact base strong-before: ClientHello deadline/cancel/dispose pending/connected | 3 | 2 trusted HTTPS / HTTP |
| Remove socket destruction from final stop | 3 settlement failures | 2 |
| Remove awaited native finish | 1 settlement while post-disconnect teardown held | 2 |
| Remove final upload join | 3 held-input failures: cancel/cleanup-error/reentrant | 14, including source-error |
| Remove endpoint matching | 2 competing-first-peer failures, including early accept | 2 trusted HTTPS / HTTP |
| Remove eight-endpoint budget | 2 bounded-settlement failures, before/after local connect | 2 trusted HTTPS / HTTP |

Original dated before/removal/design/M2 evidence remains untouched. Fresh variants and ordinary gates bind identical final production bytes.

## Fixture lifetime and executable identity

The committed test helper regenerates a two-day synthetic CA and CA-signed localhost leaf/key per host suite, verifies chain/hostname and removes its temporary directory. November 6 proof expiry is historical evidence, never a permanent test input. No certificate bypass/default trust-store mutation or production credential. Invoked argument arrays are maintained in the helper; generation.json records actual version, validity/fingerprint and verification. Source/tool/fixture hashes bind execution. Device probes would receive host-generated PEM, without OpenSSL inside the app.

Actual invoked executable `/opt/homebrew/opt/openssl@3/bin/openssl`, resolved `/opt/homebrew/Cellar/openssl@3/3.6.4/bin/openssl`, SHA-256 `67a83dd6d6d747d50c5d296dffb23e32bae9a2c588c93ae2d77e4c607b455c72`; **OpenSSL 3.6.4, 25 Aug 2026**. This is the runner's executable, distinct from interactive conda OpenSSL. Retained scratch keys are explicitly synthetic scanner candidates, not committed permanent keys.

## Native prerequisite and bounded resource observations

`pod install --deployment` exited **1**: maintained Podfile.lock lacks existing Flutter plugin graph entries **A app_links / A package_info_plus**. Dependency/lock changes are forbidden, so debug simulator build/artifact/run and unsigned release build are **BLOCKED/NOT RUN** at this concrete prerequisite. No new project/simulator/app, lock update or codesigning/account action bypasses it. Xcode/iOS26.3 runtime/device inventories are retained; both known physical iPhones are unavailable. Existing simulators/apps/history and Android originals remain untouched. No default-trust public-host probe, receipt/provider/customer request or native/signed/privacy/background proof occurred.

After own scans/build attempts/full gates completed, fresh process/load preflight showed no competing heavy application job; ordinary interactive/system load remained. One completed diagnostic resource run (4.72s including runner startup) uses ten warmup cycles, then **60 sequential cycles / 120 attempts**, **140 total sequential attempts**, and **four overlapping ClientHello stalls**. Retained TLS/silent fixtures exercise deadline/cancel plus retry, bad CA plus trusted retry, and 503 plus explicit retry. **36/36** sequential silent peers disconnected. Every retry-batch boundary has zero live silent fixture sockets and zero retained application clients; final application clients/services retained: zero. Canceling one overlapping owner leaves the other three peers connected, then all join.

Actual `/usr/sbin/lsof` snapshots, requested-GC VM profiles and RSS:

| Phase | OS FD / INET entries | GC heap bytes | Whole-process RSS bytes |
|---|---:|---:|---:|
| warm baseline | 20 / 6 | 57,244,320 | 231,292,928 |
| batch 1 | 20 / 6 | 57,588,480 | 243,875,840 |
| batch 2 | 20 / 6 | 57,652,768 | 249,675,776 |
| batch 3 | 20 / 6 | 57,728,208 | 256,557,056 |
| batch 4 | 20 / 6 | 57,765,072 | 267,485,184 |
| batch 5 | 20 / 6 | 57,789,728 | 276,611,072 |
| batch 6 | 20 / 6 | 57,835,136 | 283,443,200 |
| active direct HTTP / relay | 23 / 9 versus 25 / 11 | 57,932,112 / 57,981,008 | 288,768,000 / 296,910,848 |
| overlap four | 40 / 26 | 58,380,432 | 302,399,488 |
| post overlap | 20 / 6 | 58,060,752 | 312,131,584 |

Same retained HTTP fixture measures **two extra FD entries** for relay. Heap delta48,896 bytes and RSS difference include execution order and test/VM/diagnostic work; neither is isolated causal per-attempt memory cost. Normal topology has three application TCP descriptors plus transient listener, excluding SDK/OS transients/fixtures. A silent TLS owner retains two valid sockets, two completed task handles and two pumps, zero listener; the transferred endpoint is SDK-owned until handshake completion. Finish clears application collections.

FD/application owners do not accumulate across these batches. GC heap approaches a narrow band but is not flat; **RSS does not plateau**. Retained-memory/resource acceptance therefore remains **PARTIAL/RED**, without another run to chase green. Heap covers one test isolate; FD/RSS cover the entire flutter_tester, fixtures and VM-service diagnostics. Harness samples/latency records themselves remain retained. Kernel buffers/copies, physical peak/CPU/energy/battery, capacity and production-SLO proof are unexecuted.

Host distributions exclude warmup, **15 samples per row**; p95 nearest rank is the maximum here. These shortened settings do not change production45s:

| Observation | p50 / p95 / max (ms) |
|---|---:|
| configured60ms deadline: after ClientHello to settlement | 61.553 / 61.966 / 61.966 |
| cancellation to settlement | 0.526 / 0.652 / 0.652 |
| bad CA plus explicit trusted retry, both attempts | 8.724 / 10.568 / 10.568 |
| 503 plus explicit retry, both attempts | 9.324 / 13.068 / 13.068 |

Initial diagnostic harness errors remain raw: a compile error in capability promotion; then absent VM service for heap collection and direct-fixture live-set mutation during cleanup after140 sequential attempts. Final diagnostic uses supported `--enable-vmservice`, capability pattern and snapshot iteration; application bytes never changed. Partial source/samples are retained. The failed process exited, closing OS resources; interrupted direct-listener cleanup is not counted as joined proof. Completed final run joins owned fixtures, subscriptions, clients/gates/temp PKI. No repeat followed the nonflat RSS result. Initial bookkeeping also incorrectly expected all147 backend tracked paths to be128 source inputs (corrected to immutable source map), and treated formatter writes as unexpected. Neither was an application failure or lost-input event.

## Scans, review, Doc impact and remaining gates

Unsuppressed Semgrep1.183.0: **raw exit0, zero findings/errors**, current receipt source/tests with retained security and Dart rules. Gitleaks8.30.1: **raw exit1, seven candidates**: four newly generated synthetic private keys and three unchanged documentation capability placeholders. Confirmed secrets0; suppressions0. Exact commands/rules/tool/source/report/line hashes and triage remain in `scans/`; raw1 is never reported as0. Owner sequential Standards/Spec inspection found no additional source defect; independent final review is **NOT RUN / root-owned**. Trust, hostile peers, privacy, onePOST/manual attempt, unchanged parser/bill/state and production-null hooks were separately traced; whole security stays RED.

| Doc impact | Key/action |
|---|---|
| mobile/README.md | replace stale M1 handoff statement; ownership/limits/evidence/prerequisite pointer |
| docs/backend-api.md | update mobile TLS contract without backend behavior changes |
| docs/technical-overview.md | private client, pairing/join/cost and SDK/physical limits |
| docs/mobile-ocr-verification.md | TLS/native/pairing commands, duplicate consolidation, removal controls and regeneration/native/resource procedure |
| VERIFICATION.md | existing pointer correct; unchanged, procedural, Last verified never, <=20KiB |
| prior dated A2/M2/design/backend reports | historical evidence untouched |

Only official-writer BUG-1793644508 Fix/Docs/Observation/Log changes; **in-progress**, <=2500 bytes, all27 siblings preserved. No baseline/features/CHANGELOG change, closure, migration or grade. All128 backend source inputs stay byte-identical to c3c95cc3/554cd4ca; all336 protected originals, including untracked Android, stay intact. No backend/web/SQL/migration/CI/config/version/provider/hosting/store/main/mirror/tag/merge action, PR comment/review/watch or delegate. Publication/lease receipts are written separately after normal push/link/remote proof. Root owns public PR body/CI and independent clean review.

Backend runtime **1.619804s vs1.5s remains RED/flaky**, assignment JSON remains RED, and B/spending/provider enforcement/old-writer drain, physical/signed-client, integrated and release gates remain open. Host proof, and even future simulator proof, cannot certify physical local-network privacy/background behavior.

Evidence root: `mobile-tls-integration-20261104/` in authorized scratch. Case Counters, raw-event reconciliation, source commit, command snapshots, inventories, native prerequisite and scan triage bind claims. Final manifest freezes deliverables; later publication/lease receipts are separate. Source/fixture paths and exact hashes:

| Path | SHA-256 |
|---|---|
| mobile/lib/services/receipt_api_service.dart | `c8a1bb3215be92e54647d628caa152627be4b1dee2f8bceac168056156d5d841` |
| mobile/lib/services/receipt_io_client.dart | `6194394782da0cf4f3373155f3425a0e1fc4d79c0296dc867b7222f52de33cc8` |
| mobile/test/receipt_native_io_test.dart | `58fe702b355f3a4726212867d4e90a0bd2b07a1f48699baf5bbfe61c11c3cdd5` |
| mobile/test/tls_ownership_test.dart | `32873f24337b0398a7452ba098dce47bbbcad826235b000dd522c23268597723` |
| mobile/test/receipt_relay_pairing_test.dart | `18b2ea6fa656e6cf851307ecec240f27c90ccb6a873b74c6bdaf9c1da9a1e4dc` |
| mobile/test/fixtures/receipt_tls_fixture.dart | `eb52e466f4c2661c9851c13050e3c870c25f436b5941936989734b84d7b22ba1` |
