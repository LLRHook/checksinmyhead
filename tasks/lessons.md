# Lessons

- Keep collaborative split flows anchored to an existing shared entity when possible. Reusing tabs is safer than introducing a parallel sharing model.
- If the creator flow needs to feel simpler, preserve the established parsing and bill-entry steps and change only the handoff into sharing.
- For multi-user state, prefer a small write API that updates one claim at a time over pushing a whole mutable document through the client.
- When a collaborative workflow has to stay in progress, drive the UI off completion state instead of one-time share-row counts so the page does not exit too early.
- In lazy mode, suppress participant-only affordances early in the flow so the UI does not imply a step the creator is intentionally skipping.
- In the lazy creator path, do not show secondary share actions that produce the wrong artifact; keep the footer focused on link creation only.
- When the bill creator already knows their own items, resolve those claims in the app before publishing the collaborative link; sending them to the web creates unnecessary identity and ownership ambiguity.
- Keep every public identity surface aligned with the current product name; stale store URLs from a previous product name can look misleading during App Review.
