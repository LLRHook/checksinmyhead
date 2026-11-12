# Migration parent deadline on real PostgreSQL — 2026-11-09

Scope: BUG-1793958334. Base `e0a2c18`; `backend/migrations` is byte-identical to the
hosted heads cited below. No source changed: this note records the real PostgreSQL
execution that the [2026-11-06 note](2026-11-06-migration-outcomes.md) left open. It is
not an integrated V&V pass and says nothing about production cancellation or rollout.

## Unmodified test

`TestPostgresMigrationParentDeadline` runs the real runner on a fresh owned schema with
a 500 ms caller deadline and a pending `pg_sleep(30)` step, a 10 s activity observer and
one 15 s join. It passes only if the `PgSleep` wait event was witnessed, the single
producer result joined and is `DeadlineExceeded`, the schema holds no relation (the
baseline, 0002, 0003, the pending step and the ledger all rolled back) and a following
`Apply` succeeds.

| Run | Result |
|---|---|
| Local, `go test -race -count=1 -tags=integration ./migrations -run` the test and `TestMigrationOutcomeObservation` | 7 run, 7 pass (parent 0.66s) |
| Local, same test `-count=20` | 20 pass, 0.63–0.71s each |
| Local, all seven `failure_postgres_test.go` families plus the helper family | 21 run, 21 pass |
| Hosted `checks / Gate postgres`, run 42364117584, head `3a52cb6` | pass, 0.79s; helper parent and five children pass |
| Hosted, run 42365246558, `main` `5e877e3` (row red only for the tab package alarm) | pass, 0.95s; helper parent and five children pass |

Local: Apple silicon, Go 1.27.3, shared synthetic PostgreSQL fixture on loopback, other
work running on the machine. Hosted figures are read from each run's `reports-postgres-1`
`go-postgres.jsonl`.

## Controls

Each is a temporary edit to the test alone, run once on real PostgreSQL and reverted;
the committed bytes are unchanged. Every control fails with
`required PostgreSQL barrier/outcome was not qualified` after logging the finite
evidence struct. Fields not listed are false.

| Control | Seconds | Evidence fields set |
|---|---|---|
| Pending step without `pg_sleep` (commits inside the deadline) | 0.14 | ResultObserved, JoinAttempted, RollbackObserved |
| Worker sleeps, witness predicate never matches | 0.56 | ResultObserved, ResultNonNil, ResultDeadline, JoinAttempted, CallerDeadline, RollbackObserved, RollbackEmpty |
| Observer query fails | 0.55 | the same, plus ObserverError |
| Observer query fails, no caller deadline | 15.07 | JoinAttempted, JoinUnresolved, ObserverError |
| Witness never matches, no caller deadline | 25.11 | JoinAttempted, JoinUnresolved, ObserverError, ObserverDeadline |

## Expected bullets

1. *One producer result and its cause survive an observer error; an unreceived or closed
   channel is not success.* The five helper children pass under `-race`, locally and
   hosted. On real PostgreSQL the observer-error control still reports the worker's
   `DeadlineExceeded`, and both no-deadline controls end `JoinUnresolved` with no result
   recorded.
2. *Missing PgSleep still fails; real 500 ms, 10 s, 15 s, whole-batch rollback and
   recovery are preserved.* The first two controls fail without a witness even though a
   result arrived, and a committed success is not accepted. The last two controls show
   the 15 s join and the 10 s observer followed by the join. The unmodified test passes
   only through the rollback and recovery assertions.
3. *Finite evidence is recorded; the rollback read happens only after the worker
   joined.* All five controls log only boolean classifications. The three joined
   controls performed the bounded rollback read; the two unjoined ones did not.

## Not covered

The full eight-package PostgreSQL row was not run in this session. The unmodified test
logs evidence only when it fails. The earlier 170 s and 198.64 s supervision cutoffs,
native build acceptance and the integrated run are outside this ticket's bullets and
stay open where they are tracked.
