# Mobile upload cleanup correction — November 4, 2026

## Scope and decision

Independent review of `3ab5395..c487550` found two distinct mobile ownership gaps:
M1, cancellation during TLS negotiation, and M2, completion of native send without
joining the original multipart input's asynchronous cancellation. This correction
addresses **M2 only**. M1 was reproduced and remains open. The source/tests and
living documentation are committed at `957433ae39c2a23f761bc968eca54400936222b6`,
whose parent is `c48755060fb0ac77d5e4826f2b225390b0e5e825`.

`ReceiptApiService` now retains the original upload subscription behind a private
owner. It preserves field name, length, filename, content type and backpressure.
The attempt starts cancellation when stopped, then awaits the same memoized cleanup
future before settling. It retains the subscription across stream errors, handles
cancellation during `listen`, and converts cleanup errors to finite local messages.
Client ownership, redirect/retry policy, deadline, response limits, validation and
bill application rules are unchanged. Awaiting `IOClient.send` alone was insufficient.

The stronger existing native cancellation case retains its display name. Three
additional modes exercise source errors, cleanup errors and reentrant cancellation.
The fixture independently observes native send completion while holding original
input cleanup, then requires one cancellation, joined cleanup, a finite error and
actual peer disconnect. Source-error serialization already awaits its cleanup, so
that mode deliberately does not require send to finish before cleanup is released.

## Executed regression and removal evidence

Raw evidence is retained below the driver's original task scratch directory,
`mobile-review-corrections/`. Commands, exits, durations and source hashes are in
the corresponding `*.command.json`; stdout/stderr retain actual runner events.

| Selection | Result and qualification |
|---|---|
| `verified-input-before.command.json` | The strengthened cancellation assertion fails against the exact `c487550` service snapshot. Only the test import selects that immutable snapshot; production control flow is unchanged. |
| `missing-upload-join.command.json` | Removing only the final `await operation.finish()` causes three executed assertion failures: cancellation, cleanup error and reentrant cancellation. The source-error control passes because its serializer already waits for cleanup. |
| Final clean committed snapshot | All 362 visible tests pass, including 17 native cases; all 359 prior case occurrences are preserved. Zero failed, skipped, missing or duplicate terminal events. |
| `tls-before.command.json` | Three executed deadline/cancel/dispose failures against a silent TLS peer, plus one passing ordinary HTTP control. These establish the separate unresolved M1 gap. All fixture peers were subsequently closed and joined. |

The immutable M2 before-service SHA-256 is
`6199472346c5524ada1c135a5e78e6f6eb31fe65321bdea9ff66f76586a8d884`.
The final service SHA-256 is
`b6d4f1694c5de6e67dcc4c6eaa7af5cd8726424b4a9969bbd8873deb12c73546`;
the final native-test SHA-256 is
`56829968e4eb85efd46e627c16852c10c254932cbaa7bb318db28740b44e3c46`.

An initial added source-error fixture timed out because it incorrectly waited for
native send while the serializer itself awaited held input cleanup. That fixture
assumption was corrected; its failing raw log is preserved. An earlier scratch
`StreamIterator` approach was replaced before committing because its error path
could discard the subscription's cancellation future. Neither event is represented
as an application pass or omitted from the retained development history.

## Clean local gate

The root-owned detached worktree was created from the committed source SHA, used
the maintained lockfile, and was removed after verification. The exact command
arrays, toolchain and before/after input bindings are in
`mobile-review-corrections/clean-gate/result.json` and its raw logs. No tests were
rerun merely to replace a failure with a passing total.

```text
Local gate: GREEN   scope=affected clean=yes sha=957433a
| layer | command | executed | failed | skipped (delta) |
| acquisition | flutter pub get --enforce-lockfile | n/a | 0 | n/a |
| analysis | flutter analyze | n/a | 0 | n/a |
| mobile incl. native integration | flutter test --machine | 362 | 0 | 0 (0) |
Flaky: none   Blocked: none in this M2 correctness selection
```

Flutter was **3.41.5**, Dart **3.11.3**. `--machine` changes reporting, not test
selection or skip policy. There were also 31 successful hidden loader cases.
Repeated display labels are counted by runner identity and occurrence, rather than
silently collapsing two distinct tests. All 131 selected committed inputs were
unchanged before/after the run; the verification checkout was clean. All 336
protected original files in the primary checkout remain hash-identical.

This is macOS host-VM/native-loopback evidence. It does not certify TLS cancellation,
simulator/device behavior, a signed public binary, or the complete integrated stack.
Independent re-review of this correction remains pending at this evidence commit.

## Security evidence

Semgrep **1.183.0** ran against both changed Dart owners using the retained generic
and Dart rules with strict errors, no `nosem` suppression, and metrics disabled.
Raw exit **0**, findings **0**, errors **0**. Its source hashes match the final
committed service and test above. The command and report are in
`mobile-review-corrections/scans/semgrep-result.json` and `semgrep.json`.

The final scoped Gitleaks command, unmodified raw exit/report, copied-input hashes
and per-candidate dispositions are recorded in
`mobile-review-corrections/scans/gitleaks-result.json` and `gitleaks-triage.json`.
That scan covers all six correction paths, this evidence note and the full tracker
file. Gitleaks **8.30.1** returned raw exit **1** with **three unchanged documentation
placeholders**, zero confirmed secrets and no suppressions. Each placeholder is
verified against the parent snapshot. No scanner result changes the unresolved M1
or backend review decisions.

## Documentation impact

| Path | Updated contract |
|---|---|
| [mobile README](../../mobile/README.md) | Explicit original-input cleanup join; TLS cancellation remains unaccepted. |
| [API contract](../backend-api.md) | Separates requested native cancellation from proven input cleanup. |
| [Technical overview](../technical-overview.md) | Private input owner and incomplete TLS lifetime guarantee. |
| [Mobile OCR procedure](../mobile-ocr-verification.md) | Held asynchronous cleanup, source/cleanup errors, reentrant cancellation and missing TLS controls. |
| `bugs.md`, BUG-1793644508 | Partial correction/evidence; status remains in progress. |

`VERIFICATION.md`, dependency locks, Flutter version, backend source, receipt money
policy and the frozen baseline were preserved. No CHANGELOG migration, provider or
hosting mutation, paid inference, live database work, App Store/TestFlight action,
merge, main/mirror/tag update or deployment occurred. The program branch may be
pushed through the already authorized repository workflow; this note itself proves
no deployed identity.

## Remaining acceptance

M1 TLS ownership needs its own supported design and executed native proof. Backend
OCR F1/F2/F3 corrections, durable allowance B and the owner spending policy, old-writer
exclusion, JSON performance, clean integrated/device/signed-client verification and
release gates remain open. **Whole OCR, security, integrated and release acceptance
remain RED.** This scoped result does not establish a new overall project grade.
