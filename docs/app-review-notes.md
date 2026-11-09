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

## Prepared App Store metadata (not submitted)

Status on 2026-11-09: the public listing is version 1.4.0 in all ten storefronts
sampled through `itunes.apple.com/lookup` (us, ca, gb, au, de, fr, jp, mx, in, br).
Its description calls the app "Spliq" twice and "privacy-first ... without
compromising your data", and the web product page shows no subtitle. The 1.4.1 notes
above were prepared for a version that is not the public one.

Submitting this copy is an owner action in App Store Connect; nothing in this
repository changes the listing, and the release scripts in `.github/scripts` write
only "What's New". The copy describes what the public 1.4.0 binary does, read from
its source (`5ca1dc6`). It was not checked by running that binary against the live
service: do that first (`BUG-1793644511`).

Field limits come from App Store Connect Help,
[App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
and
[Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information),
read 2026-11-09. `DocumentationContractTests` in `ops/ci/test_delivery_gate.py`
checks the blocks below against them.

| Field | Apple limit | Editing |
| --- | --- | --- |
| Name | 2 to 30 characters | new version, or a status that permits editing |
| Subtitle | 30 characters | confirm in App Store Connect |
| Promotional text | 170 characters | any time, "without requiring an updated submission" |
| Description | 4000 characters, plain text | confirm in App Store Connect |
| Keywords | 100 bytes; each keyword longer than two characters; no app or company name, no other apps' names | confirm in App Store Connect |

### Name

```text
Billington
```

### Subtitle

```text
Split receipts item by item
```

### Promotional text

```text
Scan a receipt, choose who had what, and share a link so friends can claim their own items. Tax and tip follow what each person ordered. No account needed.
```

### Description

```text
Billington splits a restaurant bill by what each person actually ordered.

Scan the receipt or type the items in, choose who had what, and Billington works out each person's total with their share of tax and tip.

HOW IT WORKS
• Scan a receipt photo to pull out the items and prices, or enter them yourself. Check and edit the result before you split.
• Give each item to one person, or split an item between several people.
• Add tax and tip. Each person's share of both follows what they ordered.
• Share the result as a text summary or as a link that opens in a browser.

LAZY MODE
Pick your own items, share the link, and let friends claim theirs in a browser. They do not need the app or an account.

TABS FOR TRIPS
Keep several receipts in one tab, invite people with a link, see who owes whom, and close the tab with a list of who should pay whom.

PAYING EACH OTHER
Billington does not move money. It shows the payment details you choose to include, such as a Venmo, Cash App, Zelle or Apple Pay handle. If Venmo is installed, the shared web page can open it with the amount filled in; payment happens in Venmo. Marking a share as paid is a note between friends: Billington does not confirm that a payment happened.

GOOD TO KNOW
• No Billington account or sign-up.
• Amounts are in US dollars.
• Bills you save and tabs you create are stored online so their links work. Anyone with a link can open it, so send links only to the people on the bill.
• Receipt scanning sends the photo you choose to Anthropic, an AI service, to read it. You can always enter items by hand instead.

Questions or feedback: checkmateapp@duck.com
```

### Keywords

```text
bill,splitter,check,tip,calculator,dinner,restaurant,group,expenses,tab,trip,roommates,itemized
```

### Open before submitting

- The current keyword field, subtitle and any conversion or search data are visible
  only in App Store Connect. They were not read, so this keyword list is ungraded.
- Recheck every line against the binary being submitted. A 2.x build changes at
  least "Amounts are in US dollars" (receipt currencies) and the workflow wording.
- The description must stay consistent with the privacy label and policy
  ([app-privacy-label.md](app-privacy-label.md)). Do not restore "privacy-first" or
  "your data stays on your device" wording.
- Which fields can be edited without a new version depends on the app's status;
  Apple's reference states it only for the name and the promotional text.
