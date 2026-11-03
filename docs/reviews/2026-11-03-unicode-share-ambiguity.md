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
source, so this initial targeted gate is `scope=affected, clean=no`. Fresh committed
build/vet/full-race/PG/query-budget validation and independent correction review remain
pending at this implementation checkpoint.

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
