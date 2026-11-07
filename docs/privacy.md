# Privacy data inventory and publication gates

This is the maintained source inventory, not an effective hosted notice or a
released-binary certification. The public notice is semantic JSX at
`web-bill-viewer/src/app/(public)/privacy-policy/page.tsx`, destined for
`https://billingtonapp.vercel.app/privacy-policy`; its summary is at `/#privacy`.
The approved copy retains the existing commitment: **We do not sell bill or tab content.**
Source inspection alone does not verify business/provider practices or legal compliance.

## Device storage and online publication

- Drift keeps bill history, participants/groups, items, amounts and tab/member/link
  data. Settings retain display/sharing preferences, names and payment identifiers.
  These can enter later bills and shared summaries.
- The save owner commits an immutable publication request/payment snapshot and any
  destination intent locally before attempting online publication. Pending work can
  resume at launch or retry; saving for online sharing differs from sending a link.
  Release-mode keyed publication remains gated off in the current source. Do not
  equate the supported source workflow with an inspected public binary.
- Some receipt recovery credentials use the iOS device-only, unlocked Keychain
  adapter; Drift stores the nonsecret locator. Ordinary bearer links and bill details
  are separate local text. This is not a claim that all local data is encrypted or
  that uninstalling erases every credential or backup.
- Online bill/tab records can include names/descriptions, receipt items, native and
  converted amounts, tax/tip, frozen quote and display provenance, participant/member
  labels, assignments, payer/adder attribution, included payment details and manual
  paid flags. The API and configured PostgreSQL database retain shared records.

## Access, browser storage and external sharing

- Share URLs contain access credentials. The web host receives the URL; the API
  accepts the credential through Bearer or the retained query contract. Relevant
  valid links permit viewing and, according to permissions, claiming/joining/status
  changes. Display names do not verify real identity. Links do not automatically
  expire; removing local history and noindex do not revoke them.
- The browser viewer can keep a chosen claiming name and, for some tab flows, a
  member credential in localStorage. Clearing website data does not erase online
  claims/membership or revoke other copies. Authorized body/RSC still contains the
  information needed to show the bill/tab; generic metadata is a narrower safeguard.
- Clipboard, OS sharing and chosen recipients receive links or summaries, potentially
  including names, amounts and payment details. They can retain independent copies.
- Payments happen outside Billington. The Venmo handoff can carry recipient, amount
  and a bill/participant note. Other methods are shared details. Billington neither
  processes payments nor verifies transfers; participants record paid status manually.

## Providers and technical operation

- Scanning sends the whole selected receipt image to Billington's API and Anthropic's
  Claude API. Manual entry is available. Extracted details can enter a saved/shared
  bill; this upload path does not save the image in the shared bill database. Device
  originals/temporary copies and provider retention are separate.
- [Anthropic's published API terms](https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data)
  describe standard input/output deletion within 30 days, with legal, policy,
  agreement and service exceptions. Additional designated-model rules can apply.
  This is no guaranteed deadline for every scan or proof of this account's agreement,
  configured model or zero-data-retention setting.
- The current rate adapter uses Frankfurter v2 and sends currency-pair codes, not
  photos, participant names or receipt amounts. Frozen accounting and separate
  display metadata can remain with bills. Earlier ExchangeRate-API references do not
  establish current deployment or cancellation of any account. A displayed
  conversion does not perform a payment or currency exchange.
- API request logs retain client IP, time, method, path, status and duration, without
  query strings. Current SQL/error loggers suppress SQL, values and arbitrary driver
  messages while retaining finite diagnostic categories, timings and row counts.
  Source changes do not prove a deployed revision or erase old/provider logs.
- Render and Vercel provide API/web hosting. Provider/database/backup operations may
  process content and technical information, including page URLs containing access
  credentials. Actual database vendor, region, log/backup retention, agreements and
  account settings remain unverified. General [Render](https://render.com/privacy)
  and [Vercel](https://vercel.com/legal/privacy-notice) notices are not account evidence.

## Local removal, online retention and requests

Shared bills/tabs stay online until service operators remove them; no in-app control
removes an entire shared online bill/tab. Tab-list **Remove from this device** removes
the saved local tab entry, keeping receipts, shared bills/totals and other people's
access. Removing a bill from a local-only, nonfinalized tab edits that local list and
keeps history. Synced/finalized tabs offer no bill-removal swipe because there is no
supported server detachment. The existing Leave action is a separate authenticated
membership operation, not shared-tab deletion. Local mutations report failure without
announcing success or dismissing the row.

History deletion, clearing data, browser clearing and uninstalling do not delete
online records or revoke links. Removing a local entry need not erase separately
stored credentials. Operator removal does not guarantee removal from backups,
provider logs, photos, messages or recipients' devices; no universal purge deadline
is promised.

Privacy, deletion and support: [checkmateapp@duck.com](mailto:checkmateapp@duck.com).
Describe the request first, without a private bill link in the initial message;
additional information may be needed to locate records and verify authority.
Mailbox control and the actual removal procedure remain publication gates.

## Release sequencing

Serve and verify the canonical full-policy route **before shipping a client that
uses the updated Settings destination**. Establish the actual operative notice date
after reconciling served/released flows; preparation on November 5 is not an effective
date. Review Apple categories, purposes, linkage/tracking and third-party practices
against the actual public binary. Do not claim that this source change updates the
legacy policy, App Store labels/destination, logs, account settings, entitlements or
post-install/universal-link delivery. The Settings paragraph beyond its exact
destination is unchanged and still needs released-copy reconciliation.

See [scoped implementation evidence](reviews/2026-11-05-public-web.md). Independent,
driver, production, contact-channel and signed/store acceptance remain separate.
