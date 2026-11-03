# Atomic tab lifecycle — November 3, 2026

Implemented BUG-1793644504 and the lifecycle PostgreSQL slice of FEAT-1793644506.
Both stay **in-progress** for independent review/driver acceptance. This is a scoped
local result, not integrated V&V, release approval or a deployed guarantee.

Starting branch: `chore/billington-foundation-program`; local and remote starting head
`13be27bd6c2ec763c21e7ce1cbc44719f5f90e69`; origin
`https://github.com/LLRHook/checksinmyhead.git`. Existing draft PR: <https://github.com/LLRHook/checksinmyhead/pull/159>.
The implementation commit and independent remote proof are recorded below. No checkout/worktree/branch switch, force push,
main/mirror/tag push, provider action, customer operation or upload occurred.

## Delivered behavior and ownership

`FinalizeOnce` is the single production repository operation. Separate CreateSettlements,
Finalize and GetForFinalization methods are gone. One request-context Read Committed
transaction locks the tab, resolves current capability/role or genuinely memberless
policy, checks existing results, locks/project-reads bills and persisted shares in batches,
validates frozen accounting, inserts gross settlements and checks one active-state update.
Success is returned after commit. Authorized retries return stored IDs/money/created times,
finalized time and current paid flags without writes or revaluation, ordered amount DESC/id ASC.

All attached competing writers use Tab → ascending Bills → ascending Items → Shares;
settlement writes use Tab → Settlement. Membership/settings take Tab first. Initial
creator and fresh tab creation are atomic. Commands carry capabilities and object IDs;
current roles/member IDs are resolved under lock. Source payment discovers association
without holding a bill lock, rechecks scope/token and permits at most one rollback/restart
when attachment wins. Complete mutations are bounded to 10s; earlier deadlines win.

One explicit locked assignment owner batches reads/replacement and calculates once.
It preserves original claim timestamps/rounding priority, explicit zero participants,
unchanged economic share IDs and flags. Paid percentages, each component/total, ordered
item projection and frozen USD cents must survive unchanged or the whole edit rolls back.
Changed/removed rows have no name-selected paid successor; stale exact IDs get scoped 404.
Known USD identity is interpreted only in memory. Foreign frozen date/source/rate/total
must be valid. Finite checked int64 cents, aggregate sums, float-column round trips and
bounded remainder work prevent overflow or silent omission. No new financial algorithm,
cache, framework, dependency or schema was introduced.

Gross settlements, receipt-share paid flags, settlement paid flags and net payer balances
remain distinct. Paid routes are permitted after finalization and change only their flag.
Join remains available after finalization; valid-token retries do not write, invalid supplied
tokens cannot mint replacements. Leave preserves creator and recorded payer/adder IDs,
including anomalous cross-tab references. Settings use explicit fields and preserve quotes.
Orphan/ambiguous snapshots, duplicate member labels/share keys and unsafe accounting return
409 accounting_review_required without repair. Historical authorized reads remain available.
Touched errors use finite typed 400/403/404/409, generic retryable 503 or generic 500 and the
accepted safe logger; raw database messages do not enter finalize HTTP responses.

## Scope and immutable inputs

The complete driver approval and DATA_ARCHITECTURE_PLAN, original migration/log reviews,
corrected catalog-safety note and hosting constraint were read. Accepted catalog v2 and
request-error corrections remain. Fourteen frozen payload/model/manifest/fixture inputs
are byte-identical to the starting commit (hashes: `final/frozen-payloads.json`). This includes
0001, catalog payloads/checksums/provenance/ledger, go.mod/go.sum and the captured mobile
creation contract. 0002 remains reserved and 0003/identity is separately owned.
The original untracked reports, artifacts and Android tree remain untracked and untouched.
Normal volumes and the shared fixture are preserved. No global skill/config change.

## Commands, terminal accounting and controls

Commands below ran from backend, unless noted. Toolchain: module-selected Go1.27.3
Darwin/arm64, Flutter3.41.5/Dart3.11.3, Node24.22.2/npm11.19.1. No application dependency changed.
The shell default Go outside the module was1.25.7; actual module runners select1.27.3.

```sh
go test ./... -list '.*'
go test -tags=integration ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres -list '.*'
go test -race -count=1 -json ./...
go test -race -count=1 -tags=integration -json ./internal/bill ./internal/tab ./pkg/database ./migrations ./internal/startup ./internal/readiness ./internal/testpostgres
go build ./...
go vet ./...
go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./...
# mobile:
flutter test --machine
# web-bill-viewer, using the existing Node24 toolchain:
npm test -- --reporter=json --outputFile=../.vv/local-gate/atomic-lifecycle/final/web-tests.json
```

CI's gofmt guard and Git whitespace/tracker lint pass. Build/vet/govulncheck exit0;
govulncheck says no vulnerabilities. Default Go has129 roots/414 passing leaves;
PostgreSQL has138 roots/545 passing leaves. There are336 overlapping leaves and623
distinct union leaves. Every run ID has one terminal event, with no duplicate runs,
failed/skipped test leaves, build failures, race report or cached-result marker.
Four default package-level no-test-file skips are not skipped test cases. Flutter has
203 passing actual tests and21 successful loader events, no skipped/missing terminals.
Vitest has52 passing assertions across3 files, zero pending/todo/failed tests.

