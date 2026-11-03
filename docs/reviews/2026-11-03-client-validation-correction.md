# Client validation review corrections — November 3, 2026

Scope: independent client-v1 review S1 (medium) and S2 (low) at
`29ef3856a0af179a8ab6994538b7b77973b6bc22`. Root implemented the small corrections;
BUG-1793644498 remains in progress. Global security/integrated acceptance remains RED.

## Corrections

1. Pending saved-history publication checks raw stored assignment values before
   `getBillItems` can omit nonpositive entries for display. Fresh serialization and
   saved preflight use one percentage rule. Negative, non-finite, nonnumeric and
   over100 values cannot silently become valid publication input. Exactly zero
   remains supported; participant/zero-share rows survive while zero assignments
   are omitted from the request. The saved display projection and original JSON
   are unchanged.
2. Receipt-name preflight removes tags and trims exactly Go's Unicode White_Space
   set. U+FEFF remains a counted character, matching the endpoint; Dart's broader
   BOM-trimming behavior no longer bypasses the30-code-point preflight. Original
   name/history text is retained. Tab joining and server policy are unchanged.

The API serializer remains the fresh-request owner. The raw-history check is at
the existing pending-publication boundary, before accounting/display reconstruction;
no new uploader, database schema, dependency or caching layer was added.

## Executed evidence

Actual Flutter3.41.5/Dart3.11.3; synthetic HTTP responses and a unique temporary
native SQLite database. No provider or customer data was used.

| Selection | Result |
| --- | --- |
| Exact baseline source overlay, final nine regression cases |5 executed assertion failures and4 passing controls; no compile/setup failure or skips |
| Final affected `flutter pub get --enforce-lockfile` |Pass; committed locks unchanged |
| Final `flutter analyze` |Pass, no issues |
| Final `flutter test --no-pub --machine` |237 visible tests:228 retained +9 new;0 failed/skipped/missing terminals;25 hidden loading/setup/teardown events separately counted |

Native saved-history cases exercise the actual manager/database/HTTP boundary: a
negative assignment remains pending with identical stored items/participants and
no HTTP request; over100 also rejects; the exactly-zero counterpart publishes and
stores the returned link while retaining Sam's zero obligation. The card test
delivers the actual manager-derived validation error through Get Link and checks
the visible content message. Its native SQLite phase and controlled widget frames
are separate; this is not a device end-to-end journey.

Paired raw/tagged BOM cases prove FEFF plus29 letters is accepted and sent unchanged;
FEFF plus30 letters rejects before HTTP. Typed tagged entry rejects31 runes and
accepts30. Existing fresh-percentage/Unicode/provider/Done/contract tests remain in
the full suite. Final source hashes were unchanged through acquisition, analysis
and test execution.

The initial test harness needed a nullable-callback correction and separation of
native async work from widget-clock work; earlier analyzer runs also required two
brace fixes. Those failed runs are retained and are not the baseline defect proof.
The qualified before/after records are in the driver's
`billington-structure-evidence/client-v1-correction-29ef385/qualified/`.

## Evidence continuity and documentation

The prior tracker Fix text was:

> 28eab76 original Fix retained verbatim in docs/reviews/2026-11-03-client-v1-bridge.md. 43772a7 supplies the valid-client upload/name slice; 228 Flutter/54 web pass without skips. Broader acceptance remains RED.

See the [original bridge note](2026-11-03-client-v1-bridge.md),
[authorization batch](2026-11-02-authorization-batch.md) and
[authorization corrections](2026-11-02-authorization-corrections.md) for preceding
scope and execution. The tracker field is condensed to stay within its entry limit;
historical logs remain intact.

| Document | Impact |
| --- | --- |
| docs/backend-api.md | Raw saved preflight and exact whitespace semantics |
| docs/technical-overview.md | Shared validation owner and saved/display boundary |
| bugs.md | Scoped Fix/Docs evidence; status remains in progress |

No backend/web behavior, accounting formula, frozen quote, save/replay operation,
version policy, signed public client or hosting configuration changed. Web54 and
backend635-distinct-case results remain attributed to their prior source pins;
they were not rerun for this mobile-only correction. Independent re-review, public
bridge availability and integrated/device acceptance remain outstanding. No
CHANGELOG migration, PR merge or publication occurred.
