/* Explicit loopback/owned-schema journey; compiled maintained api.ts is supplied by the fixture. */
const assert = require("node:assert/strict");
const fs = require("node:fs");
const fixture = JSON.parse(
  fs.readFileSync(process.env.BILLINGTON_CD_OUTPUT, "utf8"),
);
assert.equal(new URL(fixture.base).hostname, "127.0.0.1");
const api = require(process.env.BILLINGTON_CD_WEB_API);
let checks = 0;
const ok = (condition, message) => {
  assert.ok(condition, message);
  checks++;
};
const equal = (actual, expected) => {
  assert.deepEqual(actual, expected);
  checks++;
};
const denied = async (action, status) => {
  await assert.rejects(
    action,
    (e) => e instanceof api.ApiError && e.status === status,
  );
  checks++;
};
const context = {
  billId: fixture.bill_id,
  tabId: String(fixture.tab_id),
  token: fixture.tab_token,
  memberToken: fixture.member_token,
};
const creator = { ...context, memberToken: fixture.creator_token };
const current = () =>
  api.getBill(String(fixture.bill_id), fixture.tab_token, fixture.member_token);
async function raw(
  path,
  method,
  body,
  token = fixture.tab_token,
  member = fixture.creator_token,
) {
  const response = await fetch(fixture.base + path, {
    method,
    headers: api.identityHeaders(token, member),
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  assert.equal(response.status, path === "/api/tabs" ? 201 : 200);
  checks++;
  return response.json();
}
(async () => {
  const member = await api.getCurrentMember(
    String(fixture.tab_id),
    fixture.tab_token,
    fixture.member_token,
  );
  const owner = await api.getCurrentMember(
    String(fixture.tab_id),
    fixture.tab_token,
    fixture.creator_token,
  );
  equal(member.member_id, fixture.member_id);
  equal(owner.member_id, fixture.creator_id);
  ok(
    member.member_id !== owner.member_id,
    "two same-label contexts are independent",
  );
  let bill = await current();
  equal(bill.identity_revision, 1);
  equal(bill.identity_review_status, "ready");
  equal(bill.viewer_member_id, member.member_id);
  equal(bill.participants.length, 6);
  equal(
    bill.participants.map((p) => p.label),
    ["Alex", "Alex", "", "Σ", "ς", "Birthday"],
  );
  const [first, selected, blank, sigma, finalSigma] = fixture.participant_ids;
  const shareFor = (id) =>
    bill.person_shares.find((s) => s.participant_id === id);
  await denied(
    () =>
      api.updateTabPersonSharePaid(
        String(fixture.tab_id),
        bill.id,
        shareFor(selected).id,
        false,
        fixture.tab_token,
        fixture.member_token,
      ),
    403,
  );
  await denied(
    () =>
      api.updateTabPersonSharePaid(
        String(fixture.tab_id),
        bill.id,
        shareFor(selected).id,
        false,
        fixture.tab_token,
        fixture.creator_token,
      ),
    403,
  );
  await denied(
    () => api.getCurrentMember(String(fixture.tab_id), fixture.tab_token, ""),
    403,
  );
  await denied(
    () =>
      api.getCurrentMember(
        String(fixture.tab_id),
        fixture.tab_token,
        "forged-member",
      ),
    403,
  );
  await api.requestBinding(context, selected, 1);
  await api.requestBinding(context, selected, 1);
  bill = await current();
  equal(bill.identity_revision, 2);
  equal(
    bill.participants.find((p) => p.participant_id === selected).binding_state,
    "pending",
  );
  await denied(
    () =>
      api.updateTabPersonSharePaid(
        String(fixture.tab_id),
        bill.id,
        shareFor(selected).id,
        false,
        fixture.tab_token,
        fixture.member_token,
      ),
    403,
  );
  await api.decideBinding(creator, selected, 2, 2, member.member_id, "approve");
  await api.decideBinding(creator, selected, 2, 2, member.member_id, "approve");
  bill = await current();
  equal(bill.identity_revision, 3);
  equal(
    bill.participants.find((p) => p.participant_id === selected).member_id,
    member.member_id,
  );
  await api.requestBinding(creator, blank, 3);
  await api.decideBinding(creator, blank, 4, 4, owner.member_id, "reject");
  await api.decideBinding(creator, blank, 4, 4, owner.member_id, "reject");
  bill = await current();
  equal(bill.identity_revision, 5);
  equal(
    bill.participants.find((p) => p.participant_id === blank).binding_state,
    "unbound",
  );
  const prior = structuredClone(shareFor(selected));
  await api.renameParticipant(context, selected, "Renamed", 5);
  bill = await current();
  equal(bill.identity_revision, 6);
  equal(shareFor(selected).id, prior.id);
  equal(shareFor(selected).total, prior.total);
  equal(shareFor(selected).paid, false);
  await denied(
    () =>
      api.renameParticipant(context, selected, "Overwrite stale selection", 5),
    409,
  );
  bill = await current();
  equal(
    bill.participants.find((p) => p.participant_id === selected).label,
    "Renamed",
  );
  equal(bill.identity_revision, 6);
  await api.updateTabPersonSharePaid(
    String(fixture.tab_id),
    bill.id,
    shareFor(selected).id,
    true,
    fixture.tab_token,
    fixture.member_token,
  );
  await denied(
    () =>
      api.updateTabPersonSharePaid(
        String(fixture.tab_id),
        bill.id,
        shareFor(selected).id,
        true,
        fixture.tab_token,
        fixture.creator_token,
      ),
    403,
  );
  await api.updatePersonSharePaid(
    bill.id,
    shareFor(first).id,
    true,
    fixture.source,
  );
  await denied(
    () =>
      api.updatePersonSharePaid(
        bill.id,
        shareFor(first).id,
        true,
        fixture.tab_token,
      ),
    403,
  );
  bill = await current();
  const item = bill.items.find((i) =>
    i.assignments.some((a) => a.participant_id === sigma),
  );
  const updates = [
    {
      item_id: item.id,
      expected_updated_at: item.updated_at,
      assignments: [
        { participant_id: sigma, percentage: 50 },
        { participant_id: finalSigma, percentage: 50 },
      ],
    },
  ];
  await api.updateTabBillItemAssignmentsBatch(
    String(fixture.tab_id),
    bill.id,
    updates,
    fixture.tab_token,
    fixture.member_token,
    6,
  );
  await denied(
    () =>
      api.updateTabBillItemAssignmentsBatch(
        String(fixture.tab_id),
        bill.id,
        updates,
        fixture.tab_token,
        fixture.member_token,
        6,
      ),
    409,
  );
  bill = await current();
  equal(bill.identity_revision, 7);
  await denied(
    () =>
      api.updateTabBillItemAssignmentsBatch(
        String(fixture.tab_id),
        bill.id,
        [
          {
            item_id: item.id,
            assignments: [{ participant_id: 99999999, percentage: 100 }],
          },
        ],
        fixture.tab_token,
        fixture.member_token,
        7,
      ),
    404,
  );
  await denied(
    () =>
      api.renameParticipant(
        { ...context, memberToken: fixture.creator_token },
        99999999,
        "Forged",
        7,
      ),
    404,
  );
  const cross = await raw("/api/tabs", "POST", {
    name: "Other scope",
    creator_display_name: "Alex",
  });
  await denied(
    () =>
      api.getCurrentMember(
        String(fixture.tab_id),
        fixture.tab_token,
        cross.member_token,
      ),
    403,
  );
  await denied(
    () =>
      api.renameParticipant(
        {
          ...context,
          tabId: String(cross.tab_id),
          token: cross.access_token,
          memberToken: cross.member_token,
        },
        selected,
        "Wrong scope",
        7,
      ),
    404,
  );
  const settled = await raw(`/api/tabs/${fixture.tab_id}/finalize`, "POST");
  equal(settled.accounting_currency, "USD");
  equal(settled.identity_review_status, "ready");
  equal(settled.settlements.length, 6);
  equal(
    settled.settlements.reduce((s, r) => s + Math.round(r.amount * 100), 0),
    1000,
  );
  ok(
    settled.settlements.every((r) => r.snapshot_version === 2 && r.party),
    "tagged rows",
  );
  await raw(`/api/tabs/${fixture.tab_id}/bills`, "POST", {
    bill_id: bill.id,
    bill_token: fixture.source,
    expected_revision: 0,
  });
  const replay = await fetch(`${fixture.base}/api/bills`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Idempotency-Key": fixture.key,
      "X-Billington-Identity-Version": "2",
    },
    body: fixture.original_body,
  });
  equal(replay.status, 201);
  equal(await replay.text(), fixture.original_response);
  const history = await api.getSettlementHistory(
    String(fixture.tab_id),
    fixture.tab_token,
  );
  equal(
    history.settlements.map((s) => s.id),
    settled.settlements.map((s) => s.id),
  );
  const legacy = await api.getBill(
    String(fixture.legacy_bill_id),
    fixture.legacy_source,
  );
  equal(legacy.identity_review_status, "identity_review_required");
  equal(legacy.person_shares.length, 2);
  equal(
    legacy.person_shares.map((s) => s.person_name),
    ["", ""],
  );
  await api.updatePersonSharePaid(
    legacy.id,
    legacy.person_shares[0].id,
    true,
    fixture.legacy_source,
  );
  const reread = await api.getBill(String(legacy.id), fixture.legacy_source);
  equal(
    reread.person_shares.map((s) => s.paid),
    [true, false],
  );
  fs.writeFileSync(
    process.env.BILLINGTON_CD_BROWSER_RESULT,
    JSON.stringify(
      {
        status: "pass",
        checks,
        member_contexts: 2,
        revision: 7,
        settlements: 6,
        controls: [
          "same-label paid",
          "creator same-flag",
          "pending paid",
          "empty proof",
          "forged proof",
          "cross-tab proof",
          "forged participant",
          "cross-scope participant",
          "stale revision",
          "source/tab substitution",
          "legacy exact row",
        ],
      },
      null,
      2,
    ),
  );
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
