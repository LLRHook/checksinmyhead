# Privacy disclosures against released behavior — 2026-11-09

Scope: `BUG-1793644510`, repository side only. Base `e0a2c18`. No App Store Connect,
hosting, provider-account or legacy-site change was made or is claimed. Production
was read with GET requests only.

## What was compared

| Subject | Evidence |
| --- | --- |
| Public binary | `itunes.apple.com/lookup?id=6746379502&country=us`: version 1.4.0, `currentVersionReleaseDate` 2026-08-26T18:23:06Z, minimum iOS 15.5 |
| 1.4.0 source | tag `v1.4.0+23` (`76ceda0`) and `5ca1dc6` (PR #135). `git diff --stat v1.4.0+23 5ca1dc6`: 4 files; in `mobile/lib` only the Settings version string |
| Deployed API | `GET /health` → `{"commit":"81a564f687067ab1d839d623dd5c1c01ae139d5f",...}` |
| Version policy | `GET /api/app/version-policy` → `{"minimum_supported_version":"2.0.3","store_url":...}`, no `capabilities` |
| Tab photo route | `GET /api/tabs/1/images` → 404, while `GET /api/tabs/1` → 403: the route is absent in the deployed revision |
| Rate route | `GET /api/currency/rate?from=EUR&to=USD` → 503 |
| Store label and link | product page HTML: `DATA_NOT_COLLECTED`; policy link `https://getbillington.vercel.app/privacy-policy` |
| Hosts | `billingtonapp.vercel.app/` and `/privacy-policy` → 404; `getbillington.vercel.app/privacy-policy` → 200 |
| Apple definitions | `developer.apple.com/app-store/app-privacy-details/` (data types, purposes, linkage, tracking, optional disclosure) |
| Anthropic terms | `privacy.claude.com/en/articles/7996866-...`: API inputs and outputs deleted "within 30 days", with listed exceptions |

## Findings

1. 1.4.0 uploads every finished bill on Done (`bottom_bar.dart`) and retries at
   launch (`landing_screen.dart` → `retryPendingUploads`). The public label says no
   data is collected, and the 1.4.0 Settings text says data never leaves the device.
2. The prepared policy described unreleased `main`: Frankfurter-only rates, Keychain
   recovery credentials, pending-save resume and loggers that drop SQL text. The
   deployed revision still has the ExchangeRate-API lookup and a SQL logger that
   writes statement values for failed and slow queries.
3. 1.4.0 has a tab receipt-photo upload that the deployed API no longer serves.
4. The source Settings notice promised that local data is removed on uninstall,
   which the policy explicitly declines to promise, and limited online storage to
   "shared" bills.

## Changes

- `/privacy-policy` is scoped to version 1.4.0 and the running service; statements
  about later builds start with "Not yet released". Three web tests pin the scope,
  the required statements and the absence of date, compliance or no-collection claims.
- Settings notice corrected in source, with a widget test at 2x text and 320 pt.
- `docs/privacy.md` rewritten as released / not yet released / OPEN.
- `docs/app-privacy-label.md` added: prepared answers per Apple data type, purpose,
  linkage and tracking. Not submitted.
- `scripts/verify_web_routes.py` policy statements follow the new copy.

## Executed

| Check | Result |
| --- | --- |
| New web tests on the previous page | 2 failed (scope, required statements), 1 guard passed |
| New Settings test on the previous text | failed at the first content assertion |
| `npm run lint`, `npm test`, `npm run build` (Node 25.9.0, npm 11.12.1; the pin is Node 24) | lint 0 errors; 105 of 105 tests in 11 files (102 before, 3 added); build succeeded |
| `delivery_gate.py validate-reports --row web` on that Vitest report | accepted, 105 passed, 0 failed, 0 skipped |
| `scripts/verify_web_routes.py` against an owned loopback `next start`, no fixtures | 6 public cases, 0 failed |
| `flutter analyze`; `flutter test --no-pub --reporter json` (Flutter 3.41.5) | no issues; 594 visible cases, 0 failures, 0 skips; mobile row accepted by the gate |
| `python3 ops/ci/unittest_report.py ops/ci/test_delivery_gate.py` | 42 methods, OK |

The web verifier ran without the Go/PostgreSQL fixture, so it covers the public
documents only. No headed-browser or device walkthrough was run.

## Still open

Listed in [privacy.md](../privacy.md#open-owner-evidence-and-actions): effective date,
mailbox control, Anthropic account terms, production configuration and retention,
stored tab photos, public build number, label submission, serving the maintained
route, and whether the policy should correct the 1.4.0 in-app text explicitly. The
ticket stays in progress.
