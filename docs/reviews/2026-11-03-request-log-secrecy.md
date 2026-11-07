# Request-error log secrecy correction — November 3, 2026

BUG-1793644509 follow-up to the independent review of7930917. The SQL logger and
startup errors were sanitized, but 22 existing bill/tab/legacy-web request-error
sinks still printed the returned error with `%v`. A real pgconn.PgError may contain
server-supplied sensitive text and newlines. This was an omitted existing path.

## Change and lasting proof

All 22 sinks now use database.LogRequestError, which reuses the SQL logger's finite
error/SQLSTATE classification and never formats the original error. Original typed
errors remain available for business and HTTP-status decisions. No endpoint,
authorization, money, schema, provider or public response contract changes.

One shared HTTP contract suite exercises real bill, tab and legacy-web handlers
with synthetic PgError messages/details/hints, wrapped connection errors, arbitrary
errors and not-found controls. It asserts confidentiality in both process logs and
responses, preserved404/500 behavior and useful safe categories. The suite has 12
leaf cases; it needs no database outage or customer fixture.

The driver first reproduced 9 executed confidentiality failures and 3 passing
not-found controls in an immutable7930917 archive. The prepared correction passed 12.
After migration headc541e7e, the lasting suite was consolidated into one test file.
An overlay restoring the three unchanged old handlers again produced 9 assertion
failures/3 passes, exit1, with no build or fixture failure. The corrected current
branch passes all 12. No shared source was changed by the before-control run.

## Executed checks

Base: c541e7e3d51cb927922be65e1f2fd1cc3b39aedd plus this correction.
Actual compiler Go1.27.3 darwin/arm64; PostgreSQL17.11 dedicated loopback test DB.
From backend:

```sh
go build ./...
go vet ./...
go test -race -count=1 -json ./...
go test -race -count=1 -tags=integration -json ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres
go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./...
```

The CI format row and git whitespace checks pass. JSON/count flags add fresh-run
evidence to the maintained CI test row. The tagged selection uses only the explicit
owned BILLINGTON_TEST_POSTGRES_DSN; no production database/environment was read.

| Selection | Top-level | Passing leaves | Failed | Skipped |
|---|---:|---:|---:|---:|
| Default Go race |123|385|0|0|
| Tagged PostgreSQL selection |119|413|0|0|
| Distinct union |151|481|0|0|

There are 317 overlapping leaves; do not add the rows. No result-cache reuse or
missing terminal event. Package-level no-test-file events are not skipped cases.
All generated schemas were cleaned; a final read-only namespace count is zero.
The shared PostgreSQL fixture stays running and normal volumes remain untouched.

Gitleaks 8.30.1, Semgrep CE 1.183.0 and gosec 2.30.0 complete unsuppressed with exit 0,
zero findings/errors for the correction scope. Gitleaks/Semgrep scan all five changed
Go files; gosec scans production database/bill/tab/web packages. No upload, new tool
installation or ignore-comment waiver. Govulncheck reports zero reachable/imported
package vulnerabilities and three uncalled required-module advisories. Whole-repo,
image and historical findings remain unwaived; these are scoped scanner results.

Raw commands, runners, source hashes and reports are retained in ignored
.vv/local-gate/request-log-correction/. Driver scripts and pinned archive proof
are in the authorized driver scratch workspace. No other tier was changed or tested.

Local affected backend functional gate: GREEN, clean=no. Scoped request-error
confidentiality checks: PASS. Global security/integrated acceptance: RED. Independent
correction re-review remains required. No CHANGELOG migration, provider setting,
deployment or live migration follows from this local result.

## Documentation impact

| Living file | Impact | Action |
|---|---|---|
| backend/README.md | Application request errors now covered | Document finite logging and retained typed errors |
| docs/technical-overview.md | Shared policy includes all three handlers | Record the shared classification owner |
| VERIFICATION.md | Lasting HTTP failure coverage | Add confidentiality/not-found coverage |
| docs/backend-api.md | Response contract unchanged | No edit |

The official tracker writer records the correction and pending independent review.
Historical dated evidence and the baseline ledger remain unchanged. Original untracked
reports, Android work and artifacts are preserved.
