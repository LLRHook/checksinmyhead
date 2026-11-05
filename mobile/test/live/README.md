# Matched client identity HTTP journey

This explicit functional selection uses the maintained `ApiService` builder/save owner,
real loopback HTTP handlers and an isolated PostgreSQL17.11 schema. The browser phase
executes compiled maintained `web-bill-viewer/src/lib/api.ts` with independent member
proof. It does not launch a browser or prove native Keychain, signed builds, public
rollout, timing budgets or complete identity acceptance. Atomic fresh-self binding is
not supported by the current backend/schema; create remains unbound and requests
require a creator/source decision.

Use the repository's locked Flutter3.41.5, Node24/npm11, Go and existing dependencies.
Coordinate the stage with the shared-host integrator first. The launcher rejects any
DSN except the reviewed test-only loopback endpoint; it removes inherited PG/DB options.
No backend file is written: a Go overlay adds only the anchored fixture test. Compile
and exact listing precede execution. The strict `testpostgres.Open` owns the random
schema/application name and normal migration runner. The launcher records the exact
scope and independently checks zero owned sessions/schema after cleanup. It never
kills PG sessions or drops a schema by prefix.

```sh
export BILLINGTON_TEST_POSTGRES_DSN='host=127.0.0.1 port=51168 user=billington_test dbname=billington_test sslmode=disable'
python3 mobile/test/live/run_participant_journey.py       # compile/list only
python3 mobile/test/live/run_participant_journey.py --run # one approved journey
```

The launcher prints its unique `.vv/cd-identity/http-*` output path. Reports include
Go JSON, Flutter create/recovery JSON, browser checks, runtime identity and cleanup.
Only synthetic fixture files/tokens are retained there; no customer/provider data.
Children run sequentially under bounded process groups. Review exact source SHA/diff
and runner reports; zero/missing/skipped cases are not a pass. An outer process kill
can bypass Go cleanup: read `owned-postgres.json`, ensure owned child groups/sessions
have ended, and clean only that exact schema. Never substitute a normal/public schema.
