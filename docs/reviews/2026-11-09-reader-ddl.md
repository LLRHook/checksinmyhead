# Warm readers across additive DDL — November 9, 2026

Scope: BUG-1793861425. Base `e0a2c18` (on main `5e877e3`). Synthetic data only; no
production write, deploy, hook, setting or policy change. Production was read twice:
`GET /health` reports commit `81a564f687067ab1d839d623dd5c1c01ae139d5f`, and
`GET /api/app/version-policy` has no `capabilities`. That revision predates the
migration registry: it runs GORM AutoMigrate and reads with `SELECT *`.

## Mechanism

PostgreSQL rejects a cached prepared statement whose result row type changed
(SQLSTATE `0A000`). pgx v5.10.0 (the pinned driver in both the deployed and current
revisions) drops a statement from its cache after any error, so the failure is
**once per cached statement per pooled connection**, then that statement is prepared
again and succeeds. It is not persistent and needs no restart. Only table-shaped
results (`SELECT *`, `t.*`, `RETURNING *`) are affected; an explicit column list keeps
its row type when columns are added.

## Current revision: no failure

`TestPostgresWarmServiceSurvivesAdditiveDDL` (`backend/cmd/bill-service`, integration
tag, PG17.11) keeps one service connection, observes its backend PID through the
driver tracer, and makes 15 reads through the production router and the retained
HTML handler: bill wire1/wire2/unversioned, HTML, open and finalized tab,
members, member self, settlements, health. A separate session then commits one owned
nullable column on all nine application tables in one transaction. Afterwards:

- all 15 bodies are byte-identical, on the same PID, with zero statement prepares
  (every read reused its cached statement) and zero SQL errors;
- a `SELECT *` discriminator cached on that same connection fails exactly once with
  `0A000` and then recovers, so the fixture really invalidates result shapes;
- a second complete graph is created and read through the warm writers (create, lazy
  claim, participant create, share paid, tab create/join/attach/rename, member
  rename/leave, finalize, settlement paid): zero errors, zero prepares, same PID, and
  no table-shaped projection in any statement sent.

No production code changed: the complete explicit projections in
`backend/pkg/models/columns.go` are the smallest correct design. A simple-protocol or
describe-per-call exec mode would add a round trip or lose plan reuse on every query,
and a retry on `0A000` would have to exclude every mutation. Neither is needed.

The test fails without those projections. Each of seven single-site removals
(bill root, participant/share/assignment preloads, tab root, settlement history,
share row lock) turns a warm read or write into HTTP 500 at the test's assertion;
all seven sources were restored. Command, 3 runs under `-race`: 3/3 pass.

VERIFICATION names this proof ("same observed warm PID ... owned additive columns") but
the repository had no test for it; the earlier note records the stage as not run.

## Deployed revision `81a564f`: bounded transient failures, and an unsafe overlap

Exact `81a564f` API and HTML binaries (Go 1.27.2, pgx v5.10.0, gorm v1.31.2) ran in
owned containers against an owned PG17.11, created their own schema, and were warmed
over HTTP (280 concurrent reads, 7 pooled sessions). The current binary then ran
`--migrate-only`: it adopted the legacy schema and applied 0002 and 0003 (ledger
1,2,3, exit 0). The old processes were never restarted.

| After DDL | Sequential reads, 7 routes x 12 | 10-way burst, 280 reads | Tail, 35 reads |
|---|---|---|---|
| Nothing else | bill and HTML: 4 x 500 then 200; tab and settlements: 1 x 500; 74/84 OK | 23 x 500 | 35/35 OK |
| Old sessions terminated, idle over 1 s | 84/84 OK | 280/280 OK | 35/35 OK |
| Old sessions terminated, reused at once | 7 x 500 (one per dead connection) | 280/280 OK | 35/35 OK |
| Old processes restarted | 84/84 OK | 280/280 OK | 35/35 OK |

Affected statements are the cached `SELECT *` reads of the five tables that gain
columns: `bills`, `bill_participants`, `item_assignments`, `person_shares`,
`tab_settlements`. `tabs`, `tab_members`, `bill_items` and `people` keep their shape.
A bill read fails four times per connection, one statement at a time. Worst case is
(cached affected statements) x (pooled connections, 10 per process by default); requests on a
connection opened after the DDL never fail. The current binary's `--schema-mode=verify`
still passes after the old AutoMigrate binaries restart on the migrated schema.

Connection replacement helps readers only when each terminated connection has been
idle for more than one second (pgx pings before reuse); otherwise each dead
connection costs one request. It needs SQL access at the moment of the DDL.

Overlap is unsafe for a second reason, observed and not repaired here: a bill created
by the old writer after 0003 gets the column defaults (`label=''`, no ordinal). The
current reader returns `409 client_upgrade_required` for that two-participant bill on
the unversioned and wire1 contracts (wire2 reads it as `legacy_review`); bills created
before the migration read 200. Connection replacement and restart do not change this.

## First publish

The old binary cannot be changed and migration 0003 is frozen, so the repository
cannot make live overlap safe. The supported strategy is exclusion: no `81a564f`
process may be serving when the new revision starts and migrates.

The delivery gate now observes this before the hook request
(`predecessor_clear`, [controls](../../ops/ci/README.md#existing-transports)): a
revision answering `/health` must be the same revision, have nothing pending in the
schema registry, or descend from the external `additive_ddl_warm_reader` capability
floor. `81a564f` can satisfy none of these, so the first publish is rejected while it
serves. One observation is not a drain proof.

Not done, and needing the owner: stopping the hosted service before the first
publish, and observing what the host answers for a stopped service and whether its
deploy hook starts a stopped service. Render's documentation gives its normal order
as new instance up, traffic switched, old instance signalled 60 seconds later, and
limits pre-deploy commands, one-off jobs, shell access and maintenance mode to paid
web services. Publication stays disabled by the unset `RELEASE_POLICY`.

Raw receipts (ignored scratch): `.vv/reader-ddl/` — seven control logs, four
old-binary scenario JSON files, binary hashes, gate case report (46 methods).
