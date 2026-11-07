# Local workflow review corrections — November 3, 2026

Scope: the three medium findings in the independent local-workflow review of
`fb6b4b9 → 5f4be44`. Correction base is `29ef3856a0af179a8ab6994538b7b77973b6bc22`;
its local CLI files equal the reviewed version. Root corrected these findings
directly. BUG-1793644513/4514 remain in progress for independent acceptance.

## Behavior and ownership

- Failed Compose inventory propagates its actual status. Before-start failure cannot
  authorize takeover. After-start failure retains pending ownership; bounded cleanup
  retries exact discovery. Persistently unavailable inventory produces a manual
  inspection diagnostic, without guessing IDs or reporting successful cleanup.
- Interactive Flutter retains terminal input while the Bash driver supervises Flutter
  and Next.js. Direct driver TERM/INT preserves143/130 without requiring `q`; a web
  failure preserves its original status. Owned process groups receive TERM, a shared
  two-second grace period and then KILL/reap. Existing running services are preserved.
- Docker and simulator probes run under the remaining monotonic stage deadline,
  including blocked commands and their descendants. Cancellation interrupts the
  driver's builtin wait. Acquisition remains explicitly requested and cancellable;
  readiness still defaults to90 seconds, configurable1–180. Version probes have
  separate named budgets. No GNU timeout, package, dotenv evaluation or service
  orchestration framework was introduced.

`dev.sh` retains service policy; the Python stdlib helper provides process/terminal
primitives. Compose project/volume identity, reset guards, selected-simulator policy,
default service names and the explicit legacy profile are unchanged.

## Executed evidence

All service/acquisition/simulator tools in the CLI tests are synthetic. Bash, PTYs,
signals and fixture-owned child/grandchild processes are real.

| Selection | Actual result |
| --- | --- |
| Pinned before diagnostic |11 cases:8 expected assertion failures,3 passing controls; all intended boundaries reached, no setup failures/skips |
| Final `python3 scripts/test_local_workflow.py` |55 distinct tests:43 retained +12 added;0 failures/errors/skips;121.205s |
| Added coverage |2 inventory faults, persistent inventory/manual action,4 blocked probes,2 probe cancellation signals,3 interactive TERM/INT/web-failure cases |
| `scripts/verify_local_lifecycle.py --postgres-image sha256:<local-image-id> --output <owned-directory>` |5 real PostgreSQL assertion groups pass; owned project `billington-test-local-d615e3c26074` removed |

The real lifecycle selection executes the maintained Makefile through the existing
fixture adapter. A sentinel survives ordinary down/restart; normal-project, wrong-owner
and unconfirmed-volume resets reject before deletion; explicit owned reset removes
only synthetic data. Its cleanup receipt is true. Shared driver PostgreSQL and ordinary
volumes were preserved. This is separate from full application startup.

Failed intermediate runs remain in the driver evidence. The first correction run had
two one-second prerequisite-budget failures and a three-second overall cleanup limit
failure. Separate prerequisite budgets and bounded two-second process cleanup corrected
those source issues. A subsequent blocked-getenv observation exceeded the diagnostic's
three-second whole-driver limit while its probe did time out. Lasting tests allow five
seconds for the one-second stage plus cleanup. The first full run exposed a stale
Compose-version stub interface; the command now retains `docker compose version` without
an irrelevant file argument. The final55-test run is the passing result above.

Raw records: driver's `billington-structure-evidence/local-workflow-correction-29ef385/`,
`workflow-correction-full-{first,final}.log`. Original before observers/setup attempts
are retained separately and not counted as successful witnesses.

## Documentation and limits

| Document | Impact |
| --- | --- |
| README.md | Probe deadlines, pending ownership, interactive supervision and cleanup |
| backend/README.md | Test scope, helper ownership and manual inspection instructions |
| docs/technical-overview.md | CLI/helper boundary |
| bugs.md | Scoped evidence only; no CHANGELOG migration |

No real Flutter/simulator/full-stack journey, hosted artifact, signed client or cloud
configuration was tested. No provider control plane or publication action occurred.
Independent correction review and integrated acceptance remain pending; global RED.
