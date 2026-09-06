# Billington capture validation and delivery preparation

Review date: 5 September 2026, America/Lima. The final five-frame preview campaign uses one continuous phone across its first two images. Source capture checks, final visual inspection, decoded seam equality, opaque PNG dimensions, ZIP contents and authorized preview email delivery all pass. The native editable Appshot project is a separate handoff being implemented and verified by the Appshot task; it is not established by this renderer validation.

## Capture provenance

- Installed iPhone app: **Billington 1.4.1, build 1**, bundle `com.checksinmyhead-vng.app`, confirmed from its installed `Info.plist`; the source manifest also declares `1.4.1+1`.
- iPhone: **iPhone 17 Pro Max simulator, iOS 26.3**. Six current source PNGs directly under `captures/` each measure **1320 × 2868**, with no alpha channel according to macOS `sips`.
- iPad: **iPad Pro 13-inch (M5) simulator, iOS 26.3**, per its capture manifest. The five candidate files `01-tabs.png` through `05-leo-breakdown.png` each measure **2064 × 2752**, with no alpha. All five SHA-256 values match the manifest. `00-home.png` has an alpha channel and is excluded, alongside `setup.png` and `current.png`.
- The sources show light appearance and a consistent **9:41** status time with full battery. iPad additionally shows `Sat Sep 5`; the fictional dinner's in-app date is `9/6/2026`. Those captured labels are preserved.
- These are real Flutter simulator screens using fictional saved records and an isolated instance of the current Go API on port 18080. The capture build temporarily changes the local API endpoint, then restores the source file. It is a debug capture build with unchanged UI, not proof of a byte-identical App Store release binary. See `CAPTURE-DATA.md` and `build_capture_app.py`.

## What the source images substantiate

| Source | Visible evidence |
| --- | --- |
| `01-dinner-items.png` | Dinner in Alfama: six items, subtotal **$118.00**, tax **$0.00**, tip **$11.80 / 10%**, total **$129.80**. |
| `02-completed-split.png` | Four complete shares: Leo **$40.70**, Nora **$36.30**, Maya **$31.90**, Oliver **$20.90**. They sum to **$129.80**. |
| `03-person-breakdown.png` | Leo: sea bass **$32.00**, water **$3.00 / 25%**, olives **$2.00 / 25%**, combined Tax & Tip **$3.70**; total **$40.70**. |
| `04-trip-overview.png` | Lisbon weekend: **3 bills / $191.80**. Shares: Leo **$56.70**, Nora **$51.30**, Maya **$46.90**, Oliver **$36.90**, summing correctly. |
| `05-settlement-preview.png` | Real Finalize Tab confirmation and the four settlement amounts. Finalizing locks further edits. |
| `07-settlements-tracked.png` | Finalized tab and **2/4 paid**. Nora and Maya are marked paid (**$98.20** together); Leo and Oliver remain unmarked (**$93.60** together). These are derived totals, not additional numbers displayed by the app. |

All six iPhone sources were visually inspected. The iPad dinner and Leo-detail captures were independently inspected and agree with the iPhone data. No private names, payment handles or contacts appear in these inspected sources. The settlement screens support **paid-status tracking**, not bank transfers. The captures do not establish successful receipt OCR or broad currency-conversion behavior. Tax is zero in this example, so the images demonstrate proportional tip, not a nonzero-tax calculation.

The root task also independently read the real local API: the tab is finalized, and its settlement response agrees with all four amounts and the two paid statuses above. The token-free result is saved in `outputs/api-settlement-validation.json`.

The completed-split source still has Leo's chevron pointing upward while its details are collapsed; the other three point downward. All four names and amounts are fully visible. The trip overview also retains the app's Finalize button overlapping part of a lower bill card. These are source-UI observations, not marketing-renderer artifacts; do not repaint them.

## Currency issue and current workaround

