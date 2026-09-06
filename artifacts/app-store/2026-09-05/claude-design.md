# Billington campaign — Claude design provenance

Date: 2026-09-05. **Claude Fable 5.1** authored the design and substantive renderer revisions; GPT coordinated simulator capture, integration, export and independent verification. The initial renderer predates the user's Claude-code preference; see `renderer-provenance.md` for the distinction.

## Current final preview — V2 iPhone hardware

The user's new hardware correction is implemented in `connected-primary-v2.manifest.json`, with active V2 outputs in `outputs/connected-first-campaign-v2/`. The five primary PNGs, contact sheet, canonical first-pair master and ZIP retain exactly the V1 story, copy, source screen scale and pose. One same phone still spans the first two primary panels. V1 manifests and outputs are preserved below as historical deliverables. Parent coordination owns the clearly versioned follow-up email; this design subtask does not send email.

Claude Fable 5.1 authored the bounded renderer hardware branch and V2 manifest. The actual CLI response reports `is_error:false`, duration 138.444 seconds and `modelUsage.claude-fable-5-1` with 11,499 output tokens, including 4,683 thinking tokens. A small auxiliary Haiku call is separately reported; no fallback model was configured. The exact raw output is `claude-hardware-v2.json`, its readable answer is `claude-hardware-v2.txt`, the input is `claude-hardware-v2-brief.txt`, and the substantive authored diff is `claude-hardware-v2.patch`.

The scoped code invocation used the installed Claude CLI with `--model claude-fable-5-1 --safe-mode --strict-mcp-config --mcp-config '{"mcpServers":{}}' --permission-mode dontAsk --tools Read,Edit --allowedTools Read,Edit --no-session-persistence --effort medium --print --output-format json`. Claude could read references and edit only the named renderer and cloned V2 manifest. GPT rendered and inspected the result.

The custom code-native frame uses neutral silver/aluminum styling, black glass, generous display corners and small side controls. It uses no Apple-supplied marketing artwork. Apple's [official iPhone 17 Pro specifications](https://www.apple.com/iphone-17-pro/specs/) support the selected model's 1320×2868 display, Dynamic Island and aluminum finish. This is a visually faithful custom frame, not a CAD model or Apple approval claim.

The Dynamic Island measurement comes directly from `captures/hardware/iphone17-pro-max-simctl-reference.png` (SHA-256 `1dbbe79a80ee258a06ac55a519a9f7d7225846ca4b7cd7e92c141f9605c8cf39`). Its black core is x472, y42, width376, height110, radius55 in the native 1320×2868 screenshot. Root's pixel comparison shows that the real simulator compositor screenshot and the original settlement capture are identical everywhere except the antialiased island bounding box (471,41)–(849,153). All four supplied Maestro source captures have uniform blank background under the island; their PNG files remain untouched.

The `phone.hardware: 'iphone-17-pro-max'` branch inherits through the existing merged phone object. `phone.dynamicIsland: 'draw'` overlays that physical cutout using the same scale and rotation as the source; `'source'` draws no additional island. A simple dark-center guard also prevents obvious duplication. `phone.hardwareButtons: true` adds the side controls. No hardware field preserves the legacy draw path.

Hardware constants: display corner radius150 native pixels; metal rim8 native pixels within the existing24 output-pixel shell; side-button projection2.5 native pixels; the remaining shell is black glass. The paired phone's effective display radius is107.3 output pixels and rim5.7; standalone phones use103.6 and5.5. The island, frame, rounded source mask and side buttons all share one rigid transform. The source image is drawn unmodified; only verified blank display corners and the physical island are occluded.

GPT visually inspected the full first-pair master and all-five contact sheet. The island, corners and metal edge make the phones recognizable while retaining source content and approved typography. The rendering validation reports no warnings, full phone fit including buttons, all 11 source-coordinate seam clearances passing, and zero differing channel values between the primary first two images and the master crops. Independent read-only QA subsequently passed the hardware appearance, single island with no text coverage, exact primary/master crop equality, five RGB PNGs, ZIP order/CRC and loose-file identity. Source hashes and affine geometry are unchanged. Comparing app-interior pixels with V1 outside the hardware/corner masks found zero differences across 1,749,499 pixels in each standalone frame. The rotated master had nine differing pixels out of 1,875,304 checked, with maximum channel delta13, at small antialiased glyph edges; there is no visible content change. This tiny rasterization difference means the composed rotated app interior should not be described as byte-identical to V1, even though the source capture itself is unchanged.

V2 manifest SHA-256: `9c1bd847f07c6044f36850ff75402e45c314931e7ff7aa2f47d496eeed0a5b3d`. V2 renderer SHA-256: `c40ec94987b5ab04a7cc5f6593e5a95640ce8a08fc99b3859415bf4af6cd18ee`.

### Verbatim Claude V2 response

Implementation complete. Nothing was run; GPT renders next.

**Hardware API (merged phone object, inherited by pair and standalone)**
- `hardware`: omitted keeps legacy shell path unchanged; `'iphone-17-pro-max'` enables the new branch.
- `dynamicIsland`: `'draw'` or `'source'`, default `'source'`. V2 manifest sets `'draw'`.
- `hardwareButtons`: boolean, default false. V2 sets true.

