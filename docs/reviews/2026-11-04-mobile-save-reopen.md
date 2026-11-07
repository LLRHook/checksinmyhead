# Mobile save and safe reopen — November 4, 2026

Source `a97137fa6192e53dfc7a3fe0a17bc65ae0fcdf01` implements the approved mobile
slice on the program branch. This is owner qualification, not independent/root
clean acceptance, a native pass or release authorization. BUG4500/4515 stay
in-progress; no CHANGELOG migration or Verified entry follows.

`RecentBillsManager` owns one native Drift9 transaction, immutable ordered request/
version, stable operation/key locator, saved share/presentation projection and
attachment intent. It returns the actual row ID, commits attempted state before
HTTP, and atomically checkpoints remote identity/link/frozen quote/USD total to
that exact row before presentation/attachment. Same-handle actions join; independent
identical receipts remain distinct. Done cancellation writes nothing. Offline,
response loss, local checkpoint, observer/presentation and attachment failures retain
truthful durable state. TabManager already did not create receipts at the inspected
base; its separate attachment orchestration now enters the same owner while tab
lifecycle/credentials remain there.

New publication sends only persisted bytes and a canonical43-character recovery
key. It fails closed on capability absence, unknown snapshot/key state and release
mode; it does not redirect, fall back unkeyed or automatically retry POST. A bounded
abortable request caps the creation response at64KiB and strictly validates its
persisted201 fields. Missing keys after an attempt cannot mint another identity.
Imports/ambiguous legacy rows are not automatic publication work. Capacity protects
pending/referenced rows and fails a new transaction when no safe eviction exists.
Native amounts, historical links/quotes and visible fractional JPY remain intact.
Currency review preserves evidence and requires explicit confirmation; offline foreign
entry can continue. The maintained `rate` decoder accepts finite positive integer/
float JSON numbers and retains independent display currencies such as ZAR. Pending
foreign valuation is unavailable; valid authoritative zero remains zero.

| Owner check | Actual result |
| --- | --- |
| Locked Flutter3.41.5/Dart3.11.3 acquisition, generated Drift9, analysis/affected formatting | Pass; no dependency/SDK/version/signing-setting change |
| Full Flutter unit/widget/real memory+file Drift row | 458 visible pass;392 prior cases retained;500 starts/500 terminals;0 failed/skipped/missing/duplicate cases |
| Actual maintained local server/strict PG fixture plus file-backed Flutter owner | Pass: lost201/reopen and lost attachment200/finalization; one parent/two repeated items/two shares; two keyed creates/one attach/one synthetic provider call; same key/bytes/persisted201 |
| Final-source independent removals | Five healthy passes and five executed assertion reds: key replacement, attempt ordering, exact-ID, immutable snapshot and no fallback; exact restoration retained |
| Scoped unsuppressed source scans | Semgrep23 and Gitleaks9 raw candidates; no reported scanner errors; individual dispositions retained; no new confirmed vulnerability, not a whole security pass |
| Maintained iOS simulator build with signing explicitly disabled | Compiles; linker ad-hoc artifact has no Keychain entitlement; build/artifact/source receipts retained |
| Actual owned-simulator Keychain qualification | BLOCKED: Security `-34018`; raw XCTest2 pass/3 fail/no skips, exit65. App witness failures are separate and contain an invalid null-equality positive; no positive Keychain claim follows |

The initial baseline, bridge-test failures, weak initial local-error stimulus,
parser/setup mistakes and later source repairs remain in raw evidence. Final Flutter
occurrence reconciliation retains all429 prior starts/terminals, including loaders/
hooks, and accounts for71 new occurrences (66 visible plus5 loaders). Ten actual
builder fixtures and raw negative/FEFF guards remain. No numerical performance
sampling or unrelated Go/web suite was selected. Server/image158 inputs and all336
original untracked files are unchanged. All three owned PG schemas/sessions and the
owned simulator are absent; normal volumes and other devices/credentials remain.

Detailed raw receipts are in task scratch `mobile-save-reopen-20261104/`: final
Flutter reconciliation, wire/server results, controls, scan candidates/dispositions,
source/tool/lock/artifact bindings and cleanup. Root's separate native qualifier
uses the same frozen Swift module
`ef962792ec2a195a06d67cd2fc3a5a6c5b1c6462f289a02a8e089dd0c65de4ea`;
its result is outside this receipt. Original unsigned failures are not relabeled.

Read [the maintained procedure](../mobile-save-verification.md). Independent review,
root clean committed-snapshot verification, native/signed-client/default-trust and
combined journeys remain pending. Identity0003, versioned JPY, the known `.005`
local/server allocation difference, resources and full security/integrated acceptance
remain open. Historical runtime1.619804s versus<1.5s/flaky and the separate50,000-update
latency remain RED. Capability reporting does not prove old-writer drain. No hosting
control-plane, production migration, provider/account, merge, upload or release action
was performed; keyed public release remains blocked.
