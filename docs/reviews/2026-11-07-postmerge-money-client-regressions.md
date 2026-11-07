# Postmerge accounting and client regressions — 2026-11-07

This manager-approved source checkpoint starts at merged main
`22eb43d8e33af1731fb1702d6ddd1f30bf3ca802`, whose tree equals reviewed
`9a09b67a2abb81741e4d9d53d23971a058cc3c19`. It covers backend SPEC-001/002,
mobile SP-1/4 and the exact manager-owned browser SP-2 correction. Other review
findings, including delivery process ownership and foreign-currency payment links,
remain separate. All five new tracker entries stay in-progress until integrated V&V.

## Accounting

The new Go regression calls the actual `CreateBill`, persistence preflight and
`FrozenUSDShareCents` owners, replacing only the database write with the maintained
in-memory repository. Before correction, subtotal $18.50 / tip $2.775 / total $21.275 and the
documented one-cent-tolerance example both save and then fail accounting review;
the exact-cent control passes. Creation and frozen allocation now use the same
accounting tolerance. Valid legacy, fresh-reference, unclaimed and partial inputs
remain accepted; a $9.994 partial share of a $10 receipt remains 999 cents. The insert
guard refuses malformed, negative or overallocated share evidence before persistence.

The second real creation regression demonstrates both a negative tax component on
a zero-tax participant and rejection of a valid zero-total participant. Negative
remainders now skip zero balances in the existing claim/name order. Whole rounds
are collapsed with bounded participant work; insufficient/invalid balances fail
without manufacturing negative obligations. Signed discount item details remain.
An independent small one-cent oracle and huge-count controls cover the allocator.
No historical negative component or other stored amount is rewritten.

The final affected `go test -race -count=1 -json ./internal/bill ./internal/tab`
row passes 532 named records, zero failures/skips. Earlier setup errors are retained:
CGO disabled hits the real SQLite driver's stub, and the initial CGO enabled command lacks a C
sysroot. The successful command uses the installed CLT compiler/MacOSX sysroot and
cached Go 1.27.3/modules, offline. No toolchain or dependency was acquired.

## Trip history and receipt timestamps

Real Drift tests first demonstrate 31 returned import IDs backed by only 30 rows,
eviction of a later existing target, and partial refresh after a later parse error.
The history reader also hides a database failure as an empty list. The corrected
import protects its complete incoming set and transactionally checkpoints local
tab IDs. Capacity stays 30; pending/referenced rows are retained. A capacity, parse
or checkpoint failure rolls back the whole pass. The screen clears loading in
`finally`, offers retry, and withholds partial totals/finalization on incomplete reads.

The maintained Drift 9 SQL fixture has a literal table default 1793912155. The new
receipt test fails against it before the fix and passes when insertion supplies
`createdAt` explicitly. No schema version, migration, backfill or historical row changes.

The affected ten-file Flutter row passes 116 visible cases with 126 complete
start/terminal pairs, including loaders, and runner success. It includes 11 new
capacity/timestamp cases plus existing save, retention, identity and tab controls.
The 30/31 boundary, independent pending/referenced history, late-target retention,
invalid IDs, parse/checkpoint rollback and UI failure/retry are covered. The two
braces-only analyzer corrections after that row are recorded separately; they do
not change control flow. No whole-mobile or native acceptance is inferred.

A separately reviewed test-only correction replaces both fixed 100 ms waits in
`full remote history offers retry without partial person balances` with a resettable
final members-read completion witness and a 10-second failure bound. The same
`tab_import_capacity_test.dart` file then ran once:10 visible cases PASS with11
complete starts/terminals, including the loader; no failure, skip or error. Analyzer
passes, and formatting leaves the approved `fe1a3db25aff` test bytes unchanged.
The correction receipt is `widget-completion-witness-01/CORRECTION_RESULT.json`
(SHA256 `728039dcaea7d67a71f3c51dacc8779c44605398755bd6d4cdd16f462e5ed3ae`).
This is separate focused evidence, not a rerun of116 or the Go/controller/web rows.

## Browser and gate registration

The exact SP-2 patch splits selection, suggestion seeding and member recovery by
their actual owners. A recovery success clears only its own warning. Manager's
baseline 4 intended failures, 4 fixed passes and full 102-case web row remain retained.
The integrated source separately passes the same four actual component/handler
regressions, TypeScript without incremental output, and Biome on the two changed
files. The existing Vite config warning is retained. This is injected React hook
dependency/cleanup coverage, without a browser scheduling or pixel claim.

The manifest adds three ordinary Go families to backend and PostgreSQL, two mobile
families, and one web family. Exact literal requirements cover 32 accounting children
in each Go namespace, 11 mobile cases and 4 browser cases. Existing family/selection
omission controls remain, and new independent omission fixtures keep the parent,
other children and inherited families present. Removing only these additions
restores the previous complete JSON and serialized bytes. The same 42 maintained
controller methods remain. The final offline row has 42 method starts/terminals and
1121 subtests: 1163 unique passing records. It executes 64 accounting-child omissions
plus 11 mobile and 4 browser omissions; inherited 140 assignment, 5 migration and 15 UI
omission controls remain. Final receipts and both earlier fixture-error rows are
retained in the owning evidence directory; no predicted suite total is awarded.

## Evidence and remaining gates

Owning receipts:
`pr159-money-client-followup-20261107/` in the original integrator's ignored scratch.
They retain raw red/green Go and Flutter reports, manager SP-2 hash bindings,
integrated browser/static results, controller attempts, tracker-writer receipts and
source/protected-path equality. The first controller attempt used an incorrect
synthetic report basename. Its successor exposed that omitting a family's sole case
also removed family presence; an independent synthetic family witness now isolates
literal enforcement. Both failed rows are retained without changing the gate/parser.

Manager combined-scope review accepted this focused implementation and its
separate completion-witness correction for a normal feature checkpoint. It does not
award real PostgreSQL creation/finalization, full current CI/V&V, performance,
resource, security, native build/signing/capture, App Store or release acceptance.
The previous six-row 9a09 result belongs to its unchanged merged tree and cannot be
carried to these changed app/backend inputs. No Render/provider inspection, real
PG/service access, Appshot pause/contact or dependency acquisition occurred during
this validation. The approved commit and feature push do not award those gates;
new automatic CI must qualify the committed source. Historical failures remain retained.
