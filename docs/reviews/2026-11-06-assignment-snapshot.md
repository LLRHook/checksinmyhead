# Assignment decoding and lifecycle snapshots — 2026-11-06

This source checkpoint preserves the public creation contract and all nine lifecycle verification row sets. It does not establish performance recovery, PostgreSQL mutation-control acceptance or an integrated gate. Base04e1adfb4f82383cb18126b4dea727e0952b6c57; both source candidates were independently reviewed before physical integration.

## Source semantics

`createAssignment.UnmarshalJSON` uses a strict typed carrier and private presence wrappers instead of a second RawMessage map decode. Stock encoding/json owns key folding, duplicates, string/pointer/null and float64 conversion. Presence stays independent of nil/empty values. Unknown/trailing input is rejected; the receiver changes only after success. DTO shape, shared helpers/person/share decoders, aggregate5000 create/50000 update, body/array caps, public errors, identity/replay/authority and money semantics stay unchanged. Private JSON error wording/type/offset is not an asserted compatibility contract.

The integration-only `lifecycleSnapshot` orders by unique numeric id instead of sorting full-record text. It retains all nine complete to_jsonb(r) sets, rows, columns, NULLs, nested JSON and empty arrays. Only outer row-array order changes. Eight tables have id primary keys; bill_participants has the retained composite PK plus nonnull UNIQUE(id). Current registry1/2/3 fixtures satisfy that guarantee; fresh-self0004/epoch2 is excluded. Its54 callers in19 parents/seven files compare whole-state equality, not an external literal order. No production SQL, schema, cache, projection or omission is added.

## Actual scoped evidence

- Independent source reviews: assignment Standards0/Spec0; snapshot candidate/control source Standards0/Spec0. Assignment oracle bodies are exact copies of the original decoder/shared helpers after declared renames. Snapshot oracle is the old full-record SQL, normalizing only outer table-row ordering.
- Assignment R01: six complete variants compiled before six exact lists; baseline73 and candidate73 named records PASS. Four source faults produce intended parent+child assertion failures with passing healthy siblings: null ref/name presence, unknown-field rejection and single-document guard. These are executed controls.
- R01 whole stage remains RED/exit1: the existing golden row ran from backend instead of its package cwd, producing75 passing records/two fixture-open failures/four unstarted vector children. Original raw failures are retained. No decoder repair or assertion relaxation followed.
- Separate R02: one source-identical candidate compile, exact list and the SAME six-parent golden/accounting/bounds/nonfinite row from backend/internal/bill:81 starts/81 passing terminals, no fail/skip/missing/duplicate. Candidate73+goldens81 compose154 distinct passing named records/nine parents/147 leaves across TWO rows, not one full ordinary row. Baseline and four controls remain separate evidence.
- Snapshot: four complete integration tab variants compile/link with distinct nonempty artifact hashes: candidate, old sort, settlement-row omission and additive-probe omission. No generated binary/list/TestMain/test/PG call ran. Actual SQL characterization, high-bigint/numeric/NULL/additive/nested/timestamp mutations and three negative/healthy PG controls remain UNRUN.
- Cached Go1.27.3 Darwin/arm64/CGO0 ran offline without acquisition. This matches production-service CGO mode but provides no race/SQLite/full-gate claim. Owned process groups/base directories are freshly absent, protected inputs exact, runtime flags/grants revoked and both producer fences released before interpretation. Appshot coexisted; no host quiet was claimed.

Retained ignored evidence is hash-bound, not a release attestation:

| Report | SHA256 |
|---|---|
| R01 whole result, still RED | `5ffef7e1142cecf5607d31d65d200657a76cdf6284e8c7809a9eaae78e4ff2e5` |
| R02 actual81-node golden raw | `5e46ee3de81db7d060d4b6f360f6ec21b84693a313c2a7222066bc7e94e805c8` |
| Composed assignment reconciliation | `0b3a92b4b9522e265669584f25ab700263a5c04e94c5386ce843f5d48f00f315` |
| Four-variant compile reconciliation | `1ce9f112e8337e073e5109f0d040c217eeeff7dbf12bd712af18b729aed64ea5` |

Reviewed/compiled inputs and any physical formatter delta are recorded in the ignored integration `SOURCE_INPUT_MAPPING.json`. Formatting is not a fresh application run. All unmodified case obligations, three100-sample cohorts, default600s, startup60s and operation/750ms/100ms/200ms/2s targets remain mandatory.

## Registration and remaining work

The manifest adds three assignment families to backend and PostgreSQL, with70 exact escaped/anchored report-prefixed child IDs in each row, and one integration-only snapshot parent to PostgreSQL. Independent fixture literals and omission controls stay in existing controller methods. Removing each child keeps its parent, other children and every inherited family. All five migration-child, mobile/web named and prior family omission controls remain. Stripping additions restores the entire prior JSON and serialized bytes. Adapters, matcher/schema, reports, PG packages, source/version/reference fields, publication floors and disabled policy stay unchanged.

Retained affected formatter exit 0, official tracker lint 0 (three files, zero errors or warnings), and CLT diff check 0 remain credited to their original row. Controller tooling was initially prerequisite-blocked. The separately authorized R02 then used task-owned CPython 3.12.12 and PyYAML 6.0.3 from the exact retained Mac wheel, installed offline with no index or dependencies. At working source fingerprint `1c97786700bc02f39ee71266bcbc608289dde83c3ae6bddb53a906d093857625`, the unchanged full controller selection ran once: 42 methods, 1,021 subtests and 1,063 unique passing records, including all 140 assignment-child omissions and five inherited migration-child omissions; no failures, errors, skips, missing or duplicate records. Raw controller JSON is 440,293 bytes, SHA-256 `b5d2d038fa1039262d2604dc14e40644ea59bc623f2f43ba73c1766d2689e1ef`. All four setup/install/runtime/controller jobs exited 0; final result, release, independent resource/input audit and manager retained review pass. This is offline controller evidence, not a fresh Go, PostgreSQL, application or full-gate run.

R01 remains RED: its copied-interpreter venv creation exited 1 after the nested ensurepip process received SIGABRT; the other three jobs never started. The OS cause was not captured and remains unproven. R02 uses standard interpreter symlinks with exactly three named links to the pinned base executable; its success does not establish R01's cause. The retained tool environment has 1,004 sealed entries and tree SHA-256 `54a7b130cb5429853606fcf03d3fec66fef618409513dfa60363b47c47de12ba`. Temporary resources are absent and authority is revoked. Future use requires a fresh scope and matching root identity, nonce, full tree, interpreter links and tool/support pins; the seal grants no standing execution authority. No ticket is closed or migrated, and Last verified remains never.

Hosted evidence remains the failed04e1 test merge524b0890a2ab97f59fd0ed23d898813ad821db30/run42200849836. Migration parent-deadline/helper components pass, but startup build is signal:killed at60.07s with context/kill cause unproved; cmd/tab packages alarm600.052/600.086. MaximumUSD first p95 is2.11406968s against2s (TARGET_MISS); foreign third block and large-tab cohorts2/3 are censored. Large first fresh715.891811ms and retry17.473321ms meet their targets but do not complete the workload. No cost share or recovery is inferred.

Local approved PG credentials and a task-exclusive native build boundary remain unavailable. Existing normal CI after a reviewed new checkpoint is separate future source-bound evidence, not a manual rerun or local credential grant. Precision/.005/JPY, fresh-self/schema rollout, spending/resources, signed/native/artifact/security, integrated journeys and release/hosting acceptance remain open. This source checkpoint cannot establish B+/A− or release eligibility.
