# Foundation checkpoint — November 4, 2026

## Frozen-zero summary correction

Independent accounting review of79a8568→f558642 requested changes for one inherited
P2 requirement gap: tab summaries selected frozen USD only when positive, otherwise
display/native money. Root reproduced this using synthetic PostgreSQL/HTTP journeys.
PEN0.01 at0.27 frozeUSD0 and finalized Alex0/Birthday0, but tab totals reported0.01
with native display or0.40 with JPY display. Nine before leaf cases failed; five
legacyUSD/ordinary-foreign/native-zero controls passed, with no skips/missing terminals.

Implementation `6dba4b41f55880edecd7788ac98673381065c4d1`, parent `e4af0a7`, shares
one checked saved USD audit between bill-total and share-allocation readers. Tab totals
use checked cents, preserve real zero, and interpret only unset legacy USD as identity.
Unavailable/inconsistent foreign valuation and unsafe sums return finite409
`accounting_review_required` after tab-token validation. Display/native foreign money
does not substitute. Reads/finalization make no quote call or historical bill write.
No schema, precision, identity, paid-state or source/destination/member authority change.

Actual root execution, Go1.27.3, scoped shared source with SHA256 bindings:

| Selection | Result |
| --- | --- |
| `go test -race -count=1 -json ./...` |138roots/519leaves pass |
| Maintained eight-package `-race -count=1 -tags=integration -json` selection |151roots/600leaves pass |
| Distinct Go cases after368overlap |751;zero failures/skips/cache/missing terminals |
| Build,ordinary/tagged vet,CIformat,pinned govulncheck,tracker lint |Pass |
| Final committed currency regression selections |8unit+6PostgreSQL pass |
| Unsuppressed Gitleaks8.30.1/Semgrep1.183.0/gosec2.30.0 |0candidates/0errors in stated scope |

The full selections precede an assertion-only strengthening of participant-key presence
in the new PostgreSQL test. Production Go inputs are identical to6dba4b4; all14final
regressions run against its immutable archive. The PostgreSQL journeys check
bill/tab/finalized/retried values, actual Alex/Birthday rows, old accepted quote day,
no provider refetch and raw bill immutability. Unauthorized unavailable-summary reads
remain403; authorized reads
return409 and finalization leaves stored state unchanged. No full-suite rerun is claimed
after that assertion-only edit.

Three independent archive controls fail executed assertions: restored summary fallback
(9leaves), unconditional native-zero backfill(1), review before authorization(1).
Overlays restored to committed hashes; no compilation/setup failure counts as proof.
Scans cover five committed Go inputs; gosec also covers both owning production packages.
Every exact owned schema from before/target/full/control runs was checked absent:230.
Shared PostgreSQL and ordinary volumes remain. All336 original files are preserved.

Raw result/source-binding/commands are in driver scratch under
`billington-structure-evidence/{currency-read-before-f558642,currency-read-correction-e4af0a7,currency-read-controls-6dba4b4}`
and `currency-read-correction/final-source-binding.json`. These are affected local
results, clean=no; independent correction review and integrated acceptance remain pending.
Broad BUG4515 stays open for display provenance0002,mobile decoder/save/replay/Keychain,
read-state and versioned JPY work. Legacy malformed individual-read normalization and
unchecked active-balance debt are not certified fixed by this tab-summary correction.

Doc impact: three keys in three living candidates(API,overview,backendREADME). API and
overview updated for total/error/ownership behavior; README's broad provider contract
remains accurate. VERIFICATION is unchanged at20478bytes; its full Go/PG rows select the
new tests. Frozen baseline,old dated notes,migrations and CHANGELOG are preserved.

## Independent source acceptance and other gates

Protocol review approved all36provider paths and the three-path readiness-fixture
follow-up: Standards0/Spec0 per scope. Reviewer execution NOT RUN; raw evidence was
independently parsed. Construction BUG4499 and reproducible-startup BUG4514 enter
pending-migration based on their completed scoped criteria. This is not integrated
V&V, full-stack/simulator startup, hosted adoption or a public-binary certification.

Next16.4.5 `e4af0a7` received root independent five-file source review: Standards0/Spec0,
only approved11lock entries. Separate fresh committed checkout: Node24.22.2/npm11.19.1,
ordinary npmci,lint,54tests/4files,production build and unsuppressed JSON audit all pass;
audit0all severities. Inputs unchanged and owned checkout removed. These are54unique
tests executed independently by lead/root, not108different tests. BUG4502 stays
in-progress for external alert/deployed closure; official article/tag discrepancies
remain recorded in its dated implementation note.

Global security/integrated/release acceptance remains RED. API/OCR/recovery source
safeguards are approved as the next bounded lead work; durable allowance remains a
later ordered migration. No hosting/control-plane,live database,merge/main/mirror/tag
push,store action or final grade is authorized or claimed here. Personal Victor author
and committer verified; source feature-branch publication and independent re-review follow.
