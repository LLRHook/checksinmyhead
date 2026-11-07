# Authorization review corrections — November 2, 2026

Affected local gate: **GREEN**. Full program acceptance: **RED** for the separately
recorded Flutter locked-acquisition and retained-runtime-image findings. Both authorization
tickets remain **in-progress**; independent driver review and integrated acceptance are
pending. This is a scoped implementation/security change gate, not a whole security audit.

Requested comparison snapshot: `2ef71382edfa20fefa6cc09db025c59acbc086da`.
Implementation parent supplied by the driver: `68b1a6d683bcd0b85061c15f7be8a381fece87a1`.
Those trees differ only in AGENTS.md's personal-project email; application sources match.
Correction source/test commit: `28eab76de64fcae9f0eca42d582d8bd1a4ab5696`.
Use snapshot comparison (`git diff <base> <head>`), preserving the supplied historical refs.
The lead made no branch/checkout/worktree switches or history rewrites.
At delivery preflight origin still points to the requested 2ef7138 snapshot, whose ancestry
differs from the driver-supplied local parent. The final handoff records the normal-push
result; publication is not accepted without a matching remote SHA. No force push is authorized.

Authority: the driver's AUTH_CORRECTION_APPROVAL.md accepts all three AUTH_REVIEW.md
findings under the earlier content/authorization contract. Victor's latest explicit
instruction overrides historical approval emails: new author and committer are
Victor Ivanov <victor.n.ivanov@gmail.com>. Effective identities were checked before commit.
AGENTS.md already contains this identity at the implementation parent and is retained.

## Corrections and preserved contracts

1. The creation service owns validation and share derivation once, before its trusted
   HTTP display-preparation callback, frozen USD quoting, or persistence. A small private
   raw calculation retains subtotals, charge components and positional item details for
   projection validation and rounding. Finite/bounded raw per-person and aggregate
   obligations are checked before allocation. Assigned subtotal may exceed the receipt
   only by relative floating-point noise (`subtotal × 1e-9`), preventing the absolute
   receipt tolerance from amplifying proportional tax/tip. Rounded obligations are checked
   again. Conversion to int64 cents, sums and subtraction reject overflow. Remainder
   distribution uses quotient/remainder in one participant pass, preserving recent-claim
   and alphabetical tie order. Calculation errors propagate out of both claim transactions
   so old shares and assignments roll back together; no person or invalid amount is dropped.
2. Display currency retains the pre-authorization provider's actual validation: normalize
   case/whitespace, require three bytes, then let the independent display provider resolve
   the pair. Source was verified in `81a564f:backend/internal/currency/service.go` and its
   pre-change handler. The six frozen receipt codes and receipt-provider validation are
   unchanged. Fakes prove USD to every twelve mobile choices, including PEN/AUD, plus ZAR
   (demonstrating no invented twelve-code API whitelist). Failure, zero/negative/nonfinite
   rates and display-total overflow return 503 with no write. No provider consolidation,
   frozen/display metadata migration, JPY policy, schema or dependency changes were made.
3. Nested share ID/FK/paid/detail tests now prove an otherwise-valid counterpart returns
   201 before adding exactly one forbidden field. Real repository snapshots assert no
   inserted graph, victim changes, reparented children or victim disclosure. Active/finalized
   tab, participant, item and assignment controls remain. Ten actual mobile-builder
   fixtures assert each person's subtotal/tax/tip/total and ordered item details, including
   zero Birthday shares and signed/repeated lines. Explicit expectations preserve existing
   server cent ties where client fractional projections differ by a cent. History summary,
   fractional/custom tip and partial lazy contracts remain valid.

Mandatory source/destination proof, response token stripping, tab-before-bill attachment
locks, destination-scoped membership, attribution-preserving retries and stale standalone
claim predicates remain covered by the full existing suites. Stable identity and atomic
finalization remain separate tickets, as do provider startup and metadata composition.

## Executed evidence

Toolchains: module Go 1.27.3 via GOTOOLCHAIN=auto, Flutter 3.41.5 / Dart 3.11.3,
PostgreSQL 17.11 at the task-owned loopback fixture. No dependency installation.
Raw logs, overlays, counts, stack profile and doc search are under ignored
`.vv/local-gate/auth-correction/`. Test counts below come from Go JSON and Flutter machine
reports; leaf counts exclude parent subtest containers. Tagged tab counts overlap the
ordinary Go suite and must not be added to it as unique tests.

| Command, directory | Actual result |
| --- | --- |
| `go test -race ./... -json`, backend | 105 top-level / **316 leaf passed**, 0 failed, 0 skipped |
| `go test -race -tags=integration ./internal/tab -json`, backend, test DSN set | 52 top-level / **157 leaf passed**, including **16 PostgreSQL-specific**, 0 failed/skipped |
| `go build ./...`, backend | Exit 0 |
| `go vet ./...`, backend | Exit 0 |
| exact CI gofmt check from VERIFICATION.md, backend | Exit 0; no drift |
| `go run golang.org/x/vuln/cmd/govulncheck@v1.7.0 ./...`, backend | Exit 0; 0 reachable/imported-package vulnerabilities; 3 module advisories outside the called code |
| `flutter test --no-pub --machine test/unit/services/api_service_currency_test.dart`, mobile | **5 tests passed**, 0 failed/skipped; real builder matches all ten captured payloads |
| `python3 .cycle/trackers.py install`; `lint`, root | Installed clone hooks; lint 0 errors/warnings |
| `git diff --check`, root | Exit 0 |

