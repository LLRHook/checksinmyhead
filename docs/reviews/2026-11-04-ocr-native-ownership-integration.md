# Backend native OCR ownership integration — 2026-11-04

Source **c3c95cc3fe99d1f6c5c2434553c85078726d7bc2**, from **a970c96bced7a2e49b05294c77b7496dbc2d320e**, on `chore/billington-foundation-program` / [PR159](https://github.com/LLRHook/checksinmyhead/pull/159). **Affected acceptance remains RED**: a real runtime timing assertion failed; its classification rerun does not clear it. Whole security, integrated, performance and release acceptance remain RED. Independent final source acceptance is pending; no grade or ticket closure.

This is the implementation owner's executed local evidence, **clean=no** in the intentionally shared checkout. The prepared exact-request sole-writer lease and base were checked before mutations. Driver approval accepted owned PreferGo DNS, serial numeric TCP attempts and conservative dirty-idle refusal. Independent pre-adoption review found Standards0/Spec0, ADOPTABLE; that reviewer did not execute application tests. Source and evidence commits use command-scoped Victor Ivanov `<victor.n.ivanov@gmail.com>` author **and** committer, with existing hooks. No checkout/worktree, new agent, dependency/version, SQL/schema source, Dockerfile/runtime definition, hosting control-plane, real provider call or publication change.

## Change and preservation

Replace the superseded callback wrapper with the reviewed private `provider_transport.go` / `provider_dial.go`, using only Service import/type/constructor/Close changes. Stdlib Request.Write/ReadResponse/TLS/DNS remain. The owner reserves through actual close, joins native query/socket/TLS/writer/final-Flush/callback work, refuses dirty idle reuse and never invokes partial/non200 body draining or native HTTP pool diagnostics. Healthy reuse remains enabled. Close joins leases, idle readers and the pool timer after serving stops; it is not an API for joining callers' pre-lease computation.

Root F2 is composed, not overwritten: handler passes time.Now; acquisition samples once under its mutex and sweeping samples under lock. Only the private transport constructor assertion was applied to the clock-adapted admission test. All three clock IDs remain. Existing provider adapter hunks preserve all obligations; five reviewed transport/fixture test files are adopted under their original filenames. No historical before adapter is installed. Added stress has two leaves, 32 rounds each, 768 total concurrent Close calls against active cancellation and timer/idle claim, with real socket/worker/caller cleanup.

All **336 originals** match before/after; **128 final Go/module inputs** are bound (120 original +8 new), with per-selection source checks. All unrelated tracked files match. Service content from ValidatePolicy onward—including Parse/DTO/prompt/model/schema/validation—matches the starting source byte-for-byte. VERIFICATION.md is unchanged, **20,478 bytes**, Last verified never. Previous dated reports/reviews/ADRs/raw artifacts and mobile source are preserved.

One provider TCP socket per reservation is deliberately **not** a DNS/all-process socket cap. PreferGo retains native hosts/search/server/UDP/TCP policy; serial dialing trades Happy Eyeballs latency for owned completion. DNS/address-selection sockets are separate. Legitimate idle TLS control traffic can conservatively fail one operation; no hidden redial/HTTP retry occurs. A later manual retry is separate. Public receipt limits, finite statuses, money/quantity, framing/gzip and headers remain unchanged.

## Local correctness and case identity

Go **1.27.3**; actual commands run in backend, logs under the artifact directory below:

- Literal CI gofmt shell assertion, `go build ./...`, `go vet ./...`, `go vet -tags=a2perf ./internal/receipt`: exit0.
- `go vet -tags=integration ./cmd/bill-service ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres`: exit0.
- `go test -race -count=1 -json ./...`: **889 leaves /982 started and terminal nodes**, all pass.
- `go test -race -count=1 -tags=integration -json ./cmd/bill-service ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres`: **721 leaves /792 nodes**, all pass, strict supplied loopback DSN only.
- Overlap **464**, distinct **1146**. All **1093 previous** and **960 predecessor** exact IDs retained; no equal-total inference. Receipt **190 =137 original +48 transport +3 clock +2 stress**. Both rows have zero missing/duplicate terminals, skipped cases, malformed JSON or cache results; every selected package with tests executes them. Readiness/web ordinary no-test packages are explicit, not skipped cases.
- All **207 exact generated shared-PG schemas** are absent; no prefix drop/public reset. Shared fixture PostgreSQL17.11 and ordinary volumes remain intact.

Final-source removals use its real private owner, one barrier at a time. All healthy selections pass. Seven transport removals produce **8 failed leaf assertions +2 passing controls**: DNS outer wait, 32KiB header cap, reservation cap, non200 no-read, writer/final-Flush joins (200/429), dirty-idle refusal and duplex idle interruption. Moving the clock sample outside its lock adds **2 failed assertions +1 passing control**. Zero counted setup/race/skip/cache errors in these controls. Wire cases retain one POST/no cross-origin attempts, verified TLS1.2+/HTTP1.1, early200/401 during blocked maximum upload, capacities1/2/8, finite taint handling, framing/gzip/header/quantity/money boundaries and actual cleanup.

Original prototype before evidence remains immutable: unchanged-constructor dial/TLS/DNS/drain cases versus the old owner; final-Flush-before instead bypasses the outer wrapper with an in-memory body. It is a disclosed native-mechanism control, **not a third unchanged-wrapper exploit**. This integration reexecuted all seven final-source removals and clock controls, not those historical before runs.

## Native qualification and runtime RED

Both maintained **linux/amd64 CGO0** images were rebuilt without definition/base/version changes and bound to the final source. Cosign3.1.4 verifies the pinned distroless base using its official issuer/identity; this is base verification, not final-image signing.

| Artifact | Exact image ID | Saved archive SHA-256 |
|---|---|---|
| API | `sha256:038a35bbecf3b6677530c5d30e5942621ca3314d7dcd5bb81d15554b19317626` | `ceb86df35ba93a5b247b92e1c1345b75e6d0979d001f54efea71762271b10f7d` |
| Web | `sha256:073440ae0788c6568791349bb7e00c35f07ad075b4060447dffc19b4a80c7d28` | `c64ac44c5c5f47a0e86ffd07598e40f311ebc5eeece08161a5862b3547e59da2` |

The generic maintained 75-check harness has three separate records:

1. `runtime/`: **14 checks**, fixture compiler's unchanged120s module-acquisition timeout, incomplete/RED. Its labelled builder survived the client timeout; logs and manual owned-builder removal are retained in `runtime-timeout-cleanup.json` (nothing remains).
2. `runtime-cached/`: existing read-only module cache, pinned compiler, -mod=readonly/offline, no fresh-acquisition claim; **62 checks**, web-db-unavailable **1.619804s vs <1.5s**, exit1/cleaned=true.
3. `runtime-complete/`: single classification/completion run, **75/75 pass, raw exit0**, cleaned=true. The same web predicate passed. Only diagnostic control flow could record a repeated failure and continue; predicates/budgets/timeouts are unchanged. Root inspected/authorized the exact adapter. **Runtime stays RED/flaky** from the first assertion; no further reruns or threshold relaxation.

These generic checks alone do not qualify the new provider owner. `private-runtime/attempt-5/` separately runs the **actual final API image** through OCR, fixed api.anthropic.com/synthetic key, on an individually owned **internal IPv4/IPv6 network** with explicit local DNS/TLS answers and no forwarding. Local-only paths are checked before valid requests. **16 scenarios /113 assertions** pass: native UDP and truncated-TCP A/AAAA DNS, hosts, search, IPv6 POST, fallback, roots/hostname/TLS1.1 rejection, TLS1.2+/HTTP1.1, healthy reuse, error-body closure, redirect refusal, provider-byte taint, client cancellation, actual30s provider timeout and DNS-time shutdown. Each API process exits0 with provider sockets closed; exact schemas/certificates/containers/networks are cleaned.

A separate mounted **CGO0 Linux test binary**, never a production-image addition, executes **53 ownership/clock/stress leaves** without race instrumentation; all pass, no skip/missing/cache. `attempt-6-serial/` adds one mounted package case with real resolver/query sockets: ordered native numeric attempts **127.0.0.2:443 → owned provider IPv4:443**, peak concurrent dial calls1, then close. It is supplemental instrumentation, not an unmodified API-image attempt trace. The actual image fallback scenario remains separately recorded.

Supported local OpenSSL s_server **K** injection executes a real **TLS1.3 KeyUpdate(request_update)** and native Go reply. Protected join passes; removing duplex interruption fails its assertion. This supplemental test runs on Darwin/arm64; Linux selected tests separately execute the real TLS alert-write barrier. No private crypto hooks. Actual subprocess runner uses **OpenSSL3.0.18**, path/hash/version in `openssl-execution-binding.json`; interactive PATH had reported4.1.0 and was corrected. No claim of Linux-specific KeyUpdate injection, Darwin libc equivalence, arbitrary hosted DNS/address-family/roots compatibility or deployment qualification.

Private-runtime initial attempts remain visible: PG bootstrap readiness before database creation; Docker internal-network published-port unavailability (switched to an owned in-network helper); first HTTP startup readiness; synthetic text bytes rejected400 by image sniffing before any provider call (corrected fixture to JPEG magic, without changing handler). These do not count as successful provider tests. Temporary schemas are exactly dropped/checked where created; failed initial CREATE had no target database. All task resources, including that ephemeral setup PG, were removed.

## Unchanged OCR measurements

Root activated a quiet lease after all own builds/scans/runtime work finished and mobile experiments ended. Root receipts/process/toolchain/load observations bind the single command:

`OCR_MEASUREMENT_OUTPUT=<absolute artifact>/measurements/raw.json go test -count=1 -tags=a2perf -run '^TestA2Measurements$' -json ./internal/receipt`

Go JSON: one passed leaf, zero failures/skips/cache/missing. **12×3×100=3600 timed samples**, five warmups before EACH run, command **84.585199s** with intact **75s idle/two GCs**. Every p95 target met; every observed upload/provider cancellation sample <=250ms (maxima0.056/0.030209ms). No own competing build/scan, shortening or rerun.

| Path | p95 ms, runs1/2/3 | Target ms (<) |
|---|---|---|
| admission | 0.000208/0.000250/0.000416 | 5 |
| slot_reject | 0.000208/0.000166/0.000166 | 5 |
| representative_upload_prep_parse | 6.391208/6.284416/6.303166 | 250 |
| maximum_upload_prep_parse | 13.790333/13.803417/13.553000 | 250 |
| maximum_receipt_parse | 2.122083/2.095667/2.108417 | 250 |
| shape_reject | 0.001042/0.000875/0.000834 | 5 |
| observed_cancel_release | 0.023583/0.023833/0.023042 | 250 |
| observed_upload_cancel_release | 0.014667/0.014917/0.016958 | 250 |
| quota_reject | 0.058125/0.055541/0.057584 | 5 |
| full_table_existing_admission | 0.058667/0.059625/0.063000 | 5 |
| full_table_new_peer_reject | 0.056042/0.063459/0.065917 | 5 |
| invalid_peer_reject | 0.000084/0.000125/0.000125 | 5 |

Limiter retained **1,392,192B <2MiB**. Burst allocations and pre-burst retention:

| Slots | Sampled incremental heap B | Burst TotalAlloc upper bound B | PRE-burst idle growth B | Fixed goroutines |
|---|---|---|---|---|
| 1 | 32,676,704 | 53,674,448 | -276,776 | 10 → 10 |
| 2 | 80,063,080 | 107,314,824 | -276,776 | 10 → 10 |

Each burst stays under80MiB/slot (default2 under160MiB); retention is under4MiB with fixture buffers kept alive. Sampled heap and RSS high-water are not true peaks; TotalAlloc bounds cumulative burst allocation conservatively. RSS high-water is recorded separately (122,945,536→123,027,456B;123,027,456→126,533,632B). Separate inbound transport closure: **315 samples, max502.226708ms**; this native HTTP RST-avoidance wait is not ongoing OCR work or a <250ms socket-close claim. The separate maximum-assignment harness is unchanged/unrerun; its known27.033/27.143/27.420ms versus10ms remains **RED**.

## Unsuppressed scanners and retained limits

- Pinned govulncheck@v1.7.0 exit0. Exact saved images and both Dockerfiles, Trivy0.76.1 exit0/zero vulnerabilities or failed config checks.
- Gitleaks8.30.1 **exit1/3 candidates**: unchanged named documentation capability placeholders, no confirmed secret.
- Semgrep1.183.0 **exit1/16 candidates**: synthetic test-only HTTP/TLS response fixtures, no public HTML sink.
- gosec2.30.0 **exit1/12 G104 candidates**: finite rejection paths intentionally discard NopCloser request-body Close results; native DNS socket Close is synchronous/once with joined lookup/callbacks, not raw-error propagation. No confirmed vulnerability from these candidates. `scans/triage.json` binds every location/code or line hash and disposition. **Raw1 is not0; no suppression/ignore directives or global security acceptance.**

Old history remains in [A2 backend](2026-11-04-ocr-a2-backend.md) and [mobile cleanup correction](2026-11-04-mobile-upload-cleanup-correction.md): A1 original845→optimization932→correction960 cases (708ordinary/716PG/464overlap); before15 failures/9 controls and3 removals/19 overlapping assertions; A2a836/721/464=1093, historical75runtime and414 exact schemas/336 originals. M2 clean362 Flutter cases,17 native/all359 predecessors, scoped APPROVE Standards0/Spec0 with reviewer execution NOT RUN. These historical runs are not re-executed claims here.

BUG-1793644507/4508/1793725850 stay **in-progress**, official-tool evidence updates only. M1 native TLS, allowance B/spending, old-writer drain, device/public binary/deployment/provider/clean integrated gates remain open. No paid inference, hosting changes, CI wait, PR comment/review/watch, merge or deployment occurred. Root owns public checks and independent final acceptance.

## Doc impact and raw bindings

| File | Key | Class | Action |
|---|---|---|---|
| backend/README.md | lifecycle/DNS/idle | stale-by-change | Describe complete private joins and availability tradeoffs |
| docs/backend-api.md | fixed-provider behavior | stale-by-change | Preserve wire/amount limits; explain resolver/serial/idle policy |
| docs/technical-overview.md | receipt owner/clock | stale-by-change | Replace wrapper lifetime claim with actual owner and locked time |
| docs/backend-ocr-verification.md | ownership/runtime proof | stale-by-change | Add final Flush/DNS/clock/stress/private Linux obligations |
| VERIFICATION.md | procedure/Last verified | still accurate | Unchanged, no integrated success claim |
| This dated note | local execution | new evidence | Record owner results and unresolved gates |

All new raw commands/stdout/stderr/counts/mutants/fixtures/measurement/scanner/image records are under scratch **backend-native-integration-20261104/**. `qualification-bindings.json` SHA-256 **3b57d763041024de189b065671a2f17bc0141d9085addadfe9ee51ec5b7388fe** binds **1487** files at qualification freeze. Important indexes: `gates.json`, `case-preservation.json`, `controls.json`, `source-hashes-final.json`, `preservation.json`, `postgres-cleanup.json`, `scans/triage.json`, `images/results.json`, runtime result files, private-runtime results and `measurements/{raw,summary}.json`. Per-run command records bind before/after source and336 originals. Original prototype manifest remains **645d7c363ac70fcdaac3431ff56226e392be64d5a36497acaac9239c52dacd6f** (748 verified bindings). Later commit/push/remote/lease metadata is separate; this note is not a self-referential commit/signature or an independent clean acceptance.
