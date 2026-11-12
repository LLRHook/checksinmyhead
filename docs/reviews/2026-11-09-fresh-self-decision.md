# Fresh-self participation: decision for the owner — 2026-11-09

BUG-1793644505 stays `in-progress` on one open product question. Nothing in this
note is implemented. Source read: branch `sweep/mobile-currency` on `e0a2c18`.

## What the approved plan asked for

The plan and its approval are not in this repository. The tracker Log cites them as
"original plan 60 / approval 33-34" and names the unmet item "fresh-self capability".
The in-repository records
([client integration](2026-11-05-client-identity-integration.md),
[row materialization](2026-11-05-row-materialization.md),
[technical overview](../technical-overview.md)) describe it as **atomic authenticated
fresh-self participation**: a tab member adds themselves to an attached receipt as a
new participant and is confirmed as that participant in the same authenticated
request, with no second person involved. This note uses that reading. If the plan
text says something different, correct this section first.

## What exists today

Three recorded steps, each its own request and its own bill revision
([contract](../backend-api.md#participant-reference-contract)):

1. `POST /api/tabs/:id/bills/:billId/participants` creates an **unbound** row. The
   strict body is `client_ref,name,expected_revision`; any member, binding or state
   field is a 400.
2. `POST …/participants/:participantId/binding-request` records the caller's own
   member as **pending**. Pending grants no paid authority and the person's debt stays
   a separate guest row in balances and finalization.
3. `PUT …/participants/:participantId/binding` with `approve` **confirms**. Only the
   tab creator, or a member who also presents the receipt's source token, may decide.

The creator has no shortcut: the same three steps, the third being their own approval.
`TestPostgresIdentity0003FreshParticipantIsUnboundUntilApproved` (new, PostgreSQL)
proves all of the above, including that a same-name member cannot decide.

Why it cannot be one step today: frozen migration `0003_participant_identity.sql`
only accepts a confirmed row with an approver and `approval_kind IN ('creator','source')`
(`bill_participants_binding_shape`), and a decision record with the same two actor
kinds (`bill_participants_receipt_shape`). A member confirming themselves is not a
representable state. Mobile (`participant_identity_panel.dart`) and web
(`IdentityControls.tsx`) show unbound/pending/confirmed and never show a confirmation
the server did not record.

The ticket's four Expected bullets do not depend on this. Same-name separation and
the impersonation negatives are met by the supported flow.

## Options

| | A. Accept the supported flow, amend the plan | B. One-step self-add for creator and source holders only | C. One-step self-add for every member |
|---|---|---|---|
| Who gains | Nobody; behaviour as shipped | The tab creator and whoever uploaded the receipt | Every member |
| Schema | None | None expected: a confirmed row approved by the same creator/source member satisfies 0003. To check in design: whether the write also records a decision receipt, which today needs a prior request revision | New migration 0004 replacing both CHECK constraints with a third kind (`self`); new catalog and recognizer checksums. That changes definitions current binaries validate, so it is a compatibility epoch 1 → 2 change, not a same-epoch additive step |
| API | None | One additive request field on participant create, announced by a new capability value; older servers answer 400, so clients must gate on the capability | New field or route, a new `approval_kind` value in read responses, capability bump; every reader must tolerate the new value |
| Clients | None | Mobile and web: one new action for two roles | Mobile and web: new action, new state text; mobile's stored graph observation must accept the new kind |
| Tests | Present | PostgreSQL: atomicity, retry, paid/finalized guards, both-order races for the new write | As B, plus migration up/verify, old-binary refusal, epoch-2 rollback |
| Risk | Friction: an ordinary member waits for the creator before their debts group under them or they can mark their share paid | Low. No new authority: these two roles can already approve themselves in three calls | Highest. First epoch change, while old-writer drain, rollout and the PostgreSQL gate are still open. Epoch-1 binaries refuse an unknown epoch, so deploy order and rollback need their own procedure |
| Plan requirement | Not met; plan amended | Met for two roles only | Met |

Security is the same in all three for existing receipts: a self-added participant
starts with no items and no share, so one-step confirmation cannot take over another
person's debt. Binding to an **existing** participant keeps request and approval in
every option. Under C a member could add themselves, claim items on a lazy receipt and
mark that share paid with no second person; paid flags are manual markers, not money
transfers, and the claim only creates a debt for the claimant.

Notes dated 2026-11-06 mention an isolated fresh-self 0004/epoch-2 candidate that was
deliberately left out ([migration outcomes](2026-11-06-migration-outcomes.md)). It is
not in this repository and was not reviewed here.

## Recommendation

**A now, C later as its own feature.** Amend the plan to name create-unbound, request
and creator/source approval as the identity contract for this release, and close the
fresh-self item on BUG-1793644505 as "not required by Expected". File one-step
self-add as a feature to decide after epoch 1 is qualified in production (old-writer
drain, rollout, green PostgreSQL gate). The supported flow already meets every
Expected bullet, and C is a schema-epoch change that should not ride on a bug fix.

B is worth adding only if the creator's three taps prove to be a real complaint. It
does not satisfy the plan as read above, so choosing B still means amending the plan.

## What the owner needs to decide

1. Is the reading of the plan above correct?
2. A, B or C. For A or B: approve the plan amendment. For C: approve an epoch-2
   migration and say whether it may ship before the rollout gates are green.
