# Go dependency maintenance evidence — November 2, 2026

BUG-1793644503, approved by the driver's DEPENDENCY_PHASE_APPROVAL.md.
Starting revision: f1d62374fe50e5deb32f64a40c142fb33726232f on
chore/billington-foundation-program. This is scoped implementation evidence,
not independent acceptance, integrated V&V or deployment evidence.

## Resolution and provenance

The [official release feed](https://go.dev/dl/?mode=json) still reports stable
Go 1.27.3. [GO-2026-6809](https://pkg.go.dev/vuln/GO-2026-6809) identifies
1.27.3 as the fix for the affected certificate verification path. `go.mod` and
both existing builders now select that patch. No application module or `go.sum`
entry changed. Local `GOTOOLCHAIN=auto` selected go1.27.3 darwin/arm64;
the host's base Go 1.25.7 was not a blocker.

Registry manifests were read before pinning. Both Dockerfiles retain their
existing runtime distribution and use these multi-platform index identities:

| Image | Index SHA-256 | linux/amd64 manifest SHA-256 |
|---|---|---|
| docker.io/library/golang:1.27.3 | 2920bb124f1a2e12a1d39f0cab756ae0068441ee1da7655dec7f5e374944095b | 5bbe76a31abbe0f1449d7820e550131c020b097c24d3bcfc5ad1231779982c1c |
| gcr.io/distroless/base-debian12 | fabbf1c0c357a3d42550111351daed089b20a2c954df13ee2fcff60602515e84 | d2add786f2a5f43d1ab3ae54cd3193de929d0d12c378ff60891921f56f3e47ff |

Builder `GOTOOLCHAIN=local` prevents silent compiler substitution. Docker's actual
context exporter was exercised with synthetic inputs: without `.dockerignore`,
18 excluded-file probes reached the context; with it, none did. Six source,
template, fixture and example probes remained. No real environment/key file was
opened by the probe. The [backend README](../../backend/README.md) records the
toolchain maintenance contract and both build commands.

## Executed checks

Raw logs, Go JSON events, registry indexes and result metadata are under ignored
`.vv/local-gate/dependencies/`. Counts exclude parent test containers.

| Directory | Command | Result |
|---|---|---|
| backend | CI `test -z "$(gofmt -l .)"` check | Exit 0 |
| backend | `go build ./...` | Exit 0 |
| backend | `go vet ./...` | Exit 0 |
| backend | `go test -race -json ./...` | Exit 0; 94 top-level / 272 leaf cases; 0 failures/skips; 4 packages have no test files |
| backend | `go test -race -tags=integration -json ./internal/tab` | Exit 0; 48 top-level / 147 leaf cases; 0 failures/skips; includes 7 PostgreSQL-specific top-level / 11 leaf cases |
| backend | `go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./...` before | Exit 1 / scanner status 3: one reachable standard-library finding, GO-2026-6809 at go1.27.2 |
| backend | Same pinned scanner after | Exit 0: zero reachable findings; 3 findings remain in required modules whose vulnerable symbols are not called |
| root | Both documented `docker build --pull --no-cache --platform linux/amd64` commands | Exit 0; legacy viewer/template retained |

The PostgreSQL selection used only the supplied loopback port 51168,
database/user billington_test, PostgreSQL 17.11. The unchanged harness generated
and cleaned its own billington_auth_* schemas. No developer/production data,
caller-supplied schemas or database.InitDB path was used.

| Built linux/amd64 image | Docker image ID / index SHA-256 | Extracted binary SHA-256 |
|---|---|---|
| billington-bill:validation | 1250a665d84c27ca56a741e7ea11f1b76a008a98869a03f4767a107cdc1da19a | 0e5a6b99a3dee666867ea7d577d72ea49e7ccba38dbf2467f4a576e6eb7eeaf5 |
| billington-web:validation | a15e98abe6bed09881524284235182c6d0845069379b592cb6d18b38edea2b25 | bdc75d3b7692fed9098a058d54722e9ade56adddbb564571c052d8b0ba988f72 |

`go version -m` on both extracted binaries reports go1.27.3, linux/amd64,
CGO_ENABLED=1. ELF inspection lists only libc.so.6 as a direct dynamic dependency.
Both images, run with networking disabled and no credentials, enter the existing
missing-required-database-environment guard. This proves loader/startup
compatibility, not database health or an application journey. The first probe's
assertion expected a connection refusal; the earlier required-env guard was the
correct observed behavior, and the interpretation was corrected without repeating
a passing suite. Runtime source, authorization tests and fixtures remain byte
identical to f1d62374; these are local candidate builds, not hosted artifacts.

## Security outcome and acceptance limits

Trivy 0.76.1 was verified against its [official release](https://github.com/aquasecurity/trivy/releases/tag/v0.76.1)
and [container instructions](https://trivy.dev/docs/latest/getting-started/installation/).
It ran as a disposable official container pinned to index
sha256:790fd66d1697395d8693d1acaa1ea702406a20f109b6fc7bac8db623eca6c06c;
no global installation or host credential/Docker-socket mount was used.

- `trivy config --format json --exit-code 1 /scan`, over only before/after
  Dockerfiles, exited 1. Each after-file passes 25 checks and retains DS-0002
  (HIGH, root user) and DS-0026 (LOW, no HEALTHCHECK). Each before-file also has
  DS-0001 (MEDIUM, mutable latest runtime tag), removed by the digest pin.
- `trivy image --input <saved-image.tar> --scanners vuln --format json --exit-code 1`
  exited 1 for **each** built image. Each has 41 OS-package findings and 3 Go-module
  findings: 1 HIGH, 22 MEDIUM, 14 LOW, 7 UNKNOWN in total. No finding was suppressed.
- The HIGH package finding is libssl3 CVE-2026-84782, installed
  3.0.20-1~deb12u2, fixed in 3.0.22-1~deb12u2 according to the
  [Debian security tracker](https://security-tracker.debian.org/tracker/CVE-2026-84782).
  The [OpenSSL advisory](https://openssl-library.org/news/secadv/20260929.txt)
  concerns DTLS retransmission. The package is present; exploitation by these Go
  binaries is not established. Direct ELF dependencies do not include libssl.
- Changed-file secret regex scan found zero candidate values; gitleaks was not
  installed. SAST was not run (no application-source change); no SAST pass is claimed.

**Full local gate: RED. Security gate: FAIL.** The targeted reachable Go finding
is cleared, but image findings and an independent locked-Flutter acquisition
failure prevent an unconditional acceptance claim. Flutter 3.41.5 analysis and
203 tests passed using the existing package configuration; enforced acquisition
failed twice (exit 65) because the committed lock differs from SDK-required
characters 1.4.1, matcher 0.12.19, material_color_utilities 0.13.0 and test_api
0.7.10. No mobile lock/runtime file was changed.

BUG-1793644503 retains in-progress status with Fix/Docs evidence, pending the
driver's disposition and independent validation. Concrete follow-ups for the
driver: separately authorize the four-entry Flutter lock alignment and a verified
Debian 12 base-package refresh/non-root runtime plan. Do not introduce a new runtime
distribution or waive findings implicitly. Hosting architecture, deployment
identity, source/publication gates, production exploitability, broader runtime
protocol and independent authorization review remain unverified here. No merge,
deployment, upload, publication, source-gate closure or CHANGELOG migration occurred.

## Doc impact

Seven version/ticket/context keys were searched in 38 tracked Markdown files.
The new backend toolchain contract is documented in backend/README.md; no living
doc's existing command became incompatible. Dated authorization/baseline/archive
records remain unchanged. VERIFICATION.md and CI commands retain their interfaces;
only report flags were added for the single test executions above. No affected API,
schema or financial contract changed.