The unchanged PostgreSQL harness requires only BILLINGTON_TEST_POSTGRES_DSN, rejects
nonlocal hosts/non-test databases/caller schemas, and generates unique schemas. The two
runs created 21 task-owned schemas in total. A read-only pgx probe checked those exact
names: **0 remain**. The shared fixture was left running. A missing-DSN selection of
`TestPostgresCreationMoneyBoundary` fails (1 failed / 0 skipped), as required.
New PostgreSQL tests cover small/near-zero/zero denominator controls and transactional
rollback on calculation failure for standalone and attached bills. Existing lock-wait,
retry, finalization-state, membership and stale single/batch claim cases still pass.
The existing measurement test used ten samples at each of 1/100/500 items and
10/1,000/5,000 assignments: four creation and four attachment data queries at every size.
This is local race-build/query-shape evidence, not a production latency/capacity claim.

### Safe before and control-removal proof

Before runtime edits, focused tests produced **6 expected failing leaves**, 0 skipped:
small/tiny-denominator service and HTTP cases reached quoting instead of rejecting;
PEN returned 400 instead of the expected unconfigured-provider 503; the original clean
share-ID counterpart itself returned 400. Logs show the finite 2.02 and 1,000,000 derived
obligations before the unavailable fake quote. They do not claim those service probes
persisted money. The driver's separate real-HTTP/PG observation persisted **2.02** on a
**1.01** receipt, in `billington-structure-evidence/money-review-regression.json` alongside
`billington_money_probe.py` in the approved task scratch. That historical record is retained.

Five temporary Go `-overlay` variants remove only the relevant controls from copied files:

| Removed/restored control | Expected failing leaf cases | Other selected passes |
| --- | ---: | ---: |
| Receipt denominator/total-budget checks | 4 | 2 aggregate-bound cases retain their independent protection |
| Raw aggregate bound | 1 | 0 |
| Strict JSON decoder: nested share ID/FK/paid/detail | 4 | 0 |
| Restore mistaken six-code display whitelist | 8 | 6 already-supported currencies |
| Cent conversion guard | 1 | 0 |

All five commands exit 1 for the asserted reason: **18 expected failing leaf cases**,
not an application-gate failure. No weakened file was staged. The enormous-loop HTTP
input was never executed. The extreme denominator is tested only by raw pure calculation
before any allocation; large positive/negative/MinInt64 remainders are tested only through
the new bounded three-participant distribution helper, never through the historical loop.

## Scoped review and security gate

Standards: 0 blocking findings against AGENTS.md, docs/contribution.md or the code-review
smell baseline. Spec: 0 unresolved findings in the three approved corrections. Review was
performed sequentially by this implementation lead; a new independent review remains due.

Security gate: **PASS with NOT RUN: Gitleaks, Semgrep, gosec** (not installed).
Triggers: HTTP content boundary, property authorization, money, transaction side effects.
Tests: full Go/PG suites plus 5 control overlays; all corrected abuse counterparts succeed
before exactly one forbidden field is added. Sibling sweep: standalone read, single/batch
claims, paid writes, and tab attachment/claim/paid routes checked. Existing finalization,
name identity and SQL-log secrecy limits remain BUG-1793644504/4505/4509, not waived here.
Diff secrets regex: 3 hits, all reviewed synthetic test fixture fields; 0 real secrets found.
SAST: NOT RUN (Semgrep/gosec); IaC: n/a, unchanged. Govulncheck is the scoped dependency
result above, not a whole-audit completion. No SECURITY_AUDIT.md baseline was advanced.

## Doc impact and remaining gates

Doc-sync searched 8 impact keys in 31 tracked Markdown files. Dated plans/release notes,
the frozen baseline ledger, historical authorization evidence and CHANGELOG remain unchanged.

| File | Impact | Action |
| --- | --- | --- |
| docs/backend-api.md | Derived money and independent display-code validation | Documented exact bounds/order/failure behavior |
| docs/technical-overview.md | Creation ownership and checked share calculation | Documented single preparation and rollback flow |
| VERIFICATION.md | PostgreSQL coverage and dangerous-input boundary | Added safe cases and pure-calculation-only rule |
| This note | Correction approval and executed evidence | Added point-in-time record |
| backend/roadmap.md; tasks/lessons.md; dated plans/release notes | Matching historical/still-accurate references | Retained; no new change-induced drift |
| bugs.md | BUG-1793644497 / BUG-1793644498 | Official writer updated Fix/Docs/evidence; both remain in-progress |
| AGENTS.md | Latest personal-project identity | Already corrected by driver; retained |

Full acceptance remains RED for the recorded Flutter locked-acquisition and retained-image
findings. The `--no-pub` builder run does not pass locked acquisition. No fresh full Flutter,
viewer, runtime-image scan/build, GUI, migration, public-binary, live provider or deployment
result is attributed to this correction. Wider integrated V&V and independent driver review
remain due. Original untracked reports, mobile/android/ and artifacts/ were not staged or
used as implementation targets. No PR, merge, deploy, upload or cloud mutation occurred.
