# Native editable Appshot V2 handoff

The final V2 campaign is a native Appshot project with editable copy, palette, layout, original screenshots, hardware settings, and one shared phone across the first two frames. No campaign PNG is substituted for editable content.

## Deliverables

- `outputs/Billington-v2-editable-source.zip`: complete versioned source package.
- `outputs/appshot-editable-source-v2/Billington-v2.appshot.json`: primary teal/cream campaign.
- `outputs/appshot-editable-source-v2/Billington-v2-cream.appshot.json`: all-cream alternate.
- `outputs/appshot-editable-source-v2/verification/Appshot-v2-native-editor.png`: actual editor showing all five frames and editable content controls.
- `outputs/appshot-editable-source-v2/verification/pixel-comparison.json`: ten native/reference pixel comparisons.
- `outputs/appshot-editable-source-v2/verification/ui-export-comparison.json`: visible UI import, edit, save, export and shared-seam evidence.

Open either project using **Open project** in the updated Appshot build on `feat/appshot-table-linen` (`http://127.0.0.1:5173` in this workspace). Use **Content** for copy and palette; **Composition** for phone placement, iPhone 17 Pro Max hardware, Dynamic Island mode and side buttons. The first two frames share one phone: changes to shared geometry appear from either half. **Save project** embeds the original screenshots. **Export set** produces five device-size PNGs plus the portable project.

The native integration is owned by the Appshot task. This capture task did not edit Appshot or Billington product source. Conversion uses the supported `tableLinenFromManifest(manifest, images)` export from `src/lib/model/linen.ts`, then `portableComposition` and strict `parseProject`. No duplicate converter was added.

## Native implementation and owner checks

Appshot commit `b3a05ea6933030708bfe95897d96c68ed98d0b5f` is pushed on `feat/appshot-table-linen`. The Appshot owner reports 155 unit tests and 16 production browser tests passing, Svelte check with 0 errors / 0 warnings, and passing lint and production build. The artifact-specific parity and visible UI checks below were verified independently by the capture task.

## Final input identity

- Primary manifest `connected-primary-v2.manifest.json`: SHA-256 `9c1bd847f07c6044f36850ff75402e45c314931e7ff7aa2f47d496eeed0a5b3d`.
- Cream manifest `linen-quiet-v2.manifest.json`: SHA-256 `6300b5d31dd4a1dd6b4de3a03be3ab338f64900ddfc51bba8575b94692845051`.
- Reference renderer `render-table-linen.mjs`: SHA-256 `c40ec94987b5ab04a7cc5f6593e5a95640ce8a08fc99b3859415bf4af6cd18ee`.

Both projects retain the four original 1320 × 2868 iPhone capture byte streams. The first two frames use the same completed-split source and a single shared phone at center X 1152, rotation −4.8°, top 751, bottom 2803 and maximum screen width 944. Native hardware keys preserve `iphone-17-pro-max`, `dynamicIsland: draw`, and enabled side buttons. Appshot's strict parser preserves these fields and each frame's resolved colors, typography and layout.

## Verification results

1. Both projects pass the supported converter, portable embedding and strict parser.
2. Both import through the visible file control and save through **Save project** with exactly equal JSON structures, including original embedded image bytes and the connected relationship.
3. Actual UI edits persist: headline, per-panel theme, shared center, Dynamic Island mode and side buttons on primary; headline and shared center on cream. The second linked frame displays the updated shared center. Every test edit was restored before final export.
4. Native `exportSlide` results match all ten authoritative V2 reference PNGs pixel for pixel in the reference Playwright headless runtime: zero differing RGBA values.
5. Both visible **Export set → Download complete set ZIP** operations succeed. Each ZIP contains five opaque 1320 × 2868 PNGs and the exact portable project. Each exported first pair matches the exact two crops of its own UI-runtime 2640 × 2868 panorama master, with no seam discrepancy.
6. Full Chrome UI exports have small rasterization differences from the headless reference configuration: maximum mean absolute channel difference is 0.212852 on the 0–255 scale. A matched-version full Chrome check gave the same small difference. These exports preserve identical project data and exact internal seams. The source package's preview PNGs are the authoritative reference exports.

UI ZIPs, edited test projects and UI-runtime panorama masters remain separately under `outputs/appshot-v2-native-check/`; they are not campaign source inputs. The delivered source package includes the comparison reports and editor screenshot instead of duplicating these diagnostic files.

## Reuse and limits

The portable projects require the updated Appshot build with native Table Linen support; an older build does not know this style. Typography uses newline-separated lines and paired `*italic accent*` markers. Original image bytes are embedded in each project, so reopening does not depend on this Mac's raw screenshot paths. Font assets and licenses are included for provenance and reuse; the updated Appshot build supplies the same fonts.

Five selected iPad 13-inch captures and their capture manifest are included under `captures/ipad/` as native source captures, not as a styled iPad campaign. All campaign app data is fictional USD data. The documented EUR display bug remains outside this capture task's source scope. The reference renderer is included for reproducibility context and retains its original local Appshot imports; the native `.appshot.json` files are the portable editing path.

V1 staging remains preserved under `outputs/appshot-editable-source-v1/` and is superseded by this V2 handoff. No new dependency was added for conversion or verification.
