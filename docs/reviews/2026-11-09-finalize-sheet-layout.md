# Finalize confirmation on short displays (BUG-1793935715)

Point-in-time record, 2026-11-09. Widget-test evidence only. No simulator or device run
was made for this change; native proof is still owed.

## Defect

`_FinalizeConfirmSheet` in `mobile/lib/screens/tabs/tab_detail_screen.dart` laid the
heading, every settlement row and both actions out in one non-scrolling `Column` capped
at 70% of the screen height. Anything taller overflowed and pushed Cancel/Finalize out
of the sheet.

## Change

- The heading and settlement rows scroll together; Cancel and Finalize are pinned below
  them. A scrollbar thumb shows while there is more to scroll.
- The 70% limit stays. A display shorter than about 630 points may use up to 440 points
  (the heading, three rows and the actions at default text size) or its full height.
- Above 1.5x text the amount sits under the name and shrinks to fit instead of
  overflowing the row. Action labels shrink to fit instead of wrapping.
- The modal call moved, unchanged, into `showFinalizeConfirmSheet` so tests open the
  production sheet through the production route.

Row order, labels, amounts and their formatting, the `true`/`false`/`null` results and
the finalize request are unchanged.

## Evidence

`mobile/test/finalize_confirm_sheet_test.dart`, 19 cases, app light theme:

- 12 layout cases: 320x568, 375x667, 568x320 landscape and 812x375 landscape with
  44-point side insets, each at text scale 1.0, 2.0 and 3.0 with twelve people. Each
  asserts no layout exception, all twelve amounts present once in descending order with
  their labels, every amount reachable by finger drags and clear of the actions, and
  both actions hit-testable inside the usable area before and after every scroll.
- Three people on 320x568 need no scrolling; a two-person preview on 402x874 stays
  compact; a twelve-person preview on 402x874 is exactly 70% high.
- The sheet returns `true` for Finalize, `false` for Cancel and `null` for dismissal.
- Through the real Tab detail screen, tab manager, API client and database: Finalize
  sends exactly one `POST /api/tabs/7/finalize` with the tab bearer token, no member
  token and an empty body, and stores the tab as finalized; Cancel and dismissal send
  nothing and leave it unfinalized.

Against the previous layout (same tests, only the route seam added) 16 of 19 failed
with `RenderFlex overflowed`, including 29 px for three people on 320x568; the two
Tab detail behaviour cases and the compact tall-display case passed before and after.

The test font is about twice as wide as the app's, so scales 1.0 to 3.0 are stricter
horizontally than the same settings on a device.

## Not done

- Native simulator/device capture on a short display at default and large text.
- The Tab detail screen behind the sheet was not qualified at large text.
