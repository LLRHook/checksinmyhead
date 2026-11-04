# Server creation replay and display verification

Use the exact source/artifact bindings in the dated
[implementation record](reviews/2026-11-04-replay-display.md). This is a focused
server procedure; mobile durable-save, signed-client/old-writer exclusion, production
adoption and integrated acceptance remain open. Keep prior runtime/assignment/resource
RED records. No production or hosted-provider operation is part of this procedure.

From backend, use the existing explicit loopback-only `BILLINGTON_TEST_POSTGRES_DSN`
and shared `internal/testpostgres` harness. Missing/unsafe DSNs must fail with no skip;
only newly generated owned schemas may be dropped. Compile first with `go test -c`.
Run ordinary `go test -race -count=1 -json ./...` and the entire maintained eight-package
PG row in VERIFICATION under an explicitly reserved quiet timing window. Preserve all
historical IDs and source assertions. Embedded repeated shape tests are measurements:
`TestPostgresCurrencyCreationQueryAndLatencyTargets`,
`TestPostgresCreationAttachmentQueryShapeAndLatency`,
`TestPostgresLifecycleMeasuredBudgets`, `TestPostgresReadinessQueryShape`.
Interim nonnumerical selections require an explicit allowlist and are not the full gate.

Check HTTP/router/provider composition and real TCP parsing, strict DTO/headers,
canonical golden bytes/digests, independent receipts, conflict/version secrecy,
lost201 recovery and original replay after claim/attach/paid/finalize. Compare raw
IDs/times/flags/accounting/attribution. Established replay must be one indexed scalar
read (cap2), zero provider/derivation/graph writes, no Bill hooks/preloads. Exercise
both unique-wait arrival orders, winner rollback and same-key recovery; inject each
child/mid-batch/deferred-commit failure and actual PG connection loss before/after
COMMIT. Meaningful source-overlay removals must fail executed behavioral assertions.

Validate empty/strict legacy/1/2/compatible-newer/corrupt histories and all nine 0002
definitions/enforcement; preserve old rows and complete row1. Run actual old and new
binaries' apply/verify/readiness against the full0002 schema. Prefix compatibility
and capability/health do not establish old-writer exclusion. Keep additive columns,
index and ledger during rollback; never reintroduce replay-ignorant writers after
keyed clients. Future deletion/revocation requires tombstones before identity removal.

For approved replay measurements, compile with `-tags=replayperf,integration` and set
`REPLAY_MEASURE_OUTPUT` to an owned output file. Use representative40items/8people
and max500/100/5,000 under1MiB,100observations across3runs/path. Count data, errors,
conflicts, RETURNING and every batch; report BEGIN/COMMIT/ROLLBACK/SAVEPOINT separately
and total traced statements. Targets: keyed <= 7/16 data statements within12/20 caps,
established replay normally 1/cap 2 indexed reads/0provider/0graph writes, USD p95 <= 200ms,
healthy synthetic-provider publication<=2s. Report all distributions/allocations,
the exact timing intervals, EXPLAIN plan, environment and noise. `ProviderNS` measures
WroteRequest-to-first-response-byte only; it excludes connection setup, request writing,
response-body reading and validation. `ApplicationNS` is total elapsed time minus that
interval, not CPU time. `TransactionHeldNS` measures BEGIN-through-COMMIT/ROLLBACK,
not row-lock time. Misses stay RED. The separate50,000-update performance gate remains
RED/unselected. Rebuild and
scan both exact maintained images, verify compiler/source/binary identities, run the
unchanged runtime harness (only its reviewed read-only acquisition adapter allowed),
and record bounded cleanup and absence receipts. Never erase a prior flaky failure.