**Hardware constants (native capture px, scaled by source scale)**

| Constant | Native | Output (pair / standalone) |
|---|---|---|
| Display corner radius | 150 | 107.3 / 103.6 |
| Body corner radius | 150 + shell | display + 24 |
| Silver rim width | 8 | 5.7 / 5.5 |
| Black glass bezel | remainder of shell | 24 minus rim |
| Button projection beyond body | 2.5 | 1.8 / 1.7 |
| Island rect | x472 y42 w376 h110 r55 | scaled by screenWidth/1320, screenHeight/2868 |

**Renderer edits** in `render-table-linen.mjs`
- Validation of the three fields after the merged `p` object.
- Hardware geometry closure after `bounds`: rim, radii, button rects (action, volume up, volume down on left; power, camera control on right, rows in reference-native coordinates), island local rect, and a trivial one-pixel guard at native (660,97) that skips the island with a warning if already dark.
- Fit check uses bounds including button projection in hardware mode, plain `bounds` otherwise.
- Draw branch under the same translate·rotate: buttons, shadowed silver gradient body with fine dark edge stroke, inset black glass with faint highlight stroke, display clip at 150-native radius, unmodified capture, then island fill if drawn. Legacy branch is byte-identical.
- Geometry gains `hardware` metadata: model, island mode and drawn flag, island source and output rects, display and body radii, rim and bezel widths, button bounds, and bounds with buttons. `roundedCornerRadius` reports the effective display radius.

**Manifest edits** in `connected-primary-v2.manifest.json`
- Output path changed to `outputs/connected-first-campaign-v2`.
- Global phone gains the three hardware fields. Pose, copy, ordering, seam clearances and status untouched.

Source PNGs, V1 manifests and V1 outputs were not touched.

## Preserved V1 final preview — connected first pair

The latest user correction is implemented: the primary/default five-frame campaign begins with one same physical phone spanning panels 1 and 2. The active outputs are in `outputs/connected-first-campaign/`, with `contact-sheet.png`, five native 1320×2868 primary PNGs, `connected/master-2640x2868.png`, and `billington-table-linen-final.zip`. “Final” means final preview, not submission approval. No Apple upload or email is performed by this design subtask.

Claude Fable 5.1 authored the substantive renderer change and primary manifest. The renderer now uses literal crops of one canonical 2640×2868 scene for primary panels 1–2, their contact-sheet cells, and their ZIP entries. The pose is one rigid -4.8° rotation, preserving the screenshot and shell under the same transform. The whole phone fits in the master. The seam keeps the title, $129.80 total and all four names on the left, and all four amount glyphs on the right. The right panel is intentionally a continuation; it is not independently self-contained.

Root-authorized finishing edits shortened the contact labels, clarified the first subtitle to “One dinner bill. / Each person pays their share.”, inserted the previous Claude-authored sea-bass subtitle on the person-detail frame, and set preview status to final. The final contact sheet was visually inspected after those edits and its captions no longer overlap.

The final export passes native RGB PNG encoding, font loading, text-width/collision checks, full transformed device bounds, declared source-coordinate seam-clearance windows, and zero differing channel values for primary panels versus the canonical master. Independent QA separately verified one-phone continuity, no sliced title/total/name/amount glyphs, decoded primary/master equality, correct ZIP order/CRC, and ZIP PNG identity with loose files. Root owns final delivery validation, packaging and the authorized email.

Active manifests `connected-primary.manifest.json` and `full-campaign.manifest.json` are identical: SHA-256 `9d8afa784046b112a364a669c90877d341ae39f4333cc5d27e9f741708f3dce4`. Renderer SHA-256: `28bf8495f2e93a1f390a680115f0512b80e69f5169cf2a87504960d5d3fc145f`.

Earlier standalone-first reviews below describe preserved historical drafts. Their lead-order advice is superseded by the latest user direction. The earlier centered, glyph-slicing alternate is also superseded by the new offset and tilted primary pair.

## Exact model and access verification

- Local executable: `/Users/victorivanov/.local/bin/claude`.
- Installed CLI version: `2.1.259 (Claude Code)`.
- Local authentication status: logged in through Claude, first-party provider, Max subscription. No credentials were extracted or copied.
- The exact-model probe succeeded, with `modelUsage.claude-fable-5-1` and result `MODEL ACCESS CONFIRMED.` in [claude-model-check.json](claude-model-check.json). The CLI also reported a small Haiku auxiliary call; the selected answer model was Fable 5.1. No fallback model was specified.
- Anthropic's current [model overview](https://platform.claude.com/docs/en/models/fable-5-1/overview) lists the exact ID `claude-fable-5-1`. Its [plan/access documentation](https://support.claude.com/en/articles/15424964-claude-fable-models-on-your-plan) says Fable 5.1 requires Claude Code 2.1.255 or later. Both checked on 2026-09-05.

## Invocation and restrictions

The preliminary design invocation used the following arguments from `/Users/victorivanov/Code/personal/checksinmyhead`:

