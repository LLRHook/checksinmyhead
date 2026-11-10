# Hands-on UI inspection — 2026-11-09

Scope: the journeys requested for the 2026-11-09 bug sweep, walked on a local synthetic
stack. This is an exploratory inspection, not the integrated V&V run: `Last verified`
stays `never`, and nothing here covers a signed build, a physical device, VoiceOver or
the hosted services.

## Environment

- Source `083567ae` (stack tip at the time). API and PostgreSQL 17 from
  `backend/docker-compose.yml` under compose project `billington-vv-083567ae1244`, with
  labelled synthetic volumes; `/health` reported that commit.
- Web viewer: production build with `NEXT_PUBLIC_API_URL` set to the local API, served
  on port 3100 (Node 25.9.0; the repository pins 24).
- App: debug simulator build 2.0.11, Xcode 27.2, on four simulators created for this
  run: iPhone 17 and iPhone SE (3rd generation) on iOS 27.2, iPhone Duo on iOS 27.1,
  and a second iPhone 17 for the version gate.
- Drivers: Maestro for the simulators and a headed Chrome through `agent-browser`,
  both operated by the Codex CLI; screenshots with `xcrun simctl io`. Results were
  cross-checked against API responses, the API log and the screenshots.

Deviations from `VERIFICATION.md` Appendix A, all local:

1. Host port 8080 is held by another project's container, which was left alone. The
   API was published on `127.0.0.1:28080`, and the inspected app was built from a
   scratch copy whose only change is that debug base URL. That one line was never
   committed.
2. Xcode 27.2 does not build the simulator app with the documented command
   (BUG-1794265789); the build used three `FLUTTER_XCODE_*` overrides.
3. Receipt photo scanning was not exercised: no provider key is configured and no
   paid inference was run. Bills were entered by hand.
4. The first walk of the main journeys used `APP_DOMAIN=http://localhost:3100`. The
   app only accepts share links on the two production web hosts, so every upload read
   as "link pending". That was the inspector's configuration, not an app defect; the
   override was removed, the app reinstalled and the journeys walked again. The first
   run's screenshots are kept separately and are not used below.

## Results

| # | Journey | Result | What was seen |
|---|---|---|---|
| 1 | Create a bill (items, assign, split), save, reopen | pass | USD 128.00 bill for six people; shares 44.81, 25.60, 25.60, 19.20, 6.40, 6.39 sum to 128.00; one copy after force-quit and relaunch |
| 2 | USD and foreign-currency bills | pass after fix | EUR 25.00 saved, shown as EUR 25.00 in Recent Bills and Bill Details, API quote 1.1184 dated 2026-11-10 from `frankfurter-v2-blended`. Defect found and fixed: the tab's bill picker labelled it `$25.00` (BUG-1793644500); recheck shows `EUR 25.00` |
| 3 | Tab create, attach, finalize | pass | Bill attached, tab finalized from the app, still finalized after relaunch and on the web page |
| 3b | Browser join via link, claim, mark paid | not finished | A standard tab's web page is a read-only summary by design. The join dialog on a Lazy Mode receipt was reached and its name field checked (row 10). Claiming items and marking paid from the browser were not walked: the local web server stopped at the session's two-hour background limit before that step |
| 4 | Trip import at capacity | pass | Fresh install joined a 30-receipt trip: 30 bills, 765.00, balances, same after relaunch. A 31-receipt trip was refused whole with "Retry current history" and no partial list, balances or Finalize; the 30-receipt trip stayed intact. The limit itself is filed as BUG-1794274030 |
| 5 | Side status column on Assign, Entry and Tab screens | pass | iPhone Duo, Closed pose: content clear of the column; Assigned reads `$61.00` in full at 50% with the bar ending halfway. Open/landscape pose could not be selected from the command line. The first-use tutorial dialog still extends under the column (BUG-1794273307) |
| 6 | Finalize dialog on a small iPhone | pass | iPhone SE, 375x667: no overflow at default text or accessibility-extra-large; rows scroll; Cancel and Finalize stay visible |
| 7 | Saved participant colors | pass | Each of six people keeps the colour given when added, after save and after relaunch |
| 8 | Four assignees before the overflow badge | pass | Four people: four avatars, no `+1`. Six people: three avatars and `+3` |
| 9 | Removal labels | pass | "Remove from this device?" with the statement that shared data stays online; Cancel keeps the tab; a synced or finalized bill offers no removal |
| 10 | Typed join text kept across a refresh | pass, with a limit | Text typed in "What should we call you?" survives the page's own 10-second data refresh and a cleared field stays empty. A full browser reload discards unsubmitted text; BUG-1794045429 does not promise otherwise |
| 11 | Public web copy and privacy page | pass | Billington branding only; one-click App Store link; labelled USD 128.00 example; payment copy limited to handoff, shown details and manual status; `/privacy-policy` describes 1.4.0 and marks unreleased statements; `/privacy` is 404; private pages carry noindex and no-referrer |
| 12 | Version gate | pass | Server: minimum 2.0.3 against the 1.4.0 record serves `0.0.0` with a warning; 1.4.0 is enforced. Client 2.0.11: minimum 99.0.0 or 2.0.12 shows "Update Billington"; a 503 policy, an unreachable policy and minimum 2.0.11 let the app open |

## Findings

- **Fixed in this sweep:** the bill picker currency label (row 2).
- **Device and server disagree on odd cents:** after finalizing, the settlement rows
  read Alex 44.80 and Pat 6.40 where the phone had shown 44.81 and 6.39. Recorded on
  BUG-1794264955, which needs an owner decision.
- **Filed:** BUG-1794265789 (simulator build on Xcode 27.2), BUG-1794273307 (tutorial
  dialog under the side column), BUG-1794274030 (a trip beyond the 30-receipt device
  limit cannot be opened).

## Evidence

Screenshots and driver transcripts are in ignored `.vv/ui-inspection-20261109/`
(`main/`, `layout/`, `recheck/`, `web/`, `gate/`) on the inspecting machine. The cited
files and their SHA-256 values are listed in
[evidence/2026-11-09-ui-inspection.json](evidence/2026-11-09-ui-inspection.json).
The rechecks in rows 2 and 4 used a rebuild that includes the picker fix.
