# Assignment update decode — November 9, 2026

BUG-1793644507. Base `f76b7b9`, branch `sweep/abuse-bounds`. The maximum name-based
assignment update (500 updates of 100 assignments, 2,815,905 bytes) now meets its
10 ms p95 target on the measuring machine. The target, input, sample count,
percentile and both `a1perf` harness files are unchanged (`a1_perf_test.go`
`6864caab…c1f14b`, `a1_admission_perf_test.go` `57f32bd2…7db3c`, identical to the
base). No budget or limit was waived.

Machine: Apple M4, 10 cores, 24 GiB, macOS 26.6.2, Go 1.27.3 darwin/arm64. It was
not idle: the one-minute load average was 2.3 to 8.9 during the runs below.

## Measurement

Recipe from `backend/README.md`, three runs of 100 samples after ten warmups, p95 is
the 95th ordered sample:

```sh
A1_MEASURE_OUTPUT=<file> A1_ADMISSION_MEASURE_OUTPUT=<file> \
  go test -count=1 -tags=a1perf -json -run '^TestA1(JSON|Admission)Measurements$' ./cmd/bill-service
```

| `max_mutation_50000` | p95 ms, runs 1/2/3 | median ms | max ms | MB/request | allocations/request |
| --- | --- | --- | --- | ---: | ---: |
| Recorded on November 4 | 27.033 / 27.143 / 27.420 | | | 18.71 | |
| Before, base today | 34.004 / 32.071 / 32.088 | 31.4 / 31.0 / 30.8 | 64.5 / 34.0 / 33.0 | 35.34 | 109,668 |
| After, first execution | 5.980 / 6.197 / 6.739 | 5.70 / 5.75 / 6.01 | 6.67 / 6.41 / 8.72 | 10.59 | 2,149 |
| After, second execution | 6.048 / 6.176 / 5.998 | 5.72 / 5.68 / 5.68 | 7.39 / 7.04 / 6.30 | 10.59 | 2,149 |

The other eight paths keep their targets in every run of both executions.
`reject_mutation_minimal_array` (60,000 empty updates) falls from 1.216 / 1.242 /
1.219 ms to 0.053 / 0.035 / 0.036 ms because the count is refused at update 501.
`max_creation_5000` is untouched code: 5.25 / 5.43 / 5.71 ms before, 5.15 / 5.16 /
5.70 ms after. Eight concurrent maximum updates hold 74.3 and 78.9 MB of live heap
(146.2 MB before; target 256 MiB), and the 75 s retention check passes with a heap
delta of −3.3 MB and 2 → 2 goroutines. All admission runs pass: saturation p95 at
most 0.018 ms against 5 ms, cancel release at most 0.042 ms against 250 ms.

Raw outputs stay in the ignored `.vv/sweep-abuse/` directory: before
`56a92230…552d1`, after `92aca49d…dffc` and `d887bebd…94fc`.

## Where the time went

Profile of the base with the harness loop (allocation sampling on, so shares rather
than wall time):

- The body was scanned about seven times: the decoder buffered and validated the
  whole document, each `UnmarshalJSON` collection had its value re-read by the
  decoder, counted by a hand loop and then decoded by `json.Unmarshal`, at both
  nesting levels. `jsontext` value scans were 21.6% of samples and the two count
  loops 11.1% flat.
- 45% of allocated bytes came from appending 128-byte `models.ItemAssignment`
  values to unsized slices, and 25% from the decoder growing one buffer to hold the
  2.8 MB document. `runtime.madvise` alone was 14.4% of samples.
- Validation built one map per item and one lowered string per name
  (50,000 allocations).

After the change one request spends about 3.9 ms decoding, 1.0 ms building the
command and 1.2 ms validating it (stage benchmarks on the same machine).

## Change

1. `safehttp.DecodeJSONStream` binds the document while reading it, using the
   standard library's `encoding/json/v2` decoder with the `encoding/json` v1 option
   set. Only legacy error reporting is turned off, which is what made the decoder
   buffer and pre-validate every value. Byte cap, single-document rule, cancellation
   and the two public errors are shared with `DecodeJSON`. `DecodeArrayFrom` stops
   at element limit+1 without reading further.
2. `AssignmentInputs` reads each assignment array once as a value the decoder has
   validated. An array in the plain shape (objects with exactly one `person_name`
   string and one `percentage` number, either order, no escapes, valid UTF-8, at
   most 100) is bound directly; names share one allocation. Any other array goes to
   the previous `safehttp.DecodeArray` path unchanged, so case-folded, escaped,
   duplicate, null, unknown, mistyped, out-of-range and over-count inputs keep the
   `encoding/json` result.