```sh
claude --model claude-fable-5-1 --safe-mode --strict-mcp-config \
  --mcp-config '{"mcpServers":{}}' --permission-mode dontAsk \
  --tools Read --allowedTools Read \
  --add-dir /Users/victorivanov/Documents/Codex/2026-09-05/appshot-makeover/outputs \
  --no-session-persistence --effort high --print --output-format json \
  < artifacts/app-store/2026-09-05/claude-design-brief.txt \
  > artifacts/app-store/2026-09-05/claude-design-preliminary.json
```

The process could read reference screenshots and source code. It could not edit app code, invoke the simulator, build, send email or use MCP services. No substitution or fallback model was requested.

## Source distinction

The Cobalt contact sheet supplied for critique was an **older initial campaign**, not a fresh capture. The preliminary brief explicitly identified that distinction. Current app colors and behavior were supplied from real Flutter code; new simulator captures are a separate second review input.

The final fictional story is Lisbon weekend, Maya, Leo, Nora and Oliver, using native USD throughout. Three bills total $191.80. Dinner totals $129.80 including a 10% tip, with shares of $40.70 for Leo, $36.30 for Nora, $31.90 for Maya, and $20.90 for Oliver. An earlier EUR capture exposed a real currency metadata bug documented in CAPTURE-BUG-NOTE.md; all EUR diagnostic images are excluded from the final campaign. The campaign must retain real labels and may describe verified paid tracking, but may not imply bank transfer execution. Any older EUR or invented-scenario references in verbatim preliminary responses below are superseded by these final facts.

## Claude-authored preliminary design

The exact-model design call completed successfully in 363.5 seconds with no permission denials. `modelUsage.claude-fable-5-1` reports 23,532 output tokens including 17,906 thinking tokens; the CLI also reported 15 auxiliary Haiku output tokens. The following response is preserved verbatim. Its proposed USD scenario and exclusion of settlements are preliminary assumptions, superseded by the actual seeded Lisbon data and verified local settlement flow in the fresh-image follow-up.

I have everything I need: the contact sheet, the theme tokens, both Bill Summary cards, the custom split dialog, and the full Tab detail screen. Here is the art direction.

## Critique and direction

**What the Cobalt sheet gets right, keep it.** Consistent left-aligned stack of wordmark, headline, subheadline, phone. UI rendered large enough to read. Confident two-line headline voice. Soft shadow, graphite shell, one background idea per frame. The Bill Summary frame proves the app has a real payoff screen.

**What fails, in order of damage.**
- Cobalt and lime are not Billington. The app is teal #328983, dark teal #2A736E, tan, gold. The lime diagonal and the concentric rings are template energy, and they fight the pastel person tints in the real UI. The purple dialog header in frame 04 clashes hardest.
- The payoff is buried at frame 05, and its total card eats the phone so only two shares show. Frame 01 is a participant form with no value visible.
- The linked pair sacrifices frame 02 to trash icons and empty rows. That is the "pair hides value" failure in its pure form.
- Frame 03 is a blank form with empty Subtotal and Tax fields. Its Scan Receipt row asserts OCR that nothing on screen demonstrates.
- Frame 04's custom split is 25/25/25/25. An even split does not demonstrate custom splitting, and the fourth slider is cut off.
- Label excess: eyebrow pill, wordmark, counter, footer wordmark, headline, sub. Six text elements per frame.
- Continuity slips: four different status bar times, three tilt angles, and copy that promises sharing which nothing on screen shows.

**Main direction: Table Linen.** Cream paper, teal bookends, one flat tan band the phone rests on. It belongs to Billington because every color is an app token or a direct tint of one, gold is used only the way the app uses it in its `BILL TOTAL` label, and the serif headline reads like a menu or receipt, which is the object the app is about.

| Role | Cream frames 2, 3, 4 | Teal frames 1, 5 | Source |
|---|---|---|---|
| Canvas | #FBF6EF | #2A736E | white toward secondaryContainer #FFF5ED; primaryDark |
| Band | #F1E2D2 | #24645F | tan #D9B38C at 28% over canvas; teal darkened |
| Headline | #2C2C2C | #FBF6EF | onSurface |
| Italic accent phrase | #2A736E | #D4A843 | primaryDark; accentWarm |
| Subheadline | #4C5B6B | #CFE3E0 | tertiary slate; cream at 80% |
| Wordmark | #2C2C2C with #D4A843 dot | #FBF6EF with #D4A843 dot | |
| Shadow | 0 40 80 rgba(42,115,110,0.18) | 0 40 80 rgba(0,0,0,0.30) | |

Type, two families only:
- Headline: Instrument Serif Regular, 118px, line height 120px, tracking -0.015em, max two lines, roughly 20 characters per line. One phrase per headline set in Instrument Serif Italic in the accent color. Same family, so no third personality.
- Subheadline: the renderer's sans in Regular, 44px, line height 57px, tracking 0, max two lines, measure 1000px.
- Wordmark: same sans, Medium, 34px, tracking +0.02em. No eyebrow pill, no counter, no footer.

**Restrained alternate: Linen Quiet.** Same tokens, all five frames on cream #FBF6EF, no band, no teal bookends, accent phrase in dark teal. Use it if the fresh captures' person tints read too busy against teal.

