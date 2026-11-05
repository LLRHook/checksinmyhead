# Mobile save corrections and local native recovery — 2026-11-04

The source corrections through `276c33fe138dab036f534f2c0e4d1e209cdad44f`
are accepted within their bounded scope. Independent review reports **Standards0 /
Spec0**: durable tab intent during overlapping launch recovery, per-row history
validation feedback and the Drift9 architecture inventory are corrected. The five
finite persistence diagnostics also satisfy BUG-1793848441. Its status can be
fixed-pending-migration; BUG-1793644500/4515 remain in-progress.

## Source and host evidence

Production corrections are `11e6f676` and `7bddfa9d`; commit276 adds evidence and
tracker metadata. Root's clean committed-snapshot Flutter row at7bddfa9 passes
enforced acquisition, analysis, affected formatting and all **467 visible tests**,
with **510 starts/510 terminals**, no failed/skipped/missing/orphan/duplicate runner
IDs. All prior458 visible/500 raw occurrences are preserved, including historically
repeated labels. All495 qualified tracked inputs stayed unchanged. Three guard
removals fail intended assertions with healthy controls; the real SQLite rejection
proves diagnostic confidentiality and preserved rows. See the
[correction evidence](2026-11-04-mobile-save-corrections.md).

The independent eight-path review performed read/hash/parse only, with no test,
build or scanner execution. Its report SHA256 is
`c17b1501fb246d4b976e099a0ea564a5a5612590cb6024a5bb1f827291cc15d3`.
Raw Semgrep remains exit1/14 reviewed finite-log candidates, zero errors and no
suppression; Gitleaks is exit0/zero candidates. This is no whole-security pass.

## Actual maintained iOS Runner follow-up

At exact276, root built the maintained Runner workspace with an owned ignored
functional target using the production AppDelegate, native Keychain MethodChannel,
creation-key adapter, save owner, ApiService and file-backed Drift. The same installed
artifact ran first save and actual process-reopen against an owned synthetic
loopback replay fixture. **33/33 app assertions pass:16 first process,17 reopen**.
Raw console events equal app-written receipts; all starts/terminals match and both
actual processes ended. Independent OS app-exit status is unavailable; wrapper and
intended exit remain separate. Independent review of this native evidence is pending.

After a dropped synthetic201, one EUR25 local row remains pending without invented
USD. A different app process retrieves the same native key through the actual
MethodChannel and replays the exact persisted request/key: the same row publishes
remote ID191104 and freezes USD31.25 at1.25. Ordered repeated items and a zero-share
participant survive. The closed actual SQLite file excludes the canonical key and
native bytes. The fixture observes exactly two create POSTs and two version-policy
GETs, with identical body/key digests. This synthetic fixture proves mobile behavior;
the earlier actual maintained-server/PostgreSQL/Drift proof remains separate.

Only the driver's separately bounded local simulator CLI signing was used: dash
identity, Manual, empty team/profile fields, no named authority/profile, no project
settings or entitlement changes. Fourteen code identities, actual embedded simulator
entitlements/compiler inputs, kernel and all126 installed app-file hashes were bound.
No account, provisioning, release signing or publication action occurred.

The one owned simulator was deleted, all37 previous devices/states preserved,
owned processes stopped and loopback port closed. Both normal generated files were
restored; the private target was removed. All496 tracked files,336 originals,
158 accepted server/image inputs and25 Flutter framework inputs stayed unchanged.
All five stage wrappers exited0 and cleanup passed. No app rerun or numerical
campaign was used to repair a parser result.

Retained scratch handoff: `MOBILE_NATIVE_SAVE_FOLLOWUP_RESULT_20261104.md`.
The root reconciliation binds200 files, SHA256
`ff2cf17f702fcc15754930e0f671c05095436eec3fd404b5dbd8b7ae5f0b9bf4`.
The historical unsigned `-34018` and zero-case setup failures remain unchanged.

## Remaining gates and documentation impact

The `.005` local/published allocation mismatch, identity0003/versioned JPY precision,
physical/public-signed clients, restore/old-writer drain, memory plateau, OCR durable
spending, runtime timing flake/50k-assignment latency and whole integrated/security/
release acceptance remain open. No grade, CHANGELOG migration, Verified entry,
hosting mutation or rollout approval follows.

| Document | Effect |
| --- | --- |
| This note | Records accepted source, actual native observations and limits. |
| docs/mobile-save-verification.md | Distinguishes the historical unsigned attempt from the separately bounded local simulator procedure. |
| bugs.md | Records source acceptance; only the finite-logging ticket becomes pending-migration. |

**Whole acceptance: RED.**
