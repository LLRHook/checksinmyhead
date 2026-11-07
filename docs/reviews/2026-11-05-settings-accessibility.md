# Focused Settings accessibility — 2026-11-05

Settings now derives readable foregrounds from its effective base/panel/button
surfaces and exposes a responsive, named accent palette with selected semantics.
Targets remain at least48 logical pixels at320/390 widths. Preset/custom/reset
values, existing navigation/actions and preference persistence are preserved. The
payment row accepts Settings-provided ink and names its existing options action.
One small `AppTheme.foregroundOn` helper owns contrast choice; no package, cache,
release version, global theme rewrite or payment-flow change was added.

This delivers the host/source fixes for **BUG-1793898428** and
**BUG-1793898429**. **FEAT-1793644512 remains open** for broader direct assistive
technology, device and browser coverage. This is not store accessibility or signed
public-binary certification.

## Source and review

The exact five-file candidate was independently reviewed against base
`13c871cb920904009848f84381b7008dac34ae48`: Standards0 / Spec0 findings;
reviewer execution NOT RUN. Review SHA256:
`d915d1c71ec497abbb03074ead8059a38b7489078efd6b7da061ce75de59175e`.
Applied patch SHA256:
`e9ff922260305f37e1dd1fc2f56d8cbdb60cea8ad67cd705117489441dbccfe2`.

The implementation lead supplied the production code. Root corrected only the
new test's inert platform fixture before acceptance, then verified that all five
integrated outputs match the approved hashes. The three production Dart files
change from67912 to68029 bytes (+117); this removes duplicated color decisions,
not proof that the whole workspace is condensed.

The gate adds only `mobile/test/settings_accessibility_test.dart` and its33 exact
case-name obligations. Existing rows, families, patterns, multiplicities, report
contracts and PostgreSQL packages are preserved. No uncommitted backend identity
B family or source file is included in this change.

## Actual verification

Maintained Flutter3.41.5/Dart3.11.3 ran these commands after application:

| Selection | Result |
|---|---|
| `flutter pub get --enforce-lockfile` | PASS; maintained source/lock bytes unchanged |
| Affected `dart format --language-version=3.7 --output=none --set-exit-if-changed` | PASS |
| `flutter analyze` | PASS |
| `flutter test --no-pub --reporter=json` |513 visible cases;558 starts/terminals;0 failed/skipped/errors/missing/duplicate terminals |
| Existing controller with maintained unittest adapter |42 methods/827 method+subtest records; all pass |
| Actual gate parser over the full Flutter report | PASS;519 adapter records (its own reporting semantics) |
| Required-case omission controls over that actual report |33 individual omissions plus whole Settings-family omission all rejected |

Every accepted513 case/name occurrence is retained, including all480 preexisting
visible cases. The33 new cases cover both themes/widths; default, preset and bright/
dark custom accents; text at2x; populated payment rows; physical/semantic actions;
all presets/reset/custom persistence and existing callbacks. Manipulated-report
controls are validator checks, not extra application executions.

Prior root qualification on the same accepted bytes also executed the unchanged
independent host-font fixture:9 cases/12 starts and terminals pass, covering24
actual Settings guideline evaluations and3 healthy-control evaluations. Eight
independent production guard removals each caused the intended assertion failure;
restored healthy controls pass. These are retained prior execution, not reruns
at the integration stage. Physical VoiceOver, device Dynamic Type, iPad, reduced
motion, switch/keyboard journeys and signed/public-binary parity were NOT RUN.

The original candidate's incomplete platform mock produced32 test failures;
those raw results remain preserved. The mock was corrected for exact framework
calls without changing application source/assertions. A first guard-control
preflight stopped after three valid controls; five remaining controls ran in a
separate campaign. None is reclassified as a successful full campaign. At source
integration, the first report-parser attempt rejected a file named `stdout` as
required by its filename contract; the exact bytes were then copied to canonical
`flutter.jsonl`, without rerunning Flutter or relaxing the parser.

## Evidence and remaining gates

Raw root integration commands, complete reports, before-state hashes/modes,
manifest controls and preservation receipts are retained under the task scratch
`settings-accessibility-integration-20261105/`. Earlier qualification/control
artifacts and the independent review remain at their original bound locations.
The root main-worktree run is `scope=affected clean=no`; a dirty checkout is not
clean committed-snapshot acceptance. Actual controller execution used Python3.13.5;
CI pins3.12, so controller runtime parity remains unproven. The mobile row uses the
maintained pinned SDK. No hosted CI or native/device result is attributed here.

`DESIGN_SYSTEM.md` records the effective-surface ink and semantics contract. This
change does not alter `VERIFICATION.md`, architecture/API contracts, signing or
publication settings. Existing integration/security/performance, hosted PG,
old-reader/writer, resource/spending, recovery and release gates remain RED/open.
No CHANGELOG migration or full Verified entry is justified.
