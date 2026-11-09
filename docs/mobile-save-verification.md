# Mobile save and safe reopen verification

This procedure qualifies local source and synthetic functional behavior. It does
not authorize provider/control-plane actions, rollout, real inference/customer data,
signing/provisioning, or a numerical performance run. Keep existing native OCR,
M2 upload-input ownership, TLS cancellation and resource obligations unchanged.

## Maintained host row

From `mobile/`, use Flutter3.41.5/Dart3.11.3 and the committed lock:

```sh
flutter --version --machine
flutter pub get --enforce-lockfile
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --reporter json > <task-owned-output>/flutter.jsonl
```

Generation uses pinned `drift_dev`/`build_runner`; no package/SDK bump. Compare raw
start/terminal occurrences and every visible prior392 case by relative file plus
name. Include new cases; never count loaders or setup/teardown hooks as visible
tests, and report failed/skipped/missing/duplicate/unmatched events separately.
Run affected formatting on changed Dart files and check the actual generated diff.

The owner interface is `RecentBillsManager.saveReceipt`/`resumeReceipt` with injected
real Drift, API and creation-key-store dependencies. `save_receipt_test.dart` exercises
one EUR row, stable handles versus independent identical receipts, overlap, exact-ID
checkpoint with a concurrent insert, committed attempt ordering, lost/invalid create
responses, redirect refusal and a64KiB response cap under one abortable deadline, checkpoint failure, immutable settings/payment snapshots, key/restore
windows, foreign/zero valuation, history/import exclusion, capacity and attachment.
`save_receipt_widget_test.dart` exercises actual Done cancellation, offline outcome,
listener/share/navigation failure and receipt-currency review.
`save_journey_test.dart` follows one file-backed EUR receipt through Done offline,
a repeated Done, Get Link, restart, a lost 201, a successful replay, trip attachment
and a second restart: one row, unchanged native values, one key and byte-identical
EUR requests. It also repeats Done through the actual handler after a failure, and
checks for eight EUR/USD outcomes that the stored quote state, the result message and
the history card agree. A pending native-USD receipt reports "Link pending"; only a
stored pending quote is described as a pending USD conversion. Migration/retention
and display-decoder files cover actual schema8→9 and integer/float/invalid `rate`.
The original ten actual builder fixtures and raw negative/FEFF name guards remain.

First local transaction includes native values, ordered request/version, unique
handle, nonsecret key locator, attachment intent, saved ordered shares and
birthday/custom-tip presentation metadata. It returns the exact row ID. Legacy
rows retain their raw values/links/quotes and no creation snapshot. Migration
performs no network, repricing, content merge, deletion or automatic publication.
Existing native fractional JPY remains visible. The device and the server still
place odd cents by different rules, so per-person amounts in history and on the
published receipt can differ by a cent or two; the options are in the
[2026-11-09 note](reviews/2026-11-09-mobile-save-journey.md). That and versioned
precision/identity0003 remain separate open work.

`save_tab_review_correction_test.dart` covers tab intent arriving during launch
publication and after its published-row read. Destination intent must commit before
joining that pass; conflicting destinations retain the first trip. A failed create
or attachment is not automatically repeated by the joining caller. Mixed tab
selections continue after history-review or missing-row failures, preserve earlier
commits/raw history, and show review/pending feedback through the actual selector.
Its real SQLite rejection trigger also verifies that failed URL/name writes retain
the original row and emit only finite operation labels, without SQL parameters.

## Actual maintained-server wire proof

Use the existing strict `backend/internal/testpostgres` loopback fixture with
`billington_test` database/user and random task-owned schemas. Never weaken its
DSN/schema guards, use customer data, reset normal volumes or select numerical
rows incidentally. The retained task harness in the dated source evidence injects
one additional Go test through an overlay into the maintained bill-service test
package and reuses `replayRouter`, actual migrations, actual creation/attachment/
finalization handlers and a synthetic provider. Compile-only first; execute only
`^TestMobileSaveWire$` with `-tags=integration -count=1 -json`.

The task-owned Flutter harness uses a file-backed synthetic Drift store and the
actual `ApiService` against that loopback server. Drop the first201 after real
commit, close/reopen Drift, and replay the same bytes/key. Drop the attachment200
after real commit, finalize the destination, then reconcile its known association
by authorized read. Assert one parent, preserved ordered/repeated children and
zero-share participant, exact local/remote IDs, same frozen201 result and no provider
refetch or second attachment. Keep raw Go/Flutter terminal events, schema cleanup
and source/harness hashes. A fake adapter alone cannot establish the wire result.
Control-file credentials are synthetic, mode0600, task-local and removed at cleanup.

## Secure storage and native qualification

The iOS MethodChannel uses Security OS random32 bytes, generic-password Keychain
items with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, foreground/unlocked
admission and completion, and create-if-absent duplicate retrieval. Absent, locked
and error remain different. Drift contains the nonsecret locator only. Before an
attempt, a confirmed absent key may be created; after an attempt, absent/inaccessible
keys block publication. No unsupported-platform/plaintext fallback exists. Existing
bearer URLs remain plaintext; this change makes no broader encryption claim.

Native tests use task-owned service/item names and exactly one owned simulator.
Default builds use `--no-codesign` and explicit Xcode
`CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=`. The driver's
separately bounded local simulator follow-up uses command-line dash signing only:
`CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual`, required/allowed/ad-hoc signing YES,
with empty development-team/profile fields. It changes no project settings or
entitlements and permits no named identity, provisioning or account actions.
Inspect actual embedded simulator entitlement sections, generated xcent and native
compiler inputs; an empty `codesign --entitlements` result alone is insufficient.
Disable parallel simulator cloning when using XCTest. Preserve existing devices and
credentials. Bind exact native/Dart source, target, kernel/application artifact and
result receipts; distinguish app assertions, XCTest counts, wrapper exit, intended
exit, actual process termination and unavailable independent OS exit status. Retain
failed attempts.

The retained unsigned attempt reports `errSecMissingEntitlement` (`-34018`): that
attempt remains **BLOCKED**, with2/5 XCTest passes. A later maintained-app attempt
failed before run-start with zero cases/requests; it remains setup RED. Neither is
relabeled. The bounded follow-up at276c33fe records33 passing app assertions across
first save and actual process-reopen, using the production MethodChannel and
file-backed Drift with a synthetic loopback replay fixture. See the
[acceptance note](reviews/2026-11-04-mobile-save-acceptance.md) for artifact/signing,
console, cleanup and scope limits. This does not establish physical, public-signed,
default-trust, memory or release acceptance. Delete only exact task-owned simulator,
schema and process fixtures.

## Fail-closed release and evidence rules

The creation owner checks the maintained version-policy replay capability; absence
retains one local pending receipt with no POST. Release mode additionally disables
keyed publication in source until separately reviewed source/capability floors,
replay-capable deployment, old-writer drain and native/signed-client qualification.
A capability response alone cannot establish drain. No unkeyed fallback, automatic
POST retry or replay-ignorant rollback is allowed; retain server replay state.

Run meaningful healthy/removed controls for key replacement, attempted ordering,
exact-ID checkpoint, immutable snapshot and capability/no-fallback protections.
Only executed assertion failures count as red controls, not setup/compile failures.
Restore/check exact source hashes after each. Run scoped unsuppressed source/secret
scanners and disclose raw candidates/errors with per-candidate dispositions.

Keep BUG4500/4515 in-progress. No CHANGELOG migration, Verified or green last-run
entry follows from this row; independent source review, clean root verification,
canonical native/resource/security/integrated and rollout gates remain separate.
