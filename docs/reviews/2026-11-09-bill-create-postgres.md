# Public bill creation on real PostgreSQL — 2026-11-09

Scope: BUG-1793644498, fourth Expected bullet ("Repository integration tests prove
privileged-input rejection and valid old-client creation"). Base `e0a2c18`. Tests only:
no production source, schema, contract or dependency changed. This is local evidence
against the shared synthetic PostgreSQL fixture (isolated schema per test, real migration
runner). It is not a hosted run, a signed old-binary capture or an integrated V&V pass.

## What was missing

The request DTO, strict decoding, layered guards and their unit tests were already
reviewed. On PostgreSQL the handler was exercised for one nested `id`, collection
bounds, money boundaries, replay and old-client `201`s. The reported reproduction and
the privileged-field suite ran only on SQLite, and no PostgreSQL test read back what an
old-client body stored.

## What was added

`backend/internal/tab/creation_authorization_postgres_test.go` (integration tag):

- `TestPostgresPublicCreateRejectsPrivilegedInput` — one migrated schema holding an
  active tab with a member and a paid, attached bill, and a finalized tab with a bill.
  78 cases post through `BillHandler.CreateBill`: the reproduction (negative total with
  the victim `tab_id`, active and finalized), each half alone, 17 top-level server-owned
  or unknown fields with `null`, `0` and a string, live victim tab, member, bill and
  token values, nested item, assignment, share, share-detail, participant and payment
  identities, `paid`, and a share total that disagrees with the server calculation. Each
  case first gets `201` for the same body without the field, then requires `400`, an
  identical nine-table `lifecycleSnapshot` and no victim text in the response. Afterwards
  no publicly created bill is attached, attributed or paid. The last case shows attachment
  is still the separate credentialed route: finalized tab `400`, missing member `403`,
  both unchanged, then `200` with the tab and member recorded.
- `TestPostgresActualMobileCreationFixtures` — the ten actual mobile builder bodies
  (`mobile/test/fixtures/bill_creation_contracts.json`, including `legacy_usd` and the
  signed `discount` line) through the same assertions as the SQLite test, which now takes
  the database factory as a parameter. The shared assertions also require no tab
  attribution and receipt lines stored as sent, with exactly one negative discount line.

Both families are registered in `ops/ci/case_manifest.json` `rows.postgres`.

## Results

| Command | Result |
|---|---|
| `go test -race -count=1 -tags=integration ./internal/tab -run` the two new families | 90 run, 90 pass, 0 fail, 0 skip |
| Same plus `TestPostgresCreationMoneyBoundary`, `TestPostgresAttachmentAndCreationRollback`, `TestPostgresLifecycleActualMobileCreationThenFinalize`, `TestPostgresAttachmentWaitsForCommittedFinalization` | 107 run, 107 pass |
| `go test -race -count=1 -tags=integration ./internal/bill` (whole package) | 372 run, 372 pass |
| `./cmd/bill-service -run` `TestA1PostgresProductionJSON`, `TestPostgresIdentity0003CreationAndExactReplay` | 25 run, 25 pass |
| `gofmt -l .`, `go vet ./...`, `go vet -tags=integration` (tab, bill, migrations) | clean |
| `go test -race -count=1 ./...` | 1,199 run, 1,197 pass; `internal/bill` and `internal/tab` pass. The two failures are `internal/healthcheck` `TestServiceHealthcheckMode` and its `bill-service` child: `listen tcp 127.0.0.1:8080: address already in use` (another project's listener on this machine) |
| `flutter test --no-pub test/unit/services/api_service_currency_test.dart` | 5 pass; the fixture file equals the builder output |
| `python3 ops/ci/unittest_report.py ops/ci/test_delivery_gate.py` | 42 methods, OK |

Negative controls, each a temporary source edit reverted before commit:

- Non-strict top-level decoding (`DecodeJSON(..., false)`): 58 of 78 children fail with
  `201` and changed rows (every top-level field and live-value case). Nested cases and
  the negative-total cases still pass, as expected.
- Negative total: removing the request sign check, then also the share-calculation,
  insert-guard and frozen-audit sign checks, still returns `400`. From reading the code
  (not isolated by a further mutant) the remaining refusal is `deriveCreation`'s
  assigned-subtotal bound. No mutant tried makes the reproduction fail, so those four
  cases characterize a layered refusal rather than one control.

## "Original setupRED"

The 2026-11-06 note's red R01 row is two fixture-open failures:
`TestCreationFingerprintFrozenGoldenBytes` and `TestIdentity0003Fingerprint2Golden` read
`testdata/creation-v{1,2}.json` relative to the package directory. Reproduced by running
the compiled `internal/bill` test binary from outside `backend/internal/bill`: both
parents fail on `open testdata/...: no such file or directory` and their four children
never start. Under `go test`, which runs each package in its own directory, both parents
and all four children pass (bill package: 321 run, 321 pass). It is a harness working
directory artifact, not a defect in the tests; nothing was changed.

## Not covered here

Served deployment behaviour, a signed old-binary capture, the full eight-package
PostgreSQL row and the timing families were not run. They belong to the integrated
protocol run.
