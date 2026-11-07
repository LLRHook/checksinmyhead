# Migration outcome observation

The diagnostic defect is tracked as BUG-1793958334 in the [active tracker](../../bugs.md).

This is test-only diagnostic evidence against source
`8371d6fd835fd6acc08a6138385ae973f264acdf`. It does not qualify the real PostgreSQL
migration deadline, its required PgSleep witness, production cancellation or recovery.
The current registry remains1/2/3 with synthetic future4; the isolated fresh-self
0004/epoch2 candidate is excluded.

## Defect and source change

The original `TestPostgresMigrationParentDeadline` waited for activity before
receiving the migration result. A missing-witness Fatal could therefore prevent
inspection of a result already buffered by the producer. That lost test evidence
does not establish why the PostgreSQL witness was absent.

The reviewed holder retains one actual producer result and its original error,
independently of the activity observer. It captures before and after a poll,
attempts one bounded join, and distinguishes an unreceived or closed channel from
a successful nil result. Before an observation failure it logs finite outcome
classifications; only a joined producer permits the separate bounded rollback
read. Missing PgSleep still fails. The positive path keeps the real500ms caller,
10s observer,15s join, original DeadlineExceeded, whole-batch rollback and recovery
requirements. No production, SQL, registry or operation deadline changes.

The two adopted test files come from reviewed source packet fe039511, patch
`13926a96546f26e0614c7832be8bad2d2f19dbfcce7f296331612148524e316f`.
The qualified fixture hash is
`58b4521192ff5aa5f58bdb5d01a57f22339c00baa36924543f5c5da064e87345`.
The helper compiled at f9b2b5f8; normal Go formatting changes only alignment spaces
after seven evidence-field colons, producing388d4d4c. The expressions, assertions,
imports and literals are unchanged. The formatting diff and exact before/after
mapping are retained in task scratch `migration-outcome-integration-20261106/`.
This mapping is not a test execution against reformatted bytes.

## Actual bounded qualification

Corrected qualification packet fd34a40e ran once under activation c3862e11. Its
cached Go1.27.3 Darwin/arm64 command used CGO disabled, an offline environment and
a fresh task-owned cache/TMP. It compiled all four complete integration-tagged
migration package variants before any list/case invocation. All four compiles and
four anchored lists exited0. This is no race qualification or full PG run.

The clean `TestMigrationOutcomeObservation` parent and all five children passed:

- early_deadline_result_survives_missing_barrier
- observer_error_keeps_primary_outcome
- missing_result_remains_unresolved
- closed_channel_is_not_success
- barrier_and_single_receive_preserve_original_cause

Three separately compiled removals each exited1 at their intended assertion:

| Removal | Assertion failure | Healthy sibling |
| --- | --- | --- |
| original cause retention | early deadline loses original result | missing result remains unresolved |
| capture after observer poll | observer error discards producer outcome | barrier and one receive preserve cause |
| closed-channel rejection | closed channel accepted as nil success | barrier and one receive preserve cause |

Raw failure terminals and exit1 remain unchanged. The75 retained JSON events contain
15 complete test nodes:9PASS and6 intentional FAIL, including failed control parents.
There are11 leaf occurrences:8PASS and3 intentional FAIL, five distinct helper leaves,
and four package completions. Missing/extra/duplicate/skip and setup/timeout credit
are zero. A failure is discrimination evidence only when its exact assertion and
unaffected healthy sibling both reconcile.

The canonical PG manifest adds only the tagged helper family and five exact,
anchored, report-prefixed child IDs. The existing registration matcher uses a Go
runner ID when a display name is absent; named mobile/web matching is unchanged.
The existing offline mandatory-Go contract includes five independent child-omission
controls, retaining the parent, four siblings and every inherited family.
The complete offline controller CLI passed42 methods and916 method/subtest records,
including all five omission subtests and existing mobile/web named-selection
controls. No automation method/family was added or renamed. Official tracker lint
reported zero errors and warnings. A first documentation-size candidate was refused
at20484B before writing; the same-meaning verification paragraph remains20478B.

## Receipts and limits

Task scratch `migration-outcome-qualification-20261106/revision-02/` retains all
twelve START/RESULT/argv/exit/raw bindings. Retained reconciliation SHA256:
`fc98d254852bae053595508889ff98bfd2328d544a8c23f398f4a57de392bd90`.
The independent manager verification is1e3271a4. Root audit1473a73b and the independent
manager check prove owned group15041, all fourteen recorded PIDs and the private
workspace absent. Source615/app140/Git3/external920/tools10/packet57 and315 original
untracked paths remained exact. Authorities and both producer fences were released
before case analysis; Appshot coexisted, with no host hold.

Original unexecuted packet c59e8ee1 and its stale filesystem-field defect remain
retained. The separate correction's two initial mock-harness failures also remain
RED; its five current mock passes and predecessor assertion control are not Go
application runs. No historical failure was rewritten.

The real500ms/PgSleep/10s/15s/rollback/recovery case remains unexecuted and
credential-blocked. The earlier170s cutoff/198.64s supervision overrun, hosted
startup build failure, cumulative creation/tab600s alarms, incomplete measured
cohorts, resources/security/integrated gates and rollout remain open. Native build
acceptance is unmet; no task-exclusive macOS boundary is available. Native packets
remain historical8371 inputs with no rebind or new proposal. This checkpoint changes
no app140 inputs, ordinary Go source inputs, product contracts or release status.
The previously accepted8371 Linux ordinary row (1104 records) and3460 full Flutter
row (573 canonical records) are carried only through the preserved default-Go and
app140 inputs; neither row was rerun or presented as a new integrated pass.
The test-proof ticket stays open/in progress; no CHANGELOG migration or publication.