## Narrative, app states, and scenario

**Fictional scenario, USD, all frames.** Bill name `Dinner at Lucia's`. Four people: Maya, Theo, Priya, Jonah. Tax entered as $7.68, tip preset 18%.

| Item | Price | Assignment |
|---|---|---|
| Burrata | $16.00 | Maya 50%, Theo 25%, Priya 25% |
| Rigatoni | $22.00 | Maya 100% |
| Sea Bass | $29.00 | Theo 100% |
| Margherita Pizza | $18.00 | Priya 50%, Jonah 50% |
| Tiramisu | $11.00 | Jonah 100% |

| | Subtotal | Tax | Tip | Total |
|---|---|---|---|---|
| Bill | 96.00 | 7.68 | 17.28 | 120.96 |
| Maya | 30.00 | 2.40 | 5.40 | 37.80 |
| Theo | 33.00 | 2.64 | 5.94 | 41.58 |
| Priya | 13.00 | 1.04 | 2.34 | 16.38 |
| Jonah | 20.00 | 1.60 | 3.60 | 25.20 |

These figures assume tax and tip are allocated in proportion to item share and tip is computed on the pre-tax subtotal. I did not read the calculation utility, so the executing agent must match the app's own numbers and I will re-check them in review.

Second bill for the tab frame: `Sunday Brunch`, Shakshuka $14, Pancakes $12, Avocado Toast $11, Coffees $9, all four people split evenly, tax $3.68, tip 18% $8.28, total $57.96, $14.49 each. Tab named `Cabin Weekend`, total $178.92. Per Person sorts descending in code: Theo 56.07, Maya 52.29, Jonah 39.69, Priya 30.87.

**Five frames. Frame 1 is the payoff because the store gallery shows it first and a viewer must see who owes what without scrolling.**

1. **Bill Summary, shares view.** Headline: "One bill. *Four fair shares.*" Sub: "Billington turns the table's receipt into what each person owes." State: Bill Total card with Items and Breakdown both collapsed so the total stays compact. All four person cards collapsed, names and amounts visible, none cut. Verified: both sections collapse on tap, cards default collapsed, amounts use tabular figures. Needs simulator: the exact vertical fit of four cards under the compact total card and the `Individual Shares` heading, which I only know from the old capture.
2. **Assign Items, everything assigned.** Headline: "Every dish, *to whoever had it.*" Sub: "Give each item to the people who ordered it. Shared plates included." State: all five items assigned as in the table, no dialog open, no snackbar. Not verified: I have not read this screen's list layout. Fresh capture decides whether this frame stands.
3. **Custom split dialog over Assign Items.** Headline: "Shared the burrata? *Split it your way.*" Sub: "Slide to any percentage. Billington keeps the total at 100%." State: Burrata $16.00, sliders Maya 50% $8.00, Theo 25% $4.00, Priya 25% $4.00, green 100% status pill, `Apply Split` enabled. Verified from code: header tint, status pill, sliders, presets, button states. Needs simulator: whether Jonah appears as a fourth 0% slider and whether the dialog fits its 80% height cap without scrolling.
4. **Bill Summary, breakdown plus one card expanded.** Headline: "Tax and tip *follow the food.*" Sub: "Each person's tax and tip track their share of the items, not the headcount." State: scroll so the Breakdown rows `Subtotal`, `Tax`, `Tip (18%)` sit at top, Items collapsed, Priya expanded showing `Burrata 25% × $4.00`, `Margherita Pizza 50% × $9.00`, `Tax $1.04`, `Tip $2.34`. Verified: expanded card renders the percent prefix, divider, tax and tip rows. Needs simulator: the proportional claim in the sub. If allocation is not proportional, the sub becomes "See exactly which items, tax and tip make up each share."
5. **Tab detail, unfinalized.** Headline: "One tab *for the whole weekend.*" Sub: "Group several bills into a tab and see each person's running total." State: `Cabin Weekend`, teal Total card $178.92 with `2 bills` pill, Per Person card, two bill cards, `Add Bills` FAB. Verified from code: all of this renders locally for an unsynced tab. Members, Settlements, `Finalized` badge, and the green `Finalize` FAB require backend sync or finalization and must not appear. Settlements tracks manual paid toggles, not money movement, so it stays out of the campaign entirely. Fallback if tab creation needs the backend: dark-mode Bill Summary, same headline structure, "Easy on the eyes *at a dark table.*"

Scanning is omitted. A Scan Receipt row proves nothing. It returns only if the agent captures a populated item list produced by OCR from a gallery photo in the simulator, and it would be a sixth frame after frame 3.

## Composition, captures, and review

**Canvas 1320 x 2868, all frames.**

| Block | Spec |
|---|---|
| Side margins | 96px |
| Wordmark | x 96, y 128 to 168, gold dot 12px, 20px gap before text |
| Headline | x 96, top y 248, width 1128, two lines end at y 488 |
| Subheadline | x 96, top y 528, width 1000, two lines end at y 642 |
| Band | full width, y 2040 to 2868, same y on every frame |
| Phone screen | scale 0.88 of a 1179 x 2556 capture: 1038 x 2249, x 141 to 1179, y 760 to 3009 |
| Shell | about 30px beyond screen: x 111 to 1209, y 730, bottom off canvas |
| Tilt | 0 degrees on every frame |
| Crop allowance | bottom 141px of screen off canvas, about 54 logical points; nothing of value below logical y 790 |

