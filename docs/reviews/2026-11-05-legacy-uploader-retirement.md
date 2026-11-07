# Obsolete mobile uploader retirement — 2026-11-05

Base: `b1ec44fbdc6e1c8284f7029153a6d503f75b5216`. Driver-approved scope removes
only `ApiService.uploadBill` (62 lines). The unpublished Dart app (`publish_to:
'none'`) had no runtime callers: the declaration and two test calls were the only
tracked symbol matches. App/native registration, dynamic dispatch, exports and
documentation were inspected. Done, launch/history retry and tab attachment enter
`RecentBillsManager.saveReceipt`/`resumeReceipt`, which already freeze
`buildBillRequest` output and call `publishSnapshot`.

The two existing bridge/correction adapters now use that builder and publisher.
Successful mocks reuse `creationResponse` from `save_receipt_test.dart`: all eight
authoritative fields, matching synthetic ID/token/source URL, request currency and
total, frozen rate and provenance. The canonical key encodes 32 synthetic bytes.
Valid captures assert one POST with that key; rejected percentages, names and FEFF
retain zero-HTTP and original input/state assertions. No cases or assertions were
removed. Unreachable negative-path response stubs remain irrelevant to success;
their zero-request assertions still pass.

Flutter 3.41.5 / Dart 3.11.3, committed lock enforced, actual maintained checkout:

| Gate | Before | After |
| --- | --- | --- |
| Two affected files | 34 visible; 38 starts/terminals | Same 34 occurrences; 38 starts/terminals |
| Full maintained Flutter suite | 467 visible; 510 starts/terminals | Same 467 occurrences; 510 starts/terminals |
| Affected format check | n/a | 3 files, 0 further changes |
| `flutter analyze` | n/a | No issues |

Every selected case passed with zero skips, errors, unmatched or missing terminal
events. Full accounting is 37 loaders + 6 hooks + 467 visible occurrences; there
are 465 distinct file/name pairs. Both repeated `receipt_service_test.dart` labels
retain two occurrences with distinct runner IDs. All ten request-builder fixtures
are byte-identical (SHA256
`54a3473cd9c2184332bff149bce29925ef1bfff728dc67ddec8b311fbda3f509`).

Commands from `mobile/`: `flutter pub get --enforce-lockfile`;
`dart run build_runner build --delete-conflicting-outputs`;
`flutter test --reporter json test/client_v1_bridge_test.dart test/client_v1_correction_test.dart`
and `flutter test --reporter json` both before/after; then `flutter analyze` and
`dart format --output=none --set-exit-if-changed lib/services/api_service.dart test/client_v1_bridge_test.dart test/client_v1_correction_test.dart`.
Raw command receipts, source hashes, per-ID events, multiplicities and preservation
manifests are retained in the task scratch `legacy-uploader-retirement-20261105/`.

Unsuppressed local Semgrep scans all three changed Dart files: raw exit 0, zero
candidates/errors. Gitleaks raw exits are 0/0/1: one unchanged synthetic capability
URL in the existing saved-zero test, triaged as a false positive; zero confirmed
secrets. No ignore/suppression was added.

Exact comparison proves the rest of `api_service.dart` unchanged, including the
builder, publisher, request bounds and legacy response decoders. The save owner,
native sources, server v1 endpoint, dependencies/locks and out-of-scope files/modes
remain unchanged; all 336 protected originals and 315 pre-existing untracked files
retain their bytes/modes. No performance, size, native or integrated result is
inferred from deleting unused code. Prior native33 evidence has separately been
accepted by the driver (Standards0/Spec0); its historical limits still apply.

BUG-1793644500 remains in-progress. Retirement independent review, root clean
verification and CI are pending; `.005` alignment, identity/precision, integrated
and release work remain open. Whole acceptance remains **RED**. Prior dated
evidence and the independent web/identity review inputs at the base are preserved.
