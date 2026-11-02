# Flutter lock reproducibility — November 2, 2026

BUG-1793652308 follows the locked-acquisition failure disclosed in
[Go dependency evidence](2026-11-02-go-dependency-maintenance.md) and
[web dependency evidence](2026-11-02-web-dependency-maintenance.md), associated with
BUG-1793644503/4502. Driver authority: `RUNTIME_LOCK_APPROVAL.md`, deliverable 1.
Implementation base: `f9f8fb86dd8cfa45052dcbc26edf9e69ff19c9bf`.

Flutter **3.41.5**, revision `2c9eb20739dfec95e2c74bd3dfa4601b0a8a36aa`,
Dart **3.11.3**, generated exactly these four package/checksum changes using
`flutter pub get`:

| SDK-controlled package | Before | After |
|---|---|---|
| characters | 1.4.0 | 1.4.1 |
| matcher | 0.12.17 | 0.12.19 |
| material_color_utilities | 0.11.1 | 0.13.0 |
| test_api | 0.7.7 | 0.7.10 |

The exact SDK requirements were reverified against the official
[framework manifest](https://raw.githubusercontent.com/flutter/flutter/3.41.5/packages/flutter/pubspec.yaml)
and [test manifest](https://raw.githubusercontent.com/flutter/flutter/3.41.5/packages/flutter_test/pubspec.yaml).
[Pub documents](https://dart.dev/tools/pub/cmd/pub-get#enforce-lockfile) enforced
resolution and archive-hash validation. No latest-package upgrade was selected.
The lock diff contains only these four records; all other lock bytes, the manifest,
mobile source/generated databases, CocoaPods lock and SDK/workflow pins are preserved.

| Command, in `mobile` | Executed result |
|---|---|
| Baseline `flutter pub get --enforce-lockfile` | Prior dependency run: exit 65 twice; would change four dependencies |
| `flutter pub get` | Exit 0; four records regenerated |
| `flutter pub get --enforce-lockfile` | Exit 0; no lock changes |
| `flutter analyze` | Exit 0; no issues |
| `flutter test --reporter=json` | Exit 0; 203 visible tests, 21 hidden suite loads, zero failures/skips |

Raw reports and command/result records: `.vv/local-gate/runtime-lock/`.
This lead's validation is **scope=affected, clean=no**, under the explicit shared
checkout constraint. Independent driver validation from a clean committed snapshot
remains required. Canonical CI enforcement belongs to the subsequent workflow
phase (BUG-1793644501); no workflow changed here. Runtime image findings and full
integrated acceptance remain separate gates. No ledger migration or release occurred.
