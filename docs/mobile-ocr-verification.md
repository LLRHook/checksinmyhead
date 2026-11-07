# Local mobile OCR verification

Use Flutter **3.41.5 / Dart 3.11.3**, the committed lock and synthetic fixtures.
This procedure establishes local service/model/widget boundaries; it does not replace
any mandatory row or safeguard in [VERIFICATION](../VERIFICATION.md).

From `mobile/`:

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test --reporter=json
flutter test --reporter=json test/receipt_native_io_test.dart test/tls_ownership_test.dart test/receipt_relay_pairing_test.dart
```

Retain raw machine JSON, exact commands/exits and source hashes. Count visible case
terminals separately from hidden suite-load/setup events; require one terminal for
every start, no skips and preservation of all previous case IDs. Do not treat setup,
compile errors or a zero-test selector as a failing product assertion. Retain initial
failures and explain fixture corrections before any green rerun.

The focused cases are:

- `receipt_native_io_test.dart`: the original 17 native/M2 cases and the real
  held-setup expiry regression, using the real
  `ReceiptIoClient` and a send observer forwarding its joined teardown capability,
  stalled headers/body, slow streaming upload, timeout/explicit cancellation/disposal,
  actual peer disconnect and joined asynchronous input cleanup (including source/
  cleanup errors and cancellation during listen), 302/303/307 refusal,
  a dropped response, compressed decoded cap and one wire POST per manual attempt.
  Join every owned listener/server/socket/client and temporary directory in cleanup.
  A timeout in the fixture is a failed liveness observation, never evidence that
  surviving native work stopped.
  The original complete-POST timeout case selects a logical100-ms deadline only
  after the actual wire witness. The separate real100-ms setup case requires
  zero POSTs and production close/join/resource postconditions before test cleanup.
- `tls_ownership_test.dart`: 21 real TLS cases: complete ClientHello followed by
  silence, timeout/cancel/dispose settlement and peer disconnect before fixture
  cleanup, held setup/post-TCP/teardown, trusted CA/hostname and actual invalid
  certificate HandshakeExceptions, redirects and deliberate retry wire counts.
  The first stalled deadline attempt keeps its real350-ms timer. Only its healthy
  explicit retry controls logical elapsed/timer at350ms, proving success and timer
  cancellation without claiming a response-time SLA. All wire/cleanup bounds remain.
- `receipt_relay_pairing_test.dart`: actual competing first peers, honest acceptance
  before local future registration, the eight-endpoint budget before/after local
  connect, cancellation/error cleanup and independent overlapping attempts.
  Require finite failure on budget exhaustion, no wrong pairing, no fallback/retry
  and no retained application socket/task/listener/pump after joined teardown.
- `receipt_service_test.dart`: actual production service with exclusively owned client
  factories, short timers/monotonic clock/file seams, setup/send/body/parse/cleanup
  deadline, late completion, timer/abort/subscription cleanup, exact/excess 1 MiB even
  with false/missing lengths/non-200, finite errors and bounded Retry-After seconds/date.
  No test constructor points to a public endpoint.
- `receipt_validation_test.dart` and `receipt_safeguards_before_test.dart`: depth 16,
  16384 tokens (including duplicate/ignored fields), every array 512, items 500,
  malformed scalar/container types, Unicode codepoints, finite money/confidence,
  exact ASCII currency, null/default/empty/discount/repeated-line controls and
  subtraction-checked expansion `sum(max(1, quantity)) <= 500`.
- `receipt_bill_state_test.dart`: snapshot all existing bill values, controller
  `TextEditingValue`s, list/assignment identity, quote/loading/vendor/notification state
  around rejected direct candidates, including maximum integers and NaN/infinity.
  Check valid 500-line replacements and existing two-decimal remainder/JPY behavior.
- `receipt_scan_widget_test.dart`: real service/model/review sheet, manual Apply and
  retry, finite active-user validation, disposal during network and after review opens.
  Flutter's fake clock needs a `runAsync` microtask turn for the SDK root-zone completed
  stream-cancel future. This fixture accommodation preserves awaited production cleanup.

Before acceptance, independently remove network abort/close, body cap, shape/token/
array/item/quantity guards, validation-before-mutation and late-review application
checks in isolated, backed-up task-owned overlays. Each removal must fail the intended
executed assertion. Restore exact bytes in `finally`; rerun final ordinary gates only
against the restored source, keeping failed mutant logs.

The setup seam can outlive cancellation as an OS file metadata future; late completion
is ignored before any send. The default file stream opens only when multipart upload
is finalized. Retain the original input subscription and join its cancellation future;
a synchronous onCancel-start flag or completed IOClient.send is insufficient. Hold
that cleanup future in a real upload fixture and require the attempt to remain pending
until cleanup is released. Capture cleanup errors without raw diagnostics.

The attempt-owned relay closes the reproduced SDK TLS-handoff gap on the host.
Keep the raw silent-ClientHello peer, trusted TLS and debug HTTP controls; independently
remove socket destruction, native teardown await and upload cleanup await. Each must
produce the intended failed assertion with healthy controls. Also remove pairing and
the accept budget to prove the competing-peer/flood assertions. SDK DNS/staggered
setup still owns work beyond the exported application tasks; neither three-socket
topology nor sink completion proves universal FD bounds or OS quiescence. No detached
network/body read is accepted as timeout success. Bounded synchronous JSON work cannot
be timer-preempted; monotonic elapsed checks also run after it and after cleanup.

`test/fixtures/receipt_tls_fixture.dart` regenerates an isolated synthetic CA/localhost
leaf and keys per host run using existing OpenSSL, verifies the chain and hostname,
and deletes its temporary directory. Validity is two days from generation; no dated
certificate is a permanent test input. `RECEIPT_TEST_OPENSSL` selects an existing host
executable; retain its actual resolved path/hash/version and generation commands.
Never bypass verification or modify a default/platform trust store. Device probes
must receive host-generated PEM material without requiring OpenSSL inside the app.
The historical prototype's 17 extra native-adapter executions are consolidated into
the canonical suite: 362 originals + 21 TLS = 383, plus nine pairing/resource guards
= 392 visible occurrences. Preserve repeated suite/name multiplicities using Counters.
The later [combined3460d692 full Flutter row](reviews/2026-11-06-combined-flutter-acceptance.md)
passed567 visible cases/573 canonical records with all inherited multiplicities
plus the new setup case. The earlier392 result is retained historical evidence.

No package addition, application cache, paid inference, customer API/SQL, hosting or
store action is needed. Do not launch signed release QA against the hardcoded public
API, assume a dart-define override, or bump TestFlight versions for these tests.
Native host IO tests are not iOS simulator, physical-device, signed-public-binary or
provider compatibility proof. Qualify debug artifacts on a new owned simulator only;
preserve existing simulator/app/history and Android work. Use `pod install --deployment`;
a mismatch with the existing plugin graph is a prerequisite blocker, never permission
to rewrite the lock. An approved lock repair uses ordinary `pod install` with existing
pins, reviews every generated delta, then repeats enforced pub acquisition and
`pod install --deployment` without changing either lock. See the
[iOS lock qualification](reviews/2026-11-04-ios-lock-qualification.md) for the bounded
repair and actual local simulator results.
The [driver phase-proof supplement](reviews/2026-11-04-ios-native-phase-acceptance.md)
records the separately reviewed correction and evidence limits. For body-phase stop
cases, require a forwarding witness after nonempty data reaches the actual service
reader before stopping. For ClientHello cases, check both record and handshake
lengths plus actual received bytes; record completion alone is insufficient.
Retain the complete-single-record scope when that is what the fixture proves.

Build the maintained `mobile/ios/Runner.xcworkspace`, with signing explicitly disabled
for local QA, from `mobile/`:

```sh
flutter build ios --debug --simulator --no-pub --no-codesign
flutter build ios --release --no-pub --no-codesign
```

Build-only release compilation does not authorize launching its public API configuration.
Native transport qualification instead uses a task-local entrypoint in this project
with the unchanged production modules and synthetic loopback fixtures. Bind its source,
PEM provenance, kernel/native artifact and owned simulator UDID/runtime to its results.
Keep default-trust rejection separate from synthetic-context TLS success and hostname
rejection. Inspect the actual built Info.plist: Flutter can add debug Bonjour/local
network debugging strings without changing the maintained source plist. A local socket
success does not certify ATS, local-network prompts or trust on physical devices.
Retain raw case terminals and ownership joins; record any missing console/packet
diagnostics explicitly. Physical privacy/background/network behavior needs separate proof.
Resource qualification records warmup/GC/baseline, sequential failure/cancel/retry,
controlled overlap, actual process/socket/FD inventory and retained-memory plateaus,
with fixture/test-VM/RSS limitations. Short host samples establish no battery, capacity
or production-SLO acceptance. Performance claims still require separate warmups and
three independent 100-sample runs per path without competing heavy work. Local liveness
assertion deadlines do not establish those distributions or general mobile capacity.
Existing JSON performance, durable allowance B, account budget/provider enforcement,
old-writer drain, backend independent findings and release/global gates remain open.
