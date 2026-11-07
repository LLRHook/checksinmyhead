# Static production runtime — November 3, 2026

Scoped follow-up to BUG-1793652309 under `SECURITY_INVENTORY_APPROVAL.md`, after
module commit `df821bdb5529fc61981cf213f9867204cfa413b6`. Conditional local runtime
proof passes. Whole-program acceptance remains RED; existing listener/resource
findings remain BUG-1793644507. This record authorizes no deployment or waiver.

## Decision, dependencies and provenance

Both production Docker builds now set `CGO_ENABLED=0` and use supported
`gcr.io/distroless/static-debian13:nonroot`, retaining explicit USER65532:65532,
the compiler pin/local-toolchain enforcement, templates, CA/tzdata/tmp, startup
modes, live readiness and the original same-binary health commands/timings.
Only those two lines per Dockerfile change. Application/migration/health/logging/
auth/money/display/provider logic and tests remain byte-identical. Test builds
retain CGO for race/SQLite coverage; there is no global CGO setting change.

The [Distroless support policy](https://github.com/GoogleContainerTools/distroless/blob/main/SUPPORT_POLICY.md),
[contents](https://github.com/GoogleContainerTools/distroless/blob/main/base/README.md)
and [Go example](https://github.com/GoogleContainerTools/distroless/blob/main/examples/go/Dockerfile)
were re-read before selection. Static Debian13 is maintained and supplies CA/timezone
data without libc/OpenSSL. The exact official index was fetched/hash-checked again
at 14:22 UTC before final builds. Cosign3.1.4 verified the exact index twice, before
candidate/final builds, with certificate-chain and transparency-log proof:

```text
index   sha256:25ac8f0c3b2334a9eb05452266bd4697864a8c8ef0ef71e5e6480d7f92868329
amd64   sha256:336e53e9941facdb69b755e6fd2c63f5400abd3b1ba47bb17ebafc2b1547cebd
arm64   sha256:bf6233b64054d17b31c3b555b1bbcee58958896830a305ef4d51faa257990d87
issuer  https://accounts.google.com
subject keyless@distroless.iam.gserviceaccount.com
```

No bypass flag, signing/upload action or final-image signature claim. Go's stable
feed still lists1.27.3. Builder index remains
`2920bb124f1a2e12a1d39f0cab756ae0068441ee1da7655dec7f5e374944095b`,
Linux/amd64 child `5bbe76a31abbe0f1449d7820e550131c020b097c24d3bcfc5ad1231779982c1c`.

Production import inspection with CGO1 found native files only in standard-library
runtime/cgo, net and os/user; both CGO0 graphs contain no CgoFiles, SQLite or OpenPGP.
The pinned [GORM PostgreSQL driver](https://github.com/go-gorm/postgres/blob/v1.6.3/postgres.go)
uses [pgx/Go TLS](https://github.com/jackc/pgx/blob/v5.10.0/pgconn/config.go).
No actual production native dependency was found. Go's
[resolver documentation](https://pkg.go.dev/net#hdr-Name_Resolution) explains the
behavioral switch: pure Go reads resolver/hosts files instead of libc/NSS. Local
tests below cover that switch; unknown hosting NSS behavior is not declared equivalent.

## Exact final artifacts

Both final targets were rebuilt with `--pull --no-cache --platform linux/amd64`
from the production Dockerfiles after the conditional candidate passed. Extracted
final binary hashes equal the passing candidate hashes. Immutable local identities:

| Identity | Bill API | Retained Go web |
|---|---|---|
| OCI index/image ID | `5c863e6ac2191af6ba3ea745ff19501f417daa218d9617bbdef57f7de85588aa` | `285c70d5d8a315392039a8c513b9a1619339d01790cc53e52042af5d2f9437c8` |
| Linux/amd64 manifest | `2c55feeb79e3d6a0c5ce667109e7f0b59fa5ae14e682742b340c9946f84ce079` | `14645f71de697cc6b67835d22b5c67c0d2d02c963fd397f0fe31bae31ae73ccb` |
| Config / Trivy image ID | `babb70fb141893ded23e88c3441d86aeabf8c513220b9ec72be6e4440522c61b` | `f3ac4eeca1293b825592e1556da1252efb5e8c37a4d1e85f699a1da2c08e5cb9` |
| Binary SHA256 | `c2c30eadc6ed8c07337591010893f6934d221e6aa8e65377d4cf5bf241c27225` | `f9be7bee59735a362a2b6e3a13c49ed5930c0dd62ca08479c6705ee74d0a767d` |
| Saved-image tar SHA256 | `da8aeb4bba1d2c47bd86a4c58b76955343cbdd6abfdc437874a551697a1680dd` | `7afad1c89c1215b667675c080fa048a1dc096d06c9fc5789f997fd5c01edb383` |

All digests in the table are SHA256. Archive index → platform manifest → config
hashes and layer DiffIDs match Docker inspection and the actual Trivy inputs.
Final ELF/readelf and buildinfo prove Go1.27.3, Linux/amd64, CGO_ENABLED=0,
no PT_INTERP, no dynamic section/DT_NEEDED and no libc linkage. Buildinfo retains
the approved x/net/crypto versions; no OpenPGP module enters either artifact.
No VCS SHA is embedded by the Docker build context; committed source-input hashes
tie these builds to source independently of the operator-injected health commit.

| Same-source/platform local Docker `Size` metric, bytes | CGO1/base-nossl comparison | Final static | Reduction |
|---|---:|---:|---:|
| Bill | 26,154,592 | 21,042,934 | 19.54% |
| Web | 25,998,385 | 20,888,696 | 19.65% |

This is the same daemon's reported image metric, not uncompressed rootfs bytes.
Comparison images were freshly built with the already-repaired module graph and
unchanged production Go/SQL/template inputs. Preliminary builds before an excluded
pgx direct/indirect classification adjustment are retained separately and not used
for this comparison. Historical November2 sizes/counts are not substituted.

Final OS inventory has six packages versus seven: libc6 2.41-12+deb13u4 is removed;
base-files13.8+deb13u7, ca-certificates20250419+deb13u1, media-types13.0.0, netbase6.5,
tzdata and tzdata-legacy2026f-0+deb13u1 remain. Neither final contains libc/libssl/
libcrypto files, shell/package tools or the QA executable. Trivy inventories31 bill /
30 web Go package records. Root-owned app/binaries remain0755, template0644; CA,
New York timezone, passwd/group bytes and sticky01777 base `/tmp` are preserved.
Runtime `/tmp` is a writable tmpfs explicitly owned by65532:65532.

## Actual runtime and regression evidence

The lasting `scripts/verify_static_runtime.py` plus `scripts/runtime-probe/main.go`
use standard tooling and existing locked Go dependencies. The diagnostic executable
is compiled CGO0 with the pinned builder and mounted read-only, never shipped.
The harness resolves local tags to immutable image IDs before execution.

Final execution: **69 top-level harness checks pass, zero failures/skips**, separate
from the backend unit/PG counts. Both exact final images were exercised with:

- Default fresh/no-op migration, empty-schema verify rejection without ledger
  writes, migrate-only exit and verify-only serving; ledger version1 only.
- PostgreSQL17.11, fresh owned `billington_runtime_*` schemas; public remains empty.
  Actual service sessions prove TLS. Trusted verify-full succeeds; bad CA and wrong
  hostname fail actual startup without config leaks. Diagnostic errors are typed
  certificate trust/hostname failures, not generic connection failures.
- Actual UID/GID65532, file-based passwd lookup, denied root/app writes, sticky owned
  writable `/tmp`, New York winter/summer and database timezone, public HTTPS chain
  validation, and readable retained HTML. Public HTTPS uses host-resolved example.com
  through an injected hosts entry; synthetic DNS has no public-query forwarding.
- Hosts-file name, Docker service DNS, search-domain A/AAAA, typed NXDOMAIN, long
  search suffix and in-flight deadline cancellation. DNS fixture query logs and
  `GODEBUG=netdns=2` confirm Go resolver selection/requests. Cancellation is bounded
  around250ms and must return a typed timeout after the context deadline.
- API synthetic bill create/authorized read, API no-token403, authorized retained
  HTML and legacy no-token403. No customer records or provider calls.
- Each healthy `/health` performs exactly **one** ledger query, measured using
  pg_stat_statements in the owned fixture. Ledger corruption makes health503 and
  the same-binary probe fail. A paused database yields503 in **1.025s bill / 1.033s
  web** including external HTTP overhead. Docker becomes unhealthy with unchanged
  30s/3s/10s/3 probe settings, then recovers to healthy after unpause.

Two deliberate baseline-CGO1 controls fail the lasting ELF check, one per service;
the harness rejects dynamic artifacts. Bad trust/hostname, missing authorization,
failed lookup, corrupted ledger and unavailable DB are additional real negative
controls, not suppressions. All owned fixture containers/networks/certificate
directories are removed. The shared driver PG and normal volumes are preserved.

Runtime harness setup failures remain saved: an initial bootstrap SQL command failed
before per-command stderr capture existed (exact cause unproven; TCP readiness and
capture were added); a resolver assertion overrequired a particular error wrapper
despite a bounded timeout; and stop/start erased a tmpfs database before recovery.
The corrected timeout assertion requires the actual context deadline plus typed DNS
timeout and elapsed bound. Pause/unpause preserves fixture data while proving outage.
Candidate-v4 and the final run pass without application-source changes.

## Current scans, docs and limits

Trivy0.76.1 immutable scanner index
`790fd66d1697395d8693d1acaa1ea702406a20f109b6fc7bac8db623eca6c06c`:
DB UpdatedAt **2026-11-03T13:13:42.304243913Z**, downloaded
**2026-11-03T14:17:36.155178668Z**. Check bundle
`b591e9190cff4aa4e385b1a25bccfd9ecf178d3c77fd194e1410b7ce7e1df058`
downloaded14:25:04 UTC. No ignore-unfixed, severity filtering, VEX, waivers or suppressions.

- Each final image scan exits0: CRITICAL0/HIGH0/MEDIUM0/LOW0/UNKNOWN0.
- Each same-source CGO1 comparison scan exits1: MEDIUM14/LOW8, all22 libc findings;
  no Go module finding. Static removes the package, not the advisory or listener risk.
- Each final Dockerfile:27 successes, zero failures/findings. Root/probes were
  already repaired previously; this change preserves those controls.
- Semgrep1.183.0, Go/generic and Python security rules, no metrics/upload/suppression:
  one local argv-subprocess audit match; fixed tools, owned identifiers/immutable IDs,
  no shell or caller HTTP/customer input. Zero introduced confirmed findings/errors.
- gosec2.30.0: two existing MEDIUM G114 listeners (bill main118/web main57), no Go
  errors; still BUG-1793644507. Package-scan success does not resolve that ticket.
- Gitleaks8.30.1, redacted with ignore-comments disabled: full changed-file scan
  exits1 for one unchanged technical-overview URL placeholder, present in the
  starting source; zero confirmed credentials or added-hunk secret candidates.
  No finding is suppressed. Module-only changed-file scan exits0/candidates0.

Go default385 / explicit PG413 uncached leaf cases pass; overlap317 / unique union481,
no failed/skipped cases in qualified runs. CGO1 is retained for those rows. See the
[separate module evidence](2026-11-03-go-module-inventory.md) for all module/fixture
setup failures and checksums. Final diagnostic vet/gofmt and Python compile pass.

Doc impact: backend/README.md and docs/technical-overview.md now describe static/CGO0
and resolver behavior; VERIFICATION.md links the local harness without changing
Last verified, integrated baseline counts or CI. This new dated note records the
evidence. Tracker changes use the official writer; status stays in-progress pending
independent review. Historical notes, frozen baseline, features and CHANGELOG remain
unchanged; no migration/closure or whole-goal success is claimed.

Raw `.vv/local-gate/security-inventory/`: primary-sources, signatures, build inputs,
before/final saved-image and rootfs tars, image-inventory, image-scan-identity-proof,
ELF/buildinfo, all command/result logs, scan-summary, SAST triage, static controls,
candidate iterations, final-runtime/result.json and its per-command/probe outputs.
The scratch SECURITY_INVENTORY_RESULT.md adds commit/remote/integrity/cleanup and
secret-scan evidence. No native ARM execution, clean-checkout attestation, real-host
NSS/mounted-credential compatibility, production connection, hosting mutation,
deployment identity, external-alert closure or signed-client acceptance is claimed.
Public verification belongs to the driver; a program-branch push does not establish
deployment beyond the driver's supplied81a564f API baseline.
