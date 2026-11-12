# Mobile save journey and the odd-cent difference — 2026-11-09

Scope: BUG-1793644500 on branch `sweep/mobile-currency` (`e0a2c18` base). Local
Flutter 3.41.5 host row only. The ticket stays `in-progress`: the odd-cent rule below
needs an owner decision, and integrated, native and release evidence is outside this
repository.

## What was still unproven, and what now proves it

| Expected | Before | Now |
|---|---|---|
| One stable local record across Done, share, retry, restart and tab attachment | Each step had its own test on its own row | `save_journey_test.dart`: one file-backed EUR row through all of them in order, with every native column and the request snapshot compared after each step |
| Quote state and messages agree with persistence | Only "Saved on this device" was asserted | Eight EUR/USD outcomes compare the returned result, the row a restart would read, the model's USD value and the rendered history card |
| Retryable without duplicate or wrong-USD upload | Same key/bytes proven for two requests | Five create requests across two app sessions: one key, byte-identical body with `currency_code` EUR, one remote commit, one local row, even when a repeated Done passes a USD draft |
| Flow-level Drift tests through the real seam | Done once through the actual handler | Done, failure, Done again through `DoneButtonHandler.handleDone` on the same operation: one row, two identical requests |

The seam is the maintained `RecentBillsManager` with real Drift, the real `ApiService`
and a synthetic HTTP client that commits by recovery key. No backend ran.

## Defect found and fixed

A native-USD receipt whose link was still pending reported "Link and USD conversion
pending" although its stored quote state is `native` and nothing is being converted.
Two new cases failed on that text before the change. `SaveReceiptResult.message` now
says "Saved on this device. Link pending." unless the stored quote is pending.
No stored value, schema or request changed.

## Evidence

- Before the fix: `flutter test --no-pub test/save_journey_test.dart` — 8 pass, 2 fail
  (`quote state USD offline…`, `quote state USD unavailable…`).
- After: the same command — 10 pass.
- Removal control: deleting the published-row guard in `_resume` fails the journey at
  its request count (9 creates instead of 5); the other 9 cases pass. Source restored.
- `flutter analyze`: no issues. Full `flutter test --no-pub`: 603 visible cases pass,
  0 failures or skips. Gate controller: 42 methods pass with the new file and its three
  literal registrations in `rows.mobile`.

## Decision needed: who gets the odd cent

The device and the server round a split differently. The server stores its own
result, so history on the phone and the published receipt can disagree per person.
The Log's 2026-11-03 half-cent capture is one case of this. Executed on current code
(temporary probes, not committed):

| Receipt, split evenly | Device shows and stores | Server stores and publishes |
|---|---|---|
| 0.01 between Alex and Sam | Alex 0.01, Sam 0.00 | Alex 0.00, Sam 0.01 |
| 10.00 + 0.01 tax + 0.01 tip, Alex and Sam | 5.01 and 5.01 | Alex 5.00, Sam 5.02 |
| 10.00 three ways, entered Sam, Alex, Blair | Sam 3.34, others 3.33 | Alex 3.34, others 3.33 |
| the same + 1.00 tax + 2.00 tip | Sam 4.34, others 4.33 | Alex 4.34, others 4.33 |

Device rule (`AssignmentUtils.applyLargestRemainder`): floor each total, give leftover
cents to the largest fractions, ties in entry order. Server rule
(`allocateRoundedCentsOrdered`): round subtotal, tax and tip separately, then fix each
remainder in label order. Receipt totals always agree; only the per-person cents move.
The second row is a property of the server rule itself: a symmetric split is published
two cents apart.

Expected does not require per-person parity, and every way of getting it changes
amounts people see, so nothing was changed.

| Option | What changes | Cost and risk |
|---|---|---|
| 1. Device adopts the server rule | New receipts are split on the phone exactly as they will be published | Mobile only; no contract, schema or stored-data change. Port both server paths (item-based and totals-only) with a shared fixture run by Go and Dart. The summary screen starts showing results like 5.00/5.02 and moves odd cents from first-entered to first-by-label. Already saved rows keep their old cents |
| 2. Server adopts the device rule for new receipts | Published receipts match what the phone showed | Versioned accounting contract (creation accounting is frozen at version 1), backend, web mirror and replay fixtures; old receipts untouched. Largest change; fixes the 5.00/5.02 result |
| 3. Phone shows published amounts after publishing | History switches to the server's cents once a link exists | One read after publish plus a separate stored observation; offline and pending rows still show device cents, so a row's amounts visibly change when it publishes |
| 4. Leave as is and document | Nothing | Phone and link can disagree by a cent or two per person; totals agree |

Recommendation: **option 1** now, because it needs no contract change and makes the
phone show what the group will actually be asked to pay; and a separate ticket for the
server's symmetric-split result, to be fixed in both places together under a versioned
accounting rule (option 2's server half). If a 5.00/5.02 summary is unacceptable on
the phone, take option 4 until that versioned rule exists.

## Still open on this ticket

The decision above; versioned precision (JPY) and identity under their own tickets;
integrated maintained-server, native Keychain/process and signed-release evidence.
