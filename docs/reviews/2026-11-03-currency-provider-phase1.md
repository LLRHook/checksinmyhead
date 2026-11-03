# Backend currency provider phase 1 — November 3, 2026

Implementation source commit **ee125d107bb717989c8735ff6f3f0b2910ebc050**, parent **79a856823ee7b036cc270da1028278982a7c732c**,
on `chore/billington-foundation-program`, PR https://github.com/LLRHook/checksinmyhead/pull/159.
This is the bounded provider/construction/policy phase under BUG-1793644499/4515.
The separate evidence/tracker commit does not change tested Go source. Independent
driver acceptance is pending; global security and integrated acceptance remain RED.

## Scope and ownership

Production `cmd/bill-service/main.go:newCurrencyHandlers` now supplies one required
Frankfurter v2 pair client to frozen creation, preview and display. The legacy compiled
web entry point supplies the same required constructor parameter. Currency owns the
single twelve-code receipt policy; meaningful rate fixtures exercise each code through
production composition and compare both actual unchanged mobile selector maps.
Receipt codes: USD EUR GBP CAD JPY MXN PEN AUD BRL CNY INR CHF. Provider-defined display
pairs remain independent, including ZAR. Omitted receipt currency still means legacy USD.

`exchange.Client.Latest(ctx, base, quote)` uses the official single-pair object route,
one external attempt per distinct pair, caller cancellation and a five-second maximum.
Creation shares that deadline across frozen/display work and reuses its frozen pair for
a USD display. No fallback provider, wrapper or application TTL map remains. Normal
HTTP pooling and immutable persisted accounting quotes remain. ExchangeRate-API source
and config dependence is removed, including the obsolete empty lifecycle-fixture env
entry; no external account/credential/resource was changed or canceled.

Only new foreign quotes receive exact pair/source, positive finite rate, strict day and
UTC calendar freshness validation (age <=7 days, at most one day ahead). The adapter
accepts exactly one bounded (64 KiB) object with all four expected fields, rejecting
unknown/duplicate/case-mismatched fields, arrays, multiple objects, malformed data,
nonpositive/nonfinite values and mismatched pairs. Error bodies/URLs/transport messages
are not exposed. Redirects are rejected. Upstream429/503 returns a sanitized valid
Retry-After delay/date on the public503 without an immediate retry loop.

Frozen USD fields retain their sole ownership; display amount/rate cannot overwrite
frozen source/date. Accepted rates/days are retained without rounding/reconstruction.
Native USD is rate1/source native-usd with no invented market observation. A requested
foreign display failure saves nothing instead of mislabeling native/identity amounts.
Historical persisted quotes are never refetched or freshness-rejected; explicit stored
zero values remain zero, including legitimate sub-cent conversions. Legacy rows without
quote provenance retain the existing compatibility backfill. Inconsistent historical
accounting remains evidence for the existing mutation review, not an invented repair.
Distinct persisted display observation/source/retrieval metadata waits for approved0002.

Accounting versions/precision, migration0001/catalog/history, fixed arithmetic,
source/destination/member proof, lifecycle/paid protections, tab-before-bill locking,
FEFF/saved-history corrections, sanitized logs, public-client/version policy and old
links remain intact. No migration0002/0003, replay, save-state, mobile/web feature,
identity restriction, dependency or global tool/config change was introduced.

## Reproduction and controls

Before fixing wiring, a mechanical extraction of the exact production constructors
retained their behavior: EUR creation returned503 with no persistence; USD201 and a
valid foreign quote supplied through the existing adapter both passed. The saved
extraction/test and complete output are `before_main.go`, `before_main_test.go` and
`before.log` under the raw evidence directory. This was isolated HTTP/synthetic storage,
with a local fake upstream and no receipt inference. It reproduced the omitted dependency,
not an unrelated validation rejection. The final production-composition tests pass.

Six Go overlays changed no shared source. Removing freshness, pair binding, the body
limit, PEN policy support, explicit-zero preservation or the shared deadline each
produced the expected executed assertion failure (2 /3 /1 /1 /1 /1 failing leaf cases).
The deadline control finished in a bounded ~7.6s rather than running an unbounded loop.
No enormous-loop payload was executed. Commands/results are in `controls/results.json`;
all ordinary final-source cases pass. A temporary test exact-float multiplication
comparison was corrected to a tolerance for derived display amounts; accepted quote
rate/day assertions remain exact. That initial test failure is retained in targeted.log.

