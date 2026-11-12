# App Store privacy label: prepared answers

Prepared answer sheet for the App Privacy questions in App Store Connect. **Not
submitted.** Entering it is an owner action in App Store Connect; nothing in this
repository changes the public label, which showed "Data Not Collected" on
2026-11-09. This sheet is a reading of Apple's published definitions against the
[data inventory](privacy.md). It is not legal advice or a compliance statement.

Source for every definition quoted here:
[App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/),
read 2026-11-09. Apple says the answers can be updated at any time without an app
update, and that the developer is responsible for keeping them accurate.

## Why "Data Not Collected" does not fit

Apple defines "collect" as "transmitting data off the device in a way that allows you
and/or your third-party partners to access it for a period longer than what is
necessary to service the transmitted request in real time." Data collected only for
app functionality "still needs to be declared".

The public 1.4.0 binary posts every finished bill to the Billington API when the user
taps Done, and the API keeps it in a database until an operator removes it. That is
collection under this definition. The optional-disclosure exception does not apply:
it requires collection that is "not part of your app's primary functionality" and
that the user "affirmatively chooses" each time; saving a bill is the primary
function and the upload is automatic.

## Scope

Answers cover the **public 1.4.0 binary with the deployed service** (API commit
`81a564f`). The last column notes what changes when a build from current `main`
becomes public. Re-run the sheet against the binary actually submitted.

## Data types

Purpose for every "Yes" row: **App Functionality** only. There is no analytics,
advertising or personalization code in 1.4.0 or on `main` (`mobile/pubspec.yaml` has
no such SDK). **Tracking: No** for every row: no third-party data is linked for
advertising and nothing is shared with a data broker.

| Apple data type | Answer for 1.4.0 | Basis | Changes on `main` |
| --- | --- | --- | --- |
| Contact Info: Name | Yes | Participant names, the creator's display name and tab member display names are typed into named fields and stored online. Apple: asking for "a specific data type ... such as their name" requires the specific type. | none |
| Contact Info: Phone Number | Yes | Zelle and Apple Pay payment identifiers are entered as a phone number and uploaded with each bill. | none |
| Contact Info: Email Address | Yes | The Zelle identifier may be an email address. | none |
| Financial Info: Payment Info | Yes | "form of payment": the selected payment methods and their handles (Venmo, Cash App, Zelle, Apple Pay) are stored with each bill. No card or bank account number is requested. | none |
| Financial Info: Other Financial Info | Yes | Bill amounts, each person's share, tab balances and settlements ("debts, or any other financial information") and manual paid flags. | adds currency, frozen rate and USD totals |
| User Content: Photos or Videos | Yes (conservative) | The API does not store the scanned photo, but forwards it to Anthropic, whose published terms describe retention up to 30 days: longer than servicing the request. Anthropic is not code in the app, so Apple's "third-party partners" wording does not plainly cover it; Yes is the cautious reading. Separately, 1.4.0 can attach a receipt photo to a tab: the deployed API rejects it (404), earlier API versions stored it. | tab photo attachment removed |
| User Content: Other User Content | Yes | Free-text bill and tab names, tab descriptions and item names. | none |
| Identifiers: User ID | Yes | Joining a tab returns a member credential that identifies that member to the service ("assigned user ID"). | adds participant identity |
| Diagnostics: Other Diagnostic Data | Yes | Request logs keep the client IP address, path, time and status. Apple: declare a stored IP address "based on how you use" it; here that is diagnostics and scan rate limiting. The deployed SQL logger can also write statement values. | statement values removed from logs |
| Location (precise or coarse) | No | No location API; the IP address is not used to derive location. | none |
| Contacts | No | Names are typed; the address book is not read. | none |
| Identifiers: Device ID | No | No advertising or device identifier is read or sent. | none |
| Usage Data, Browsing History, Search History, Purchases | No | No analytics, no in-app purchase. | none |
| Diagnostics: Crash Data, Performance Data | No | No crash or performance SDK. Data Apple collects itself is not the developer's to declare. | none |
| Health & Fitness, Sensitive Info, Audio, Gameplay, Customer Support, Surroundings, Body | No | Not requested by any feature. | none |

## Linked to the user

Recommended answer: **Linked: Yes** for every "Yes" row.

Apple: data "is often linked to the user's identity, unless specific privacy
protections are put in place before collection to de-identify or anonymize it", and
the developer "must not tie the data to other datasets that enable it to be linked".
Billington has no account, but a stored bill holds names beside payment handles,
phone numbers or email addresses, and a member credential ties later requests to a
tab member. No de-identification is applied before collection. The request log line
(IP address) is the only candidate for "not linked"; treating it as linked is the
conservative answer.

## Privacy links

- **Privacy Policy URL (required).** The public listing points to the legacy
  `https://getbillington.vercel.app/privacy-policy`. The maintained page is
  `https://billingtonapp.vercel.app/privacy-policy`, which returned 404 on
  2026-11-09. Do not switch the link until the maintained route is served.
- **Privacy Choices URL (optional).** None prepared. Deletion requests go to
  `checkmateapp@duck.com`.

## OPEN before submitting

1. Owner confirmation of each answer, in particular linkage and the Photos row,
   which rest on provider terms rather than this account's Anthropic agreement.
2. Anthropic retention agreement or zero-data-retention setting. A verified
   zero-retention agreement could change the Photos basis for scanning.
3. Render and Vercel log retention, and whether tab photos stored by the 1.4.0-era
   API still exist.
4. Mailbox control for `checkmateapp@duck.com`.
5. Which policy URL the listing should use, and an effective date for that policy.
6. Whether TestFlight 2.0.x builds need the same answers (the label is per app, not
   per build).
