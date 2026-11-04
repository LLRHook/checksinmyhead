# Local mobile OCR verification

Use Flutter **3.41.5 / Dart 3.11.3**, the committed lock and synthetic fixtures.
This procedure establishes local service/model/widget boundaries; it does not replace
any mandatory row or safeguard in [VERIFICATION](../VERIFICATION.md).

From `mobile/`:

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test --machine
flutter test --no-pub --machine test/receipt_native_io_test.dart
```

Retain raw machine JSON, exact commands/exits and source hashes. Count visible case
terminals separately from hidden suite-load/setup events; require one terminal for
every start, no skips and preservation of all previous case IDs. Do not treat setup,
compile errors or a zero-test selector as a failing product assertion. Retain initial
failures and explain fixture corrections before any green rerun.

The focused cases are:

- `receipt_native_io_test.dart`: real `dart:io`/http IOClient on loopback TCP/HTTP,
  stalled headers/body, slow streaming upload, timeout/explicit cancellation/disposal,
  actual peer disconnect and joined asynchronous input cleanup (including source/
  cleanup errors and cancellation during listen), 302/303/307 refusal,
  a dropped response, compressed decoded cap and one wire POST per manual attempt.
  Join every owned listener/server/socket/client and temporary directory in cleanup.
  A timeout in the fixture is a failed liveness observation, never evidence that
  surviving native work stopped.
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

The confirmed Dart TLS-negotiation cancellation gap remains open. A raw loopback peer
that receives ClientHello and then stays silent must eventually prove timeout/cancel/
dispose settlement and actual disconnect, alongside trusted-TLS/hostname controls.
Current HTTP loopback passes do not prove that missing TLS phase. No detached
network/body read is accepted as timeout success. Bounded synchronous JSON work cannot
be timer-preempted; monotonic elapsed checks also run after it and after cleanup.

No package addition, application cache, paid inference, customer API/SQL, hosting or
store action is needed. Do not launch signed release QA against the hardcoded public
API, assume a dart-define override, or bump TestFlight versions for these tests.
Native host IO tests are not iOS simulator, physical-device, signed-public-binary or
provider compatibility proof. Performance/memory claims require separate warmups and
three independent 100-sample runs per path without competing heavy work. Local liveness
assertion deadlines do not establish those distributions or general mobile capacity.
Existing JSON performance, durable allowance B, account budget/provider enforcement,
old-writer drain, backend independent findings and release/global gates remain open.
