# Investigation Plan

- [x] Map the tabs finalize/share flow in mobile and web
- [x] Verify whether local SQLite is still used and where
- [x] Trace finalize API behavior and math calculations
- [x] Patch the root cause of the bug
- [x] Run targeted tests for the affected flow

## Review

- Finalize/share now waits on backend tab creation and bill sync instead of racing local state.
- Mobile Drift SQLite is still in use for local cache/history, but backend finalize math comes from Postgres.
- `flutter analyze lib/screens/tabs` passed.
- `GOCACHE=/private/tmp/go-build go test ./internal/tab ./internal/bill` passed.

# Lazy Mode Plan

- [x] Add a creator entry point for "I'm Lazy" in the mobile landing flow
- [x] Reuse the existing receipt parsing and bill creation flow for lazy-mode bill generation
- [x] Add backend support for updating item assignments and recalculating shares on a shared lazy bill
- [x] Add a friend-facing web claim page on the tab viewer that fits the existing design language
- [x] Add tests for assignment recalculation and the new lazy-mode API behavior
- [x] Run targeted verification for the mobile, backend, and web changes

## Review

- Added an `I'm Lazy` shortcut on the mobile landing screen that skips participant setup and routes into the existing bill parsing flow.
- Lazy-mode summaries now create a tab-backed share link, upload the parsed bill with no upfront shares, and hand friends a collaborative claim page.
- The tab viewer now keeps the lazy board active until every item is fully claimed, then falls back to the normal totals/payment view.
- Backend now recalculates person shares from item assignments and the targeted backend, Flutter, and web tests passed.
