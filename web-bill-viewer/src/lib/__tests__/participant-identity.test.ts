import { afterEach, describe, expect, it, vi } from "vitest";
import {
  ApiError,
  type Bill,
  computeTabPersonTotals,
  decideBinding,
  getCurrentMember,
  getSettlementHistory,
  type Participant,
  renameParticipant,
  requestBinding,
  type Tab,
  updateLazyBillItemAssignmentsBatch,
} from "../api";
import {
  legacySuggestion,
  readMember,
  readSelection,
  recoveryToken,
} from "../identity-storage";
import { isLazyItemPaid, setLazyAssignmentPercentage } from "../lazy-bill";

const person = (
  id: number,
  label = "Alex",
  member: number | null = null,
): Participant => ({
  participant_id: id,
  bill_id: 7,
  client_ref: `r${id}`,
  label,
  binding_state: member ? "confirmed" : "unbound",
  member_id: member,
  pending_member_id: null,
  pending_request_revision: null,
});
afterEach(() => vi.unstubAllGlobals());
describe("participant identity", () => {
  it("paid and draft identities discriminate same blank casefold labels and retain rename", () => {
    const shares = [{ person_name: "Alex", participant_id: 11, paid: true }];
    expect(
      isLazyItemPaid(
        [{ participant_id: 12, person_name: "Alex", percentage: 100 }],
        shares,
      ),
    ).toBe(false);
    expect(
      isLazyItemPaid(
        [{ participant_id: 11, person_name: "Renamed", percentage: 100 }],
        shares,
      ),
    ).toBe(true);
    const draft = setLazyAssignmentPercentage(
      [{ participant_id: 11, percentage: 50 }],
      12,
      50,
    );
    expect(draft.map((a) => a.participant_id)).toEqual([11, 12]);
  });
  it("version2 bill-scoped storage never selects from legacy names or another bill", () => {
    const rows = [person(11), person(12)];
    expect(
      readSelection(
        JSON.stringify({ version: 2, bill_id: 7, participant_id: 12 }),
        7,
        rows,
      ),
    ).toBe(12);
    expect(
      readSelection(
        JSON.stringify({ version: 2, bill_id: 8, participant_id: 12 }),
        7,
        rows,
      ),
    ).toBeNull();
    expect(
      readSelection(
        JSON.stringify({ version: 2, bill_id: 7, participant_id: 99 }),
        7,
        rows,
      ),
    ).toBeNull();
    expect(
      readSelection(JSON.stringify({ display_name: "Alex" }), 7, rows),
    ).toBeNull();
    rows[1].label = "Renamed";
    expect(
      readSelection(
        JSON.stringify({ version: 2, bill_id: 7, participant_id: 12 }),
        7,
        rows,
      ),
    ).toBe(12);
  });
  it("legacy membership keeps its token for authentication and label as suggestion only", () => {
    const raw = JSON.stringify({
      display_name: "Alex",
      member_token: "old-proof",
    });
    expect(readMember(raw, "9")).toBeNull();
    expect(legacySuggestion(raw)).toBe("Alex");
    expect(recoveryToken(raw)).toBe("old-proof");
    expect(
      readMember(
        JSON.stringify({
          version: 2,
          tab_id: 8,
          member_id: 1,
          member_token: "proof",
          display_name: "Alex",
        }),
        "9",
      ),
    ).toBeNull();
  });
  it("members/me validates the returned tab scope and never sends a name rejoin", async () => {
    const fetch = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          member_id: 13,
          tab_id: 9,
          display_name: "Alex",
          role: "member",
        }),
      ),
    );
    vi.stubGlobal("fetch", fetch);
    expect((await getCurrentMember("9", "tab", "proof")).member_id).toBe(13);
    expect(fetch.mock.calls[0][0]).toContain("/members/me");
    const headers = new Headers(fetch.mock.calls[0][1].headers);
    expect(headers.get("X-Member-Token")).toBe("proof");
    fetch.mockResolvedValue(
      new Response(
        JSON.stringify({
          member_id: 13,
          tab_id: 8,
          display_name: "Alex",
          role: "member",
        }),
      ),
    );
    await expect(getCurrentMember("9", "tab", "proof")).rejects.toThrow(
      "Invalid scoped membership",
    );
  });
  it("label-only and missing revision writes fail before HTTP; stale current writes do not automatically retry", async () => {
    const fetch = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ code: "identity_revision_conflict" }), {
        status: 409,
      }),
    );
    vi.stubGlobal("fetch", fetch);
    await expect(
      updateLazyBillItemAssignmentsBatch(
        7,
        [
          {
            item_id: 4,
            assignments: [{ person_name: "Alex", percentage: 100 }],
          },
        ],
        "source",
        2,
      ),
    ).rejects.toThrow("occurrence");
    await expect(
      updateLazyBillItemAssignmentsBatch(7, [], "source"),
    ).rejects.toThrow("revision");
    expect(fetch).not.toHaveBeenCalled();
    await expect(
      updateLazyBillItemAssignmentsBatch(
        7,
        [
          {
            item_id: 4,
            expected_updated_at: "old-time",
            assignments: [{ participant_id: 11, percentage: 100 }],
          },
        ],
        "source",
        2,
      ),
    ).rejects.toMatchObject({
      status: 409,
      code: "identity_revision_conflict",
    });
    expect(fetch).toHaveBeenCalledTimes(1);
    const request = fetch.mock.calls[0][1];
    expect(JSON.parse(request.body)).toEqual({
      expected_revision: 2,
      updates: [
        {
          item_id: 4,
          expected_updated_at: "old-time",
          assignments: [{ participant_id: 11, percentage: 100 }],
        },
      ],
    });
  });
  it("binding generation actor proof and source proof stay separate; exact deliberate retry retains original body", async () => {
    const fetch = vi
      .fn()
      .mockImplementation(
        async () =>
          new Response(
            JSON.stringify({ participant: person(11), identity_revision: 4 }),
          ),
      );
    vi.stubGlobal("fetch", fetch);
    const context = {
      billId: 7,
      tabId: "9",
      token: "destination",
      memberToken: "actor",
    };
    await requestBinding(context, 11, 2);
    expect(JSON.parse(fetch.mock.calls[0][1].body)).toEqual({
      expected_revision: 2,
    });
    for (let i = 0; i < 2; i++)
      await decideBinding(context, 11, 3, 3, 13, "reject", "source");
    expect(fetch.mock.calls[1][1].body).toBe(fetch.mock.calls[2][1].body);
    expect(JSON.parse(fetch.mock.calls[1][1].body)).toEqual({
      expected_revision: 3,
      request_revision: 3,
      member_id: 13,
      decision: "reject",
      bill_token: "source",
    });
    expect(
      new Headers(fetch.mock.calls[1][1].headers).get("X-Member-Token"),
    ).toBe("actor");
    await renameParticipant(context, 11, "", 4);
    expect(JSON.parse(fetch.mock.calls[3][1].body)).toEqual({
      name: "",
      expected_revision: 4,
    });
  });
  it("unavailable and raw legacy settlement history stay explicit rather than becoming an empty result", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            settlements: [
              {
                id: 4,
                person_name: "",
                amount: 1,
                snapshot_version: 1,
                party: null,
              },
            ],
            identity_review_status: "legacy_identity_review_required",
            accounting_currency: "USD",
            viewer_member_id: null,
          }),
        ),
      ),
    );
    const history = await getSettlementHistory("9", "tab");
    expect(history.settlements).toHaveLength(1);
    expect(history.identity_review_status).toBe(
      "legacy_identity_review_required",
    );
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(new Response("{}", { status: 503 })),
    );
    await expect(getSettlementHistory("9", "tab")).rejects.toBeInstanceOf(
      ApiError,
    );
  });
  it("confirmed members group by scoped ID while same-label unbound occurrences stay separate", () => {
    const bill = {
      id: 7,
      total: 4,
      usd_total: 4,
      currency_code: "USD",
      identity_review_status: "ready",
      participants: [
        person(11),
        person(12, "Alex"),
        person(13, "", 91),
        person(14, "alex", 92),
      ],
      person_shares: [11, 12, 13, 14].map((id) => ({
        id,
        participant_id: id,
        person_name: "Alex",
        total: 1,
        paid: false,
      })),
    } as Bill;
    const tab = { id: 9, bills: [bill] } as Tab;
    const totals = computeTabPersonTotals(tab);
    if (totals === null) throw new Error("Unexpected review fixture");
    expect(totals).toHaveLength(4);
    expect(new Set(totals.map((t) => t.key)).size).toBe(4);
    bill.identity_review_status = "identity_review_required";
    expect(computeTabPersonTotals(tab)).toBeNull();
  });
});