The ten captured mobile fixtures execute real create → attach → finalize HTTP/PG paths,
covering full/partial/custom/fractional tips, discounts, saved history and birthday zeros.
New HTTP/state and real PG tests cover concurrent finalizers, discarded successful response,
paid snapshot replay, insert/second-batch/update/deferred-commit rollback and retry, every
competing writer in both arrival orders and owner commit/rollback, revoked authority,
source discovery/attachment, stale recreated IDs, duplicate/orphan histories, finite/overflow/
foreign/zero accounting, member provenance, finalized joining/payment, settings and deadlines.
Raw JSONB snapshots include children, IDs, money, quotes, flags and timestamps. Observed PG
lock waits and channels establish ordering; no elapsed sleep inference is used.

The real initial regression failed four assertions: paid6→5.50 accepted (200), child/time
changes, finalize retry400 and different response. This is one failed leaf, with no fixture/
compiler failure. Original baseline JSON remains. Seven isolated Go control overlays each
fail one executed leaf (eight assertion messages total): paid projection, tab root lock,
current authority, exact share scope, atomic transaction, checked commit and claim priority.
All have exit1 and complete test terminals, no skipped/build failures. Overlay payloads,
source hashes, exact argv, assertions and stderr remain in `controls/summary.json`.
No source worktree was changed for controls. Early development NaN snapshot serialization
and a typed-nil assertion bug were test defects, corrected before the accepted pass; their
failed logs are retained and are not counted as controls. A log rename raced a redirected
command; the completed second full PostgreSQL stream is retained as `final/postgres.jsonl`
(final follow-up run; duration190.395s for tab), with all terminals. Earlier runs remain separate from final counts. After c5a9ba1, a test/evidence follow-up
adds checked UTF-8/index tie tests and source-payment-first races against attachment and
recreation. Their targeted run and both complete uncached Go rows pass. Application source
is unchanged from c5a9ba1; earlier HTTP assertions/refinements are included in this final row.
`final/*-implementation.jsonl` retains the earlier complete implementation selections.

## Measured query shape and latency

Each measurement below has **100 samples per run, three runs**, local PG17.11 on Docker
with a Go race build. Data statements come from pgx's actual query tracer. BEGIN/COMMIT/
SAVEPOINT/SET and observation/fixture-reset queries are separate. Per-run fresh+retry
transaction-control total is400; no artificial contention is in these timed samples.
Other fixture/test work can run concurrently; no production distribution is claimed.
All targets below are local targets, and none missed in this run.

| Operation | Observed data statements | p95 across runs1 /2 /3 (ms) | Approved target |
|---|---:|---|---|
| Fresh10 bills/8 people |7|4.917 /4.472 /4.554|≤9; ≤200ms|
| Retry10 bills/8 people |3; zero writes|1.848 /1.610 /2.013|≤4; ≤100ms|
| Fresh100 bills/10,000 shares |7|169.667 /175.270 /172.985|≤750ms|
| Retry large tab |3; zero writes|4.333 /4.927 /5.417|≤4; ≤100ms|
| Source paid, attached |5|1.936 /1.902 /1.810|≤6 plus at most one discovery restart; ≤100ms|
| Tab-share paid |6|2.233 /2.159 /2.201|≤6; ≤100ms|
| Attachment |4|1.700 /1.705 /1.576|Bounded shape (no separate latency target)|
| Assignment500 items/5,000 allocations |13 including5 insert chunks|281.781 /263.561 /241.932|≤14 plus bounded insert chunks; no separate latency target|

The deterministic attachment-discovery race proves the single restart path separately;
normal timed paid samples have no restart. Readiness remains unchanged: exactly one live
ledger query/request, 3×100 samples, p95 0.325 /0.349 /0.387ms and the existing1s deadline.
No per-person query, cache, item/payment/participant graph or provider call is in finalize.

## Scoped security and cleanup

Gitleaks8.30.1 scans the24 changed/new Go files with full redaction, empty ignore file and
allow-comment suppression disabled:0 candidates/errors, exit0. Semgrep CE1.183.0 runs296
rules over those24 explicit targets with OSS-only, strict/error mode, metrics/version checks
off and nosem disabled:1 candidate,0 errors, exit1. It is the **unchanged test constraint**
in authorization_postgres_test.go, formatted with a generated numeric uint fixture ID;
no external string/identifier enters that SQL. It is retained unsuppressed and triaged
as no injection path. The new snapshot table list is also a fixed literal list. All new
production object/token/boolean values use parameters. Gosec2.30.0 with -nosec covers13
production files/3271 lines:0 issues/errors/suppressions, exit0. There is no global scanner
or hosting-security acceptance claim. Raw argv, rule/config paths, findings and source
hashes are in `scans/results.json` and raw tool JSON/stderr. No candidate was hidden.

