# Billington screenshot campaign — research notes

Verified 5 September 2026 against the primary sources linked below. This note informs preview production; it does not record an App Store upload or approval.

## Verified Apple requirements

| Item | Current rule and production implication |
| --- | --- |
| File format and count | Upload 1–10 screenshots in JPEG/JPG/PNG. Images must have no alpha channel or transparency. Export opaque RGB PNGs, not merely RGBA PNGs whose alpha happens to be opaque. |
| Main iPhone set | The 6.9-inch category accepts portrait **1320 × 2868**, **1290 × 2796**, or **1260 × 2736**; landscape swaps the axes. The current iPhone 17 Pro Max simulator produced 1320 × 2868 captures for this campaign. |
| Smaller iPhone sets | A 6.5-inch set is required only if the 6.9-inch set is absent. Its portrait sizes are 1284 × 2778 or 1242 × 2688. Apple documents scaling fallbacks for smaller categories; three complete size sets are not mandatory. |
| iPad, if supported | A 13-inch set is required if the app runs on iPad: portrait 2064 × 2752 or 2048 × 2732. A finished iPhone campaign alone does not establish complete iPad submission coverage. |

Source: [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

Screens must show the actual app being used; title art, login, or splash screens alone are insufficient. Text/image overlays are allowed (§2.3.3). Use fictional account data and properly licensed material (§2.3.9). Avoid unrelated metadata and unverifiable product claims (§2.3.7); keep screenshots appropriate for a general audience (§2.3.8). Billington captions therefore need evidence in the captured UI, and its trip, people, expenses, and settlement amounts should form a coherent fictional story. [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Apple guidance and the panoramic-device distinction

Apple recommends leading with the app's essence: the first one to three screenshots can appear in search results when no app preview is available. Later images should each explain a main feature or benefit. It also suggests showing Dark Mode if supported. These are editorial recommendations, distinct from pixel specifications. [Creating your product page](https://developer.apple.com/app-store/product-page/)

The separate marketing artwork guidelines require Apple-supplied device images to remain unmodified, including no cropping or tilting. Generic device illustrations should omit Apple-specific hardware details. They also recommend full signal, Wi-Fi, and battery indicators. A phone spanning two panels is not explicitly endorsed by the screenshot specifications. Preserve the requested panorama as a creative preview, while retaining a complete-device or frameless alternative; do not describe the panorama as guaranteed Apple-compliant. [Apple marketing resources and identity guidelines](https://developer.apple.com/app-store/marketing/guidelines/)

## Credible automation workflows

| Workflow | Verified capability | Fit for this campaign |
| --- | --- | --- |
| fastlane `snapshot` | Drives Apple UI tests over configured device/language combinations, collects captures, produces an HTML review gallery, and supports status-bar overrides including 9:41 with full reception/battery. | Good repeatable capture pipeline after setup; unnecessary to replace working simulator automation just for this campaign. [snapshot documentation](https://docs.fastlane.tools/actions/snapshot/) |
| fastlane `frameit` | Adds frames, custom backgrounds, fonts, colors, and captions above/below screenshots; supports reusable configuration. | Useful baseline framing/localization, but a bespoke connected composition still needs intentional layout. [frameit documentation](https://docs.fastlane.tools/actions/frameit/) |
| Maestro | Tests compiled Flutter apps through their exposed Semantics tree without adding a Dart dependency; uses semantic labels/identifiers rather than Flutter Keys. Its `takeScreenshot` command writes PNGs. | Strong future capture option for repeatable real-user journeys. [Flutter support](https://docs.maestro.dev/get-started/supported-platform/flutter), [capture command](https://docs.maestro.dev/reference/commands-available/takescreenshot) |
| Expo + Maestro | Expo documents running Maestro end-to-end flows for Android and iOS development builds in EAS Workflows. | A useful example of automated capture infrastructure; Billington is Flutter, so adopting Expo itself offers no campaign benefit. [Expo workflow tutorial](https://docs.expo.dev/tutorial/cicd/e2e-tests/) |
| AppScreens | Keeps raw app images separate from marketing layers; provides exact positioning, listing previews, and ZIP export. Its first-party product documentation includes connected-element layouts and localization. | Reference for a mature studio workflow: preserve genuine UI, edit the surrounding design, inspect the listing, then export. Reuse local Appshot instead of purchasing another editor. [Designer documentation](https://help.appscreens.com/design-and-customize/how-does-the-appscreens-designer-work), [product overview](https://appscreens.com/) |
| Browser composition | Playwright supports page and element screenshots, allowing HTML/CSS layouts to become PNG artifacts. | Suitable for repeatable local rendering of a shared panoramic canvas and its individual frames. [Playwright screenshots](https://playwright.dev/docs/screenshots) |

## Campaign recommendations — design judgment

Use one editorial system: restrained teal/ivory or dark teal palette, large concise headlines, consistent alignment, and generous breathing room. Suggested five-part narrative, subject to actual UI evidence: shared trip/tab → bill details → assign individual items → see everyone's share → settle balances. Avoid promising money transfer if the app only records settlements.

For the requested connected pair, render one continuous master composition and crop at exact integer panel boundaries. Keep each caption wholly inside its own frame, and ensure each image remains meaningful alone; a storefront can show only part of the sequence. Review the full strip, each full-size export, and a reduced listing-sized view. Connected galleries are an established tool-supported design option, but their effectiveness depends on the individual panels remaining readable. [Storeboard's first-party panorama guidance](https://storeboard.dev/blog/panoramic-app-store-screenshots)

Final checks: correct dimensions, RGB/no alpha, no debug banners or loading states, consistent status bars, legible real UI, truthful copy, fictional consistent amounts/people, and exact panorama continuity. Preserve original simulator captures and record their device/runtime provenance separately from marketing exports.
