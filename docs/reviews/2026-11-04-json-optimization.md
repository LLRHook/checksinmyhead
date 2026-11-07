# Bounded JSON optimization — November 4, 2026

Source `1932dedbaca5e5ec9d68ba2c5fe88c11663859aa`, parent `740dab8bf97f44ce5d38f93c6e59730a753b009a`.
Reserved shared-checkout execution, **clean=no**. Affected correctness passes;
**performance acceptance remains RED**. Root owns clean QA, independent acceptance
and public post-push checks. Whole A1/security/integrated/release acceptance remains
open; B+/A− is a target. Driver-reported A1 review P2s (net/http rejected-body drain
outside the handler/gate and malformed-left-XFF mapped-IP normalization) are separate
root corrections after handback, not implemented or independently verified here.
`router.go` is unchanged.

## Profile, change and limits

Before editing, a quiet actual production router→decoder/DTO→handler loop at740dab8
reproduced the maximum50,000-assignment miss: p95 **34.212/35.266/34.757ms**, about
41.25MB allocated/request. Original A1 misses **55.217/58.208/80.263ms** and one
minimal-array rejection5.380ms remain unchanged in [the A1 report](2026-11-04-api-a1.md).
No claim is made that concurrent load caused those older misses.

Pinned Go1.27.3 allocation profiles attribute59.48% of original allocated bytes to
JSON decoder buffer fetch,8.91% to reflect slice growth and about7.05% to regexp
replacement paths. CPU samples include31.26% `runtime.madvise` and repeated JSON
scans. These are whole-process profile shares, not per-request wall-time fractions.

Two production changes:

- `pkg/safehttp/json.go` keeps the existing element-count guard **before** typed
  allocation, then reserves bounded capacity. Non-strict DTOs receive one complete
  validated value through `UnmarshalJSON`; stdlib `json.Unmarshal` avoids another
  streaming buffer. Strict arrays retain `Decoder.DisallowUnknownFields`, including
  nested fields. Outer bytes/EOF/cancellation/errors/admission are unchanged.
- `pkg/security/sanitize.go` skips regexp replacement copies only when no `<` exists,
  making a tag match impossible. Otherwise the same package-global `<[^>]*>` regexp
  runs; Go `TrimSpace` and FEFF semantics stay. The regexp was never compiled per call.

Array-only p95=29.296–30.003ms/allocation21.99MB; adding the sanitizer fast path
reaches18.71MB. A measured `bytes.Buffer` candidate was discarded (p9531.431–31.969ms):
the pinned compatibility decoder deliberately hides that specialization. Raw probes
and setup errors remain. No cache/name memoization, new parser/framework/dependency,
unsafe code, contract/limit/price change or GC/GOMAXPROCS/experiment setting was added.

## Final intact original harness

Both original a1perf harness files are byte-identical to740dab8. Three runs×100
samples/path, ten separate warmups/path; actual constructors and transformations,
injected services,0SQL/provider calls. One test process at a time, normal desktop
activity/idle shared PG, no own PG/race/image/scanner work during timing. Root confirmed
only low-load source inspection. Exact environment and source/payload bindings remain
local. Short feedback/profile overlays omit only the75s wait; their retention metadata
is **not qualified proof**. Final retention uses the untouched original75s wait.

| Path | Bytes | p95 ms, runs1/2/3 | Target ms | Result |
| --- | ---: | ---: | ---: | --- |
| normal_tab | 45 | 0.007 / 0.007 / 0.007 | 10 | PASS |
| max_tab_bytes | 16384 | 0.021 / 0.025 / 0.059 | 10 | PASS |
| max_creation_5000 | 201051 | 2.828 / 2.914 / 3.124 | 10 | PASS |
| max_mutation_50000 | 2815905 | 27.033 / 27.143 / 27.420 | 10 | **MISS** |
| reject_tab_bytes_known | 16385 | 0.004 / 0.010 / 0.011 | 5 | PASS |
| reject_tab_bytes_streamed | 16385 | 0.043 / 0.015 / 0.027 | 5 | PASS |
| reject_creation_minimal_array | 50045 | 0.165 / 0.130 / 0.169 | 5 | PASS |
| reject_mutation_minimal_array | 180013 | 1.156 / 1.134 / 1.193 | 5 | PASS |
| reject_syntax | 1 | 0.003 / 0.003 / 0.003 | 5 | PASS |