The shared fixture is billington-driver-pg-20261102, container1577f8dd92237f6e5a7139ef5ffda01dc3fbedbe00c927ec606c2eac28053d81,
owner label codex.driver=6f0c2a94-9d95-49ea-95a3-ff8ea3e558c7, loopback127.0.0.1:51168,
dedicated DB/user billington_test, PG17.11; inspection matched the supplied provenance
billington-structure-evidence/postgres-qa.json. The integration-only shared harness rejects
unsafe/missing DSNs and caller schema/options, creates/drops only exact owned random schemas,
and initializes current schema with the actual0001 runner. No shared/normal data reset or
fixture stop occurred. The cleanup query checks only observed exact generated namespaces;
its final count/result and read-only argv are in `final/cleanup.json` (refreshed after controls).

## Documentation impact and changed files

| Document | Impact | Action |
|---|---|---|
| docs/backend-api.md | Atomic finalize/replay, state/capability/payment/error policies | Updated contracts without changing response shapes/routes |
| docs/technical-overview.md | Transaction owner, lock order, projection/assignment seam and limits | Updated ownership and remaining currency/identity limits |
| backend/README.md | PostgreSQL lifecycle proof and operational reading | Updated test coverage/evidence links |
| VERIFICATION.md | Lasting lifecycle/measurement selection | Same exact affected rows;20407 bytes (<20KiB); integrated baseline/Last verified untouched |
| bugs.md /features.md | Fix/Implementation/Docs evidence | Official writer only; both in-progress, entries<2500 bytes; unrelated entries/proposals preserved |

No CHANGELOG entry or ticket migration/full V&V was performed. Exact changed source/doc
content hashes are in `final/source-doc-manifest.json`; the implementation paths are:

- `VERIFICATION.md`
- `backend/README.md`
- `backend/internal/bill/accounting.go`
- `backend/internal/bill/accounting_test.go`
- `backend/internal/bill/assignments.go`
- `backend/internal/bill/create_request_test.go`
- `backend/internal/bill/handler.go`
- `backend/internal/bill/repository.go`
- `backend/internal/bill/repository_test.go`
- `backend/internal/bill/service.go`
- `backend/internal/bill/service_test.go`
- `backend/internal/tab/authorization_integration_test.go`
- `backend/internal/tab/authorization_postgres_test.go`
- `backend/internal/tab/commands.go`
- `backend/internal/tab/creation_authorization_integration_test.go`
- `backend/internal/tab/handler.go`
- `backend/internal/tab/handler_test.go`
- `backend/internal/tab/lifecycle_postgres_test.go`
- `backend/internal/tab/lifecycle_shape_postgres_test.go`
- `backend/internal/tab/repository.go`
- `backend/internal/tab/repository_test.go`
- `backend/internal/tab/service.go`
- `backend/internal/tab/service_test.go`
- `backend/internal/tab/settlement.go`
- `backend/pkg/mutation/errors.go`
- `backend/pkg/mutation/errors_test.go`
- `bugs.md`
- `docs/backend-api.md`
- `docs/technical-overview.md`
- `features.md`

## Acceptance limits

Independent AUTHZ/LOGIC review and driver acceptance remain pending. Production adoption,
backup/restore, signed-client compatibility, old-writer drain/exclusion and actual deployed
source identity are unverified. The source guarantee requires cooperative writers. The
positive-only USD GetTab fallback, legacy net/missing-payer presentation, stable participant
identity/name impersonation and receipt replay/save remain with their approved owners.
Neither existing paid flag confirms payment. No Vercel/Render auth/inventory/config/manual
deploy/hook/rollback, customer data operation, publication workflow mutation or other
provider action occurred. The parent owns public checks. Local scoped success does not
change whole-program acceptance or authorize deployment.

## Commit and remote binding

Implementation commit: `c5a9ba1199b1484faa66b99530c034272bbe121a`, sole parent
`13be27bd6c2ec763c21e7ce1cbc44719f5f90e69`,31 authorized paths. Effective author and
committer were verified before commit; stored identities are both Victor Ivanov
<victor.n.ivanov@gmail.com>. The commit hook reports zero tracker errors/warnings.
The staged diff SHA256 is `c07907496a38358e20f4795ba95e5168f309bd45aefb84efa45952b80fbed6e0`;
the content manifest pins each source/doc file. Source hashes match scoped scanner inputs.

A normal push advanced only `refs/heads/chore/billington-foundation-program` from
13be27b to c5a9ba1. The very next tool action linked the existing PR159 successfully.
Independent `git ls-remote origin refs/heads/chore/billington-foundation-program` then
returned `c5a9ba1199b1484faa66b99530c034272bbe121a`, equal to local HEAD. Raw remote proof
and effective/stored identities are in `final/implementation-remote-proof.json` and
`final/commit-identity-*`. This test/evidence follow-up records that observed
source binding; the driver's complete ATOMIC_LIFECYCLE_RESULT.md records the final
follow-up SHA and post-push equality. No application source changed after c5a9ba1.

The push server reported three vulnerabilities on the repository's **default branch**
(two critical, one high). Branch-scoped govulncheck reports none. These are distinct
scopes; the banner is retained, not represented as a whole-program security pass.
Public application/deployment checks remain parent-owned and were not performed here.
