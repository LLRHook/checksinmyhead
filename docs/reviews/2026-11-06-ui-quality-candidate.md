# UI identity and readability candidate — 2026-11-06

Reviewable source from a02108d7759079e17f8d32905fc14a9a16be668e. This note does not
claim accepted widget, native or screenshot evidence. The ten UI files are the exact
final R02 formatter bytes; no further UI edit or formatting was performed.

2026-11-06 CI correction: [run42289112203/mobile job128137633416](https://github.com/LLRHook/checksinmyhead/actions/runs/42289112203/job/128137633416) at a962 failed `Assignee stack summarises everyone past four` (test70): global `find.text('A')` matched the11px avatar initial and18px other item content, after the four-circle and `+2` checks passed. This proves a finder-scope defect, not a production UI defect. The exact test-only correction scopes `A`/`B`/`C`, `+2` and no-`D` finders to `CircleAvatar` descendants, retaining all four-circle/label/remainder/absence/no-exception obligations and literal IDs. It supersedes the test-file byte-equality statement above; the nine production UI files and app140b0bec558 remain unchanged. No local test or formatter ran; corrected functional acceptance awaits automatic source-triggered CI. The failed raw row is retained, and PG/full/native/quality95/release limits remain open.

2026-11-06 second CI correction: [run42290401669/mobile job128142328595](https://github.com/LLRHook/checksinmyhead/actions/runs/42290401669/job/128142328595) at8edf records the prior overflow test70 PASS and one error event in test73, `Participant visual controls custom split rows remain usable at enlarged text size`: `scrollUntilVisible` throws `StateError: Too many elements` because its finder includes the vertical participant list and horizontal per-row preset scroll views. This establishes a test scroll-owner ambiguity, not a production geometry defect. The exact correction asserts one `ListView` and one downward vertical `Scrollable` and uses that owner, preserving all four row visibility/bounds checks, actual Apply Split, ordered roster,25percent each,price20,no-exception and all literal IDs. No `.first`, skip, viewport/text-scale/deadline/workload change or local formatter/test is introduced. Both failed CI rows remain retained; this correction awaits automatic source-triggered CI and does not establish canonical/full/native/quality95 acceptance.

## Source scope

Nine existing UI library files plus `mobile/test/screenshot_quality_test.dart` preserve
saved color provenance for single/same-color rosters, composited-surface ink on changed
light-theme rows/avatars and Bill Details initials in both themes, plain item counts,
actual expansion chevrons, four real avatars before
overflow, and a saved custom owner color with fresh occurrence refs. Proposed cases
use actual parents, default text with safe insets, enlarged custom-split text, toggles,
ink/stacks and unchanged recorded amounts. The first literal case covers both themes.
Other dark-theme branches are unchanged; rendering/contrast acceptance remains pending.

No receipt ordinal/ref removal, person model or main/theme owner change, global
MediaQuery/FittedBox zoom, adaptive Finalize fix, money/precision/calculation/persistence,
API/authority/schema/provider/dependency or native setting change is included. The
separate short-height Finalize bug remains open. FEAT-1793644509's released-result,
receipt-review and browser-participation acceptance stays unchanged: a private pre-Done
prototype cannot close it. Older f4 BEFORE images are not this candidate and do not
establish current geometry, ink or screenshot quality.

## Actual retained R02 outcome

Three planned jobs actually started/completed, exits0/0/1: formatter10 files/8changed;
analyzer `No issues found!`/exit0/stderr0; selected widget command exit1. Its stdout
is empty, with168-byte stderr reporting Flutter failed to run `xcrun --find clang`.
No machine loader/test event or widget compilation credit exists. All106 expected
names (15new +91inherited) remain unstarted; no app assertion failure was observed.
Nested xcrun PID/exit/errno was not retained, so an additional OS/SDK drift cause is
unproved. Initial R01/R02 source packets and raw failures remain immutable.

Installed Flutter source requests compiler configuration before hooks can reuse the
cached SQLite seed. Its macOS tester path also names ar/ld, lipo, otool,
install_name_tool and ad-hoc codesign; those later steps were UNEXERCISED. Enabling
only xcrun would leave known prerequisites unresolved. Local Apple permissions stay
closed. The existing automatic Linux mobile gate is the selected future proof route.

Actual reservation:18:27:39.638219–18:30:39.638219 UTC. Effective authority was revoked
18:27:57.458940; supervisor RESULT20.275833s and RELEASE20.276398s were within180s.
Independent root audit was23.887097s late, root release23.888368s late, and manager
release70.931214s late. These closing-bound misses are explicit and unwaived. No app
runtime overrun, sleep explanation or OS cause is inferred. Release preceded retained
interpretation. The complete1539-row inventory proved all five recorded PIDs and
group91833 absent; owned runtime/intermediate paths were absent, inputs and SDK3 final
bytes/modes exact, authority revoked/grantnull/quietnull. Both fences are released.
Appshot coexisted without a host hold.

Retained analysis SHA256:
`eb33e9eff50b6a1f8046fba7eff051506f4d267f18016a483e96f1f0c22aed6e`.
Manager independent result:
`d283005bdcb99be688764d2592836e0e6a193e435d18ab66908283f3cf3affb4`.
Explicit manager release:
`080a99fa16e6acb075e73943b639fcd3e1012849d51f97cb18981618fb1dcb4d`.
Failed RESULT/RELEASE:
`96a7c2399f0d68fa8c92881e0c0a1bf699d94542069d480635038f03506f7551` /
`65cced83d7c3002c1d96b86eb9b71921b44aa2a3107d0377e7181caebad79399`.

Postformatter private621:
`99cc9b0283bad49332b003e2d2a3f69437984475a85769e60d9013c88eb88e6d`.
Changed app140:
`b0bec5580a4be7715fece1cd407b33b54d8c8582487a4e979417351dca12375f`.
Analyzer0 applies to those exact UI bytes. This combined proposal also changes gate
fixtures/manifest/docs. Its offline controller acceptance is recorded below; mobile
functional acceptance remains pending.

## Mandatory cases and future validation

Only `mobile/test/screenshot_quality_test.dart` is added to the mobile families, with15
escaped, fully anchored full-name requirements. Stripping those additions restores
the entire prior JSON and serialized bytes. All prior rows/reports/selections, floors,
parser/schema, workloads/samples/deadlines remain unchanged. The existing controller
method independently declares15 healthy literal names and15 one-case omission
subtests. Its focused manifest keeps every mobile family present while isolating the
new literal requirements; every inherited control remains unchanged. No automation
method/family or report adapter is added. The full offline suite exercised these
omission controls successfully, as recorded below.

Source review and the single offline controller qualification are complete. Physical
adoption into a reviewed draft checkpoint is a separate source-writer step and does
not imply accepted mobile behavior. No manual CI dispatch/rerun is selected. Automatic Linux mobile CI must supply actual suite/start/terminal/done,
all inherited multiplicities and15 new mandatory names.573 prior +15 new =588 canonical
records is EXPECTED ONLY. No E9c full-row carry,106 targeted passes or quality95/native
acceptance follows. Setup/loader/compiler failures, partial/missing/duplicate/skipped
or failed cases remain RED.

## Actual offline controller qualification

The separate UI offline-controller R03 stage ran once under the exact120s reservation
20:11:07.496741–20:13:07.496741 UTC. One existing-full-controller job exited0:42 exact
method starts/terminals,1036 subtests and1078 unique passing records, complete/success
true,0fail/error/skip/missing/duplicate. All140 assignment omissions (70 per backend/PG),
five inherited migration omissions and15 new UI literal omissions passed. These are
delivery-gate fixture/control results, not Flutter widget execution.

Raw controller report:447515 bytes, SHA256
`2129dd7990c296403294ed3a8838b19bed4633add20ae32166d61fa7863f2c18`.
Independent retained acceptance:
`8fde24904fe85430b425e11546d7f03be1e9e0b090e1e4c04ff11fe250c462ca`.
Independent root cleanup/input audit:
`2448d6f76a0d34c833fda3ba497f8ded9d9d189c9b952859635f7fdaa92e1f60`.
Manager release:
`b895c4d5c4e006b42786e9e9eb37e90874e4590918ce38f72de00b6f5b72dee0`.

The preceding offline-controller R02 remains RED: a live temporary fixture vanished
between enumeration and lstat; the allocation predicate threw ENOENT and terminated
the live owned group. Its25 textual starts/24ok and missing job terminal/full report
provide no canonical suite acceptance. The separate R03 source correction tolerates
only vanished descendants under stable owned roots, retaining resource/error guards;
14 pure metadata checks passed, including the original-guard failure control. The
successful actual row recorded0vanished entries, so the ENOENT branch has mock proof
and no actual runtime branch witness. This is logical observation, not a disk quota.

R03 needed no group signal. All recorded PIDs60754/60755/60757 and group60755 were absent
in the independent complete inventory; owned output/cache/TMP were absent. Source,
proposal, tools/support and the immutable1004-entry environment/three interpreter links
were exact; runtime authority was revoked. Supervisor, independent closure and explicit
root/manager releases completed within the reservation; manager release20:12:03.986172
was63.510569s before expiry. Appshot coexisted without a host hold or contact. No suite
rerun, package setup/repair, app/native/PG action or source adoption occurred in this
qualification. Historical failures and the earlier widget-stage closing miss stay raw.

## Verification obligations

The [mobile save/reopen procedure](../mobile-save-verification.md) adds real
memory/file-backed Drift, immutable keyed-request, lost-response/local-checkpoint,
attachment-finalization and currency-confirmation checks to the full Flutter row.
Native Keychain results, app witnesses and harness exit codes must be reported
separately; unsigned `-34018` is BLOCKED, never a native/release pass. Retain canonical
OCR native/M2/TLS obligations unchanged. No numerical performance qualification is
implied by these functional cases.

[Assignment/snapshot evidence](2026-11-06-assignment-snapshot.md) remains separately
scoped. Complete PG/numerical/resource/security/integrated acceptance, signed public
clients, physical a11y and quality95/release remain open. Native build/capture needs
the existing task-exclusive macOS ownership contract; no already-provisioned qualifying
boundary is available. This proposal grants no SDK permissions, credentials, account/VM/
runner, fresh-self0004/epoch2 adoption or capture/backend action. Tracker statuses and
acceptance remain unchanged.
