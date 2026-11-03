# Migration/readiness implementation evidence — November 3, 2026

Implementation snapshot: `53d1e1ce79807e80dc57a600735ec282517aa003`, descending normally
from `7930917a026811416c267d6bc978acd6dbadc209` on `chore/billington-foundation-program`.
This is scoped source/local PostgreSQL evidence for FEAT-1793644505 and the migration
slice of FEAT-1793644506. It is not integrated V&V, production adoption or a security pass.
No CHANGELOG migration, deployment, provider/account change or production access occurred.

## Implemented contract

One embedded ordered runner owns both maintained binaries' schema startup. Only frozen
0001 is embedded; 0002 remains reserved, with no empty/speculative production migration.
The baseline SHA-256 remains
`d46084b1caae072be155d7e38c71eba986774853e7d004b08d19daa411992f55` (7483 bytes).
Released `81a564f` and captured `f1d62374` model/init/module blobs have no diff.
`baseline-provenance.json` retains the original dump hash and explicit normalization.
`catalog-provenance.json` separately pins the PostgreSQL 17 catalog query, 147-object
manifest, ledger DDL and combined validation payload; exact integer decoding avoids
losing adjacent int64 sequence definitions. No pg_dump formatting or physical-column-order
fingerprint is used. The independent frozen legacy fixture also has a pinned digest.

Read Committed transaction/advisory lock ordering precedes all ledger inspection/creation.
The ledger records exact SQL/validation checksums, name/version, epoch and DB timestamp;
known history is immutable and never downgraded. Reviewed additive later same-epoch
versions may extend the known prefix. All pending SQL/ledger work, final validation and
commit are checked together, including rollback errors. No automatic retry hides failure.
Fresh and strict known-legacy targets are distinguished; missing/wrong objects fail closed,
while unrelated extension relations/objects are ignored. Adoption never executes data repair.

Default startup applies/verifies; `--migrate-only` applies/exits; `--schema-mode=verify`
checks without applying before serving. Invalid modes/flags fail with sanitized errors.
Both binaries use the same options, initializer and health handler. The historical payer
backfill is retired, not reported as successfully run. Null/dangling/cross-tab references,
IDs, capability tokens, JSONB, quote/display evidence and paid flags remain unchanged.
No authorization, money calculation, display contract or logger policy was changed;
logger tests only adapt to the initializer's context/mode/state signature.

Budgets remain 5s lock acquisition, 60s total schema startup and 1s live health query.
Health preserves healthy status/commit fields, otherwise generic 503. A successful
startup state plus a live required-ledger check is necessary; there is no accounting
preload, provider access or cache. Catalogs are validated at startup; out-of-band DDL
requires rerunning verify, rather than a catalog scan on every health request.

## Executed affected gate

Toolchain: actual backend Go **1.27.3 darwin/arm64** (`GOTOOLCHAIN=auto`, matching go.mod).
The root launcher reports Go 1.25.7; it is not the compiler used in backend commands.
Python 3.13.5; shared PostgreSQL **17.11**, dedicated loopback `billington_test` DB/user.
No dependency manifests/locks changed and no framework/tool was installed globally.
The detected affected CI matrix is build/vet/race tests/govulncheck in `.github/workflows/ci.yml`
and `deploy-backend.yml`. Other tiers, GUI/provider journeys and integrated protocol were
not selected by this backend-only change. The additional PG row remains local, not CI-wired.

Commands run from `backend` with `GOTOOLCHAIN=auto`:

```sh
go version
go test ./... -list '.*'
go test -tags=integration ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres -list '.*'
go build ./...
go vet ./...
go test -count=1 -race -json ./...
go test -count=1 -race -tags=integration -json ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres
go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./...
```

The tagged command uses only `BILLINGTON_TEST_POSTGRES_DSN` pointing to the explicitly
approved `127.0.0.1:51168` synthetic fixture, sslmode disable. `-json` adds machine-readable
reporting to the CI race row; `-count=1` prevents cached-result claims. Full raw reports
live under ignored `.vv/local-gate/migration-readiness/`.

| Selection | Top-level tests | Leaf cases passed | Failed | Skipped |
|---|---:|---:|---:|---:|
| Default Go race | 122 | 373 | 0 | 0 |
| Final tagged PG selection (includes default tests in selected packages) | 119 | 413 | 0 | 0 |
| Overlap by package/test identity | 91 | 317 | — | — |
| Distinct union | 150 | 469 | 0 | 0 |

Leaves exclude parent tests with descendants. Four default packages (`cmd/bill-service`,
`cmd/web-service`, `internal/readiness`, `internal/web`) have no default test files; Go
emits package-level skip events for these, not skipped test cases. The binaries and
readiness have separately executed integration coverage; the legacy web handler has no
own tests. Do not add default and tagged counts.
An earlier tagged pass omitted the subsequently added query-tracer test (118/412);
the final tagged rerun is justified by that harness/test addition. The standalone shape
run and development/control runs overlap the final counts and are not extra coverage.
Build/vet (including `go vet -tags=integration ./...`)/format/diff checks pass. govulncheck exits 0 with zero reachable or imported-package
advisories and three advisories in required modules whose affected functions are uncalled;
this is not a claim of zero module advisories. No CI wait was used as evidence.

