# Repository guidance

## Working agreement

Use the current task and maintained repository as context. Preserve unrelated edits,
untracked Android work, and screenshot artifacts. Git commits use Victor Ivanov
<vivanov@paradigmtesting.com>.

Before adding a dependency, verify its functionality, current stable release, and API
in primary documentation. Keep architecture in [docs/technical-overview.md](docs/technical-overview.md)
and contracts in [docs/backend-api.md](docs/backend-api.md); update affected docs with code.
For UI changes, consult [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). For iOS builds, open
`mobile/ios/Runner.xcworkspace`; use available simulator tools or Flutter/Xcode tooling.

## Development workflow

Maintain one root [bugs.md](bugs.md)/[features.md](features.md) pair; Jira is off.
Use only `python3 .cycle/trackers.py` for tracker entries and IDs; read
[.cycle/TRACKERS.md](.cycle/TRACKERS.md) before writing. File confirmed bugs and approved
features with evidence and testable acceptance. Respect approval already supplied in the
current task; obtain missing product decisions before implementing proposals.

Run `python3 .cycle/trackers.py install` once per clone, then lint after merges/rebases.
Complete relevant checks from [VERIFICATION.md](VERIFICATION.md), update affected docs,
and record Fix/Implementation and Docs before setting pending-migration status.
Only a successful integrated protocol run migrates work into [CHANGELOG.md](CHANGELOG.md).
Keep runtime failures open; procedure preparation and CI success are not a V&V pass.
The [baseline ledger](docs/reviews/2026-11-02-baseline.md) maps historical findings; active
status belongs to the trackers. Preserve local database volumes during ordinary shutdown;
use isolated synthetic data for destructive verification.

## TestFlight versioning

- Before preparing a TestFlight build, bump both the marketing version and source build number in `mobile/pubspec.yaml` (`version: X.Y.Z+N`).
- Keep the Runner target's `MARKETING_VERSION` values in `mobile/ios/Runner.xcodeproj/project.pbxproj` in sync with `X.Y.Z`.
- Update the visible app version in `mobile/lib/screens/settings/settings_screen.dart` to match.
- Increment `N` for each release build. The TestFlight workflow may override the binary build number with the next available App Store Connect value, so confirm the workflow summary shows a build number newer than the last upload.
- Do not use the marketing version as the build-number input; confirm the uploaded artifact reports the intended marketing version and build number.
