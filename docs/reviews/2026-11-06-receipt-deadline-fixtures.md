# Receipt deadline phase fixtures

This is a test-only continuation of BUG-1793644508. Production receipt service,
native transport and its real 45-second deadline are byte-identical to c437469.
Original test IDs, complete POST and disconnect witnesses, same-service explicit
retry, separate client ownership, wire counts and cleanup joins remain required.

The original native timeout case now selects its logical100-ms deadline only
after the real complete POST arrives within the unchanged two-second bound.
It still requires typed failure, exactly one POST, peer disconnect within400ms
and zero owned resources before independent test cleanup. A new real100-ms
held-setup case requires zero POSTs and observes exactly one production close,
completed production join and zero resources before any test dispose/finish.
The independent finish exists only in finally; it cannot hide a missing join.

The stalled TLS deadline case retains the first attempt's real350-ms timer.
Only the healthy retry uses a test clock at the same logical350-ms value with
elapsed held at zero. It proves success and cancelled timer ownership, not a
350-ms response SLA. Cancel/dispose variants retain real clocks. The same
service must use two distinct clients/connections and exactly one subsequent
POST. The clock fixture intercepts only its selected operation timer and delegates
all observation/cleanup timers. Real wire prerequisites are never optional.

Independent manager source review approved the correction with Standards0/Spec0,
resolving IO-FIX01; reviewer application execution was NOT RUN. Final formatting
and affected analysis exited0. The source-bound positive selection passed7/7,
including both corrected cases, the new setup case, existing client-close and
final-check cases, parser and real TLS manual-retry controls. It has13 complete
starts/terminals with no skips, errors or missing cases.

Five separate temporary production-guard removals produced eight intended matcher
failures and five healthy parser successes. They discriminate timeout callback,
client close, joined transport, timer cancellation and final elapsed check.
Every suite loaded successfully before its target cases. No compile/setup error,
TimeoutException, missing terminal or skipped case was credited. Test finalizers
independently closed and joined resources; exact production bytes were restored
after every removal. The canonical manifest adds only the new real-setup case.

Raw commands/reports, hashes and cleanup are retained in task scratch
`layout-and-io-integration-20261106/revision-04/`: READY3b1108bb,
RESULT2680665d and ROOT_CLEANUP_AUDITa0c90091. All seven owned groups and task
TMP/PKI were independently absent and permissions revoked before host release.
The earlier controller failures, original d6 full Flutter RED and its two passing
classification cases remain immutable. Those historical causes are unproved.

The subsequent combined3460d692 full Flutter row passed567 visible cases/573
canonical records; see the [scoped acceptance](2026-11-06-combined-flutter-acceptance.md). These results
establish neither real45-second wall-clock performance nor native/device/signed
qualification, memory plateau, durable allowanceB, provider spending, old-writer
safety or integrated/release acceptance. BUG-1793644508 stays in progress; no
tracker migration, provider/account action or publication is authorized here.