Maximum mutation allocates18.713MB/request, about55% less than the equivalent41.25MB
baseline; p95 is about21–23% lower but still2.7× the10ms target. Creation allocates
3.573MB/request. All median/p95/max/allocation counts/raw samples are retained locally;
a separate acceptance reader exits1 on baseline and final, preserving all three misses.
No target, input, timer boundary or sampling definition changed.

Eight-way max: live heap75,164,696bytes (71.68MiB), process high-water RSS116,064,256bytes
(110.69MiB), both below256MiB; cumulative allocation149,635,312bytes is not live memory.
Two GCs/75s idle/two GCs: retained heap delta−3,264,624bytes, goroutines2→2, within4MiB/
fixed target. Saturation p950.005875/0.005083/0.015375ms; observed-cancel release maximum
0.208542ms/300samples, within5ms/250ms targets. Maintained real-TCP cancellation passes.
No PaaS/socket/DDoS/deployed-capacity claim follows.

Final CPU profile still has61.26% cumulative outer-array and43.38% nested-array
stacks (overlapping), dominated by JSON string/object/value scans. Buffer fetch remains
46.34% of allocation, largely outer bounded streaming decode; model-copy allocations
remain27.36%. The retained small stdlib changes do not meet10ms.

Driver-review alternatives, **not implemented or promised to meet10ms**:

1. Stdlib token/preflight counting plus one typed content decode, reducing repeated
   nested value scans. Must preserve case/escapes/duplicate arrays (including earlier
   oversize values), ignored unknown graphs, strict creation and preallocation guards.
   This adds parsing-policy complexity and needs dedicated differential/removal review;
   no custom grammar or target relaxation.
2. A content-only internal assignment representation across the service seam to reduce
   simultaneous DTO/model copies. This changes an architecture contract and requires
   concrete driver review; repository authority/financial checks must remain.

## Executed verification

Local gate: GREEN scope=affected clean=no source=1932ded.

| Selection, backend cwd | Roots | Leaves | Fail/skip/cache/missing |
| --- | ---: | ---: | --- |
| `go test -race -count=1 -json ./...` |156|680|0/0/0/0|
| `go test -race -count=1 -tags=integration -json ./cmd/bill-service ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres` |158|692|0/0/0/0|

440overlap/932distinct; all845original cases preserved,87added. Ordinary readiness/web
package events mean no ordinary tests, not skipped cases. Full IDs/terminals/set-diff
remain local. Two optional measurement roots record3300samples, not3300tests.
Compatibility selection89leaves (includes two existing allocation-control leaves)
passes final source and immutable original production files via owned Go overlays.
Actual standalone/attached router checks cover escaped/case/duplicate/null/unknown
fields, normalized duplicate names, finite numbers, malformed/trailing/count errors
with no service call, and500×100full positive command contents. Sanitation additionally
checks2048seeded byte/Unicode inputs against the old regexp+TrimSpace contract.
Existing real HTTP→PG strict/max-valid/no-write/auth/accounting rows pass.

Removing the count guard in an owned overlay gives one expected failed over-limit
leaf (`typed values=3 decodes=3 error=<nil>`) and one passing at-limit control. Exit1
is assertion falsification, not compilation/setup failure; shared source was unchanged.
No application test failed or needed a rerun. CI build/vet/format, maintained tagged
vet, a1perf-tag vet and pinned `govulncheck@v1.7.0` pass. No unchanged Flutter/web/
release rerun or fresh cross-tier/integrated result is claimed.

Both linux/amd64 static images rebuilt from exact tested production/module inputs;
all75runtime checks pass,0failures/skips, owned resources cleaned. Existing cosign3.1.4
verified the signed static-debian13 base using standard issuer/subject. Image/binary/
archive/buildinfo bindings remain local. Shared-checkout VCS metadata is not independent
committed provenance; no hosted resolver/artifact identity claim.

- bill: `sha256:1dfa20c4519c75fbcde98bd44704778c9bcc79869098326a305370b9d4c15f0e`
- web: `sha256:467f76fe1c5b46e6a1c31750fb57b1650aa44eb3467b17b46e87eef41a83a94d`

