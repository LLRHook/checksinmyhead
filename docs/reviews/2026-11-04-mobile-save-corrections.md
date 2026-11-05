# Mobile save review corrections

Base `0d5d286fd5d68700cd9fc8c65f6271296380c0c4`; review corrections
`11e6f676bc1b0593417008e92703533f91f14701`; final application source
`7bddfa9d5f49b1f8a9155acad044f2673a6aea09`. Victor Ivanov authored and committed
both source commits with the personal project identity. Independent re-review is
pending; this note records root execution, not reviewer execution or release approval.

## Behavior

- **C1:** correct the current architecture inventory from Drift8 to9. Schema and
  generated database code are unchanged by this correction.
- **S1:** record a new tab destination transactionally before joining in-flight
  receipt recovery. A conflicting request preserves the first destination and
  does not taint its result. If the existing pass already read no destination,
  continue attachment from its acknowledged publication and current row. Failed
  creation or attachment is not automatically repeated by the joining action.
- **S2:** handle each selected history/read failure independently, continue later
  rows and retain earlier commits. The actual selector presents review/pending
  feedback without attributing every failure to connectivity. Existing owners
  accept their current dependencies for real storage/widget tests; default callers
  retain the same singleton/Provider behavior. No new orchestrator or framework.
- **BUG-1793848441:** a real SQLite rejection demonstrated that original driver
  errors could echo synthetic receipt write parameters. Five inherited persistence
  diagnostics now emit only finite operation labels. Return/control behavior and
  failed rows remain unchanged. No creation key or source capability is logged.

## Actual verification

Detailed raw logs, commands, source bindings and controls remain in the active
task's `mobile-save-review-corrections-20261104/` scratch evidence. Clean committed
qualification is in `mobile-save-correction-driver-clean-7bddfa9d/` and
`MOBILE_SAVE_FINAL_CORRECTION_ROOT_CLEAN_ACCEPTANCE_20261104.json`.

| Row | Result |
| --- | --- |
| Five original review regressions | Before correction: four executed assertion failures and one actual widget exception/missing-feedback failure; no skips. Initial test import collision was a compiler failure, not negative proof. |
| Focused final cases | Nine pass, including standalone healthy recovery, overlapping/late intent, conflicting destination, no automatic write retry, mixed selection and real SQLite confidentiality/state. |
| Three guard removals | At the review-correction source, removal selections produce7/1/2 failing visible cases with healthy counterparts. Exact sources restored. The later finite-log/test-only delta does not change those guards or assertions. Initial all-negative selection failed its healthy-control requirement and remains retained. |
| Real SQLite confidentiality | Before log correction: eight healthy cases and one intended confidentiality assertion failure. After: nine pass; failed URL/name writes preserve their row and produce finite diagnostics. |
| Clean locked acquisition, analysis and affected formatting | Pass at7bddfa9 using Flutter3.41.5/Dart3.11.3; no dependency/SDK changes. |
| Full clean Flutter suite | **467 visible cases;510 starts/510 terminals**, zero failures/skips/missing/orphan/duplicate runner IDs. All prior458/500 and intermediate466/509 occurrences retained by file/name/multiplicity. |
| Clean source and cleanup | All495 tracked QA files unchanged, tracked tree clean, owned QA worktree removed. All336 protected originals and170 backend/lock inputs independently rehashed without mismatches. |
| Scoped Gitleaks | Two-commit source range, explicit rules/empty ignore file/redaction: exit0, zero candidates. Initial command-not-found attempt has no scanner result. |
| Scoped Semgrep | Four changed Dart files, strict existing rules, no suppression: raw exit1,14 finite-constant diagnostic review candidates, zero scanner errors. Each candidate's actual source/hash is retained; no remaining raw error interpolation at these sinks. This is not a global security pass. |

The full final raw Flutter output SHA256 is
`6e8523ffff28c1f21a7130fc4d2be8bd011b044554fc4fe6aa52e51b5eceb58a`.
The earlier11e6f67 clean suite also passed466/509; its wrapper incorrectly required
distinct test labels. Two parameterized labels already occur twice in the prior
suite. The retained-log correction preserves their multiplicities and unique
runner IDs; it did not rerun the application. That original wrapper RED remains
recorded. The final7bddfa9 wrapper and every maintained command exit0. Legitimate
blank/daemon machine frames are validated and kept separate from test events.

## Limits and documentation

No backend/web/Ruby suite or numerical benchmark was rerun for these mobile-only
changes. Actual maintained-server/PostgreSQL/file-backed Drift recovery evidence
from the preceding save batch remains separately scoped. No native app was run
at7bddfa9. The0d5d286 maintained Runner build/signing inspection passed, but its
runtime configuration guard failed before any case/HTTP request; native integration
remains BLOCKED and setup/capture RED. Historical unsigned failures and the separate
20-case committed Swift-class proof retain their own scopes.

| Document | Impact |
| --- | --- |
| docs/technical-overview.md | Correct schema inventory caused by the preceding migration. |
| docs/mobile-save-verification.md | Add current overlap, selection and SQLite diagnostic regressions. |
| This dated note | New evidence; previous dated reports remain unchanged. |

Existing API/migration/precision contracts are unchanged. BUG4500/4515 and the new
logging bug remain in-progress for independent acceptance; no CHANGELOG migration
or Verified entry. Known`.005` alignment, stable identity, spending, runtime/large
JSON performance, resources, full integration, public policy/store and release
gates remain open/RED. No hosting, production data, account, publication or rollout
action, and no overall grade, follows from this scoped mobile gate.
