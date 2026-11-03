# Client v1 bridge — scoped implementation evidence, 2026-11-03

Base/local/independently read remote at start: `0f365beecce637291defa1d95e1ffd1a2b798f76`.
Implementation commit: `43772a7cea40ac402020d7b2f8396ec72207dfc5` on unchanged branch
`chore/billington-foundation-program`. An evidence-only follow-up carries this note and
tracker/procedure updates. Final publication head, both commits and independent remote
comparison are recorded in the driver scratch `CLIENT_V1_BRIDGE_RESULT.md` and ignored
`.vv/client-v1-bridge-20261103/remote-proof.json` after the single normal branch push.
No deployment follows from a program-branch push.

Driver `CLIENT_V1_BRIDGE_IMPLEMENTATION_APPROVAL.md` authorizes the fixes and dormant
write deletion. The supplied wave-7 registry assigns this exact T3 run the exclusive
writer lease at the base; the driver checkpoint prohibits concurrent root source writes.
Current thread identity and the driver's explicit ownership message were reconfirmed.
No branch/checkout/worktree/reset/rewrite/cherry-pick/force operation was used.

## Behavior and evidence

- `ApiService.buildBillRequest` / `_buildItemsJson` stays the only creation serializer.
  It rejects non-finite, negative and over-100 percentages and totals above the existing
  `100 + 1e-9` tolerance; it omits only valid exactly-zero assignments. Provider maps,
  participants, zero shares/birthday rows, item order, signed discounts, fractions,
  partial/empty lazy claims and custom-tip metadata remain intact.
- The lasting regression executes actual ItemCard expansion/tap → AssignmentProvider
  → ApiService upload under the existing HTTP MockClient seam. Alex=100/Sam=0 remains
  in memory; the request contains only Alex's assignment and both participant/share
  rows, including Sam's zero breakdown. This is client execution, not live HTTP/PG.
- Receipt entry and builder share the actual creation endpoint's 30-Unicode-code-point
  name check after its tag stripping/trimming. Typed, recent, automatic-self and group
  entry use it. A group is validated completely before any participant is added; its
  error stays visible above the scroll area. Done preflights the same builder before
  local serialization. Explicit saved Get Link propagates a typed validation error to
  its existing snackbar while retaining the old readable data. No truncation, history
  rewrite, guessed member binding or tab/member bound change occurs. Tab join's current
  historical byte check remains distinct.
- Current source confirmed one runtime SettlementCard caller, the tab page, always
  read-only. Three rendered-behavior characterizations passed before deletion. Removed
  toggle/optimistic state, writable/tab/token props and the unused settlement-paid API
  helper plus its two obsolete tests. Names, amounts, paid count/status and Billington
  guidance remain. The existing Venmo URL is now a labeled anchor; no new browser writer.
- Existing saved attachment (`TabManager`, source token plus stored same-tab member),
  finalize/member recovery, settlement and settings callers were traced and preserved.
  Three maintained API calls execute a credential contract test. Attached web claims
  already pass the stored member token from LazyBillBoard to the batch helper; mobile
  standalone claims keep bill authority. No duplicate member arguments were added.

## Executed checks

Toolchain: installed Flutter 3.41.5 (`2c9eb20739`), Dart 3.11.3; supplied darwin-arm64
Node 24.22.2/npm 11.19.1 selected by PATH for every npm gate. No Node25 parity claim.
Raw argv, cwd, start/end UTC, exit, exact per-path input SHA256, stdout/stderr and runner
JSON live under ignored `.vv/client-v1-bridge-20261103/`. The final client input manifest
SHA256 is `b6256c52311ce1d34455057a0dd876c0ffd0609a46a3bea7b2e80f0ad6762648`; final test/static/build inputs were byte-compared before commit.

| Selection | Before | Final | Failure/skip accounting |
| --- | --- | --- | --- |
| `flutter pub get --enforce-lockfile` | exit 0 | exit 0 | Lock unchanged |
| `flutter analyze` | no issues | no issues | Intermediate 2 syntax diagnostics in error-display edit corrected; analyze and full suite rerun |
| `flutter test --reporter=json` | 203 passed | 228 passed | 0 failed, 0 skipped; +25 lasting tests; loader/hidden events excluded |
| Scratch client regressions on unchanged base | 5 passed, 13 expected failures/errors / 18 | All covered by final tests | 9 failure + 4 error terminal events; 0 skipped; not added to final count |
| Read-only SSR characterization | 3 passed | 4 lasting render tests passed | 0 failed/skipped; original suite 52 minus 2 removed helper tests plus 4 = 54 |
| `npm ci` | exit 0 | exit 0 | Package lock unchanged |
| `npm run lint` | exit 0 | exit 0, 36 files | 0 issues |
| `npm test -- --reporter=json --outputFile=…` | 52 passed | 54 passed | 0 failed/pending/skipped |
| `npm run build` | not needed for deletion baseline | exit 0 | Next 16.4.4/Turbopack plus TypeScript passed |
| `npm audit --audit-level=moderate --json` | not run | exit 0 | 0 info/low/moderate/high/critical |
| `python3 .cycle/trackers.py lint` | 0 errors/warnings | 0 errors/warnings | Official writer and ordinary hooks only |

One scratch SSR invocation had a wrong relative config path: startup failed with zero
tests; the corrected absolute-config run passed all 3 before deletion. No test was
removed or skipped to hide a failure. Expected base regressions and corrected authoring
errors are retained separately, not described as flakiness or added to the final total.