Unsuppressed Trivy0.76.1 exact archives/Dockerfiles:0findings/exit0. Gitleaks8.30.1:
0candidates/exit0; gosec2.30.0:0findings/errors/exit0. Semgrep1.183.0 raw exit1/one
candidate/no errors: `math/rand` in the deterministic **test only**, generating no
capability/key/nonce. Explicitly triaged0security defects,0suppressions; no warning/check
disabled. Source scope, rules, raw finding and triage remain; raw exit1 is not called0.

All206exact observed owned PG schemas checked absent; shared fixture1577f8dd… remains
running, normal volumes untouched. Runtime-owned resources/certificates cleaned. All336
original files match baseline, including ignored Android/artifacts. VERIFICATION remains
20,478bytes. No schema/migration/lock/.github/OCR/mobile/web/hosting/account/provider
inference change, alternate checkout/subagent/history rewrite or main/mirror/tag/merge/
store action. Normal source feature-branch publication only.

Doc impact: six tracked living candidates searched for4507/JSON/array/sanitization;
existing contracts/ownership/limits stay accurate, no living text changes needed. Only
this dated note adds evidence; old reports stay immutable. A pre-existing positive-only
USD-fallback sentence in technical-overview is reported to root for currency/docs
reconciliation outside this4507-only tracker scope. Official writer updates only4507
Fix/Docs/evidence, keeping in-progress; other tickets/CHANGELOG/frozen baseline unchanged.

## Reproduction and bindings

Raw directory: `/Users/victorivanov/.t3/scratch/2026-11-02-do-you-see-the-checks-a3e558c7/api-json-optimization`. Retained `run.py`, `run_gates.py`, `run_images.py`, `image_scans.py`,
`run_scans.py`, `count-report.py`, `perf_accept.py` record exact argv/exits/durations/
source hashes/logs. No new tracked raw-sample or test-ID dump. Final measurement recipe:

```sh
A1_MEASURE_OUTPUT=/absolute/final.json A1_ADMISSION_MEASURE_OUTPUT=/absolute/admission.json \
  go test -count=1 -tags=a1perf -json -run '^TestA1(JSON|Admission)Measurements$' ./cmd/bill-service
```

`short-overlay.json` maps the unchanged measurement file to a copy removing only75s
wait; same loop at740dab8/final with `-overlay=... -run '^TestA1JSONMeasurements$'
-cpuprofile=... -memprofile=... -o ...` supplies profiles. `original-source-overlay.json`
restores the two production files from740dab8 for compatibility only. Payload overlay
adds an early export return before warmup/timing; nine original body byte/hash bindings
are in `payload-sha256.json`. No measurement definitions change.

| Raw artifact | SHA-256 |
| --- | --- |
| `baseline.cpu.pprof` | `8bd0fe66a61199b8bb71b62fd50db71a2f865c798a20f3a2a9415bd7400ecb29` |
| `baseline.alloc.pprof` | `05e66fcea3da9cec2c4fd89c86901e2dac599b820df778a6f79a558a21785c5a` |
| `final.cpu.pprof` | `f1abaeef8ca2430fba99dafc5ae40264ea134555b9ae1f92483dae8f5c01d02b` |
| `final.alloc.pprof` | `4f183bb3b3322608a1b4d18675722fd54a75ef816407bb77d1fff43cf4956234` |
| `baseline-short-valid.json` | `350662272ec70b74d555500e41569fcb8efb202e0f102b6cada0fcd05f8b1e41` |
| `final-original-harness.json` | `5777c716e31ab68cb7060b7f27003140e59a21079a75909a226e58839d47847f` |
| `final-admission.json` | `bad749a50d9d9fd017327c6f9f875b692155b8aced7b161a20f1a72117a9e186` |
| `payload-sha256.json` | `45ed9b68a977d349ca2cae16ff5b4749ba255c5ac2abb24fb11d1da814dafb10` |
| `test-ids.json` | `8e231ef881a531817e32accd70e27cc3da31affa6268a29697dbb1603b2ef2ac` |

`evidence-bindings.json` additionally binds counts/source maps/cleanup/scans/runtime.
Effective/stored author AND committer checked as Victor Ivanov
<victor.n.ivanov@gmail.com> for every commit. Feature-branch push, immediate PR159 link
and independent remote proof follow. CI/reviews/public checks are NOT RUN by lead;
root owns P2/performance/clean/review/host acceptance. Whole acceptance remains RED.
