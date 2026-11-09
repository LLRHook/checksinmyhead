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
