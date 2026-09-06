# Native editable Appshot campaign integration

The existing Appshot project model supports original screenshots, editable copy/colors/frame treatments and one continuous phone shared across adjacent frames. Exact Table Linen styling requires the Appshot owner's native renderer/schema extension; an approximate export is intentionally not being substituted as the final editable campaign.

The owner has supplied the pending integration contract: `tableLinenFromManifest(manifest: unknown, images: Record<string, ImageRef>): Composition`, exported from `src/lib/model/linen.ts`. Image keys are the manifest's original image paths. The native model will use style `table-linen`, resolved `Slide.linen` values for colors/layout/phone/band, `Panorama.linenPhone` for shared geometry, and newline-separated typography with paired `*italic accent*` markers. The converter accepts `table-linen` and `linen-quiet`; linked panels are primary exports. Use this converter once available rather than duplicating conversion logic.

Appshot checkout: `/Users/victorivanov/Code/personal/appshot/app`.

Authoritative files inspected:

- `src/lib/model/types.ts`: `Composition`, `Slide`, `Typography`, `Panorama` and `ImageRef`.
- `src/lib/model/project.ts`: strict portable import validation and IndexedDB persistence. Unknown fields are dropped by `parseProject`, so adding unsupported custom fields to an old project does not preserve them.
- `src/lib/render/canvas.ts`: shared native preview/export renderer.
- `src/lib/stitch/panorama.ts`: canonical two-panel world geometry.
- `src/lib/render/export.ts`: PNG, ZIP and portable original-image embedding.
- `src/routes/+page.svelte`: visible Open project, Save project, Content, Composition and connected-device controls.

## Features already supported

The project file uses `version: 1`, a device key such as `iphone-6.9`, and 1–10 slides. `ImageRef.blobUrl` can contain original PNG bytes as a data URL, with explicit natural dimensions. Images must be under 12 MB; a project must be under 60 MB. Four unique final iPhone captures are approximately 0.5–0.6 MB each, so portability fits comfortably within these limits.

The `panorama` object references adjacent `leftId` and `rightId` slide IDs and a single image. Native rendering constructs one two-panel world and crops it into adjacent exports. It does not independently create two different phones. Copy remains separate and editable on each panel.

## Gaps communicated to the Appshot owner

| Table Linen requirement | Existing model/renderer limitation |
| --- | --- |
| Dedicated Table Linen direction | Style enum currently has cobalt, paper, midnight, sorbet and terminal. |
| Restrained flat two-band background | Paper style unconditionally adds a beige lower region, ellipse and flecks; other styles also add their own decorations. |
| One regular/italic accent phrase | Headline is a single-color string without rich text segments or italic metadata. |
| Exact type block geometry | Font metrics, headline/subtitle positions and wrapping are style-driven; the schema lacks the custom pixel controls. |
| Quiet wordmark only | Native renderer always adds counter/footer treatments. |
| Source-preserving custom phone placement | Native single/panorama phone vertical positions are fixed; the schema lacks top, bottom, shell, radius and max-width fields. |
| Exact per-slide palette roles | Native schema exposes one text color, background colors and campaign accent, without separate subtitle, band and wordmark roles. |

These gaps were sent to the Appshot owner's task `01a073de-15e4-7f70-b160-9b88b8a43390`. That task owns the native implementation; this capture task must not edit its source concurrently.

## Final campaign relationship

Use the upcoming `connected-primary.manifest.json` from the Claude design agent as the art-direction authority. Do not use the superseded `full-campaign.manifest.json` pair placement.

1. Frame 1: first half of one shared phone using `captures/02-completed-split.png`.
2. Frame 2: second half of that same shared phone and exact same source bytes.
3. Frame 3: `captures/03-person-breakdown.png`.
4. Frame 4: `captures/04-trip-overview.png`.
5. Frame 5: `captures/07-settlements-tracked.png`.

The source screenshots are real iPhone simulator captures at 1320 × 2868 with fictional USD data. Do not flatten the campaign PNGs into background images or claim those are editable raw app screenshots.

The custom renderer being brought into native Appshot is `render-table-linen.mjs` in this artifact directory. It is owned by the Claude design agent while the first-pair primary composition is being finalized.

## Import/export verification after native extension

Generate the portable project through the new supported schema using exact Claude Fable 5.1 for substantive helper code. Verify it passes the native `parseProject` boundary, imports through the visible Open project control, exposes original screenshots and editable text, and saves back through Save project with the same source bytes and connected relationship. Compare the native exported connected pair and full campaign against the custom renderer's authoritative output. Record any remaining pixel differences candidly instead of representing an approximate native design as the exact primary campaign.

An isolated browser session verified the existing editor controls and was closed cleanly. No Appshot source files were changed during this investigation.
