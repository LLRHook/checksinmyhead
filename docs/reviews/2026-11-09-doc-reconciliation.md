# Operational and product documentation reconciliation — 2026-11-09

Scope: `BUG-1793644512`, documentation only. Base `e0a2c18`. No code, hosting or
store change. Historical text was labeled and linked, not deleted.

## What was checked against what

| Document | Checked against | Result |
| --- | --- | --- |
| `README.md` | viewer routes; PR #149; production GETs | It already names `/privacy-policy` and no longer advertises `/privacy`. The roadmap still listed production deployment as not done; now corrected, with the dated hosting state and a statement that `/privacy` was removed on purpose |
| `backend/roadmap.md` | git history | Still presented `railway up` as a future deploy command, "current" diagrams with R2 and Gemini, and Docker Compose as the dev start. Now a labeled historical record with a status block; 17 places labeled |
| `backend/README.md` | `backend/docker-compose.yml`; `GET /health` | Compose inventory was already right (PostgreSQL and API by default, `legacy-web` profile for the 8081 renderer). It did not say where production runs or that Railway was abandoned; a "Production and history" section now does |
| `docs/backend-api.md` | `backend/cmd/bill-service/main.go` | 6 of 31 registered routes were not named literally (tab batch claims, tab-share paid flag, leave, member rename, binding request and decision). A route index now lists all 31, with the lifecycle limits |
| `docs/technical-overview.md` | `backend/pkg/models`; mobile save owner; iOS entitlements | Model sketches lacked lazy, payer and currency fields; two passages still said "fire-and-forget sync"; nothing stated lifecycle limits or what invite links can do. All corrected |
| `docs/market-analysis.md` | current architecture | Had a one-line note; now a status block listing each obsolete assumption, and its three analysis sections are labeled historical |

Railway history: the release API was pointed at Railway in `26109fb` (2026-03-28) and
reverted in `7b97d03` (2026-04-22). Railway appears nowhere else in maintained docs.

Invite capability, from source: `Info.plist` registers the `billington` scheme;
`RunnerProfile.entitlements` is empty since `5c684e8` removed
`com.apple.developer.associated-domains`; the viewer still serves an
`apple-app-site-association` file for `/t/*`; `app_links` is a dependency but no
install-time link recovery exists. The 1.4.0 `Info.plist` registers no URL scheme.

Privacy destinations, read today: the App Store listing links
`getbillington.vercel.app/privacy-policy` (200); source Settings links
`billingtonapp.vercel.app/privacy-policy` (404); the 1.4.0 binary has no policy link.

## Executed

| Check | Result |
| --- | --- |
| `DocumentationContractTests.test_operational_docs_label_history_and_match_routes_and_signed_capabilities` | Failed on the previous docs; passes now. Restoring any one of the six documents to its previous version makes it fail again (six of six detected) |
| `python3 ops/ci/unittest_report.py ops/ci/test_delivery_gate.py` | 44 methods, OK (42 at base, one added for store copy, one for this ticket) |
| `npm run lint`, `npm test`, `npm run build` (Node 25.9.0; the pin is Node 24) | 0 lint errors; 110 of 110 tests; build succeeded |
| `python3 .cycle/trackers.py lint` | 0 errors, 0 warnings |

`VERIFICATION.md` is unchanged at 20,172 bytes.

## Not done

- Which public URL is the intended privacy destination for the listing is an owner
  decision; both observed destinations are recorded, neither is changed.
- Invite behavior is stated from source and entitlements. No signed build was
  installed or driven (`FEAT-1793644507`).
- Whether a Railway project, a database vendor contract, backups or alerts exist was
  not checked (`FEAT-1793644501`).
- `tasks/todo.md` and the dated notes in `docs/reviews/` were not edited.
- The README tagline and `mobile/pubspec.yaml` description still say "privacy-first".
  That is brand wording rather than a stale instruction and was left for the owner.
