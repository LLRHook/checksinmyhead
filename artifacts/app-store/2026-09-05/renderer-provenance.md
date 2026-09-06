# Renderer authorship and verification

The initial `render-table-linen.mjs` implementation was authored by GPT from Claude Fable 5.1's Table Linen art direction. That implementation was written immediately before the user preference changed to require Claude authorship for substantial remaining code. It is not represented as Claude-authored initial code.

After the preference change, exact `claude-fable-5-1` was invoked to review the script and author necessary substantive corrections. Its read-only prompt is preserved locally in `claude-renderer-review-brief.txt`, and its unmodified JSON response is stored locally as `claude-renderer-review.json`. Completed corrections are recorded below.

Initial execution/verification by GPT:

- `node --check` passed.
- Five standalone PNGs exported from a historical repeated smoke capture, each 1320 × 2868 and PNG color type 2 (RGB).
- macOS `sips` independently confirmed the first frame's dimensions and `hasAlpha: no`.
- Every standalone screen reports a visible fraction of 1.0; the entire source rectangle is uniformly scaled inside the display mask. The historical source itself has incomplete on-screen person content, which is not repaired or marketed as fresh evidence.
- The optional two-panel composition contains one phone, not two. Both panel canvases match their exact regions in the 2640 × 2868 master, with zero differing channel values.
- `unzip -t` passed for all five PNGs and the validation JSON.
- An intentionally overflowing headline caused export to fail with a request to shorten the copy. No automatic type shrinking was performed.
- Contact sheet, full-size first frame and uncut connected pair were visually inspected. All smoke artifacts are under `outputs/smoke/table-linen`; the contact sheet states `SMOKE TEST · HISTORICAL CAPTURES · NOT FINAL CAMPAIGN`.

No final screenshot mapping, final copy approval, App Store upload, or email delivery is claimed by this renderer subtask.

Claude review completed successfully in 375.038 seconds. The result reports modelUsage.claude-fable-5-1, with a small auxiliary Haiku call and no permission denials. Claude judged the initial renderer sound overall, then authored corrections for shared-phone collision checking against both panels, directly verified font-face loading, vertical text collision guards, PNG IHDR size/depth verification, and manifest validation/provenance. The exact substantive code patch was applied without code changes; its README replacement was integrated as a prefix replacement because the original paragraph continues on the same line. Authored patch: claude-renderer-review.patch; integrated code-only extraction: claude-renderer-code.patch.

A second exact claude-fable-5-1 call authored the minimal correction to preload panorama images only when enabled. Its full response and patch are saved as claude-renderer-smallfix.json and claude-renderer-smallfix.patch. After the main patch, the full Table Linen smoke rerender passed, and a deliberately colliding right-panel subtitle correctly caused the shared phone export to fail.

The final connected-first revision was authored by exact Claude Fable 5.1. It adds primary panorama replacement, a rigid shell-and-capture rotation around the screen center, transformed bounds checks, and native-source seam-clearance assertions. The resulting five-frame campaign begins with literal crops of one −4.8° phone master, then shows Leo's allocation, the trip and paid tracking. GPT applied the coordinator's accurate opening subtitle, reused Claude's previously approved person-detail copy, shortened contact labels and verified the final exports. Independent decoded comparisons found zero differing channels between both primary crops and the master. Final ZIP order, CRC, loose-file identity, RGB dimensions and visible source bounds all pass. Exact invocation and model evidence are recorded in `claude-design.md`; raw model traces and patches remain local and ignored.

The V2 hardware correction was also authored by exact Claude Fable 5.1, in a successful 138-second call. It adds a custom iPhone frame with measured island mask, larger display corners, silver rim and side controls. GPT supplied actual simulator measurements and reviewed the code and renders. Source-mode and duplicate-detection checks against a real system-composited screenshot both preserve its island and produce identical PNG pixels. The campaign source files and their geometry are unchanged. Independent V2 seam, format, ZIP and visual checks pass. Three straight-phone app interiors match V1 exactly; the rotated interior has nine isolated antialiasing differences with no visible content change. V2 hashes are recorded in `HARDWARE-REFERENCE.md` and `claude-design.md`.
