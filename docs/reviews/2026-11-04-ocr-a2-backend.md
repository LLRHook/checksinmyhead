# Backend OCR safeguards — November 4, 2026

Source **34bc4154b2ec8f067bbc371d92adebb5d9a58e79**, base
fd26598566b6662f8ce68841221c2e94c182ecb0. Source-writer local execution,
**clean=no**; independent clean/integrated acceptance pending. A2a only: mobile A2b,
durable allowance B and hosted/provider acceptance are not completed. Existing
maximum JSON latency and global security/release gates remain **RED**.

`internal/receipt` owns a single policy: default 2 nonwaiting slots (1–8), 40s
operation before upload, provider 30s with earlier caller/socket deadlines winning;
10 admissions/60s per normalized peer, 4096 keys, fixed ten timestamps, admission
pruning and a joined 15s sweeper. Invalid admitted images stay charged; denials do
not allocate peer state or extend expiry. Total multipart 10 MiB includes boundaries;
streaming/no disk or pixel decode, 32 parts, 16 KiB/64 parsed headers, duplicate image
400 and excess 413. Rejection reuses the accepted safehttp read-deadline helper.

The fixed HTTPS endpoint, claude-sonnet-5-5, 4096 output tokens, schema and prompt
remain. A verified-TLS HTTP/1 private pool is bounded by scan slots. Nonempty bodies
have GetBody=nil, no idempotency/inbound headers, no automatic rescan/replay.
Redirect targets are discarded before client parsing; every non200 body closes
without reading/draining error content. Native request body closure and completed
write callbacks are joined even for early responses. Deadline is rechecked after
cleanup. Success cap+1 reads are 2 MiB decoded / 512 KiB text; token/shape/quantity
preflight rejects excess without clamping or partial results. Finite errors retain
no raw cause/content/URL/key/Location; bounded Retry-After preserves long waits by
omitting rather than shortening the header. API fields/money/currency semantics stay.

## Executed local evidence

- 1,093 distinct maintained Go leaves: ordinary **836**, PG **721**, overlap **464**;
  all prior **960** IDs preserved, failed/skipped/cached/missing terminals **0**.
  Ordinary readiness/web package events have no test files; these are not skipped
  cases. The PG row retains all eight packages. OCR rejections issue **0** SQL;
  health issues **1**. Provider success is exercised through the private TLS seam,
  without a database dependency, rather than sending a real inference request.
- Go 1.27.3 build, ordinary/tagged/a2perf vet, literal CI formatting and pinned
  govulncheck exit **0**. Full matrix repeated only after the native-writer/cleanup
  fixes. No unchanged Flutter/web suite rerun; receipt field structs/schema hash
  unchanged, existing ten mobile-creation contracts preserved in the Go/PG rows.
- Exact pinned before overlay: **8** assertion failures / **4** valid controls.
  Additional before failures expose early-returning native writer and cancellation
  during cleanup; both pass final. Nine final guard-removal experiments execute
  **10** failed leaf assertions / **1** at-limit control (no compile failures in
  counted experiments). The initial redirect mutant's nil-body GET panic is retained
  but excluded; the corrected negative overlay normalizes only that counterfactual
  HTTP GET to NoBody so the redirect acceptance assertion actually executes.
- Both final static images, base signature verification and existing **75** runtime
  checks pass; fixture resources cleaned. Trivy images/Dockerfiles **0** findings,
  gosec **0** findings/errors. Unsuppressed Semgrep raw exit **1**, **7** candidates:
  synthetic TLS JSON/adversarial response writes, no user HTML sink. Gitleaks raw
  exit **1**, **3** existing documentation placeholders. Confirmed **0**, suppressions
  **0**; raw nonzero exits remain nonzero.
- **414** exact task-owned PG schemas absent (207 in final row), shared fixture
  retained, normal volumes preserved, all **336** original files hash-identical.

Initial compile/setup mistakes, a malformed-body fixture correction, the upload
measurement's loopback-quota fixture correction, weak initial redirect removal,
and all preliminary samples/failed controls remain in ignored evidence. They are
not counted as product failures or silently discarded. The legacy TestTruncate ID
now checks finite errors; the obsolete raw receipt excerpt helper is removed.

## Qualified measurements