Background is flat color plus the band. No gradient, no rings, no grain, no illustration.

**Connected pair, frames 2 and 3, primary treatment.** Two full phones, shared band and shared cream. Frame 2 phone center x 720, frame 3 phone center x 600, so the phones lean toward the shared gutter and read as one desk when scrolled. Frame 2 shows the list, frame 3 shows the dialog opened over that same list, which is the story the pair tells. Nothing is hidden and frame 1 is untouched.

**Straddle fallback, only if the renderer's linked-pair mode must be used literally.** Frame 2 phone center x 1000, so 229px of shell continues into frame 3's left edge, and frame 3's own phone drops to scale 0.82 at center x 780. Use this only if the fresh Assign Items capture shows no prices or controls in its right 20%. Otherwise keep the primary treatment.

**Layout fallback if Appshot fixes the headline block.** Keep its positions, but set the headline to 118px serif and the sub to 44px sans, and drop the phone top to y 760 by adjusting scale down to 0.84 if needed. Never shrink type to fit; shorten copy instead.

**Ranked capture list.** iPhone 15 Pro or 16 Pro simulator at 3x, light mode, default teal primary confirmed, status bar overridden to 9:41 full battery via simctl, identical in every frame, animations settled, no keyboard, no snackbar, no scroll indicator.

1. Bill Summary, both total sections collapsed, four cards collapsed.
2. Custom split dialog, Burrata 50/25/25, 100% green, Apply enabled.
3. Bill Summary scrolled to Breakdown, Priya expanded.
4. Assign Items list, all five items assigned.
5. Tab detail `Cabin Weekend`, two bills, unsynced.
6. Fallback: dark-mode Bill Summary shares view.
7. Conditional only: post-OCR populated items from a gallery receipt.

**Pass or fail review checklist.**
- Only the seven palette hexes above appear outside the phone. Any cobalt, lime, or gradient fails.
- App pixels untouched. No recolor, no fabricated cards, no edited amounts.
- No `Finalized`, `Settlements`, `paid`, `Finalize`, or `Members` UI in any frame.
- One status bar per frame, same time in all five, Dynamic Island from the capture only.
- Two type families total. Headline and sub each at most two lines, no single-word last line.
- Every visible amount matches the scenario tables, and per-person totals sum to the bill total.
- Frame 1 alone shows the total, four names, four amounts, with no amount cropped.
- No amount, button, or pill touches or crosses the canvas edge.
- Band top at y 2040 on all five frames.
- Frame 3 dialog fully visible including `Apply Split`.
- Copy makes no claim of OCR, payment, settlement, or sharing.

**Assumptions to review when fresh captures arrive.** The `Individual Shares` heading and card order in the current build. Assign Items list appearance and right-edge content. Whether the compact total card leaves room for four cards. Proportional tax and tip allocation and tip base. Whether the dialog lists only the three preselected people. Person tint colors the app assigns and how they sit on teal versus cream. Tab creation offline, the bill card date format and participant summary text. Instrument Serif rendering at 118px in the renderer.


## Fresh-image design review — native USD

Exact `claude-fable-5-1` call, Read only, no fallback, successful with no permission denials. Inputs were the four fresh iPhone captures, three fresh iPad captures, and actual first two-frame composition. Raw response: `claude-design-fresh.json`; prompt: `claude-design-fresh-brief.txt`. Final settlement was not yet supplied in this pass.

All eight files loaded: the preliminary text, four iPhone captures at 1320x2868, three iPad captures at 2064x2752, and the two-frame contact sheet. Here is the refined direction.

**1. Critique of the first-fresh-preview sheet**

What works: the left-aligned stack of wordmark, two-line serif headline, italic accent phrase, and sans sub is exactly the Table Linen voice. Teal bookend with gold italic and cream frame with teal italic both read cleanly. The band at roughly y 2040 sits behind the phone on both frames. The status bar and Dynamic Island come from the capture only. Oliver's full row and amount are intact in frame 01.

Corrections:
- **Phone is too small.** It measures about 0.69 of the capture width, so "3 item(s)" and item prices go faint at thumbnail size. Tighten the top stack (geometry in section 3) and raise the whole-phone scale to 0.74. That is the ceiling for an intact bezel on this canvas.
- **Frame 02 copy.** "Nothing missing." is a vague claim. Use "Every dish. / *Every dollar.*" with sub "Six items, a 10% tip, and one total that adds up." The screen shows $118.00 plus $11.80 equals $129.80, so the copy is checkable.
- **Frame 01 sub.** Replace "Every share, down to the detail." with "Each person's share of the dinner, built from what they ordered." That is what the Leo expansion in frame 3 then proves.
- **Teal bookend tone.** The in-app total card is close in hue to #2A736E. It still separates because of the white screen and black shell, so keep the hex. Do not lighten the gold for contrast. At 118px it reads fine.
- **Palette holds.** Cream against the app's cool grey surface is fine because the shell isolates it. Maya's orange avatar is the loudest pixel and it echoes the gold accent, which helps.

