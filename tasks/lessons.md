# Lessons

- Keep collaborative split flows anchored to an existing shared entity when possible. Reusing tabs is safer than introducing a parallel sharing model.
- If the creator flow needs to feel simpler, preserve the established parsing and bill-entry steps and change only the handoff into sharing.
- For multi-user state, prefer a small write API that updates one claim at a time over pushing a whole mutable document through the client.
- When a collaborative workflow has to stay in progress, drive the UI off completion state instead of one-time share-row counts so the page does not exit too early.
- In lazy mode, suppress participant-only affordances early in the flow so the UI does not imply a step the creator is intentionally skipping.
- In the lazy creator path, do not show secondary share actions that produce the wrong artifact; keep the footer focused on link creation only.
- When the bill creator already knows their own items, resolve those claims in the app before publishing the collaborative link; sending them to the web creates unnecessary identity and ownership ambiguity.
- Keep every public identity surface aligned with the current product name; stale store URLs from a previous product name can look misleading during App Review.
- Treat currency as a general bill attribute, not a one-country exception: default to USD, allow explicit selection, and preserve the original currency alongside any converted display total.
- When a user reports an old version label, verify all source version authorities and the installed artifact before changing version numbers; stale builds can make correct source look incorrect.
- Payment handles can remain privacy-preserving without a user database when they are local by default and copied only into the specific shared bill/tab the user intentionally publishes.
- Treat a release-version correction as a coordinated change: update Flutter metadata, native iOS marketing version, and the visible Settings label, then build TestFlight from the merged commit.
- For every TestFlight release, bump both the Flutter marketing version and source build number; verify the workflow's resolved App Store Connect build number is also new.
- For a reported regression, inspect the feature's history before concluding the old behavior was never supported; separate a removed interaction from a changed data model, and preserve both compatibility and the intended new boundary.
- For codebase cleanup, apply KISS literally across implementation and tests: delete unnecessary comments and duplicate test logic, share behavior through small helpers/generics when semantics match, and keep code only when a live product path or compatibility requirement needs it.

# Lazy Mode item identity and paid-state interactions

- Receipt rows may share the same display name and price; selection must be keyed by row identity, never a user-visible name.
- A paid share must block item changes both in the UI and in the tap handler. Disable every row after payment, not only rows currently assigned to that person.
- Enforce paid-share immutability on the server for both removals and new assignments, and serialize payment writes with bill assignment transactions.
- Show Review when the local selection differs from saved assignments, even when the changed selection is empty.
- Allocate item, tax, and tip rounding remainders across shares so the cents add back to the billed totals.
- After successfully marking a shared bill paid, return the user to the app landing page instead of leaving them in a picker that invites more selection.
- Keep item selection local while the user is choosing; persist the changed set once on Review, matching mobile and avoiding a refresh after every tap.
- For multi-item review, use one server-side transaction; on a stale or unavailable item, roll back the whole selection and return the refreshed picker so the user can choose again.
- Treat unpriced, indented receipt lines after a priced row as possible modifiers/continuations; never assign them a duplicated price as a separate item.
- Keep lazy web and mobile picker edits local and save full item-assignment sets only through Review; reuse the existing percentage-assignment contract instead of adding another split model or immediate-save path.