3. Command slices are sized once. Validation reuses one name set, takes one map
   operation per name and lowers ASCII names without allocating; other names still
   go through `strings.ToLower`.

**The strict participant-reference route is not faster.** Requests with
`X-Billington-Identity-Version: 2` still use the buffered decoder. The harness does
not measure that route. A one-off benchmark of the same 500 × 100 shape with
`participant_id` (a 1.86 MB body, not committed) took 26.2 to 27.2 ms and
21.0 MB per request, against 5.8 to 6.0 ms for `BenchmarkMaxAssignmentUpdate`. It
would miss a 10 ms target if one were applied to it.

`encoding/json/v2` and `jsontext` compile by default in Go 1.27.3 but sit behind its
`jsonv2` experiment. A build with `GOEXPERIMENT=nojsonv2` fails to compile, and a
toolchain change needs the tests below rerun.

## Compatibility evidence

- `TestAssignmentStreamDecodeDifferential`: 68 array shapes in two documents each,
  67 whole-document cases and the maximum body, decoded by the new path and by a
  retained copy of the old one, for both route body shapes. Same acceptance, same
  values including nil against empty and float bits.
- `TestAssignmentStreamDecodeGenerated`: 6,000 seeded documents mixing plain and
  irregular fragments, three in ten then truncated or damaged.
- `TestAssignmentCanonicalBindingOwnership` and `…ArbitraryBytes`: the direct binding
  owns exactly the plain shape, and over 200,000 damaged inputs it never accepts
  bytes that are not valid JSON or returns values different from `encoding/json`.
- `TestStreamSingleJSONDocument`, `TestStreamArrayStopsAtLimit`,
  `TestStreamArrayStdlibCompatibility`: the streaming entry point against
  `DecodeJSON` and `encoding/json`, including a megabyte of body left unread behind
  an excess element.
- `TestAssignmentValidationMatchesBaseline` and `TestAssignmentIdentityKeyAppendMatches`:
  20,000 seeded updates against a retained copy of the old validation.
- `TestMaxAssignmentUpdateAllocationBudget`: 12 MiB and 4,000 allocations per maximum
  request (10.59 MB and 2,152 measured). It failed on the base at 35,339,075 bytes
  and 109,670 allocations.
- Existing `TestJSONAssignmentWireContract`, `TestJSONMaximumMutationContract` and
  `TestCreateAssignmentDecode*` pass unchanged.
- 21 single-guard removals each make a named test fail by assertion, not by a build
  error: 11 in the direct binding and its fallback, 5 in validation and identity
  keys, 3 in the streaming decoder, 2 for the allocation budget (unsized slices
  23.5 MB, buffered decode 19.0 MB).
- Local fuzzing, not part of the suite: 1,248,516 executions of the direct binding
  and 1,341,434 of whole documents against the old path, no difference found.

## Static runtime harness

The November 4 miss was `web-db-unavailable` at 1.619804 s against < 1.5 s. Both
images were rebuilt from this branch for linux/amd64 (bill `sha256:8b96d040…0967`,
web `sha256:092f1bc9…2b2e`) and the documented harness run four times against the
PostgreSQL image pinned in `.github/workflows/checks.yml` (`sha256:839fbb5a…57a5`):

| Run | Checks run | Failures | bill / web `db-unavailable` s |
| --- | ---: | --- | --- |
| 1 | 75 | none | 1.020 / 1.045 |
| 2 | 75 | none | 1.024 / 1.033 |
| 3 | 28 | `bill-runtime-probe` | not reached |
| 4 | 75 | none | 1.025 / 1.040 |

**The harness is still not reliably green.** The November 4 miss did not recur in
the three complete runs, which does not prove it cannot. Run 3 stopped at a
different check: the probe's `dns_cancellation` assertion was false after 256 ms
(run 4 passed the same assertion at 256 ms, so elapsed time was not the failing
term). The probe does not record which term failed. From reading
`scripts/runtime-probe/main.go`, the likely cause is that it reads the lookup
context's error immediately after the resolver returns: the socket deadline and
the context timer expire at the same instant, so the resolver can return its
timeout before the context reports `DeadlineExceeded`. That is not confirmed by a
capture. The host was running this branch's controller tests during run 3. The
failure is retained as a failure, the probe was not changed, and every run removed
its labelled containers and networks.

## Not established

Hosted proxy allowlist and topology, deployed capacity, the integrated protocol run
and release acceptance. `TestServiceHealthcheckMode/bill-service` fails on this
machine only because another project's container holds `127.0.0.1:8080`, the fixed
address that test proves in the built binary.