Captures that best prove value: 02-completed-split (four names, four amounts, total), 03-person-breakdown (Leo's sea bass, two 25% shared lines, Tax & Tip $3.70 which is exactly 10% of Leo's $37 of items, so proportional tip is real), 04-trip-overview ($191.80, 3 bills, four running totals summing to the trip total).

Regions that must stay visible: on 02, the Oliver row at capture y 2436 to 2520. On 03, all three item lines and the Tax & Tip row at y 1900 to 2230. On 04, the Per Person card through Oliver at y 2200 and the Dinner in Alfama card at y 2390 to 2630.

Real UI limitations found:
- Leo's chevron points up in 02-completed-split while collapsed, unlike the other three rows. Recapture from a fresh open so all four chevrons match, if the app produces that state.
- "3 item(s)" placeholder plural under every name. Truthful, leave it.
- Tax renders as $0.00 in the Breakdown. Copy must say tip, not tax and tip.
- The green Finalize button overlaps the lower right of the Dinner in Alfama card, and the Tram & viewpoints card is cut by the home indicator. The trip per-person totals are not dinner share plus an even quarter of $62, so copy must not say "split evenly."
- The camera icon in the tab app bar is not evidence of scanning. No OCR copy anywhere.
- iPad screens leave the lower 40% empty on all three captures.

**2. Final six-frame sequence**

| # | Source | Headline | Sub | Visible outcome |
|---|---|---|---|---|
| 1 | 02-completed-split | One bill. / *Four fair shares.* | Each person's share of the dinner, built from what they ordered. | $129.80, Leo $40.70, Nora $36.30, Maya $31.90, Oliver $20.90, whole phone |
| 2 | 01-dinner-items | Every dish. / *Every dollar.* | Six items, a 10% tip, and one total that adds up. | Six item prices, Subtotal $118.00, Tip $11.80 10%, whole phone |
| 3 | 03-person-breakdown | Leo's share, / *line by line.* | The sea bass, a quarter of the shared plates, and tip on only that. | Three item lines with 25% pills, Tax & Tip $3.70, Nora row below, whole phone |
| 4 | 04-trip-overview, pair left | Three bills. / *One weekend.* | Group a trip's bills in one tab. | $191.80, 3 bills, members, four names, Dinner in Alfama title |
| 5 | 04-trip-overview, pair right | Everyone's / *running total.* | One number per person across every bill. | $56.70, $51.30, $46.90, $36.90, $129.80, Finalize button |
| 6 | Settlement capture, not yet supplied | Know where / *everyone stands.* | Finalize the tab and mark each share paid as it comes in. | Conditional: only if the screen shows per-person paid or unpaid status. I have not seen it. |

Frames 4 and 5 are the connected pair. Frames 1 through 3 and 6 are whole phones. Every headline is under 17 characters per line, safe at 118px in 1128px.

**3. Implementation-ready art direction, 1320x2868**

Palette roles are unchanged from Table Linen: teal #2A736E canvas with band #24645F on frames 1 and 6; cream #FBF6EF with band #F1E2D2 on 2 through 5. Headline #FBF6EF on teal, #2C2C2C on cream. Accent phrase #D4A843 on teal, #2A736E on cream. Sub #CFE3E0 on teal, #4C5B6B on cream. Shadow 0 40 80 at rgba(42,115,110,0.18) on cream, rgba(0,0,0,0.30) on teal. No gradient, grain, ring, pill, counter or footer.

Type: Instrument Serif Regular 118px, line height 120px, tracking -0.015em, one phrase italic. DM Sans Regular 44px, line height 57px, measure 1000px. Wordmark DM Sans Medium 34px with a 12px gold dot.

| Block | y range | x |
|---|---|---|
| Wordmark | 112 to 152 | 96 |
| Headline | 208 to 448 | 96, width 1128 |
| Sub | 488 to 602 | 96, width 1000 |
| Phone screen, scale 0.74, 977x2122 | 664 to 2786 | 172 to 1149 |
| Shell, 30px | 634 to 2816 | 142 to 1179 |
| Band | 2040 to 2868 | full width |

Tilt 0 on every frame. The whole shell fits with 52px clearance. Oliver's row lands at y 2467 to 2529 on frame 1.

iPad, 2064x2752, three frames from the three iPad captures: 04-whole-bill with frame 1 copy, 05-leo-breakdown with frame 3 copy, 02-trip with frame 4 copy. Same palette. Headline 128px on 132px leading, sub 48px on 62px, wordmark 36px, margins 112px. Device screen at scale 0.88, 1816x2422, x 124 to 1940, y 600 downward, bottom off canvas. That removes only the empty lower region, the Share button and the Finalize button, each cropped whole rather than sliced. Never mix the two device sets.

**4. Connected-pair recipe, 2640x2868 world**