Lasting PG regressions cover fresh/adopt/repeat preservation; partial/wrong actual column,
default, key, FK schema/action/deferral, index key/uniqueness/predicate/expression/order/
opclass and sequence definitions; exact large integers; harmless DDL spelling/column order;
unrelated tables; ledger checksum/validation/name/gap/epoch; compatible later prefixes;
observed competing advisory lock waits before ledger creation and independent target schemas;
5s lock timeout; actual DDL/DML/ledger failures and deferred FK failure at **commit**;
rollback across multiple pending versions; backend connection termination/context cancellation,
rollback/released lock/retry once; earlier total caller deadline; 1s blocked-ledger health;
unavailable/invalid readiness and both actual binaries' apply/verify/migrate-only dispatch.
Existing authorization/money/display fixtures run through the shared current-schema runner.
An explicit missing-DSN selection fails one executed PG test, with no skip or created schema.

## Controls, query shape and diagnostic limits

Nine isolated Go overlay experiments fail executed assertions when removing: registry
checksum; independent recognizer checksum; actual catalog-definition comparison; exact
catalog integer decoding; known-prefix checksum; advisory lock; checked commit; live
readiness; retired payer backfill. Exact argv, overlays, executed cases and outcomes are
in `controls/summary.json`. No shared source mutation was used for the experiments.
The backfill experiment's first attempt was unproved because the parent overlay did not
reach subprocess `go build`; it is retained. Repeating only that control with the same
overlay propagated through `GOFLAGS` fails payer preservation in both real binaries.

Readiness was measured with an actual pgx query tracer for **three runs of 100 requests**:
exactly one SQL query/request. In the dedicated shape run local race-build p95 values were
0.336/0.323/0.332 ms (max 0.422 ms). One fresh startup used 12 traced statements/60.5 ms;
one repeat used 10/48.1 ms, including transaction control, setup, catalog/ledger queries.
These are a small local fixture and one-sample startup observations, not production
latency, startup distributions or loaded-table DDL budgets. The final PG run also records
its own measurements; no warm/cold/load guarantee is inferred.

Initial development failures were test setup errors: a cross-reference fixture lacked
its matching reference row, and the preservation helper queried a deliberately removed
table. Both were corrected before the lasting passing runs. A preparation command used
the backend cwd with root-relative paths and failed before writing catalog files; corrected
at repo root. One reporting helper initially summed a missing JSON Test value; the corrected
package/test-identity counter is `test-counts.json`. All failed attempts remain in private
logs. No test/scanner failure is relabeled as a passing run.

## Unsuppressed scoped scans

Scans target immutable committed source at `53d1e1c`: a backend archive (SHA-256
`4c69fe71a040e1e752f4e58e3ba2904826aea636f264aa3ce245e1d98515afe8`) and copies
of the 34 existing changed paths; the 35th path is the removed zero-byte Compose placeholder.
Private `scans/summary.json` records exact argv, config/rule hashes and exits. Source remains
local; scanner account tokens were removed, Semgrep metrics/version checks off, `--oss-only`,
no login/upload/autofix, no ignore-comment suppression, and no secret provider verification.

| Scanner | Scope / unsuppressed result | Disposition |
|---|---|---|
| Gitleaks 8.30.1 | Source 3 candidates, exit 1; commit range `7930917..53d1e1c` zero, exit 0 | Existing docs `memberToken` placeholders; no credential. Random nonfunctional bearer control detected and fully redacted in report/log; fixture deleted. |
| Semgrep CE 1.183.0 | 21 changed Go files, 8 audit candidates, zero scan errors, exit 1 | Two unchanged HTTP/TLS-listener audit conditions; six test-only exec/SQL audit candidates resolved by fixed repo-built binary, argv literals, numeric IDs and private table/predicate literal allowlists. |
| gosec 2.30.0 | 10 production files / 926 lines, 2 G114 findings, zero scan errors, exit 1 | Existing HTTP listeners lack server deadlines; canonical BUG-1793644507 remains open. |

All 13 candidates were reviewed. No new confirmed migration vulnerability was found.
Existing listener TLS termination/timeout findings remain unwaived; scanners retain
nonzero exits. This is **not** a whole-repo/image/history security audit or green gate.
Existing image/package findings and overall security/integrated acceptance remain RED.

## Documentation, cleanup and remaining gates

Living README, backend README, architecture, API health contract and VERIFICATION were
updated for the new schema modes/readiness and lasting PG selection; `make test` now
includes the new migration package. Historical dated reports/baseline remain untouched.
Official `trackers.py` records FEAT-1793644505 as shipped-pending-migration; FEAT-1793644506
keeps its prior open status with a migration-slice evidence log. No unrelated statuses or
CHANGELOG entries were changed; install/lint completed with 0 errors/warnings.

At least **171 distinct owned test schemas** are individually observed in retained logs;
passing preliminary non-JSON runs did not print schema names, so this is not an invented
total across all preparation. All cleanup hooks ran, and a final read-only namespace
query found zero `billington_test_*`, `billington_auth_*`, `billington_migration_*` or
`billington_catalog_*` schemas. The catalog capture itself created/rolled back one unique
schema in a transaction. Shared fixture ID/owner/loopback endpoint remain unchanged and
running; no public schema, normal volume or customer data was used. Test-built binaries
were temporary; no application listener/container/server was started by this phase.
Original untracked reviews, Android work and artifacts remain intact.

Operational acceptance still needs actual production catalog/adoption inspection,
backup/recovery and isolated restore, hosting command/privilege/predeploy setup, bridge
and verified drain of older incompatible/uncooperative writers, and later keyed-client
rollout sequencing. Keep additive ledger/columns on application rollback and never return
to replay-ignorant servers after keyed clients activate. Atomic financial finalization,
stable identity, receipt 0002 and full integrated V&V are separate unfinished phases.
