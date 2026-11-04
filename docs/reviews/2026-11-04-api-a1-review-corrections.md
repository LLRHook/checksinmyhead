# A1 rejected-body and peer-identity corrections — November 4, 2026

Source: `4ffdeee2067777199f94b240d5053f4ce2943f8e`, based on
`8d5b7a162dab6652485b050987a8a5e699e2f536`. The driver implemented the two P2
findings from the independent `6e03e48 → 740dab8` A1 review after the optimization
lead returned its sole-writer lease. Scoped correctness passes; independent
correction review, performance and whole security/integrated/release acceptance
remain open. No overall A1 approval or new product grade.

## Behavior and source scope

`DecodeJSON` now expires body-read deadlines on every error, after stopping/joining
its cancellation callback. The shared mutation gate applies the same rejection
boundary before refusing or aborting a request with a body. HTTP/1 adds
`Connection: close`; the expired deadline also prevents post-handler body-close
work from waiting for a missing remainder. A close header alone was insufficient.
HTTP/2 uses its stream deadline without the HTTP/1 header. Finite statuses, generic
errors, size classification, CORS/Retry-After, gate ownership and valid keep-alive
behavior remain covered. This does not claim zero kernel buffering, zero attempted
reads, universal socket admission or cancellation of arbitrary context-free work.

Forwarded-IP normalization canonicalizes each valid token, including mapped IPv4,
while retaining invalid/empty tokens and their order. Gin still selects right to
left under the configured trust policy and falls back to the socket if it reaches
an invalid hop. An unused malformed left prefix no longer disables normalization
of a valid selected suffix. Trust-none remains the default; no hosted topology is
inferred.

Seven source/test/living-doc paths changed: `pkg/safehttp/{json,router}.go`,
`cmd/bill-service/a1_review_test.go`, `cmd/web-service/a1_test.go`, backend README,
API documentation and technical overview. No dependency, migration, schema,
financial, identity, OCR, mobile, web-client or publication code changed.

The driver inspected the pinned application and installed Go/Gin source before
implementation. Relevant primary code:
[Go server](https://github.com/golang/go/blob/go1.27.3/src/net/http/server.go),
[Go body close](https://github.com/golang/go/blob/go1.27.3/src/net/http/transfer.go),
[Gin selection](https://github.com/gin-gonic/gin/blob/v1.12.0/gin.go).

## Executed regressions and controls

Against unchanged production inputs at `8d5b7a1`, the new API tests produced
**15 expected failing leaves and 9 passing controls**. Eight failures observe
stalled oversized/malformed/second-document/chunked/saturated requests over real
TCP; seven observe malformed-left-prefix peer identities. The Expect control
received headers but still caught stalled transport cleanup. Tests observe both
response delivery and connection completion, without completing the missing body.

After correction, **28 focused leaves pass**, including both actual router
constructors, default-policy net/http TCP, valid HTTP/1 keep-alive and a real TLS
HTTP/2 rejection/follow-up control. The latter is a local compatibility fixture,
not a production TLS or same-connection multiplexing certification.

Three independently executed owned overlays fail the intended assertions:

| Removed protection | Failed leaf executions | Passing controls |
|---|---:|---:|
| Read deadline removed, close header retained | 8 | 0 |
| Gate rejection stop removed | 2 | 0 |
| Original all-or-nothing normalizer restored | 9 | 9 |

The 19 failures overlap across controls; they are not 19 additional maintained
tests. No compile/setup failure is counted as a removal proof. An initial
post-fix EOF-only test assertion rejected a legitimate TCP reset after the complete
finite response. The assertion was corrected to accept EOF or reset; its failed
run is retained. Final maintained rows passed without a failed-test rerun.

## Affected local gate

Go 1.27.3, shared checkout, **clean=no**. The source commit matches all **109**
recorded Go/module test inputs. CI commands remain authoritative; test commands
add uncached execution and JSON reporting for case/skip accounting.

| Command, backend directory | Roots | Leaves | Failed/skipped |
|---|---:|---:|---:|
| `go test -race -count=1 -json ./...` | 161 | 708 | 0/0 |
| Maintained eight-package integration selection, `-race -count=1 -tags=integration -json` | 162 | 716 | 0/0 |

The second command selects `./cmd/bill-service ./internal/bill ./internal/tab
./pkg/database ./migrations ./internal/startup ./internal/readiness
./internal/testpostgres`. Overlap is 464; the union is **960 distinct leaves**,
preserving all 932 optimization cases and adding 28. Zero cached results,
duplicate runs, missing terminals or failed packages. Ordinary no-test package
events are not skipped test cases. Build, ordinary/tagged vet, literal CI format
check and pinned `govulncheck@v1.7.0` pass; no reported Go vulnerabilities.
Unchanged Flutter/web/release suites were not rerun for this Go-only correction.

Both static linux/amd64 images were rebuilt; the pinned base signature verified,
and the existing runtime journey passes **75 checks**, zero failures. Docker IDs:

- Bill: `sha256:024b146dc5f0db0bf41238df10e9fe6ca6edec320f1cc7b7dfdfc56f70af3055`.
- Web: `sha256:4c853bba2905b240350c168338b3603bdbbb74cc34ab92d4faf294f9788c48a3`.

Trivy exact-image archives and Dockerfile scans report zero findings without
suppression. Scoped Semgrep/gosec report zero findings/errors. Gitleaks exits 1
with five candidates: two synthetic test literals and three documentation
parameter placeholders, individually triaged as zero usable credentials and zero
suppressions. Its nonzero exit is retained. Runtime artifact `bytes` fields are
inherited image-size metadata, not executable lengths; binary hashes remain bound.

## Evidence, cleanup and limits

Raw artifacts are retained outside tracked source in this task's
`api-a1-review-correction/`: before/focused logs and input hashes, controls and
overlays, exact commands/exits, runner IDs/counts, source bindings, signature/build
logs, saved images/scans/runtime results and cleanup. `evidence-bindings.json`
hashes 24 records; full samples/IDs are not duplicated into this note. The complete
path is recorded in the driver handoff in the task scratch directory.

All **206 exact task-owned schemas are absent**; shared PostgreSQL remains running.
Runtime-owned containers/networks/certificates were removed; normal volumes were
preserved. All **336 original files** match the original manifest.

Doc impact: five maintained documents searched. Backend README, API and technical
overview now describe rejection cleanup and invalid-hop preservation; root README
and VERIFICATION need no changed command/limit. VERIFICATION remains 20,478 bytes.
Dated baseline/A1/optimization evidence and CHANGELOG remain unchanged. Existing
currency/security-description drift belongs to BUG-1793644512, outside this repair.

Known 50,000-assignment p95 misses at the optimization pin remain **RED**; no budget,
payload, sampling rule or collection limit was waived. These transport fixes do
not establish a fresh full performance measurement. Independent review, clean
committed-snapshot/integrated/device/provider/public-binary validation and remaining
OCR/save/replay/identity/precision work remain outstanding. No hosting control-plane,
production database, deployment, publication, main/mirror/tag or merge action occurred.
