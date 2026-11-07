# Unicode share ambiguity correction

The independent authorization review of `13be27b..fb6b4b9` found one P2 specification
gap. Tab-share ownership used Go's `strings.EqualFold`, while the new ambiguity check
used SQL `LOWER` with Go `ToLower`. Those equivalence relations differ for valid names
such as `S`/`ſ` and `Σ`/`ς`. One member could therefore toggle either of two matching
shares instead of receiving the required accounting-review response.

This is a correction to the approved temporary ambiguity containment, not stable
identity, a new naming policy or a migration. The driver implemented the small review
finding after the local-workflow lead completed and released the shared source tree.
Parent at correction start: `5f4be44a0fb0502d61589f1e69acc4893ce1b0da`; its relevant
application source is unchanged from `fb6b4b99e8a1726c9334ba30a9042f8665ae3551`.

## Change

The existing transaction still takes Tab → Bill → exact Share locks and requires
current same-tab member proof. One batched projection of this bill's share names now
replaces the SQL lowercase count. It counts candidates with the same `EqualFold`
relation as authorization and requires exactly one before changing or replaying a
paid flag. It does not rename/merge rows, change credentials, add uniqueness, alter
financial values or broaden source-capability authority. One projection replaces one
query; the existing six-statement paid budget remains the target.

## Executed regression

`unicode_authorization_postgres_test.go` creates each valid tab/creator and receipt
through the real HTTP handlers, with a successful strict `201` creation and authorized
source-proof attachment before testing payment. Finalized cases use real finalization,
rather than manually marking an incomplete synthetic snapshot.

With Go 1.27.3, actual PostgreSQL 17.11 and the maintained isolated-schema harness:

```sh
go test -race -count=1 -tags=integration -json ./internal/tab \
  -run '^TestPostgresLifecycleUnicodeShareAmbiguity$' -timeout 90s
```

| Source | Executed result |
| --- | --- |
| Exact pre-correction application source | 12 leaves: 7 expected failures, 5 passing controls; exit 1 |
| Corrected application source with identical test bytes | 12 leaves passed; zero failures/skips/setup failures; exit 0 |

The seven failing cases independently exercise both long-s targets before/after
finalization, ordinary/final sigma, and an equal-flag retry. Before correction they
returned 200 rather than 409; paid-changing cases also failed full unchanged-state
assertions. Five controls preserve unique Unicode-equivalent authorization before and
after finalization, ordinary own-share payment, different-label denial and the existing
folded-member ambiguity guard. Every negative case compares the complete database
snapshot and checks the finite typed review response when applicable.

Twelve generated schemas per run were observed and all exact owned names were absent
in the independent cleanup probes. Shared PostgreSQL and normal volumes remain.
Evidence is retained under `.vv/local-gate/unicode-ambiguity/{before,after}/`: raw Go
JSON/stderr, result/command/input hashes, exact executed test and repository source,
and exact-name cleanup SQL/output. Passing tests run from driver-owned diagnostic
source, so that initial targeted gate is `scope=affected, clean=no`.

## Fresh committed validation

The driver then ran the maintained Go selections in a fresh detached worktree at
implementation commit `af4365578ca1b0715b867e4fe9311825d392661f`:

| Row | Result |
| --- | --- |
| Build, format, ordinary and integration vet | Pass with Go 1.27.3 |
| `go test -race -count=1 -json ./...` | 129 roots / 414 leaves, all passed |
| Maintained seven-package PostgreSQL selection, `-race -count=1 -tags=integration -json` | 139 roots / 557 leaves, all passed |
| Distinct Go leaves after overlap | 635; 336 overlap; zero failed/skipped/cached/missing-terminal cases |
| Pinned `govulncheck@v1.7.0 ./...` | Pass; no findings |
| Three 100-sample tab-paid runs | Six data queries each; p95 2.362 / 2.267 / 2.285 ms |

The paid measurement retains the existing 100ms local target; no production capacity
claim follows. All 194 exact owned schemas were absent after the fresh selection.
Committed input hashes match, the source remained clean, and its owned worktree was
removed. Raw commands/events/case IDs, measurements and cleanup proof are retained in
the driver scratch `billington-structure-evidence/unicode-clean-af43655/`.

Unsuppressed focused scans also pass at that code commit: Gitleaks 8.30.1 over all six
changed files has zero candidates; Semgrep 1.183.0 over the two Go files with retained
local rules has zero candidates/errors; gosec 2.30.0 over five tab production files /
1,457 lines has zero issues/errors and no suppressions. Raw results, exact source and
rule hashes are in `billington-structure-evidence/unicode-scans-af43655/` in driver
scratch. These are affected-source scans, not whole-program or final-image certification.
This follow-up changes documentation/trackers only. Independent correction review is
still required; no completed review is inferred from the fresh passing gate.

## Documentation impact and remaining gates

| Surface | Disposition |
| --- | --- |
| `docs/backend-api.md` | Clarify matching relation, typed collision response and retry boundary |
| Technical overview | Existing transaction/legacy-identity ownership unchanged |
| `VERIFICATION.md` | Existing ambiguity, PG and performance selections still apply; Last verified remains never |
| Trackers | Preserve lifecycle/identity tickets in progress; no CHANGELOG migration |

The accounting reviewer approved the original lifecycle slice; authorization acceptance
requires this correction and fresh review. Historical/current client bridging, stable
identity, currency/save/replay, ingress/receipt/panic boundaries, production adoption,
old-writer exclusion, signed public binary and final image verification remain separate
open work. Global security/integrated acceptance remains RED. No hosting action,
customer data, live migration, PR merge or release publication is authorized by this note.
