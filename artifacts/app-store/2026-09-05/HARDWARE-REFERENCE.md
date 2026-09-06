# iPhone frame correction — source evidence

The first emailed campaign used a generic graphite frame. The user's subsequent correction requires a recognizable iPhone frame while retaining the same continuous phone across the opening two panels. Version 1 remains preserved; the corrected exports are version 2.

The capture device is the **iPhone 17 Pro Max simulator running iOS 26.3**. Apple's specifications confirm a 1320 × 2868 display with Dynamic Island, a 78.0 × 163.4 mm body, and an aluminum enclosure. The hardware illustration should use a restrained silver rim and black display bezel, with no Apple logo or unsupported material claim. [Apple iPhone 17 Pro specifications](https://www.apple.com/iphone-17-pro/specs/)

## Direct compositor measurement

A new `simctl io … screenshot` of the unchanged settlement screen is stored locally as `captures/hardware/iphone17-pro-max-simctl-reference.png`. Its SHA-256 is `1dbbe79a80ee258a06ac55a519a9f7d7225846ca4b7cd7e92c141f9605c8cf39`.

At native 1320 × 2868 resolution, the central black island core occupies **x=472, y=42, width=376, height=110**, centered at (660, 97), with approximately 55 px end radii. The antialiased difference extends one pixel farther around those bounds.

An RGB comparison between this system-composited screenshot and the original `07-settlements-tracked.png` finds differences **only inside (471, 41)–(849, 153)**. All app content and status glyphs elsewhere are byte-identical. Maestro's raw screenshot omitted the physical display occlusion; the actual simulator compositor includes it.

The measured island rectangle is uniformly RGB (250, 250, 250) in the dinner and person-detail sources, and (255, 255, 255) in the trip and settlement sources. It contains no foreground text or status icons. Thus the explicit hardware layer covers blank safe-area pixels only. It is not a redraw of app UI, a second status bar or an invented app feature.

The four original source PNGs remain unchanged. The iPhone hardware and source image must share one rigid transform in the connected pair. A source that already contains an island must preserve it without drawing another. Corner masks and the surrounding frame need independent visual checks so they do not remove meaningful app content.

This evidence describes a custom device illustration calibrated to the actual simulator. No Apple-supplied marketing artwork is included, and the geometry is not represented as App Review approval.

## Completed V2 verification

Exact Claude Fable 5.1 authored the hardware patch. The current manifest is `connected-primary-v2.manifest.json`, SHA-256 `9c1bd847f07c6044f36850ff75402e45c314931e7ff7aa2f47d496eeed0a5b3d`; renderer SHA-256 is `c40ec94987b5ab04a7cc5f6593e5a95640ce8a08fc99b3859415bf4af6cd18ee`. V2 output is under `outputs/connected-first-campaign-v2/`; V1 remains preserved.

Independent inspection confirms one island per phone, legible status glyphs, intact continuity and no lost app information. New display corners remove only light background pixels. Both actual opening PNGs match the master regions with zero differing channels; all five images are opaque 1320 × 2868 RGB PNGs. ZIP order, CRC and byte-identity checks pass.

Each straight phone preserves 1,749,499 tested app-interior pixels from V1 exactly. The rotated shared master has nine isolated differences among 1,875,304 tested pixels, maximum channel delta13, consistent with minor antialiasing variation. No visible text, amount or placement changed; this is not absolute rendered-pixel identity for the rotated phone.

The actual simulator source was also rendered in explicit `source` mode and `draw` mode. Both preserve its existing island and produce pixel-identical output images. The latter triggers the dark-center guard and records the skipped duplicate. The four campaign captures use explicit `draw` because their measured safe-area region is blank.
