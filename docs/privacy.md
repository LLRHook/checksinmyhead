# Privacy data inventory and publication gates

This is the maintained source inventory. It is not an effective hosted notice, a
released-binary certification or a legal-compliance statement. It separates what the
**public App Store binary and the deployed service** do from what exists only on
unreleased `main`. The public notice source is
`web-bill-viewer/src/app/(public)/privacy-policy/page.tsx`, destined for
`https://billingtonapp.vercel.app/privacy-policy` (summary at `/#privacy`). The
prepared App Store label answers are in [app-privacy-label.md](app-privacy-label.md).
The copy keeps the existing commitment: **We do not sell bill or tab content.**

## Evidence baseline (2026-11-09)

| Subject | Observed | How |
| --- | --- | --- |
| Public App Store binary | 1.4.0, released 2026-08-26, US storefront | `itunes.apple.com/lookup?id=6746379502&country=us` |
| Source for 1.4.0 | tag `v1.4.0+23` and commit `5ca1dc6` (PR #135); `mobile/lib` differs between them only in the Settings version string | `git diff --stat v1.4.0+23 5ca1dc6` |
| Production API | commit `81a564f` (PR #158, 2026-10-13); predates PR #159 | `GET https://billington-api.onrender.com/health` |
| Version policy | `minimum_supported_version` 2.0.3, no `capabilities` | `GET /api/app/version-policy` |
| 1.4.0 and the policy | 1.4.0 has no version gate (added in `3b7cc4f`, 2026-10-12), so it keeps using the API | `git merge-base --is-ancestor 3b7cc4f 5ca1dc6` fails |
| Store privacy label | "Data Not Collected" | public product page |
| Store privacy policy link | `https://getbillington.vercel.app/privacy-policy` (HTTP 200; legacy host) | public product page |
| Maintained web host | `/` and `/privacy-policy` return 404 on `billingtonapp.vercel.app` | read-only GET |

The store does not publish the build number of the public binary. The deployed web
viewer does not report its revision; the 404s show only that the maintained public
pages are not served. Both stay OPEN below.

## Released: 1.4.0 with the deployed service

**On the device.** Drift keeps bill history (participants, items, amounts, share
link), recent people and groups, and tabs with their access and member credentials.
SharedPreferences keeps the display name, selected payment methods and their
identifiers, and display preferences. 1.4.0 does not use the Keychain.

**Sent and stored online.** Tapping Done on a finished bill saves it locally and then
posts it to `POST /api/bills` without a separate choice; bills without a share link
are retried silently at the next launch. Lazy mode (Create Link) creates a tab and a
bill. The request carries the bill name, amounts, tax, tip, participant names, items,
assignments, per-person shares and the selected payment methods with their
identifiers (Venmo, Zelle, Apple Pay and Cash App handles, phone numbers or emails).
With no method chosen, 1.4.0 sends the placeholder `Venmo` / `@username`. Creating
a tab sends its name, description and the creator's display name; joining sends a
display name and returns a member credential. The API keeps these records in
PostgreSQL until an operator removes them.

**Receipt scanning.** The selected photo goes to `POST /api/receipts/parse` and from
there to Anthropic's Messages API. The handler reads it into memory and does not
store it. Anthropic's
[published API terms](https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data)
(re-read 2026-11-09) describe deletion within 30 days with exceptions; they are not
evidence of this account's agreement or zero-data-retention setting.

**Tab receipt photos.** 1.4.0 can attach a receipt photo to a tab through
`POST /api/tabs/{id}/images`. The 1.4.0-era API stored those files on the service
disk with a database row. The route was removed in `9593849` (2026-09-10) and the
deployed API answers 404, so the upload now fails. Whether earlier files or rows
still exist is OPEN.

**Logs.** The deployed request logger records client IP, time, method, path, status
and duration, without query strings. The deployed SQL logger writes the statement,
with its values, for failed and slow (500 ms) queries, and handlers log raw internal
errors: bill content and access credentials can reach the service log.

**Rate providers.** 1.4.0 has no currency feature and requests no rates. The deployed
API still serves `/api/exchange-rates/{currency}` (Frankfurter v2) and
`/api/currency/rate` (ExchangeRate-API, with a key from the environment) for later
builds; both receive currency codes only. `/api/currency/rate` answered 503 on
2026-11-09, which does not show whether a key is configured.

**In-app text.** 1.4.0 Settings says: "Your data never leaves your device. Billington
is designed with privacy-first principles—zero cloud storage and zero accounts. All
information is stored locally and removed completely when you uninstall." That is
not true of the behavior above and cannot be corrected without a new public binary.
1.4.0 has no policy link.

## Not yet released (`main`, 2.0.11 source)

None of this is in the public binary; most of it is also not deployed.

- Receipt currency, frozen USD rate and display metadata on bills. `main` uses
  Frankfurter only; the ExchangeRate-API adapter is gone.
- Durable save: an immutable request snapshot and destination intent are committed
  locally before publication, with resume at launch or retry. Keyed publication is
  still gated off in release mode (`supportsCreationReplay`), so a release build of
  current `main` would hold saved bills as pending instead of sending them.
- Some recovery credentials use the iOS device-only, unlocked Keychain adapter;
  Drift stores the nonsecret locator. Ordinary links and bill details stay plain
  local text. This is not a claim that all local data is encrypted or that
  uninstalling erases every credential or backup.
- SQL and error loggers that keep finite categories, timings and row counts and drop
  statement text, values and driver messages.
- Leave tab, **Remove from this device**, participant identity (wire version 2), the
  client version gate, and the Settings link to `/privacy-policy`.
- The corrected Settings notice: no accounts; saving a bill or creating a tab can
  send it to the service; scans go to Anthropic; removing history, clearing data or
  uninstalling does not delete online bills or tabs.

TestFlight 2.0.x builds exist (tags `v2.0.0+26` to `v2.0.11+36`). They are not the
public App Store version; who holds them is OPEN.

## Access, browser storage and external sharing

- Share URLs contain access credentials. The web host receives the URL; the API
  accepts the credential as Bearer or as the retained query parameter. A valid link
  permits viewing and, by permission, claiming, joining and status changes. Display
  names do not verify identity. Links do not expire; removing local history and
  `noindex` do not revoke them.
- The browser viewer can keep a chosen display name and, for tab flows, a member
  credential in localStorage. Clearing website data does not erase online claims or
  membership.
- Clipboard, OS sharing and chosen recipients receive links or summaries, possibly
  with names, amounts and payment details, and can keep their own copies.
- Payments happen outside Billington. The Venmo handoff can carry recipient, amount
  and a note. Other methods are shared details. Billington neither processes payments
  nor verifies transfers; participants record paid status manually.
- Render and Vercel host the API and viewer and can process content and technical
  information, including page URLs that contain credentials. General
  [Render](https://render.com/privacy) and
  [Vercel](https://vercel.com/legal/privacy-notice) notices are not account evidence.

## Local removal, online retention and requests

Shared bills and tabs stay online until service operators remove them; no released or
unreleased client deletes an entire shared online bill or tab
(`FEAT-1793644500` is open and this inventory does not depend on it). History
deletion, clearing data, browser clearing and uninstalling do not delete online
records or revoke links. Operator removal does not reach backups, provider logs,
photos, messages or recipients' devices; no purge deadline is promised.

Privacy, deletion and support: [checkmateapp@duck.com](mailto:checkmateapp@duck.com).
Describe the request first, without a private bill link in the initial message.

## Disclosure surfaces

| Surface | State on 2026-11-09 | Matches released behavior? |
| --- | --- | --- |
| App Store privacy label | "Data Not Collected" | No. Prepared answers: [app-privacy-label.md](app-privacy-label.md). Owner submits. |
| App Store policy link | legacy `getbillington.vercel.app/privacy-policy` | Not reconciled here: separately owned, not edited. |
| Maintained `/privacy-policy` source | Scoped to 1.4.0 and the running service; later behavior marked "Not yet released" | Yes in source, covered by web tests. Not served (404). |
| 1.4.0 Settings text | "never leaves your device" | No. Needs a public release. |
| Source Settings text | corrected notice, covered by a widget test | Applies only once a 2.x build is public. |
| Support contact | `checkmateapp@duck.com` in app, policy and home page | Consistent in source. Mailbox control OPEN. |

## OPEN: owner evidence and actions

Nothing below is claimed as done.

1. Effective date of the policy. None is stated; preparation dates are not one.
2. Control of the `checkmateapp@duck.com` mailbox and the actual removal procedure.
3. Anthropic account terms: retention agreement, zero-data-retention setting, model.
4. Production configuration: database vendor and region, backup and log retention on
   Render and Vercel, whether `EXCHANGE_RATE_API_KEY` is set, deployed viewer revision.
5. Whether tab receipt photos or `tab_images` rows from the 1.4.0-era API remain.
6. Build number of the public 1.4.0 binary, and who holds TestFlight 2.0.x builds.
7. Submitting the App Store privacy label and choosing the policy URL (App Store
   Connect, owner only).
8. Serving the maintained `/privacy-policy`, and the state of the legacy host.
9. Decision: whether the public policy should carry an explicit correction of the
   1.4.0 in-app text until a corrected binary is public. Recommended: yes.

## Release sequencing

Serve and verify the canonical policy route **before shipping a client whose Settings
link depends on it**. When a 2.x build becomes the public App Store version, re-run
this inventory against that binary and the deployed service, then update
`storeVersion` and the "Not yet released" markers in the policy page, the web tests
that pin them, and the label answers. Do not claim that a source change updates the
legacy policy, the App Store label or link, provider logs, account settings or
entitlements.

See the [2026-11-09 evidence](reviews/2026-11-09-privacy-disclosures.md) and the
earlier [public-web record](reviews/2026-11-05-public-web.md).
