# Authorization batch implementation evidence — November 2, 2026

APPROVED: the driver-approved Stage 2 plan in the current task authorizes
BUG-1793644497 and BUG-1793644498 together. This record covers implementation and
executed local evidence. It is not an integrated V&V, independent review, release,
deployment or public-binary compatibility acceptance.

Repository: checksinmyhead, branch chore/billington-foundation-program.
Starting HEAD: c346d2dbae6e5d464f9ed2d1b7476132cf897f61.
Reviewed runtime baseline: 81a564f687067ab1d839d623dd5c1c01ae139d5f.
Attachment commit: 4c146e8c586a460ced5d81ca40ee56239184b807.
Creation commit: 39d81cde03fdbf2dd341c565c18cd71b8532ceb7.
The accompanying evidence commit adds PostgreSQL integration tests, living docs and
tracker evidence. Both tickets remain **in-progress** because required security rows
are red. CHANGELOG and the frozen baseline ledger are unchanged.

## Implemented contract

- Creation binds an explicit, locally strict content DTO, requires name/subtotal/total,
  bounds the body and graph, rejects privileged/unknown fields including null/zero,
  validates accounting before quotes and builds fresh standalone associations.
- Service and repository guards reject associated/preidentified graphs. The service
  validates finite accounting and derives shares; the repository independently guards
  identities and ownership. Conversion overflow cannot reach persistence.
- Attachment takes credentials, never an attribution ID. The repository transaction
  locks destination before source, checks destination capability/finalized state and
  membership, unconditionally matches source ID/token, then attaches only a standalone
  source. Active same-target retries are no-ops after full reauthorization.
- Member creation/deletion takes the same destination lock. The standalone claim
  repository now includes tab_id IS NULL in its locked predicate for both handlers.
- Existing cent allocation is retained. Share item breakdowns remain populated, repeated
  descriptions retain array position, and zero-share participants remain present.
- Native monetary magnitudes/absolute item sums are bounded to 1e9; assigned net amounts
  cannot exceed receipt subtotal. ID validation matches existing 32-bit route parsing.
  There is no new dependency, schema migration, cache, provider or runtime framework.

## Red before / green after

Before production edits, the lasting handler → service → SQLite repository regressions
ran using the starting runtime. .vv/local-gate/auth-red.log records seven failing leaf
cases, including:

1. Omitted bill_token returned 200, changed ownership and disclosed the synthetic
   victim receipt/payment handle through the destination. Fixed behavior is 400 with
   identical parent/child state and no victim disclosure.
2. Otherwise-valid positive creation with a victim tab_id returned 201 for both active
   and finalized tabs and wrote rows. Fixed behavior is 400 with zero state changes.
3. Existing nested IDs were accepted. A later baseline-source Go overlay confirmed the
   exact database effect: item.bill_id changed 1 → 2, assignment.bill_item_id changed
   1 → 2, share.bill_id changed 1 → 2; the existing participant gained a second parent
   link. The fixed tests reject each field separately and preserve the original graph.

Seven independent source-overlay control removals produced expected test failures:
source ownership predicate, strict DTO field rejection, service fresh-graph guard,
repository fresh-graph guard, total accounting consistency, retry attribution no-op,
and stale standalone predicate. The repository guard removal executes against a
real SQLite fixture and demonstrates an unauthorized bill row, rather than relying on
a mock or invalid DB. Single/batch stale-claim removal returned 200 and changed claims.
Overlays stayed under ignored .vv/control-removal/; working production source was
never reversed and no checkout/worktree was created.

## Commands and actual results

Commands run from their specified tier; GOTOOLCHAIN=auto selects module Go 1.27.2.
The Node 24.22.2 toolchain prepared by the driver was prepended to PATH.
Counts come from Go JSON runner events and Flutter/Vitest output. Leaf counts exclude
parent test containers, so parent and child events are not double-counted.