Shared image 04-trip-overview, scale 0.80, screen 1056x2294, tilt 0. Screen top y 690, so the Dinner in Alfama card and the Finalize button end above the canvas bottom at about y 2858, and the cut Tram card falls off canvas entirely. Screen left edge at world x 604, so the gutter at x 1320 maps to capture x 895. That column sits between the end of "$191.80" at 861 and the start of the amount chips at 937. Band spans the full 2640 width at y 2040. Each frame keeps its own top text block at the section 3 positions.

Honest tradeoff: frame 4 has about 574px of empty band to the phone's left, and the gutter slices the left edge of the Oliver chip in the Members row, which begins at capture x 898. No glyph is cut. The executing agent must pixel-check world column 1320 between y 690 and 2868 for glyph pixels and nudge the offset up to 10px if any are found. If the Oliver chip slice is judged unacceptable, the intact alternate is a five-frame campaign: frame 4 becomes the whole-phone trip overview at section 3 geometry, and frame 5 is dropped, or replaced by a new capture of the tab scrolled to show all three bill cards with headline "Tram, pastéis, / *dinner. All in.*" I have not seen that capture.

A literal spanning pair on frame 1 is not offered. The main proof stays whole.

**5. QA checklist, pass or fail**

1. Only the nine palette hexes above appear outside the device. No cobalt, lime or gradient.
2. App pixels untouched: no recolor, no edited amounts, one status bar per frame showing 9:41 from the capture, no drawn Dynamic Island.
3. Frame 1 shows $129.80 and all four names with amounts, Oliver's row fully inside the canvas and above the band's shadow.
4. Frame 3 shows all three Leo item lines, both 25% pills and Tax & Tip $3.70.
5. Pair: "$191.80" entirely in frame 4, all four amount chips and $129.80 entirely in frame 5, band continuous at y 2040, column 1320 free of glyph pixels.
6. Copy never claims OCR, payment, transfers, currency support or even splitting. Frame 6 ships only with a real screen showing paid or unpaid status.
7. Two type families, each headline and sub at most two lines, no single-word last line, no shrink below 118 and 44px.
8. iPad frames use only the three iPad captures, iPhone frames only iPhone captures, and every off-canvas crop removes whole elements or blank space, never a partial name or amount.

## Complete five-frame draft and settlement — final visual check

Exact `claude-fable-5-1` call, Read only, no fallback, successful with no permission denials. Inputs: complete full-campaign-draft contact sheet, full-size lead and settlement frames, genuine settlement raw capture, connected master, and prior fresh design response. These input PNG dimensions and SHA-256 hashes are recorded in `claude-design-input-manifest.json`. Raw response: `claude-design-final-check.json`; prompt: `claude-design-final-check-brief.txt`.

All six files loaded, including the fresh design response. Review follows.

**Verdicts**

- **Email preview: PASS.** Five coherent frames, correct palette roles, two type families, straight legible phones, truthful copy. Send it.
- **Eventual App Store use: no blocking issues in the main five frames.** The connected alternate would block if promoted, for reasons below. This is not a submission approval.

**Settlement frame (05) verified against the real capture**

The frame pixels match the capture exactly: Finalized badge, Settlements card with 2/4 paid, Nora and Maya with green checks and struck names, Leo and Oliver unmarked, four amounts summing to the trip total.

| Claim in copy | Visible proof |
|---|---|
| See every share | Leo $56.70, Nora $51.30, Maya $46.90, Oliver $36.90 |
| Know who's paid | 2/4 paid, two checked and struck rows |
| Track paid and unpaid | Two paid rows next to two unpaid rows |

No transfer, execution, all-settled, currency, or OCR claim appears. Keep the headline and sub as they are. No replacement improves truth, and the current pairing is already the clearest I would write.

**Lead frame (01)**

All four names and amounts are inside the bezel with margin: Leo $40.70, Nora $36.30, Maya $31.90, Oliver $20.90, plus the $129.80 total. Oliver's row and the Share button are whole. At full size the serif headline holds at two lines with no orphan, the gold italic separates from the teal, the sub sits at a comfortable measure, and the app's smallest text reads without strain. The one flaw is real UI: Leo's chevron points up while collapsed, unlike the other three rows.

**Connected alternate**

It is a genuine single phone spanning frames 02 and 03 with a continuous band and matching top blocks. It sacrifices the entire item-detail screen: the six itemised dishes and the subtotal, tax and tip breakdown are gone, so the right-hand headline "Every item. Nothing missing." is now proven only by Leo's three lines. Worse, the phone is centred on the gutter, so a store carousel would cut "Bill Details", "Dinner in Alfama", "$129.80", "Participants" and every item name in half on each individual screenshot. My earlier recipe required the gutter column to be free of glyph pixels. This version fails that. It should stay an alternate, labelled as such in the email, and not enter a store set in this form.

**Ranked corrections**

1. **Frame 02 headline repetition (copy, optional but recommended).** Three of five headlines open with "Every", and "every share" appears on both 02 and 05. The screen actually shows Leo expanded, so make it specific. Replace with:
   ```
   Leo's share,
   line by line.
   ```
   Sub:
   ```
   The sea bass, a quarter of the shared plates,
   and tip on just those.
   ```
   Every phrase is checkable against the two 25% pills and Tax & Tip $3.70.

