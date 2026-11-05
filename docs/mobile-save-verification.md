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
listener/share/navigation failure and receipt-currency review. Migration/retention
and display-decoder files cover actual schema8→9 and integer/float/invalid `rate`.
The original ten actual builder fixtures and raw negative/FEFF name guards remain.

First local transaction includes native values, ordered request/version, unique
handle, nonsecret key locator, attachment intent, saved ordered shares and
birthday/custom-tip presentation metadata. It returns the exact row ID. Legacy
rows retain their raw values/links/quotes and no creation snapshot. Migration
performs no network, repricing, content merge, deletion or automatic publication.
Existing native fractional JPY remains visible. `.005` local/server allocation
and versioned precision/identity0003 remain separate open work.

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
Every qualification build must pass `--no-codesign`; Xcode invocations must explicitly
set `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=` and avoid
all provisioning/account actions. Disable parallel simulator cloning when using
XCTest. Preserve existing devices/credentials. Bind exact native/Dart source, target,
kernel/application artifact and result receipts; distinguish app assertions, XCTest
counts, wrapper exit and missing diagnostics. Retain failed attempts.

The retained unsigned attempt reports `errSecMissingEntitlement` (`-34018`): native
Keychain is **BLOCKED**. Its reported2/5 XCTest passes and the host/wire
results do not qualify actual native storage; lookup failed before one intended
random-failure seam was reached. Root owns any separately bounded next
native path. No signing/project-entitlement workaround follows. Simulator proof,
even if later successful, would not establish physical/signed/default-trust/release
acceptance. Delete only exact task-owned simulator/schema/process fixtures.

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