| Directory | Command | Actual result |
|---|---|---|
| root | python3 .cycle/trackers.py install --auto; python3 .cycle/trackers.py lint | Clone setup; lint 0 errors/0 warnings |
| backend | go build ./... | Exit 0 |
| backend | go vet ./... | Exit 0 |
| backend | CI gofmt check | Exit 0; no formatting drift |
| backend | go test -race ./... -json | Exit 0; 94 top-level / 272 leaf cases; 0 failed/0 skipped tests; four packages have no test files |
| backend | go test -race ./internal/bill -run '^TestCreateBillDirectServiceAndRepositoryGuards$' -count=1 -json | Exit 0; final stronger DB-state assertions pass, 13 leaf cases |
| backend | go test -race -tags=integration ./internal/tab -json | Exit 0; 48 top-level / 147 leaf cases, 0 failed/0 skipped; includes 7 PostgreSQL-specific top-level / 11 leaf cases |
| backend | go test -tags=integration ./internal/tab -run '^TestPostgresAttachmentWaitsForCommittedFinalization$' -count=1 without test DSN | Expected exit 1 with explicit missing-prerequisite failure; never skips |
| backend | go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./... | Exit 1 (scanner exit status 3): reachable GO-2026-6809 in crypto/x509@go1.27.2, fixed in 1.27.3 |
| mobile | flutter analyze | Exit 0, no issues, Flutter 3.41.5 / Dart 3.11.3 |
| mobile | flutter test | Exit 0, 203 tests; final expanded builder fixture subsequently verified by targeted row below |
| mobile | flutter test --no-pub --dart-define=BILLINGTON_CAPTURE_CONTRACTS=true test/unit/services/api_service_currency_test.dart | Exit 0, 5 tests and ten actual builder contracts; updates only the scoped golden fixture |
| web-bill-viewer | npm ci | Exit 0, locked install; no manifest/lockfile change |
| web-bill-viewer | npm run lint | Exit 0, 35 files |
| web-bill-viewer | npm test | Exit 0, 52 tests / 3 files |
| web-bill-viewer | npm run build | Exit 1 after compile/type-check: known Next 16.4.0 security fatal |
| web-bill-viewer | npm audit --audit-level=moderate --json | Exit 1; one critical Next dependency entry with three advisories |
| root | git diff --check | Exit 0 |

The first web attempt found stale node_modules (Next 16.2.12/Biome 2.4.15); its build
pass was discarded as invalid evidence. npm ci restored locked Next 16.4.0/Biome 2.5.15
before the reported web rows. Flutter initially refreshed four SDK-constrained
transitive lock entries during fixture capture; those incidental lock changes were
removed. No dependency versions are part of this batch.

## PostgreSQL evidence and bounded work

The test-only DSN selected the supplied loopback PostgreSQL 17.11 fixture on port 51168,
database/user billington_test. Each test generated a fresh billington_auth_* schema.
The harness refuses nonlocal/fallback hosts, another database, caller schemas/options,
and absent prerequisites. Cleanup drops only its generated schema. It never calls
database.InitDB, drops public, reuses a developer schema or reads production data.

Executed cases use channels and observable PostgreSQL lock waits, without timing
sleeps: competing destinations yield exactly one association; same-target waiting
retry retains the first member and updated_at; committed finalization blocks a waiting
attachment; membership create/delete serialize with attachment; a newly created member
causes a waiting formerly-memberless attach to require membership; actual database
constraint failures roll back attachment and child creation. Both stale standalone
single/batch handlers are paused after their read, attached, then resumed; neither can
change assignments/shares.

HTTP create → attach measurements use ten synthetic USD samples at each size, under
the race detector on local PostgreSQL. Each creation and attachment uses four data SQL
statements, excluding transaction control, independent of item count. Creation batches
items/assignments/shares; attachment queries one destination, membership existence,
one source and one update. Requests with participants add their bounded association
inserts; no per-item external requests occur.

