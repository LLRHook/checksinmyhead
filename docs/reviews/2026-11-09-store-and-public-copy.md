# Store and public-page copy — 2026-11-09

Repository side only. Base `e0a2c18`. No App Store Connect, hosting or legacy-site
change was made or is claimed; production and the store were read with GET requests.

## App Store copy (`BUG-1793644516`)

| Subject | Evidence |
| --- | --- |
| Public listing | `itunes.apple.com/lookup?id=6746379502&country=<cc>` for us, ca, gb, au, de, fr, jp, mx, in, br: each returns version 1.4.0, name "Billington", and a description containing "Spliq" |
| Public description | 437 characters; "Spliq" twice; "privacy-first ... without compromising your data" |
| Subtitle | the web product page shows the category in the subtitle position; the App Store Connect value was not readable |
| Field limits | App Store Connect Help, App information and Platform version information: name 2–30 characters, subtitle 30, promotional text 170, description 4000, keywords 100 bytes with each keyword longer than two characters |
| Released workflow | 1.4.0 source `5ca1dc6`: scan or manual entry, item assignment and item splits, proportional tax and tip, text and link sharing, Lazy Mode claiming in the browser, tabs with balances and settlements, payment handles for Venmo, Zelle, Apple Pay and Cash App, a Venmo deep link on the web page only, manual paid marks, US dollars only |

Prepared copy is in [app-review-notes.md](../app-review-notes.md#prepared-app-store-metadata-not-submitted):
name 10 characters, subtitle 27, promotional text 155, description under 1,700,
keywords 95 bytes.
`DocumentationContractTests.test_prepared_store_copy_says_Billington_and_fits_Apple_field_limits`
failed before the section existed and passes with it; the gate file now has 43 methods.

Not done and not claimed: submitting the copy, reading the current keyword field or
any conversion data, and running the public 1.4.0 binary against the live service.

## Maintained public pages (`BUG-1793644517`)

Checked on source at this commit, then on a local production build (`next start` on
an owned loopback port, synthetic unreachable API URL).

| Expected | Result | Evidence |
| --- | --- | --- |
| Primary action reaches the App Store in one click | Met in source | Header, hero and closing actions all link to `https://apps.apple.com/app/id6746379502`; no `#download` detour. A GET of that URL ends at `apps.apple.com/us/app/billington/id6746379502` with 200 |
| Hero shows a supported completed split | Met in source | Labeled USD example: 100.00 + 10.00 + 18.00 = 128.00; shares 51.20 + 44.80 + 32.00 = 128.00, each a whole-cent item amount (40, 35, 25) plus the same tax-and-tip proportion |
| Payment copy separates links and details from processing or confirming | Fixed | The note named only a "Venmo handoff" and "shared payment details". It now says what each service does: Venmo opens the app from a shared page; Zelle, Cash App and Apple Pay are details only; nothing is processed or confirmed. Source check: only `venmo.ts` builds a link, `PaymentDetails.tsx` renders no link |
| Keyboard navigation and outbound destinations | Met on the local build | Real Tab presses in a browser tab at 1280 px: 14 stops in document order, skip link first, every stop visible with the 3 px focus outline. At 375 px: 13 stops (the header store button is hidden; the hero action remains), no horizontal overflow. Outbound GETs returned 200 for the store listing, Anthropic, Frankfurter, ExchangeRate-API, Render and Vercel links |

Five tests in `web-bill-viewer/src/lib/__tests__/public-claims.test.ts`. The payment
test failed on the previous copy. The other four passed on unchanged source, so each
was run against a deliberate break (hero action to `#download`, a share changed by
one dollar, a confirmation claim, a detail turned into a link, a nav link to a
missing section, a contact link opening a new tab): all six breaks were detected and
the sources restored.

| Check | Result |
| --- | --- |
| `npm run lint`, `npm test`, `npm run build` (Node 25.9.0; the pin is Node 24) | 0 lint errors; 110 of 110 tests in 12 files; build succeeded |
| `delivery_gate.py validate-reports --row web` | accepted, 110 passed |
| `scripts/verify_web_routes.py`, no fixtures | 6 public cases, 0 failed |

Limits: one browser engine, home page only, no screen reader, no real device, and
the Venmo link was not followed. Whether a focused element is scrolled fully into view
was not established (the page uses smooth scrolling and the tab was in the background).

Not done and not claimed: the maintained pages are not served (`billingtonapp.vercel.app/`
returned 404), and the legacy `getbillington.vercel.app` home page, read today, still
sends "Download Free on iOS" to `#download`, links the store through a `/spliq/` slug
and says "Deep links to Venmo, Zelle, Apple Pay, and Cash App so settling debts is one
tap away". That host is separately owned and was not touched.
