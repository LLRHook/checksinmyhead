# Receipt limiter bounds and single provider attempt — November 9, 2026

BUG-1793644508. Branch `sweep/abuse-bounds`. Two tests were added; no production
or mobile source changed. Loopback fixtures only: no paid inference, no real
provider call, no customer data. The ticket stays in progress for the items under
"Open".

## What the code does today

- `internal/receipt/admission.go` keeps at most 4096 peer keys, each a fixed array
  of ten timestamps. Every admission prunes expired keys under the same lock before
  it decides, and a 15 s sweeper prunes idle tables. A new peer that meets a full
  table gets 503 with `Retry-After: 15` and adds no state.
- Concurrency is one process-wide slot count (`OCR_MAX_INFLIGHT`, default 2, 1 to 8).
- These limits are per process. `backend/README.md`, `docs/backend-api.md` and
  `docs/technical-overview.md` state that they multiply across replicas and that
  there is no durable or global account or dollar allowance.
- The handler calls the provider once per admitted request. Provider and quota
  failures map to finite 429, 503, 422 or 413 responses with a bounded
  `Retry-After` where one applies.

## Added proof

- `TestAdmissionPeerTableStaysBounded` drives 4,296 distinct peers through the real
  admission path at one instant, 100 more a second before expiry, 4,296 more at
  exactly one window, and one a window later, on a controlled clock. The table
  never exceeds 4096 keys, each excess peer is refused with 503 and 15 s, a renewed
  peer survives its neighbours' expiry, one key remains after the last burst and
  none after the idle sweep. The table payload bound is 4096 × 272 bytes.
- `TestHandlerFailuresMakeOneProviderAttempt` sends real multipart requests through
  the handler to a loopback TLS provider fixture built by the production
  constructor. For provider 429, 529, 500, 401, 400 and an unusable 200, each client
  request produces exactly one provider POST and a finite public error; a second
  scan is a second POST charged to the same peer. Ten admitted scans and five
  quota denials from one peer produce ten provider POSTs.
- Five single-guard removals each fail one of these tests by assertion: admission
  pruning, the table cap, the expiry boundary, a second `Parse` call on error and a
  dropped `Retry-After`.

Existing proofs that still pass in the ordinary Go row (221 named records in
`internal/receipt`, none failed or skipped): `TestAdmissionLifetime`,
`TestAdmissionContenders`, `TestAdmissionIdleSweepAndClose`,
`TestDriverAdmissionClock`, `TestProviderWirePolicy` (one POST for each of twelve
provider statuses), `TestProviderStaleBeforeWriteDoesNotRetry`,
`TestProviderRedirectImmediate`, `TestFailureWireMapping`,
`TestHandlerSaturationAndCancellation` and `TestOwnershipPoolCap`.

Mobile, unchanged source (`receipt_api_service.dart` `c8a1bb32…5d841`):
`flutter test --no-pub test/receipt_service_test.dart` passes 49 of 49, including
one send for each of ten failure statuses and one send per attempt for a manual
retry.

## The November 5 "cancel-removal assertion fails" note

This is a control, not a defect. With only `_timer.cancel();` removed from
`_ReceiptOperation.finish`, the same file reports 46 passed and 3 failed, each
`Expected: false, Actual: <true>` on the operation timer's `isActive`. Restored
source passes 49 of 49 and has the same hash as before.

## Open

- **Blocked on the owner:** hosting and provider budgets (how many replicas run,
  and what spend limit the provider account enforces) are not confirmed. Nothing
  in this repository can confirm them, and no value was assumed.
- **Blocked on a product decision:** a durable or global spending allowance
  ("allowance B") does not exist. Today's ceiling is per process and per client
  address; it has no daily or dollar bound.
- Mobile retained-memory plateau: NOT RUN. The harness that produced the November 4
  "RSS does not plateau" result is not in this repository.
- Native client qualification, signed-binary behaviour and the integrated run were
  not exercised here.