## Executed gates and counts

Actual compiler Go1.27.3 darwin/arm64, selected by unchanged go.mod/go.sum; the host
launcher is1.25.7. PostgreSQL17.11 uses the supplied dedicated loopback fixture and
strict test-only random schema harness. No selected test skipped for missing setup.
Commands from backend (CI commands with fresh JSON evidence flags):

```sh
go build ./...
go vet ./...
go vet -tags=integration ./...
go test -race -count=1 -json ./...
go test -race -count=1 -tags=integration -json ./cmd/bill-service ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres
go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./...
```

Build/vet/tagged-vet, the CI gofmt guard, git whitespace checks and tracker lint pass.
Pinned govulncheck exits0, “No vulnerabilities found.” Runner-native `-list` enumeration
matches every executed root: default137, tagged148, missing0/extra0. Package no-test-file
events are not test skips.

| Qualified run | Roots | Passing leaves | Failed | Skipped |
|---|---:|---:|---:|---:|
| Final default Go race |137|511|0|0|
| Final mandatory tagged selection |148|586|0|0|
| Distinct leaf union |—|737|0|0|

There are360 overlapping leaves; do not add the rows. Counts come from terminal runner
JSON, not source grep. Earlier same-phase passing runs and the final targeted/parser
check remain separately attributed; they are not added to these qualified counts.
Final raw files: final-race.jsonl, final-postgres-race.jsonl, final-build.log,
final-vet.log, final-vet-integration.log and final-govulncheck.log.

Root `python3 scripts/test_local_workflow.py` ran55 tests:54 pass,1 fail,0 skips. The
unchanged normal-Flutter-quit case timed out at the stubbed API loopback readiness
stage with124 while heavy checks ran. Its one required targeted rerun passed1/1 in
6.549s. This is classified **FLAKY/RED**, not a waived or green result; the phase changes
only its real lifecycle fixture's obsolete empty provider env entry. No unrelated
workflow correction is bundled. The actual maintained lifecycle harness passed all
five assertion groups (down/restart preservation, guarded reset and quiet Compose
config/profile checks), with cleanup_complete=true. Other tiers were not touched or
rerun; prior Flutter/web evidence belongs to its original pin and is not adopted here.

Local gate: **RED**, scope=affected, clean=no, source=ee125d1.
Go functional/PG rows PASS; workflow row FLAKY/RED. Independent security/integrated
acceptance remains RED. No clean checkout was created, per the explicit shared lease.

## Query shape and latency

The actual production composition HTTP path uses the real repository and migration
runner. A pgx tracer counts every data statement, including RETURNING/association
writes/any ORM reads; BEGIN/COMMIT are reported separately. No per-person queries,
full-tab loads or caches hide work. Each fixture has three warmups followed by three
runs of100 samples (1,200 measured creates total) in final-performance.jsonl. The
representative shape is40 items/8 people/320 assignments (17,182-byte body); maximum is
500 items/100 people/5,000 assignments (250,328-byte body). Native USD makes0 external
calls; each foreign receipt makes exactly2 (distinct EUR/USD and EUR/ZAR), including
200 calls per100-sample run. All traffic is local fake-provider traffic.

| Shape | Data / transaction statements | p95 run 1 / 2 / 3 | Fake upstream wait p95 run 1 / 2 / 3 |
|---|---|---|---|
| representative_USD | 6 / 2 | 6.816375ms / 6.275708ms / 6.369ms | 0s / 0s / 0s |
| representative_foreign | 6 / 2 | 6.671583ms / 8.538084ms / 6.855333ms | 177.458µs / 213.501µs / 191.791µs |
| maximum_USD | 6 / 2 | 51.850958ms / 51.926375ms / 51.265209ms | 0s / 0s / 0s |
| maximum_foreign | 6 / 2 | 50.822709ms / 50.975833ms / 50.904625ms | 210.958µs / 202.791µs / 207.25µs |

