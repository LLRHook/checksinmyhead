# Participant identity: full Flutter row and Expected coverage — 2026-11-09

Scope: BUG-1793644505, branch `sweep/mobile-currency` on `e0a2c18` (mobile inputs
identical to main `5e877e3`). Local macOS host shared with other agents, Flutter 3.41.5.
No production code changed for this ticket. It stays `in-progress` on the
[fresh-self decision](2026-11-09-fresh-self-decision.md) and the hosted, signed and
rollout gates.

## "Full d6 Flutter RED (two I/O errors)"

The two errors at `d6e2d65` were `native timeout closes actual upstream connection`
(`receipt_native_io_test.dart`) and `stalled TLS deadline preserves deliberate retry
wire ownership` (`tls_ownership_test.dart`). Each raced a short real deadline (100 ms
and 350 ms) against real loopback I/O, which only lost under whole-row concurrency.
They were corrected on 2026-11-06 in test code only
([deadline fixtures](2026-11-06-receipt-deadline-fixtures.md)):
`test/fixtures/receipt_deadline_clock.dart` now owns that single deadline timer, so
the native case expires it after the complete POST has arrived and the healthy TLS
retry runs with elapsed time held at zero. Nothing further needed fixing here.

Evidence on current code, default concurrency, no retries or selectors:

| Command | Runs | Result per run |
|---|---|---|
| `flutter test --no-pub` | 5 consecutive | 593 visible cases pass; 650 starts and 650 terminals including loaders; 0 failures, errors or skips; runner success |
| `flutter test --no-pub test/receipt_native_io_test.dart test/tls_ownership_test.dart` | 10 consecutive | 39 pass, 0 fail |

Both formerly failing case IDs are present and pass in every run. This is a local
row, not hosted CI and not a wall-clock claim for the production 45-second deadline.

## Expected bullets against tests

| Expected | Proof |
|---|---|
| Two people named Alex keep separate ownership | `TestPostgresIdentity0003BindingAuthorityAndRetry`, `…BindingGenerationReceiptAndCurrentProof`: two members named Alex; only the confirmed member ID gains or keeps authority |
| …and separate debts | **New** `TestIdentity0003SameNameMembersKeepSeparateDebts`: two confirmed members and one guest, all labelled Alex, stay three debts in balances and in finalization rows; taking the payer's name moves no debt; the name-keyed wire-1 view is refused instead of merged |
| Another name gains no paid authority | `BindingAuthorityAndRetry` (same-name member 403 before, during and after approval); `TestPostgresLifecycleHTTPIsolationMembershipAndSettings` (duplicate label neither revokes nor grants) |
| Reads | wrong member proof 403 on `GET /api/tabs/:id` and on attach (`BindingAuthorityAndRetry`) |
| Edits | name-keyed or duplicate claims 400/409 (`ReferenceClaimsAndParticipantRecovery`); another member's binding request 409; **new** `TestPostgresIdentity0003FreshParticipantIsUnboundUntilApproved`: a member cannot confirm their own new participant by field or by deciding their own request |
| Finalization | wrong token and invalid member 403 with unchanged state (`LifecycleHTTPIsolation…`); member rename leaves the frozen snapshot byte-identical (`BindingAuthorityAndRetry`) |
| Stable references, legacy plan, old links | Unchanged from the 2026-11-05 notes; not re-run here beyond the cases above |

Removal controls for the two new families: keying parties by label fails two of three
balance subtests (one merged $60 debt instead of three); letting any member decide a
binding fails the PostgreSQL case at its first 403. Source was restored after each.

Commands: `go test -race -count=1 ./internal/tab -run TestIdentity0003SameNameMembersKeepSeparateDebts`
(3 subtests pass); with the shared fixture DSN,
`go test -race -count=1 -tags=integration ./cmd/bill-service ./internal/tab -run '<the five families above>'`
(21 terminals pass, 0 fail, 0 skip). The full eight-package PostgreSQL row was not run here.