| Items / assignments | Create p50 / max | Attach p50 / max | Data SQL create / attach |
|---|---|---|---|
| 1 / 10 | 2.780 / 4.820 ms | 1.745 / 2.957 ms | 4 / 4 |
| 100 / 1,000 | 42.908 / 46.120 ms | 1.885 / 2.160 ms | 4 / 4 |
| 500 / 5,000 | 217.635 / 232.521 ms | 2.051 / 2.321 ms | 4 / 4 |

These measurements establish bounded access shape, not production throughput, a
before/after latency improvement or an approved production latency budget. Full-tab
read capacity remains FEAT-1793644502.

## Compatibility and security review

Ten golden requests come from the actual mobile buildBillRequest path, including
RecentBillModel reconstruction: normal, custom tip with stale percentage metadata,
fractional percentage tip, signed discount, fractional allocations/repeated names,
empty lazy, partial lazy, history with no items, history with unassigned items, and
legacy USD omission. Legacy omission matches release-v1.4.0 source's content graph;
the underlying builder calculation matches the current builder. This is source
compatibility, not execution of an installed historical/public binary.

All fixtures create standalone, attach with the returned source token and read through
destination capability without exposing source tokens. An unrelated standalone bill
remains inaccessible. Tests also cover a supported foreign quote via a fake provider
and a provider failure with no persistence. Old ?t=/?m= links, bearer/member headers,
opaque source token bytes, memberless legacy policy with source proof, custom tips,
zero/birthday shares and non-null item breakdowns are preserved.

Sibling sweep: both bill association write families converge on the repaired boundary.
CreateTab constructs a fresh graph and injected bills/members cannot attach existing
objects. Both standalone claim verbs share the repaired repository predicate. Existing
tab claim/paid/finalize/settlement/member routes and imports/retries were traced.
Atomic finalization remains BUG-1793644504; chosen-name paid authorization remains
BUG-1793644505; existing SQL token/payment logging remains BUG-1793644509. No new
out-of-scope sibling fix or deployed association path was introduced.

Security gate: FAIL (baseline dependency rows); scoped controls pass, SAST NOT RUN.
Triggers: AUTHN, AUTHZ, TEN-equivalent object isolation, VAL, API, LOGIC, SECRET/ERR.
Tests: 185 security/contract leaf cases in default Go selection plus 11 PostgreSQL cases.
Control-removal checks: seven expected failures; original baseline regressions red.
Scans: regex secret scan, 0 real secrets (56 synthetic test literals reviewed);
gitleaks, semgrep/gosec NOT RUN (not installed); IaC n/a; build/vet and govulncheck ran.
Findings: known Go vulnerability and critical Next entry block overall acceptance.
The API intentionally retains its existing 403 token convention instead of generic 401.

## Doc impact and acceptance boundary

| File | Impact | Action |
|---|---|---|
| docs/backend-api.md | Creation whitelist, valid arithmetic example, limits, independent source/member proof, no-op retries/errors | Updated |
| docs/technical-overview.md | Ownership of fresh creation, attachment transaction and standalone transition | Updated |
| VERIFICATION.md | New test-only PostgreSQL selector, safety/prerequisite contract and limited coverage | Updated procedure only; Last verified/count baseline untouched |
| docs/reviews/2026-11-02-baseline.md | Frozen historical mapping | Unchanged |
| bugs.md | Formal status/Fix/Docs evidence | Official writer only; both in-progress |

No pre-existing dated report was edited. The existing docs-drift ticket
BUG-1793644512 retains unrelated historical inaccuracies.

Implementation and integrated API tests are delivered for driver review. Overall local
gate is RED due to BUG-1793644503 and BUG-1793644502. Independent review, a clean/full
system protocol, actual public-binary/device compatibility and production budgets
remain unaccepted. The task prohibited new checkouts/worktrees, so verification ran
clean=no in the authorized checkout; no skill worktree/rebase recipe was followed.
No subagents, .github changes, deployments, uploads, cloud/credential changes, PRs,
merges, force pushes or CHANGELOG migration occurred. Original untracked reports,
mobile/android and artifacts are preserved. Prefer forward compatibility corrections;
reverting the authorization batch reopens both boundaries.
