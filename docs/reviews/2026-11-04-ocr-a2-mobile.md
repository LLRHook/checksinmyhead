# Mobile OCR A2b source evidence — 2026-11-04

Source `57b4647d53602df37fc23696ab96ac3f2b5180d3`, based on
`3ab5395f47d52d11f80dabf2e1569fc30426a915`. Request
`billington-ocr_a2_mobile-20261104-v1`; sole shared source writer, no subagents.
This is scoped local implementation evidence, not independent/whole-A2 acceptance.

Each attempt owns an http 1.6.0 abortable multipart request/IOClient, 45s deadline,
body subscription and cleanup. Native timeout/cancel/dispose closes actual I/O;
manual retry uses a fresh client. Redirects/automatic retries are disabled.
Decoded bodies (all statuses) stop at cap+1 of 1 MiB. Bounded preflight checks
16-depth/16384-token/512-array/500-item limits before typed graphs; one owner
validates Unicode/money/confidence/currency and checked 500-line expansion.
Bill candidates are fully validated/built before mutation; review uses the same
rounding owner and retains discounts. Widget disposal/late review checks preserve
manual confirmation/navigation. No currency-confirmation/JPY/precision redesign.
Monotonic checks run after synchronous parse and cleanup; timers cannot preempt CPU.

Flutter **3.41.5 / Dart 3.11.3**, ordinary unchanged locked acquisition exit0;
`flutter analyze` exit0, no issues. Full `flutter test --machine`: **359/359**, zero
failures/skips/missing/duplicate terminals; all **237** pre-change case IDs retained.
31 hidden load/setup terminals are separate. New cases: 49 service, 37 validation,
14 native host-IO, 12 bill-state, 5 widget and 5 boundary regressions. Native tests
use real loopback TCP/HTTP, stalled headers/body/upload, abort/close, gzip cap,
302/303/307 refusal, dropped response and exact POST counts/manual retry. They are
not iOS simulator, physical-device or signed public-binary coverage.

Immutable-base model proof fails4/passes1; native send-only timeout proof fails1
(actual upstream survives). The native before harness changes only URL/client/
timeout injection, preserving the defect. Nine independent removals each fail the
intended executed assertion: actual native cancellation, body cap, depth, tokens,
array/item limits, quantity, validation-before-state and late widget application.
No compile/setup/zero-test failure is counted as removal proof. Exact inputs,
patches, commands and JSON terminals are retained. Final ordinary suite binds all
131 Dart/test/lock inputs; only an unused import/native-test formatting followed
removal experiments, with no functional source change.

Retained initial errors include a test Person-key compile mistake, root-zone
stream-cancel fixture pumping, native peer write-future resets and analyzer issues.
A real intermediate cleanup-deadline test exposed terminal-signal double completion;
that source defect was fixed and rechecked. No discarded rerun-to-green history.
Native fixtures await owned cleanup; temporary receipt directories are removed.
336 protected originals remain hash-identical; backend source, locks/manifests,
migrations/CI/frozen notes and normal volumes/shared PostgreSQL remain unchanged.

Unsuppressed scoped scans: Semgrep1.183.0 exit0/findings0/errors0 on all11 Dart owners/
tests (four focused Dart rules plus retained generic security rules); Gitleaks8.30.1
raw exit1/findings3, unchanged named API-document placeholders, confirmed0/suppressions0.
Raw candidate line hashes/triage remain; no broad dependency certification is claimed.
Only BUG-1793644508 is updated through `.cycle/trackers.py`; in-progress, <=2.5KB.
[Mobile procedure](../mobile-ocr-verification.md) supplements VERIFICATION; its actual
mandatory matrix/safeguards remain and file size is 20478 bytes <=20 KiB.

Raw evidence: scratch `ocr-a2-mobile/` under the November2 parent task, including
`commands.jsonl`, `counts.json`, `implementation-bindings.json`, per-run input hashes,
`experiment-inputs/`, patches and raw scanner JSON. Source/identity receipts are in
`source-commit.json`; final commit/remote/lease/preservation bindings and the substantive
handoff live in scratch `OCR_A2_MOBILE_IMPLEMENTATION_RESULT.md` and
`ocr-a2-mobile/final-bindings.json`. The [official http API](https://pub.dev/documentation/http/latest/http/AbortableMultipartRequest-class.html)
identified 1.6.0 and was checked against the exact cached locked implementation.

Backend independent review remains **REQUEST CHANGES: three P2 findings** for native
provider lifetime, pre-lock quota timestamps and native diagnostic logging; reviewer
execution NOT RUN. No backend correction is folded into this slice. Durable allowance
B, owner budget/provider/account enforcement, old-writer drain, independent clean/
integrated/device/provider/hosting/signed-public/release gates remain open. Existing
JSON performance/global gates stay RED. Mobile performance/memory distributions were
not measured; liveness fixture deadlines do not establish capacity or p95 budgets.
No paid/public inference, customer SQL, Vercel/Render authentication/control plane,
release build/version bump/store publication, main/tag push, merge or review submission.
Root owns current CI/public post-push and independent acceptance.
