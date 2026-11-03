# Required Go module inventory — November 3, 2026

Scoped repair from `95553f7cad092031506ca1781b5296910361d8d9`, under
`SECURITY_INVENTORY_APPROVAL.md`; tracked by BUG-1793714791. This is local module
evidence, not integrated acceptance, a deployed-artifact claim or a package waiver.

## Selection and smallest graph

Primary sources were fetched again November 3 at approximately 14:04 UTC before
resolution. The official [Go stable feed](https://go.dev/dl/?mode=json) still lists
1.27.3; the module directive and both immutable builder pins remain unchanged.
The official proxies report [x/net 0.62.0](https://proxy.golang.org/golang.org/x/net/@latest)
and [tagged x/crypto 0.58.0](https://proxy.golang.org/golang.org/x/crypto/@latest).

The explicit approved exception is x/crypto
`v0.58.1-0.20261009181718-2f1f834330b2`. The official
[GO-2026-5932 record](https://vuln.go.dev/ID/GO-2026-5932.json) now names that
parent-module fixed boundary. The exact [upstream commit](https://go.googlesource.com/crypto/+/2f1f834330b2d36ab3db8bfb33aaa1ac16794588)
has the 0.58.0 tag commit as its sole parent and adds only `openpgp/go.mod`.
It separates unsafe, unmaintained OpenPGP from the parent module; it does not repair
OpenPGP. No containing newer stable tag was published when checked. No separate
OpenPGP module or replacement library is introduced.

Both [GO-2026-6860](https://vuln.go.dev/ID/GO-2026-6860.json) and
[GO-2026-6866](https://vuln.go.dev/ID/GO-2026-6866.json) identify x/net 0.62.0 as
fixed. Official proxy `.info`, `.mod` and signed checksum-database records were
saved and compared with Go's generated module/manifest sums. `go mod verify` passes.

| Required module graph | Before | After | Reason |
|---|---|---|---|
| x/net | 0.60.0 | 0.62.0 | Both HTML advisory boundaries |
| x/crypto | 0.57.0 | 0.58.1-0.20261009181718-2f1f834330b2 | Approved parent-module separation |
| x/sys | 0.48.0 | 0.49.0 | x/net and x/crypto minimum |
| x/text | 0.42.0 | 0.43.0 | x/net and x/crypto minimum |
| x/sync | 0.23.0 | 0.24.0 | x/text minimum |
| x/term | 0.46.0 | 0.47.0 | x/net and x/crypto minimum; graph only |
| x/tools | 0.49.0 | 0.51.0 | x/text tool requirement; graph only |

No module was added or removed from the graph. `go.mod` changes exactly five
indirect versions; `go.sum` replaces their ten module/manifest checksum lines.
`go get` was restricted to the two approved pins. `go mod tidy` also classified
the already-imported pgx as direct; that unrelated classification was excluded
from the final diff. No broad updater or framework/toolchain change was used.

## Actual validation

Test builds retain CGO for race/SQLite coverage. All commands run locally with
Go 1.27.3. `clean=no`: no checkout/worktree/branch change was authorized.

| Check | Actual result |
|---|---|
| Exact CI gofmt guard, `go build ./...`, `go vet ./...` | Exit 0 |
| `go test -race -count=1 -json ./...` | 123 top-level / 385 leaf; pass385, fail0, skip0, cached0; four packages have no test files |
| `go test -race -count=1 -tags=integration -json ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres` | 119 top-level / 413 leaf; pass413, fail0, skip0, cached0 |
| Default/PG overlap | 317 shared leaf identities; unique union481, not 798 |
| CI `go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./...` plus JSON/verbose | Exit0; required-module0, imported-package0, reachable-symbol0 |
| Separate `-scan module -json` from `backend/cmd/bill-service` | Exit0; zero module findings |
| Linux/amd64 production dependency inspection, both commands | No SQLite/OpenPGP import; CGO0 graphs have no CgoFiles |

Fresh before JSON had exactly GO-2026-5932, GO-2026-6860 and GO-2026-6866 as
required-module findings, with zero imported/reachable findings. Fresh after
reports clear all three; no historical scanner count is reused as current.
The before/after scanner is the regression control for these inventory fixes.

Initial PG execution used an older passwordless fixture DSN: 411 passed and two
executable-mode leaf cases failed because the empty password trips their secrecy
check (and cannot satisfy normal startup). Supplying the recorded approved synthetic
password produced the complete passing run above, without source/test changes.
This setup failure is preserved, not classified as application flakiness or a pass.
Two supplemental module-scan invocations failed during setup (patterns disallowed;
then no Go files in the module root); the valid service-directory invocation is
separately retained. CI's source scan passed independently.

## Limits, documentation and evidence

No application logic, ordered migration, reserved 0002, readiness query, logging,
authorization, money/display defaults, framework, mobile or receipt-provider code
changes. Existing auth, HTTP-log, money and migration/readiness tests remain in
the executed selections. No live database or hosting account was contacted.

Doc-sync searched tracked Markdown for these module/advisory names and version
pins. Living runtime docs do not quote the replaced module versions; this dated
evidence note is the only new module documentation. Historical reports and the
frozen baseline remain unchanged. Fix/Docs are recorded through the official
tracker writer; the ticket stays in-progress pending independent review. No
CHANGELOG migration or whole-program success is claimed.

Raw records: `.vv/local-gate/security-inventory/`, including
`primary-sources.json`, `*-sumdb.source`, `approved-modules-download.log`,
`module-delta.json`, before/resolved module graphs, `minimal-module-final-diff.log`,
all `*.result.json` command records, actual `go-*.log` JSON events,
`module-verification-summary.json` and `native-production-review-*.json`.
The source-scoped dependency checks pass; the separate conditional static-runtime
work and independent integrated/security review remain outside this module result.