Go 1.27.3 / darwin-arm64, 10 CPUs/GOMAXPROCS 10; no competing heavy gate/build/scan
load during timed measurements. Each of 12 paths has **3 × 100** samples after
**5 warmups per run** (3,600 timed samples); local synthetic providers only.

| Path | Three p95s, ms | Target |
|---|---|---|
| Maximum total upload + prep/parse, maximum response/text | 12.991292/12.927000/13.378375 | <250 |
| Representative upload + maximum response/text | 6.226375/6.055291/6.159083 | <250 |
| Maximum receipt parse | 2.099083/2.053791/2.033791 | <250 |
| Full-table existing-peer admission | 0.056167/0.066875/0.076666 | <5 |
| Full-table new-peer rejection | 0.068083/0.066250/0.057750 | <5 |

Observed cancellation maxima: provider **0.088750 ms**,
actual blocking upload/permit **0.024041 ms**,
both <=250 ms. All qualified OCR targets met. Go HTTP/1 transport StateClosed has a
separately observed fixed RST-avoidance wait, max **502.216750 ms**:
actual reads/callbacks/permit had already exited. No <250ms socket-closure claim.

Limiter retained heap **1,397,512 bytes** (<2 MiB). Actual local TLS bursts:
1/2-slot sampled incremental heap **38,426,240 / 70,946,680 bytes**;
cumulative burst allocations **53,818,904 / 107,689,336 bytes**,
a conservative allocation upper bound below 80/160 MiB. Samples are not continuous
true peaks. Process RSS high-water ended at **122,552,320 bytes**;
not per-request retained memory or host capacity. PRE-burst comparison, intact 75s
idle/two GCs with fixtures kept alive: **-273,632 bytes**, goroutines
**7 → 7**. Deliberately held I/O/provider time is excluded from prep/parse timing.
Unchanged maximum assignment harness not rerun/altered; its known 10ms miss remains.

## Artifacts and replay

Follow [the living procedure](../backend-ocr-verification.md), the maintained
[verification matrix](../../VERIFICATION.md), [API](../backend-api.md#post-apireceiptsparse)
and [architecture](../technical-overview.md#anthropic-claude-for-receipt-ocr).
Scratch-relative ignored evidence is `ocr-a2-backend/`; raw samples/IDs/profile input
bindings stay there, not duplicated here. Exact commands/exits are in run_gates.py,
gates.json, final-controls.json, image-builds.json and scanner results. Before-state
production is supplied by git-show/-overlay at the immutable base, no checkout.

| Evidence | SHA-256 |
|---|---|
| Final 120 Go/module input bindings | `b6b3787b4bf6071cef3c47fe76734b43185c17d64d4ab82872ce1a5d4e0e5994` |
| Final raw measurement record | `d1377e77823a494b7ae7b73cfe0686fc8bdf21819a5e897b07422381c653685d` |
| Final maintained counts | `b2edd8cc68aecdcd98447e2a4f8dde99627e6920a73b1f71dd807d6328f66584` |
| Final native runtime result | `18e6ef537f17afea2ac91f49d9a4d9fe1dcd1e13bc7d252b013db6f605f7ab70` |

Bill image `sha256:35a16d56deee2b8ad91feec9938e006c76e2b607a34add70e69e16a973b93d0f`, archive
`ce416b569647be375e092375a391c07ef0f5d4bedb58b7c15785cc7a41b918c2`; executable
`a401f4e3d1508ab1928d06a26538c2194e5085de3e27a0581267a66ef12305f1`.
Web image `sha256:db2019fde68245a2751e44ce836b2574fcc01a86871c492198aba519b4cdd58b`, archive
`4eed6ce3e376bec66f7354083078cd542192d6bae9b9ee6a57ef83592b96725f`; executable
`939e2c5f11fdd1f5e7eab36ca02ae847503fb61948db6a9c73506b1469212895`. Signature verifies the pinned distroless base,
not a signature/provenance claim for final images. Local dirty-tree build association
is retained; root owns independent committed/clean verification.

HTTP/JSON correction review at fd26598 remains scoped APPROVE (Standards0/Spec0,
reviewer execution NOT RUN). BUG-1793644507 remains in progress for known performance
and remaining scope; 4508 remains in progress for B; 5850 awaits independent driver
acceptance. No CHANGELOG migration, new grade, schema, dependency, provider/account,
hosting/deploy, real inference, publication or mobile change. Pre-existing field/name/
quantity and security-description doc drift remains under BUG-1793644512.
