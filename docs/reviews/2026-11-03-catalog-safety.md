# Supplemental catalog safety — November 3, 2026

Follow-up to independent migration review S1/S2, FEAT-1793644505. Frozen v1
recognition missed inherited descendants and ineffective internal FK triggers.
These are restored/maintained-schema checks, not evidence of a production defect
or an HTTP caller's ability to change PostgreSQL catalogs.

## Correction and compatibility

Independently pinned startup guard v2 supplements the frozen v1 catalog query.
One composed SQL statement returns v1 objects and a mandatory boolean safety row.
The parser requires that row to pass, then excludes it from v1 manifest comparison.
No extra per-catalog round trip or per-request schema scan is introduced.

The guard rejects inheritance on either side of required application/ledger
relations, including cross-schema descendants. It requires each unpartitioned FK's
four internal check/action triggers to be effective for ordinary writes: origin or
always-enabled. Disabled and replica-only states fail. Replica-mode sessions also
fail; origin/local are accepted. Unrelated inheritance and always-enabled FK
enforcement remain compatible. Startup safety does not attest old row integrity
after past maintenance; legacy data remains unchanged for later financial review.

0001 SQL, v1 query/manifest/ledger DDL and checksums, provenance and frozen legacy
fixture are byte-identical to the prior source. Guard v2 has a separate SHA256 pin;
recorded v1 ledger digests/timestamps are preserved. No new migration version or
reserved0002 placeholder, data/backfill, dependency or authorization change.

## Lasting tests and controls

The new PostgreSQL suite has22 leaves: adoption and both ledgered modes cover same-
schema/cross-schema descendants, ledger descendants, disabled/replica-only FK
triggers on referencing/referenced relations, and replica sessions. It compares raw
data and ledger history after rejection. Compatible controls prove unrelated
inheritance succeeds and always-enabled FK enforcement returns SQLSTATE23503 for
an orphan insert. A separate unit detects changes to the embedded v2 guard payload.

An owned95553f7 archive reproduced20 unsafe acceptances with2 compatible controls
passing. The prepared correction passes22. Existing/new migration, startup,
readiness and fixture selection passes120 leaves. Four coherent control overlays
remove parent-edge, trigger-state, session-role and checksum checks; they fail8/9/3/1
executed assertions. SQL controls update their expected digest so they establish
behavior, not merely checksum rejection. No fixture/compiler failure is counted.

The first development probe used unsupported ENABLE REPLICA/ALWAYS TRIGGER ALL;
those setup failures are retained separately. Corrected tests select/quote one
actual internal FK trigger. Only the subsequent20 actual unsafe-acceptance failures
are before evidence. The final compatible control was tightened to require23503
and all22 targeted leaves reran successfully after that test-only refinement.

## Current source verification

Integrated onto57c1875e8a8e72df6d7b88eb5e0430700a6cb14b after the exclusive runtime
writer returned. Original catalog.go and all seven frozen-payload hashes matched
before transplanting. Current Go1.27.3/PG17.11 commands from backend:

```sh
go build ./...
go vet ./...
go test -race -count=1 -json ./...
go test -race -count=1 -tags=integration -json ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres
go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./...
```

Build/vet, CI format guard, whitespace and tracker lint pass. All runners are
uncached, with no missing test terminals:

| Selection | Top-level | Passing leaves | Failed | Skipped |
|---|---:|---:|---:|---:|
| Default Go |124|386|0|0|
| Explicit PostgreSQL |121|436|0|0|
| Distinct union |153|504|0|0|

Overlap is318 leaves; counts are not additive. The final22-leaf targeted rerun is
overlapping evidence, not22 more unique tests. Package-level no-test-file events
are not skipped test cases. Production code did not change after the complete gate.
Govulncheck reports no vulnerabilities after the separate module repair.

Scoped Gitleaks8.30.1 and Semgrep CE1.183.0 scan the four changed source/SQL files;
gosec2.30.0 scans production migrations. All exit0 with zero findings/errors and no
suppression. SQL is additionally reviewed directly; no claim that every SQL property
is covered by a scanner. Changed test-source scans reran after the23503 assertion.
No image rebuild is attributed to this correction; prior static-image evidence is
the57c1875 scope. New final artifacts remain an integrated verification requirement.

Raw current evidence is in ignored .vv/local-gate/catalog-safety-correction/;
archive/control/frozen-hash proof is in the authorized driver scratch workspace.
Only exact observed owned schema names are queried for cleanup. The shared local
fixture and normal volumes remain; no production/customer connection or provider
action occurred. Independent correction re-review remains pending. Local affected
backend checks pass; global security/integrated acceptance remains RED.

## Documentation and tracker impact

README/architecture now describe supplemental guard v2 and immutable v1 history.
VERIFICATION adds enforcement coverage while remaining below20KiB; its Last verified
and integrated baseline counts are unchanged. API health behavior is unchanged.
FEAT4505 is in-progress pending correction review; broader FEAT4506 remains open.
BUG4509 now reflects independent logging approval as fixed-pending-migration.
All tracker edits use the official writer; full original migration evidence remains
in its dated note and Git history. No CHANGELOG migration or overall-green claim.