Execution deviation: an incorrectly rooted formatting `npm exec -- biome …` fetched
unrelated `biome@0.3.3` into temporary npx cache. The exact executable directory was
identified and removed; the invocation had no source target at that cwd. The supplied
Node24 and existing locked `web-bill-viewer/node_modules/.bin/biome` then passed from
the correct directory. No repository package/lock, global config or skill changed.
The downloaded npm content cache was not globally purged. See `accidental-tool-fetch.json`.

## Invariants and limits

All tracked bytes outside the authorized client/docs paths and all 336 original
untracked files in PROJECT_STRUCTURE_REVIEW.md, TECHNICAL_REVIEW.md, artifacts/ and
mobile/android/ were byte-verified unchanged. Original ten contract fixtures retain
SHA256 `54a3473cd9c2184332bff149bce29925ef1bfff728dc67ddec8b311fbda3f509`.
Mobile lock: `ba003adde839fdf84d2cf5023d90b319c1ff8e2828e674277afcdeb3c14bf73c`;
web lock: `44afbdd819a2eb0aa5ba35be7aaaaa3e0704d7b4e461086b172e86e8391c36c3`.
Versions, backend/models/schema/migrations, strict fresh DTO, finite accounting,
independent source/tab/member proof, locks, URLs, currency/math, replay and identity
are unchanged. Root Unicode correction `af4365578ca1b0715b867e4fe9311825d392661f`
and its previously executed 635-distinct-case Go gate remain untouched; no Go suite
was rerun or counted here. Reviewers' scratch reports were not edited.

The separately captured penny tie remains: actual client/provider at driver execution
pin `fb6b4b99e8a1726c9334ba30a9042f8665ae3551` sends Alex=.01/Sam=0 for a 50/50 cent;
established v1 server persists Alex=0/Sam=.01 and .005 raw details. That executed
50-case/76-request driver evidence is in scratch CLIENT_COMPATIBILITY_EXECUTION.md and
billington-structure-evidence/legacy-contracts-fb6b4b9, distinct from this run. No penny
algorithm was changed; BUG-1793644500 receives this evidence note only.

Historical research compares old `52c75267dfa3792edbaffd394b9341ff08a69834` with
`13be27bd6c2ec763c21e7ce1cbc44719f5f90e69`, not this implementation. Its reconstructed
fixtures are not signed binary captures. No customer DB/data, browser/simulator,
provider authentication/settings, live writes, deployment, release/version-policy,
App Store/TestFlight, workflow/publication, PR body/merge, main/mirror/tag or account
action occurred. Public compatible signed bridge availability, served behavior, old-writer
drain, replay/identity rollout and integrated journeys remain unverified/global RED.
Root owns token-free post-push checks and independent review of this client slice.
The final code gate is GREEN only for affected client rows (`clean=no`); global RED.
Before publication, remote was independently reread and still exactly the base.

## Documentation and tracker impact

| Living document | Change |
| --- | --- |
| docs/backend-api.md | Explain strict-compatible zero omission, percentage validation and receipt-specific name bound |
| docs/technical-overview.md | Keep serialization owner, explain entry/error paths and presentational settlement card |
| VERIFICATION.md | Point at this scoped client evidence; Last verified and integrated baseline unchanged; under 20 KiB |
| bugs.md / features.md | Official writer only; preserve acceptance/dependencies/original log history and broader status |

BUG-1793644498 was already 2,736 bytes. Its Fix summary is shortened with a link here;
its original Fix evidence is retained verbatim below, with original acceptance,
dependencies and Log unchanged. FEAT-1793644507 stays open; BUG-1793644498 stays
in-progress; BUG-1793644500 stays open. No closure, migration or CHANGELOG update.

Previous BUG-1793644498 Fix evidence (historical claims, not rerun here):

> Correction 28eab76 validates raw per-person components and aggregate obligations before cent allocation, prevents tolerance denominator amplification, checks cent/int64 arithmetic and bounds remainder work by participant count. Creation prepares once before separate display/frozen quoting. Historical display-provider validation restored, including all twelve mobile choices and ZAR; receipt policy unchanged. Nested share tests require successful clean controls; ten actual builder fixtures assert every person and item detail. Safe before failures and five control-removal failures recorded; 316 Go and 157 integration-tagged tab leaf cases pass with zero skips. Full acceptance remains RED for recorded Flutter locked-acquisition and retained-image findings; independent review pending.

## Changed paths

- `VERIFICATION.md`
- `bugs.md`
- `docs/backend-api.md`
- `docs/reviews/2026-11-03-client-v1-bridge.md`
- `docs/technical-overview.md`
- `features.md`
- `mobile/lib/screens/quick_split/bill_summary/widgets/bottom_bar.dart`
- `mobile/lib/screens/quick_split/participant_selection/participant_selection_sheet.dart`
- `mobile/lib/screens/quick_split/participant_selection/providers/participants_provider.dart`
- `mobile/lib/screens/quick_split/participant_selection/widgets/add_person_field.dart`
- `mobile/lib/screens/recent_bills/components/recent_bill_card.dart`
- `mobile/lib/screens/recent_bills/models/recent_bill_manager.dart`
- `mobile/lib/services/api_service.dart`
- `mobile/lib/services/receipt_validation.dart`
- `mobile/test/client_v1_bridge_test.dart`
- `web-bill-viewer/src/app/t/[id]/page.tsx`
- `web-bill-viewer/src/components/SettlementCard.tsx`
- `web-bill-viewer/src/components/__tests__/SettlementCard.test.ts`
- `web-bill-viewer/src/lib/__tests__/api.test.ts`
- `web-bill-viewer/src/lib/api.ts`
