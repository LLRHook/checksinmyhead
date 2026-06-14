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
