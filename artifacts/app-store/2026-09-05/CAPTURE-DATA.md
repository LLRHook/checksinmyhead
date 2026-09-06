# Fictional capture data

The campaign data uses a fictional Lisbon weekend with Maya, Leo, Nora and Oliver. Three USD bills total $191.80: Dinner in Alfama ($129.80 including a 10% tip), Tram & viewpoints ($28.00), and Pastéis & coffee ($34.00). Item assignments range from individual items to shared purchases. No payment handles or personal contacts are included.

The seed script creates records through the current, unmodified Go API, preserving the real API currency metadata (native USD, rate 1). It then copies equivalent saved-bill representations into the simulator application's real Drift database. Screens must still be opened and captured inside the real Flutter app.

## Local services

- API: `http://127.0.0.1:18080` (container port 8080)
- Docker network: `billington-preview-20260905`
- Database container: `billington-preview-db-20260905`
- API container: `billington-preview-api-20260905`
- No API keys are supplied; receipt parsing is unavailable in this isolated preview service.
- The unrelated existing service on port 8080 remains untouched.

## Seed and capture

1. Run `python3 artifacts/app-store/2026-09-05/seed_preview.py` once after the API is healthy. This creates API data and saves its local capability tokens to `fictional-seed-state.json` for reproducibility. Do not publish that state file.
2. Launch the debug app once to initialize its schema, then terminate it before changing the database.
3. Locate its container with `xcrun simctl get_app_container DEVICE_ID BUNDLE_ID data`. The database is `Documents/split_bill.sqlite`.
4. Run the seed script with `--db /absolute/path/to/Documents/split_bill.sqlite`. It validates Drift schema version 8 and creates a SQLite backup before insertion.
5. Launch the debug app configured for port 18080. Open Tabs → Lisbon weekend, the saved Dinner in Alfama, participant details, and the share sheet for real screenshots.
6. The saved Lisbon crew group can populate Quick Split participant selection. Bill entry and item assignment are ephemeral UI states, so enter an actual bill through the UI to capture them.
7. Capture the active tab before finalization. The app's Finalize action produces a real Settlement Preview. To prepare the finalized state via API instead, run `seed_preview.py --finalize --db DATABASE_PATH` while the app is terminated. Two of four settlement rows are marked paid through the real API.

## Fidelity constraints

- The final campaign uses USD throughout. EUR captures are diagnostic only: the actual participant breakdown widget incorrectly labels foreign-currency numeric shares as dollars. Do not include diagnostic EUR screenshots or make currency-conversion claims in this campaign.
- The actual settlement UI records each person's total share and paid/unpaid status. It does not display bank transfer execution or a network of person-to-person transfers; campaign copy must not imply either.
- The current selector supports USD, EUR, GBP, CAD, JPY and MXN; avoid “every currency” claims.
- Local DB persistence supports recent bills, saved people/groups and tabs. Shared data and settlement state need the API.
- Avoid renaming a EUR bill inside its details screen during capture: that widget currently reconstructs its local model without the currency fields, so it may temporarily show USD until reloaded. Data is seeded with finished display names to avoid this unrelated issue.
- The script suppresses only the existing item-assignment tutorial using its real persistence key. Complete onboarding in the app normally, or set the existing `flutter.is_first_launch` and `flutter.display_name` preferences while the app is terminated.

## Cleanup

After all app captures are complete, stop/remove only the two dedicated preview containers and their dedicated network. No existing stack or production data needs to change. Keep raw screenshots and finished exports, and omit local seed tokens or database backups from public/email preview artifacts.