The earlier EUR diagnostic walkthrough exposed a saved-bill display bug: the participant wrapper reconstructs `RecentBillModel` without currency metadata, falling back to USD. The rename callback has the same omission. Source inspection confirms both omissions; see `CAPTURE-BUG-NOTE.md`. The source issue remains unfixed in this screenshot task. The current campaign uses newly created **native USD** records, and diagnostic EUR captures must remain outside delivery. Preliminary design text referring to EUR bills, converted USD tabs, or the earlier invented scenario is superseded.

## Apple requirements and final checks

Apple permits 1–10 JPG/PNG screenshots without alpha channels. The current iPhone size is accepted in its 6.9-inch category. This app targets device families `1,2`, so the 13-inch iPad requirement applies; the candidate iPad size is accepted. Pixel compliance alone is not App Review approval. [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)

Apple requires actual app use, permits explanatory overlays, and calls for fictional account information. Captions must describe the genuine captured features. [App Review Guidelines, §2.3](https://developer.apple.com/app-store/review/guidelines/)

The requested connected opening is the primary creative direction. Preserve an intact-screen alternative because Apple's separate device-artwork guidance restricts alterations to supplied product images; do not claim that panorama geometry guarantees approval. [Apple marketing artwork guidance](https://developer.apple.com/app-store/marketing/guidelines/)

The final first pair is one rigid −4.8° phone rendered on a 2640 × 2868 master. An independent decoded-pixel check compared the actual final PNG files with their master regions: both have **zero differing channels**. The seam preserves the bill title, $129.80, four names and four complete amount labels. The second panel intentionally continues the first, with amounts on the right and names on the left; it is not a self-contained view of who owes what.

All five primary images are 1320 × 2868, 8-bit RGB PNGs without alpha. The source screen is fully retained across the opening pair and inside each later phone. Font loading, text fit, transformed device bounds and source-coordinate seam windows pass with no renderer warnings. The corrected opening subtitle is “One dinner bill. / Each person pays their share.” The final contact sheet has no overlapping labels.

The final ZIP contains exactly the ordered primary PNGs—shared bill, fair shares, Leo's allocation, trip summary, paid tracking—and a validation JSON. CRC checks pass and every PNG in the ZIP is byte-identical to its loose file. The final manifest SHA-256 is `9d8afa784046b112a364a669c90877d341ae39f4333cc5d27e9f741708f3dce4`; renderer SHA-256 is `28bf8495f2e93a1f390a680115f0512b80e69f5169cf2a87504960d5d3fc145f`.

Authorized preview email delivery is confirmed by Gmail's SENT label and a subsequent message read. Four attachments have matching delivered byte sizes: final overview PNG (429,523), connected opening PNG (977,977), five-frame PNG ZIP (2,849,427), and cream alternate contact PNG (356,194). The local ignored `email-delivery.json` preserves the recipient, message identifier and attachment metadata. Nothing was submitted to Apple or TestFlight.

## Sensitive data and minimal delivery package

An exact-value scan checked **16 local fixture capability values from 2 seed-state files** against **284 currently tracked files plus artifact documents/code/patches, 302 files total**. No exact fixture values were found. This is a targeted fixture-leak check, not a comprehensive secret audit. The seed-state files and SQLite backups remain local and ignored; exclude them from every delivery archive.

For preview delivery, include the final contact sheet and the final ordered iPhone PNG ZIP; include the selected native iPad PNGs separately if needed. For an editable source pack, include only the selected manifests, their referenced raw captures, renderer, font assets/licenses, usage note and final validation. Use explicit filenames rather than archiving the entire artifact directory. Exclude seed-state JSON, databases, flows, diagnostic EUR images, smoke/earlier exports, hierarchy dumps and CLI traces.

The custom JSON manifest is editable renderer input; it is **not a native Appshot project**. Native Appshot handoff is being prepared separately and remains pending verification. The current script relies on this Mac's existing Appshot installation/Vite server and hard-coded dependency path; the source pack therefore is not standalone. The README now documents the connected first pair as primary PNG and ZIP content.

The dedicated preview API and database containers were stopped after the final settlement API check. The temporary browser session was closed, the iPad simulator was shut down, and the iPhone retains the captured app state. Product source remains unchanged by this capture workflow.