All approved phase targets pass in the qualified non-race loopback measurement: <=12
representative / <=20 maximum data statements; representative USD p95<=200ms; healthy
publication target p95<=2s. Provider wait is separately measured as summed WroteRequest
→ GotFirstResponseByte time per operation; it is not a real-provider latency/SLA claim
or total body/decode duration. Application p95 and all raw per-run numbers are retained.
The mandatory race build reports its own slower measurements separately; final runs
contain no TARGET_MISS/miss=true reports. Earlier timings include concurrent image/PG
work and are not used as a performance regression baseline. No production/device load
or sustained Frankfurter outage has been established.

## Security, runtime and source binding

Current official docs/OpenAPI were verified before implementation:
[Frankfurter](https://frankfurter.dev/),
[pair/OpenAPI](https://api.frankfurter.dev/v2/openapi.json), and
[official changelog](https://github.com/lineofflight/frankfurter/blob/main/CHANGELOG.md).
The documented blended daily pair/storage contract supports this adapter. Our freshness
limits are an approved application policy, not provider promises. Prior supplied public
currency coverage remains point-in-time evidence only; no public-API load test ran.
Raw source documents, retrieval times and hashes are in primary-sources/manifest.json.
No new package was added; no global tools/skills/config were installed or altered.

| Tool / scope | Actual result and triage |
|---|---|
| Gitleaks8.30.1, all phase changed files, redacted/no allow comments | Exit1,4 candidates,0 errors: synthetic test `?t=synthetic` and3 unchanged documentation placeholders; no credential found; no suppression |
| Semgrep CE1.183.0,24 Go files, maintained local security rules, OSS/strict/no nosem/metrics off | Exit1,14 candidates,0 errors:11 fake-upstream ResponseWriter fixture writes,2 unchanged non-TLS listeners,1 unchanged uint-generated SQL failure fixture; no new confirmed production finding |
| gosec2.30.0,21 production files/2369 lines, -nosec | Exit1,2 retained MEDIUM G114 listeners,0 Go errors/0 suppressions; existing ingress/server-hardening work remains open |
| Trivy0.76.1, exact saved final bill/web artifacts | Exit0 each;0 findings at every severity, no unfixed/severity/VEX/ignore suppressions |
| Trivy config, both unchanged Dockerfiles | Exit0;27 successes/0 failures each |
| Cosign3.1.4, shared pinned distroless base | Exit0 with Google issuer/keyless distroless identity; signature proof applies to the published base, not unsigned local builds |

The separate metadata added-hunk/new-note Gitleaks scan exits1 for one repetition of
the same documented synthetic fixture example; no credential or suppression is present.
SAST candidates are retained and triaged, not hidden or declared a blanket green scan.
Scanner argv, versions/rules, full output and per-file hashes are under scans/ and
versions.json. Source hashing binds tested/scanned code to ee125d107bb717989c8735ff6f3f0b2910ebc050;
raw tested-source-sha256.json includes the complete maintained source snapshot.

Final local linux/amd64 static CGO0 images:

- bill `sha256:ff95b75c844ceb814d0949452e389add2d3a6dffa42a14785fd1c91c8d1d40b4`;
  saved archive SHA256 `13d557037c50d82ddc717391ef1f55bb68f65e4ffcb30e2b2f61a0b829199d10`;
  ELF SHA256 `297ecb4f68c76d3953b8b13872567f4d584b1230e7db1f714182f4fc33faf73b`.
- web `sha256:1dde1834b9943a482eff58533e95b251c41b0903dfe08b20698dee2440241bfa`;
  saved archive SHA256 `cdbaf25c54d6f1e86363f3cc97dd877ae792fb41423819e72e3d3c415134c013`;
  ELF SHA256 `f93d5518aa3a36c2338c3df7cca2aa2984bb263b6957759f1c4ed3fb38f98730`.

The maintained runtime harness ran69 checks/0 failures/cleaned=true against those
immutable images, proving bounded DNS/cancellation/search behavior, CA/hostname trust,
static ELF/CGO0, TLS application DB connections, timezone, readiness failure/recovery,
Docker health transitions and exact legacy HTML/no-token403 controls. Image/runtime
health source identity is fixture-injected, not independent deployed binary provenance.
No final-host resolver, hosting settings or production adoption claim follows.
Trivy DB updated2026-11-03T19:16:30.092559407Z, downloaded19:50:13.107926626Z.

Build commands were the maintained Dockerfiles from backend context with
`--platform linux/amd64`, phase-specific local tags; runtime command:

```sh
python3 scripts/verify_static_runtime.py --bill-image billington-currency-phase1-bill:20261103 --web-image billington-currency-phase1-web:20261103 --postgres-image sha256:3b0cda93be7c8dba2ed484d19393d93845dc3dafb88973e248ba8e6d99d784e1 --output .vv/local-gate/currency-provider-phase1/runtime
python3 scripts/verify_local_lifecycle.py --postgres-image sha256:3b0cda93be7c8dba2ed484d19393d93845dc3dafb88973e248ba8e6d99d784e1 --output .vv/local-gate/currency-provider-phase1/lifecycle
```

## Doc impact, cleanup and remaining gates

| Living path | Impact/action |
|---|---|
| backend/README.md | Remove key dependency; document pair/freshness/retry/ownership and new PG composition selection |
| docs/backend-api.md | Preserve rate wire field; document observation timestamp, receipt/display policy, frozen/native ownership and pending0002 |
| docs/technical-overview.md | Replace dual provider/cache description with one required adapter and explicit follow-ups |
| backend/.env.example / docker-compose.yml / scripts/verify_local_lifecycle.py | Remove obsolete provider key, including synthetic fixture configuration |
| VERIFICATION.md | Add mandatory cmd/bill-service selection; retain all rows/Last verified/baseline counts;20,478 bytes below20KiB cap |
| bugs.md | Official writer only:4499/4515 Fix/Docs/Log/dependencies; both stay in-progress, entries1802/2109 bytes |

Original untracked roots (PROJECT_STRUCTURE_REVIEW.md, TECHNICAL_REVIEW.md, artifacts/,
mobile/android/) retain all336 file hashes.315 are visible to git;21 are ignored files
inside the preserved roots, explaining the apparent count difference. No broad staging,
new checkout, subagent, force push/rebase/reset or published ancestry rewrite occurred.
Shared billington-driver-pg-20261102 and normal volumes remain. All owned random PG
schemas cleaned (final prefix count0); exact runtime containers/networks and lifecycle
fixture resources cleaned. Retained local images, raw .vv evidence and scratch controls
are review artifacts; no temporary instrumentation entered application source.
Prior dated notes, baseline ledger, CHANGELOG, migration source, mobile/web source and
locks remain unchanged. Raw evidence is ignored `.vv/local-gate/currency-provider-phase1/`.

Explicit follow-ups remain under the approved program:

1. Display observation/source/retrieval persistence in migration0002 after migration
   acceptance; frozen compatibility fields must never be reused for it.
2. Server creation replay and immutable fingerprint/retention; mobile one-ID save/resume,
   attempted marker, exact response checkpoints, Keychain/crash/reopen/recovery and
   exact-ID attachment. No replay-ignorant rollback or unkeyed fallback may be introduced.
3. Mobile ApiService.getCurrencyRate still reads `value` instead of server `rate`;
   BillData retains a draft quote, CurrencyConversionPreview retains its input Future,
   TabDetail retains `_usdToDisplayRate` and falls back to1/USD on error. Those are
   remaining client state/decoding/failure contracts, not removed backend TTL maps.
   Local persisted frozen quotes are accounting evidence and must remain.
4. Receipt review/ambiguous currency and offline continuation, zero-USD upload decoder,
   pending totals, legacy unlinked/import review and full save/replay/attachment journeys.
5. Required negotiated whole-yen JPY precision/versioned accounting after identity phases;
   keep visible fractional legacy values and old version calculations intact.
6. Independent review/driver acceptance, retained workflow flake/ingress findings,
   public token-free source-adoption checks by the root after push, production/schema
   readiness, signed public-client/device/provider/outage evidence and integrated V&V.

No hosting/account/publication action, public/customer data operation, provider control
plane/credential/domain/env change, live migration, main/mirror/tag update, PR creation/
merge/comment/review, App Store/TestFlight action, Railway cancellation or watch occurred.
The authorized normal feature-branch push is separate from root public acceptance.