2. **Connected alternate labelling.** No pixel change. In the email, caption it "Alternate: continuous phone, email only" so nobody reads it as a store candidate. If it is ever promoted, it must be rebuilt so the gutter lands in whitespace, which is a separate job.

3. **Leo chevron on frame 01.** Recapture from a fresh open if the app produces four matching chevrons. If it does not, leave it. Non-blocking.

Nothing else needs work. The Finalize button overlapping the Dinner in Alfama card on frame 04, and the Tram & viewpoints card clipped by the home indicator on 04 and 05, are real app states from the capture and read as a live scrolling screen rather than errors. Leave them.


## Connected-first primary — Claude-authored implementation

The exact-model call completed successfully in 587.5 seconds with no permission denials. Its selected model was `claude-fable-5-1`, with 46,648 output tokens including 28,926 thinking tokens. The CLI also reported 18 auxiliary Haiku output tokens; no fallback model was configured. Claude authored the renderer and manifest changes through Read/Edit only. Raw response: `claude-connected-primary.json`; prompt: `claude-connected-primary-brief.txt`; code patch against the preserved pre-change renderer: `claude-connected-primary.patch`.

Invocation from the project directory:

```sh
claude --model claude-fable-5-1 --safe-mode --strict-mcp-config \
  --mcp-config '{"mcpServers":{}}' --permission-mode dontAsk \
  --tools Read,Edit --allowedTools Read,Edit --no-session-persistence \
  --effort high --print --output-format json \
  < artifacts/app-store/2026-09-05/claude-connected-primary-brief.txt \
  > artifacts/app-store/2026-09-05/claude-connected-primary.json
```

The following implementation response is preserved verbatim. Its original first subtitle and long contact labels were subsequently adjusted under the root task's explicit instructions, as recorded in the current-outcome section above.

Implementation is complete. Nothing else depends on further reads.

**Design rationale.** On the actual completed-split capture, no glyph-free vertical seam exists: the title plus pencil icon extends to source column 937 while the four amount chips begin at 891, so any straight seam cuts one or the other. A modest counter-clockwise tilt of -4.8° lets the fixed seam at x=1320 track a diagonal through whitespace: between the signal and wifi glyphs in the status bar, right of the pencil, right of the $129.80 digits, left of the Items badge, through the empty gutter between "3 item(s)" and every chip, and right of the Share label. The left panel keeps the title, $129.80 and all four names; the right panel keeps all four amount chips. Both panels are teal so the phone sits on one continuous plane with the existing tonal band and physical shadow. No overlays, no fake UI.

**Chosen geometry** (master 2640x2868, seam at x=1320):

| Item | Value |
|---|---|
| Screen size / scale | 944 x 2051 px, scale 0.7152 |
| Unrotated screen top/bottom | 751 / 2803 |
| Phone centre | (1152, 1776.5), rotation -4.8° |
| Rotated shell bounds | x 570–1734, y 689–2864 (fully on canvas, no crop) |
| Screen split at seam | about 65% left panel, 35% right panel |
| Seam source column | 1016 at screen top, 775 at screen bottom |

Seam windows at critical rows are declared in the manifest under seamClearance, and the renderer throws if the computed seam column leaves any window.

**How primary inclusion works.** With panorama.primary true, the renderer requires the pair to be adjacent and ordered, renders the 2640-wide master once before the slide loop, crops it into two 1320 canvases, verifies byte-for-byte pixel equality against the master, and then uses those crops in place of standalone renders for panels 1 and 2. The same crop canvases feed the primary PNGs, the contact-sheet cells, and the ZIP entries. The master is exported to connected/master-2640x2868.png outside the ZIP. Geometry records one shared entry for the pair with rotation, transformed bounds, seam columns, and per-panel visible shell/screen bounds, with no discarded standalone geometry. With primary absent or false, the old optional behavior is unchanged. Rotation uses a single translate-rotate transform for shell, edge stroke, clip and screenshot, and the fit, copy-collision and seam checks use the transformed corners.

**Modified paths**
- `artifacts/app-store/2026-09-05/render-table-linen.mjs`
- `artifacts/app-store/2026-09-05/full-campaign.manifest.json`
- `artifacts/app-store/2026-09-05/connected-primary.manifest.json` (identical campaign, explicit name)

Output goes to outputs/connected-first-campaign. Slide IDs are shared-bill, fair-shares, person-detail, trip-summary, settlement. New copy: "Dinner for four. / One shared bill." and "Four fair shares. / Exactly what’s owed."

**What GPT should check first**
- Render did not throw on seam clearance, headline width or copy collision. If the status-bar window fails, adjust centerX by a few pixels rather than the tilt.
- Panel 1 shows "Dinner in Alfama", $129.80 and all four names intact. Panel 2 shows $40.70, $36.30, $31.90, $20.90 intact and the pencil icon whole.
- Status bar glyphs at the seam are not sliced, and the Share label is entirely on panel 1.
- Contact sheet cells 01 and 02 join into one phone; the ZIP contains exactly five 1320x2868 PNGs plus validation.json.
- validation.json panorama.mode is "primary" and seams report zero differing channel values.
