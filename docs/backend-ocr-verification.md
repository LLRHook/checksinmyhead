# Local backend receipt verification

Run from the actual source checkout using Go pinned in `backend/go.mod`. No real
provider request, inherited provider credential, account, hosting setting or customer
photo/database is needed or authorized by this procedure. All provider tests set a
synthetic key and replace only owned network seams; the production HTTPS endpoint,
TLS checks, HTTP/1 policy and private transport stay under test. Do not run a valid
scan against the fixed endpoint to fill a coverage gap.

1. Record source/module/test hashes, SHA, toolchain and dirty/index state. Preserve
   all unrelated files and volumes. Reconcile the maintained `VERIFICATION.md` matrix.
2. In `backend`, run `go test -race -count=1 -json ./internal/receipt ./cmd/bill-service`
   for focused development. Final verification uses `go build ./...`, `go vet ./...`,
   the literal CI format command, `go test -race -count=1 -json ./...` and pinned
   `go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./...`.
3. Execute the entire eight-package integration row from `VERIFICATION.md` with
   `-count=1 -json`, its strict loopback-only `BILLINGTON_TEST_POSTGRES_DSN`, and no
   skips. The shared `internal/testpostgres` harness owns exact random schemas;
   retain their generated names from JSON output and check their individual absence.
   Never broadly drop a prefix, initialize public or remove ordinary data volumes.
4. Exercise actual admission policy: 1–8/default 2; invalid/precanceled peer; both
   concurrent cancellation orders, panic/error/success release; 10/60s normalized
   IPv4/mapped/IPv6 identities; denial-no-charge/no-extension; 4096 live keys with
   existing-peer success/new-peer 503; admission expiry and real 15s idle sweep;
   close/join the sweeper. Retain all three quota-clock cases: sample exactly once
   under the mutex, no sampling/charge on canceled admission, and actual rolling
   admission ordering. Existing proxy constructors retain hop/fallback coverage.
   Through the handler, each client request makes one provider request for a provider
   failure and none for a peer-quota denial
   (`TestHandlerFailuresMakeOneProviderAttempt`).
5. Real TCP upload cases must keep bytes missing while requiring response AND
   StateClosed/handler/permit completion: known/streamed size excess, bad headers,
   unsupported MIME, duplicate image, earlier deadline and disconnect. Use shared
   safehttp rejection; no deferred `Part.Close`/arbitrary draining on known rejection.
   Cover total 10 MiB and +1, 32/33 parts, 64/65 parsed headers and 16 KiB/header excess.
6. Local verified TLS/TCP must count actual wire POSTs for 301/302/303/307/308,
   tainted Location/key/error data, reused/stale connections and manual retry. Prove
   nonreplayable nonempty bodies/GetBody nil/no idempotency headers, HTTP/1 only,
   prompt closure of stalled non200 bodies, early/late context cancellation, joined
   early-response request writers INCLUDING final Flush and deadline rechecks after
   cleanup. Require held dial/TLS/DNS cleanup, no native drain or provider-byte
   diagnostics, healthy reuse, dirty/stale idle refusal without hidden redial, and
   duplex idle interruption joining real TLS-generated writes. Exercise reservations
   1/2/8 including actual closing, timer/idle/callback cleanup and concurrent Close
   against cancellation/claim. Response headers total 32 KiB across at most four
   informational responses, truncated/declared-vs-streamed/gzip decoded 2 MiB cap+1 reads,
   text 512 KiB and all shape/quantity boundaries. Retain finite typed errors, friendly
   status mapping, Retry-After seconds/date/invalid/long-wait behavior and CORS.
7. Keep before-failures, valid controls and executed guard-removal assertions distinct
   from compile/setup errors. Rerun a failing test once to classify a timing failure;
   never relabel a flaky pass green. Count leaves, overlap, skips, missing terminals,
   cached results and packages from JSON events rather than line counts.
8. With no competing build/scan/test load, run:

   ```bash
   cd backend
   OCR_MEASUREMENT_OUTPUT=<absolute-ignored-file> go test -count=1 -tags=a2perf \
     -run '^TestA2Measurements$' -json ./internal/receipt
   ```

   Keep all 3×100 samples after five warmups EACH: admission/rejections p95 <5ms;
   representative/maximum upload+encoding+parsing and maximum receipt p95 <250ms;
   observed actual upload/provider cancellation release <=250ms (exclude deliberate
   blocked I/O). Record Go's separate HTTP/1 RST-avoidance close wait without
   counting it as ongoing OCR work or claiming <250ms socket closure.
   Preserve misses. Limiter retained heap <2 MiB; OCR incremental peak <=80 MiB/slot,
   default 2 <=160 MiB; include real local TLS and both-slot bursts. Distinguish sampled
   live heap/RSS high-water from true peak and cumulative
   TotalAlloc (a conservative burst allocation upper bound). After an intact 75s
   idle and two GCs compare against a PRE-burst baseline with fixture buffers kept
   alive; require <=4 MiB retained growth and fixed lifecycle goroutines.
   The unchanged maximum assignment harness and its 10ms gate are separate;
   do not change/rerun it as part of this OCR measurement or waive its target.
9. Build both final static images, verify the pinned base signature and run the existing
   75-check [runtime harness](../backend/README.md#static-runtime-verification).
   Scan scoped source and exact saved images unsuppressed; retain raw exits, candidates
   and dispositions. Record original-file hashes, exact SQL/schema cleanup, image IDs,
   artifact hashes, lifecycle resources and commands in ignored evidence.
10. The generic 75-check runtime probe does not exercise this private provider owner.
    Qualify the actual final CGO0 Linux API image at the OCR endpoint with an owned
    internal DNS/TLS provider fixture, fixed api.anthropic.com and a synthetic key.
    Verify local-only provider paths BEFORE valid requests; keep host DNS/hosts/routes
    untouched. Cover hosts/search, UDP/truncated-TCP DNS, A/AAAA/serial fallback,
    roots/hostname/TLS1.2+/HTTP1.1 and timeout/cancel/close/no detached native work.
    Label mounted package-test-binary evidence separately. Missing IPv6 prerequisites
    are BLOCKED. Record KeyUpdate-specific execution as NOT RUN/source-derived if
    supported local APIs cannot inject it; the executed native TLS alert-write barrier
    remains a distinct control. Do not use private crypto hooks.

The [native integration record](reviews/2026-11-04-ocr-native-ownership-integration.md)
binds local executions and remaining limits; it is not deployment or integrated
acceptance. Private Go DNS/serial TCP and conservative dirty-idle refusal are explicit
tradeoffs: DNS/address-selection sockets are outside the provider TCP reservation
cap, and legitimate idle TLS control traffic can fail one operation before manual
retry. Preserve all historical before/removal evidence and final-source controls.

Backend fields and money semantics are unchanged. Existing receipt parsing fixtures
cover nulls/discounts/repeats/fences/empty items and schema/model/prompt compatibility.
The PG constructor test counts zero statements for OCR rejections and one for health;
provider-success proof uses the private local TLS seam without a database dependency.
Meaningful mobile schema tests can accompany any later field change. A2b must still
prove real client upload/body/parse cancellation and application-side checked expansion;
backend bounds do not certify mobile safety. Durable/global allowance B, independent
clean/integrated/hosted/provider acceptance and release remain separate gates.
