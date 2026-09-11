# App Review Notes

## What is new in 1.4.1

Billington 1.4.1 contains two visible product changes:

1. Open an active shared tab link, choose **Join this trip**, enter a display name, and open any receipt. Guests can select an unclaimed item or split it with other people. The updated assignments and shares persist after refresh. Finalize the tab in the app to confirm the same link becomes read-only and no longer offers Join.
2. When entering a receipt in the app, select its original currency. For a non-USD currency the app shows the latest available daily conversion to USD before continuing. The receipt keeps its original amounts and rate audit details; shared tab totals, balances, and settlements use the frozen USD value.

If the daily reference rate cannot be retrieved, Billington explicitly asks the user to retry or use USD and does not save an unverified conversion.

## Previous 1.4.0 reviewer context

Billington 1.4.0 adds a visible, user-facing Lazy Mode workflow for receipt-based bill splitting. It is available directly from the main screen under “I'm Lazy”; there are no reviewer-only switches, hidden menus, or environment-specific features.

The creator scans or enters a receipt, selects their own items in the app, and shares the remaining bill. Friends use the linked web bill to select or split items, review the tax and tip calculation, choose a listed payment method, and mark their share as paid.

## Review walkthrough

1. Open the app and choose “I'm Lazy” from the main screen.
2. Scan a receipt or enter a bill manually.
3. On the summary screen, select the items the creator had and tap “Create Link”.
4. Open the generated link in a browser or on a second device.
5. Tap “What was yours?”, enter a display name, select items, and optionally split an item.
6. Review the personal subtotal, tax, tip, and total. Use the Venmo button or the displayed external payment details, then tap “Mark as paid”.

Receipt scanning requires camera or photo-library permission. The app does not process payments; it only displays the creator's payment details and records the user's self-reported paid state.
