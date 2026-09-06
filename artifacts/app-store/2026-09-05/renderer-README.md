# Table Linen renderer

`render-table-linen.mjs` implements Claude's palette and type system in native Canvas 2D. It imports Appshot's existing `canvasToPng`/`safeFilename` from `/src/lib/render/index.ts` and `createZip` from `/src/lib/render/zip.ts`; no Appshot or Billington product file is modified. Playwright is reused from the existing Appshot installation.

Run while Appshot's Vite server is available:

```sh
node /Users/victorivanov/Code/personal/checksinmyhead/artifacts/app-store/2026-09-05/render-table-linen.mjs /absolute/path/to/manifest.json
```

An optional second argument overrides the output directory. All outputs must remain beneath this campaign artifact directory. For smoke work set `status` to `smoke` and place outputs under `outputs/smoke`; the contact sheet is prominently labeled as historical test captures. Smoke frames must never be substituted into the final campaign.

The example manifest is an **unmapped draft**, not approved final copy or a claim that these captures exist. Replace image paths and copy after the real UI walkthrough and Claude's fresh-image review. Relative image/output/font paths resolve against the manifest's directory. PNG and JPEG inputs are accepted.

| Field | Meaning |
| --- | --- |
| `version` | Required, currently `1`. |
| `status` | Required: `smoke`, `draft`, or `final`. `final` requires 5–6 slides. |
| `style` | `table-linen` (cream/teal, flat band) or `linen-quiet` (all cream, no band). |
| `slides` | 1–10 images, each with unique kebab-case `id`, `image`, `headline` and `subtitle` arrays. Normally use the requested 5–6-frame narrative. |
| `headline` | One or two explicitly broken lines. Wrap one accent phrase in asterisks, e.g. `"*Four fair shares.*"`. Real Instrument Serif Italic is used. Overflow causes an error; copy is never silently shrunk. |
| `subtitle` | Zero, one, or two explicitly broken lines. DM Sans 44 px by default. |
| `theme` | Per-slide `cream` or `teal`; first/last default to teal. Quiet overrides teal with cream. |
| `colors` | Global or per-slide overrides for `canvas`, `band`, `headline`, `accent`, `subtitle`, `wordmark`, `dot`, `shell`, `shellEdge`, `shadow`. |
| `layout` | Global/per-slide numeric overrides: `margin`, `wordmarkTop`, `headlineTop`, `headlineWidth`, `headlineSize`, `headlineLeading`, `headlineTracking`, `subtitleTop`, `subtitleWidth`, `subtitleSize`, `subtitleLeading`, `bandTop`. Defaults follow Claude's design. |
| `phone` | Global/per-slide geometry: `mode`, `top`, `bottom`, `maxWidth`, `centerX`, `shell`, `radius`, `frameless`, `shadow`, `rotation`. Rotation is a finite angle within ±8 degrees, applied to the entire phone around its screen center. `full` uniformly scales the complete capture to fit the transformed bounds. `bottom-crop` requires a written `cropReason` and is recorded in validation. |
| `phone.radius` | Legacy display mask in output pixels, default 60. The hardware preset uses its calibrated corner radius instead. |
| `phone.hardware` | Omit for the V1 generic shell, or use `iphone-17-pro-max` for the V2 custom silver rim, black bezel and native-150-pixel display corners. Screen, frame and hardware share one rigid transform. |
| `phone.dynamicIsland` | `source` (default) preserves an existing island. Explicit `draw` adds the measured mask to Maestro sources that omit it. A dark-center guard skips the extra mask when one is already present. No second status bar is drawn. |
| `phone.hardwareButtons` | Optional boolean. Adds restrained side controls in hardware mode; their projections are included in the transformed fit check. |
| `panorama` | `enabled:true`, `leftId`, `rightId`, `image`, phone overrides, and optional `primary:true`. A primary panorama requires adjacent ordered slides and replaces those slides in the primary PNGs, contact sheet and ZIP with exact crops of **one** shared phone master. Without `primary`, the pair remains a separate alternate. |
| `panorama.seamClearance` | Optional assertions with `label`, `sourceRow`, `min`, and `max`. Each checks the source column crossed by the seam at the given native source row. Rotation is included in this calculation. Recalibrate these windows when replacing the source capture. |
| `fonts.italic` | Optional real italic TTF path. Defaults to artifact-local `fonts/InstrumentSerif-Italic.ttf`. |

Outputs include individual 1320 × 2868 RGB PNGs, an ordered campaign ZIP, a contact sheet, the resolved source manifest, and JSON validation with manifest/input/font hashes and dimensions, complete-screen fractions, font identity, warnings and export metadata. Every PNG's IHDR is checked for the expected size, 8-bit depth, and RGB color type; loaded font faces are verified directly rather than through `FontFaceSet.check()`. An enabled panorama also exports its uncut 2640 × 2868 master under `connected/`. With `primary:true`, the two crops are the corresponding numbered campaign PNGs and ZIP entries; otherwise the alternate crop files stay under `connected/`. The renderer compares both decoded panels with the same master's exact regions and fails on any differing channel value.

The current campaign uses `connected-primary-v2.manifest.json`: one rigid −4.8° iPhone frame spans its first two teal panels, followed by Leo's allocation, trip totals and paid tracking. The whole physical phone fits the two-panel master; panel 2 continues the amounts from names on panel 1. `linen-quiet-v2.manifest.json` uses the same composition on cream. The previous generic-frame campaign remains in `connected-primary.manifest.json` and its V1 output folder.

The V2 island uses the actual simulator's blank safe-area rectangle: native x472, y42, width376, height110, radius55. `HARDWARE-REFERENCE.md` records direct measurement and source comparisons. Original PNGs remain untouched; the island covers no app content or status glyphs, and the larger corner mask removes only background pixels. Inspect this again when replacing a capture. This is custom code-native artwork, with no Apple logo or supplied marketing art.

This reference script imports Appshot development modules. Let Vite finish rebuilding before rendering; an intervening full-page hot reload can destroy the execution context and requires rerunning the command. Native Appshot export avoids this separate reference-runner workflow.

Font asset: Instrument Serif Italic is OFL-licensed and was fetched from the first-party [Google Fonts repository](https://github.com/google/fonts/tree/main/ofl/instrumentserif), after verifying the [font metadata](https://github.com/google/fonts/blob/main/ofl/instrumentserif/METADATA.pb). Its license is stored beside the font. Regular Instrument Serif and DM Sans load from Appshot's existing font assets. No package dependency was added.
