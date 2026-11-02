# Supported nonroot runtime and local probes — November 2, 2026

BUG-1793652309 follows the retained-image findings in
[dependency evidence](2026-11-02-go-dependency-maintenance.md), associated with
BUG-1793644503. **GO-2026-6809 is a distinct Go standard-library advisory.** The
OpenSSL package finding was CVE-2026-84782 in the former Debian 12 image.
Authority: driver `RUNTIME_LOCK_APPROVAL.md`, deliverables 2–3; base
`f9f8fb86dd8cfa45052dcbc26edf9e69ff19c9bf` on the existing program branch.

## Scope and provenance

Both runtime stages now use:

```text
gcr.io/distroless/base-nossl-debian13:nonroot
index sha256:e6b0f82595aa1edde72c8054de7a9dca30f0f8f54820c37a167c0ddfc21c5c67
amd64 sha256:cc3b7a5bd4b2514b404640cfeabef4ef4ab5a64592d56dc7968a9ab4ae83820c
arm64 sha256:56a7dd8307a2f1d6b52cda162afaf42063d6c38eda880108cc32ac5c4fa1f81f
```

The anonymous registry index bytes and both platform manifests were reverified
before building. Current maintainer [image availability](https://github.com/GoogleContainerTools/distroless#what-images-are-available)
and [support policy](https://github.com/GoogleContainerTools/distroless/blob/main/SUPPORT_POLICY.md)
identify Debian 13 as supported and other tags as deprecated/no longer updated.
This approval supersedes the earlier Debian 12 hold. Maintainer
[base contents](https://github.com/GoogleContainerTools/distroless/blob/main/base/README.md)
justify retaining libc while removing unused OpenSSL.

Cosign **3.1.4**, downloaded only to a task-specific `/tmp` directory after
[release](https://github.com/sigstore/cosign/releases/tag/v3.1.4), checksum and
[verification API](https://docs.sigstore.dev/cosign/verifying/verify/) checks,
verified the exact index with issuer `https://accounts.google.com` and identity
`keyless@distroless.iam.gserviceaccount.com`. Exit 0; certificate trust,
transparency-log inclusion and image claims were verified without bypass flags.
The Darwin arm64 tool hash is
`9f9b8cd557cf2e5b3df3373a00baa005a86b02391e3e06dd0ce37b3a1533d3a4`.
No global install, application dependency or tool configuration changed.

The existing Go **1.27.3** builder/index `2920bb124f1a2e12a1d39f0cab756ae0068441ee1da7655dec7f5e374944095b`
and build commands are unchanged. Extracted binaries prove linux/amd64,
CGO_ENABLED=1, `/lib64/ld-linux-x86-64.so.2`, direct dependency `libc.so.6`
only, and maximum required GLIBC symbol version 2.34. No resolver/CGO switch.

## Behavior and actual checks

Explicit `USER 65532:65532` applies to both final images. Copying the executable
to its absolute destination before `WORKDIR` preserves root-owned mode-0755
`/app` and binaries. Legacy templates remain root-owned, readable and byte-identical.
The base retains a sticky mode-1777 `/tmp`, CA certificates and timezone data.

The new shared `internal/healthcheck` mode runs before DB setup. It sends exactly
one GET to `127.0.0.1:8080/health` or `:8081/health`, requires HTTP 200 and the
established service JSON status, rejects redirects and proxy inheritance, and
bounds the whole request to two seconds and the body to 4096 bytes. Exit 0/1
has no diagnostic output. Docker uses the same executable in exec form: 30-second
interval, three-second timeout, ten-second start period, three retries. No helper
packages, third production binary, shell or background poller were added.

| Affected check | Actual result |
|---|---|
| CI format, `go build ./...`, `go vet ./...` | Exit 0 each |
| `go test -race -json ./...` | 110 top-level / 333 leaf cases pass, zero failed/skipped; four packages have no tests |
| `go test -race -tags=integration -json ./internal/tab` | 52 top-level / 157 leaf cases pass, including 16 PostgreSQL-specific leaf cases; zero failed/skipped |
| Final `go test -race -json ./internal/healthcheck` after expanding executable cases | 5 top-level / 27 leaf cases pass; zero failed/skipped. The broader run already passed the unchanged 316 other leaf cases; no redundant broad rerun |
| Both exact Docker builds, `--pull --no-cache --platform linux/amd64` | Exit 0; final image identities below |
| Seven control-removal checks via Go overlays in this checkout | All seven induce expected test failures: status code, status text, body bound, deadline, redirect and each startup dispatch |
| Real nonroot container journey | 20 recorded checks pass, zero failed/skipped; diagnostics include the assertions below |

Lasting tests run each real executable with no `DB_*` configuration against
healthy, non-200, malformed, oversized, redirect and timeout endpoints, then a
closed endpoint; default invocation still reaches DB initialization. Unit tests
also cover wrong/missing/null status, invalid field type, trailing JSON, header
and body stalls, and single-request behavior. Overlay files leave tracked sources
unchanged. `GOFLAGS` propagates dispatch overlays to the tests' child Go builds.

The container journey used unique labelled containers/network, a disposable
PostgreSQL **17.11** data filesystem and synthetic CA/server certificates. Both
default commands booted, connected through DNS to the PostgreSQL alias with
`verify-full` and a readable mounted root CA, and reached Docker **healthy**
using their unchanged image probe configuration. Server `pg_stat_ssl` confirmed
both application connections encrypted. API create/read, absent-token denial,
authorized legacy HTML rendering and legacy absent-token denial passed.

A test-only read-only mounted Go diagnostic executable, built with the existing
toolchain/dependencies, checked each exact running image: process/diagnostic
UID/GID 65532, DNS, trusted PostgreSQL TLS, rejection of an unrelated CA and wrong
hostname, system CA verification of `https://example.com/`, New York winter/summer
offsets and database timezone, read-only root/application writes denied, owned
sticky `/tmp` writable, and template readability. It is absent from final images.
Tests used `--read-only`, dropped all capabilities and enabled no-new-privileges.
All owned containers, network, databases and certificates were removed; the
shared `127.0.0.1:51168` fixture remains running.

## Image/package identities and security

Docker-reported `.Size` bytes are a consistent local metric, not a portable
uncompressed-size definition. Before images are preserved dependency-phase
builds, predating later authorization corrections; their Dockerfile/base match
this task's starting runtime. Bytes are an observed comparison, not an isolated
same-source size benchmark. No fresh child checkout was created.

| Image | Before image ID | Before bytes | Final image ID | Final bytes |
|---|---|---:|---|---:|
| bill | `1250a665d84c27ca56a741e7ea11f1b76a008a98869a03f4767a107cdc1da19a` | 28,344,050 | `e803faca8fb9bf7b396dfbe3fc5e5cac4edbd040416666c837760ce8a5032236` | 26,111,040 |
| legacy web | `a15e98abe6bed09881524284235182c6d0845069379b592cb6d18b38edea2b25` | 27,789,661 | `e3b39822844184bfcd3088dbaf115f43daccb63cb12b361720b1ec6af9ea0cf9` | 25,962,187 |

Final binary SHA-256: bill
`3f263e74fc59208e424a50c3c6d9d119395c196fff163a7b4bfefe2c90f7b8b8`;
web `e3e644ba8928b2be8c033ca2540c041b935c49d31ed2a49cea8ec0f6f8dce2a1`.
Both before and after have **seven OS packages**. After removes libssl3 and adds
tzdata-legacy: libc6 **2.41-12+deb13u4**, CA certificates **20250419+deb13u1**,
tzdata/tzdata-legacy **2026f-0+deb13u1**, plus base-files, media-types and netbase.
Trivy additionally inventories 31 bill / 30 web Go-package records.

Trivy **0.76.1**, disposable image index
`790fd66d1697395d8693d1acaa1ea702406a20f109b6fc7bac8db623eca6c06c`,
scanned the before/final Dockerfiles and exact saved final images without
suppressions. Each final Dockerfile has **27 successes, zero failures**; each
before file has 25 successes plus root HIGH and no-HEALTHCHECK LOW. The combined
before/after command exits 1 because the before findings remain in that report.

Each final built-image scan exits **1**: **0 CRITICAL, 0 HIGH, 14 MEDIUM, 8 LOW,
3 UNKNOWN**, versus before **1 HIGH, 22 MEDIUM, 14 LOW, 7 UNKNOWN**. All 22 OS
findings are in libc6 with no scanner fixed version. No libssl package remains.
The three module records are GO-2026-5932 (`x/crypto` openpgp),
CVE-2026-78661 / GO-2026-6860 and CVE-2026-97045 / GO-2026-6866 (`x/net` html).
The last two have a reported fixed version 0.62.0; module upgrades are outside
this approved scope. Pinned govulncheck exits 0: zero imported-package or reachable
symbol findings, three required-module findings. This limits demonstrated
reachability; it does not erase package findings or establish live exploitability.

Gitleaks **8.30.1**, redaction enabled and ignore comments disabled, found one
existing documentation placeholder in the full-file scan, byte-identical to base
line 190 in `docs/technical-overview.md`: zero confirmed secrets and no new-hunk
candidate. The raw exit-1 report and location-only triage remain visible, with no
suppression added. Semgrep **1.183.0** (metrics/version checks off, local
rules) and gosec **2.30.0** scanned the changed source without suppressions or
uploading source. Manual triage found zero introduced security defects: six final
test-fixture/exec candidates use only fixed local inputs, and two existing HTTP
listener candidates are unchanged. Gosec's two MEDIUM G114 listener-deadline
findings remain tracked by BUG-1793644507; hosting TLS termination is unverified.
No entry-point hardening or unrelated refactor was folded into this change.

## Limits and handoff

**Local gate RED, scope=affected, clean=no; security gate FAIL** for retained
unsuppressed findings. No passing test suite failed or skipped. The test-only
diagnostic's initial compile error and unsupported Docker process-list formatting
were corrected; its first failed journey and successful final run are both retained.
An initial dispatch-overlay experiment did not propagate into child builds; the
corrected GOFLAGS check proves both guards. The ownership adjustment required a
second pair of builds/scans; original results are retained rather than overwritten.

Raw records: `.vv/local-gate/runtime-lock/`, including source/binary/image hashes,
package/filesystem inventories, signature output, scanner reports and command
result JSON. The task scratch directory retains the QA orchestration scripts.
These are mutable local records, not independent clean-snapshot attestations.
The driver owns fresh committed-snapshot acceptance and independent review.
Arm64 manifests exist; only linux/amd64 behavior was executed on an arm64 daemon.
Docker health is liveness, not ongoing DB readiness or actual hosting health
configuration. No Render/Vercel identity, production mount compatibility,
promotion/rollback, signed iOS journey, deployment or external-alert closure was
established. Existing runtime-injected commit values are not binary provenance.
Both new tickets remain in-progress; no global gate, auth state or CHANGELOG
migration was advanced. Frozen baseline, historical reviews and unrelated files
are preserved.
