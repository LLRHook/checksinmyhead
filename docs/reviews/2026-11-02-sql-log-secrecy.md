# SQL log secrecy — November 2, 2026

Scoped BUG-1793644509 implementation against runtime base
`2d853ad8da1ba14b9871bb4042c61fd2d825244a`. Both maintained DB-using binaries use
this logger and InitDB error boundary. No dependencies, HTTP authorization,
financial calculations, model/schema, health contract or runtime probe changed.

The logger discards arbitrary Info/Warn/Error messages and arguments. Trace emits
only a fixed event, elapsed time, row count, exact allowlisted operation/table,
error category and known SQLSTATE; unknown SQL/driver text cannot become a label.
GORM bind interpolation is disabled as defense in depth. Invalid/overflowing slow
thresholds use a static warning. Shared initialization errors are sanitized while
the executable-tested missing-env guard remains unchanged.

## Evidence

Local Go1.27.3 via GOTOOLCHAIN=auto; no clean checkout by explicit instruction.
All reports are under ignored `.vv/local-gate/migration-logging/`.

| Executed command (backend directory) | Result |
| --- | --- |
| `go test -race -json ./pkg/database` | 6 top-level / 13 passing leaf cases, zero failures/skips |
| `go build ./...` | exit 0 |
| `go vet ./...` | exit 0 |
| `go test -race -json ./...` | 116 top-level / 356 passing leaf cases, zero failures/skips |
| `go test -race -tags=integration -json ./internal/tab` | 52 top-level / 157 passing leaf cases, zero failures/skips; overlaps default suite |

The explicit PG test-only DSN selected loopback51168, billington_test, synthetic
credentials and PostgreSQL17.11. The existing harness's generated schemas were
removed; `schema-cleanup.json` records their identities and a read-only namespace
check. Shared fixture remains running. No public/foreign schema was changed.

Actual pre-fix source was tested through a Go overlay: synthetic bill/member tokens,
payment handle, receipt content and a newline marker leak at Error/Warn/Info, with
Silent passing (3 expected failing leaf cases). No source checkout was replaced.
Six independent current-source control removals also fail executed assertions:
raw Trace values, generic messages, config value, table classification, SQLSTATE
classification, and startup errors. `control-summary.json` retains commands and
failures. These expected failures are separate from the passing gate. Go overlays
replace scratch-worktree reverts because this session forbids worktree changes.

Security trigger: ERR/LOG and configuration secrecy. Lasting tests cover all levels,
raw parameter-bearing SQL, hostile identifiers/opcodes/errors, SQLSTATE-shaped
arbitrary codes, config overflow and missing-env/default startup. Existing health
CLI and capability/privacy regressions pass in the default/PG selections.
Scoped Gitleaks8.30.1 (full changed source files, 100% redacted, ignore-comments off),
Semgrep1.183.0 (local approved rules, metrics/version checks off) and gosec2.30.0
(database package, no suppressions) each exit0 with zero candidates/errors.
No account upload or new scanner install occurred. This is no whole-audit claim.

## Limits and documentation impact

Retained runtime-image medium/lower findings keep full security/integrated acceptance
RED. Ordered migrations/readiness, unsafe payer-backfill retirement and remaining
financial/identity/provider/release work are separate. Today's /health remains the
previous liveness contract until the migration phase supplies lasting readiness proof.
No production migration, schema compatibility, hosting configuration or provider-log
redaction is established by this change.

Doc-sync keys: SQL logger, DB_SLOW_QUERY_MS, initialization errors, SQLSTATE, secrecy
verification. Maintained backend README and technical overview now state the logging
contract; VERIFICATION lists lasting cases. API docs have no changed public surface.
Only approved BUG-1793644509 receives official tracker updates; it remains pending
integrated migration into CHANGELOG. Frozen baseline and historical reports unchanged.
