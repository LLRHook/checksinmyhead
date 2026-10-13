import { beforeEach, describe, expect, it, vi } from "vitest";
import type { Bill, PersonShare, Tab } from "../api";
import {
  computeTabPersonTotals,
  getBill,
  getSettlements,
  getTab,
  getTabMembers,
  joinTab,
  updateLazyBillItemAssignments,
  updateLazyBillItemAssignmentsBatch,
  updatePersonSharePaid,
  updateSettlementPaid,
  updateTabBillItemAssignments,
  updateTabBillItemAssignmentsBatch,
  updateTabPersonSharePaid,
} from "../api";

beforeEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

function makeShare(
  person_name: string,
  total: number,
  overrides: Partial<PersonShare> = {},
): PersonShare {
  return {
    id: 1,
    person_name,
    items: [],
    subtotal: total,
    tax_share: 0,
    tip_share: 0,
    total,
    paid: false,
    ...overrides,
  };
}

function makeBill(overrides: Partial<Bill> & Pick<Bill, "id">): Bill {
  return {
    name: `Bill ${overrides.id}`,
    subtotal: 0,
    tax: 0,
    tip_amount: 0,
    tip_percentage: 0,
    total: 0,
    date: "2025-01-01",
    payment_methods: [],
    items: [],
    person_shares: [],
    ...overrides,
  };
}

function makeTab(bills: Bill[], name = "Trip"): Tab {
  return {
    id: 1,
    name,
    description: "",
    bills,
    total_amount: 0,
    finalized: false,
    finalized_at: null,
    created_at: "2025-01-01",
    net_balances: [],
  };
}

// ── computeTabPersonTotals ──────────────────────────────────────

describe("computeTabPersonTotals", () => {
  it("reconciles fractional cents to each frozen USD bill total", () => {
    const share = 0.8 / 3;
    const tab = makeTab(
      [
        makeBill({
          id: 1,
          name: "Small foreign receipt",
          subtotal: 0.8,
          total: 0.8,
          currency_code: "EUR",
          usd_exchange_rate: 1.25,
          usd_total: 1,
          date: "2026-08-29",
          person_shares: ["Alice", "Bob", "Cara"].map((name, index) =>
            makeShare(name, share, { id: index + 1 }),
          ),
        }),
      ],
      "Fractional split",
    );

    const totals = computeTabPersonTotals(tab);
    expect(
      totals.map(({ person_name, total }) => ({ person_name, total })),
    ).toEqual([
      { person_name: "Alice", total: 0.34 },
      { person_name: "Bob", total: 0.33 },
      { person_name: "Cara", total: 0.33 },
    ]);
    expect(totals.reduce((sum, entry) => sum + entry.total, 0)).toBe(1);
  });

  it("uses an ordinal name tie-break for non-ASCII participants", () => {
    const share = 0.8 / 3;
    const tab = makeTab(
      [
        makeBill({
          id: 1,
          subtotal: 0.8,
          total: 0.8,
          currency_code: "EUR",
          usd_exchange_rate: 1.25,
          usd_total: 1,
          date: "2026-08-29",
          person_shares: ["ä", "z", "Ω"].map((name, index) =>
            makeShare(name, share, { id: index + 1 }),
          ),
        }),
      ],
      "Ordinal split",
    );

    const totals = computeTabPersonTotals(tab);
    expect(totals.find((entry) => entry.person_name === "z")?.total).toBe(0.34);
    expect(totals.find((entry) => entry.person_name === "ä")?.total).toBe(0.33);
  });

  it("uses UTF-8 order for supplementary versus high-BMP names", () => {
    const tab = makeTab(
      [
        makeBill({
          id: 1,
          name: "One cent",
          subtotal: 0.008,
          total: 0.008,
          currency_code: "EUR",
          usd_exchange_rate: 1.25,
          usd_total: 0.01,
          date: "2026-08-29",
          person_shares: ["😀", "Ａ"].map((name, index) =>
            makeShare(name, 0.004, { id: index + 1 }),
          ),
        }),
      ],
      "UTF-8 split",
    );

    const totals = computeTabPersonTotals(tab);
    expect(totals.find((entry) => entry.person_name === "😀")?.total).toBe(0);
    expect(totals.find((entry) => entry.person_name === "Ａ")?.total).toBe(
      0.01,
    );
  });

  it("does not scale a partial assignment to the full USD bill total", () => {
    const tab = makeTab(
      [
        makeBill({
          id: 1,
          name: "Partially assigned",
          subtotal: 80,
          total: 80,
          currency_code: "EUR",
          usd_exchange_rate: 1.25,
          usd_total: 100,
          date: "2026-08-29",
          person_shares: [makeShare("Alice", 8)],
        }),
      ],
      "In-progress split",
    );

    expect(computeTabPersonTotals(tab)[0].total).toBe(10);
  });

  it("aggregates mixed-currency shares in frozen USD values", () => {
    const tab = makeTab(
      [
        makeBill({
          id: 1,
          name: "Paris dinner",
          subtotal: 100,
          total: 100,
          currency_code: "EUR",
          usd_exchange_rate: 1.085,
          usd_total: 108.5,
          date: "2026-08-29",
          person_shares: [makeShare("Alice", 50)],
        }),
        makeBill({
          id: 2,
          name: "Tokyo train",
          subtotal: 1000,
          total: 1000,
          currency_code: "JPY",
          usd_exchange_rate: 0.0068,
          usd_total: 6.8,
          date: "2026-08-29",
          person_shares: [makeShare("Alice", 1000)],
        }),
        makeBill({
          id: 3,
          name: "Legacy cab",
          subtotal: 10,
          total: 10,
          date: "2026-08-29",
          person_shares: [makeShare("Alice", 10)],
        }),
      ],
      "International trip",
    );

    expect(computeTabPersonTotals(tab)).toEqual([
      {
        person_name: "Alice",
        total: 71.05,
        bill_count: 3,
        all_paid: false,
      },
    ]);
  });

  it("aggregates across multiple bills", () => {
    const tab = makeTab([
      makeBill({
        id: 1,
        name: "Dinner",
        subtotal: 80,
        tax: 5,
        tip_amount: 15,
        tip_percentage: 20,
        total: 100,
        person_shares: [
          makeShare("Alice", 60, {
            subtotal: 40,
            tax_share: 2.5,
            tip_share: 7.5,
          }),
          makeShare("Bob", 40, {
            id: 2,
            subtotal: 30,
            tax_share: 2.5,
            tip_share: 7.5,
          }),
        ],
      }),
      makeBill({
        id: 2,
        name: "Lunch",
        subtotal: 40,
        tax: 3,
        tip_amount: 7,
        tip_percentage: 18,
        total: 50,
        date: "2025-01-02",
        person_shares: [
          makeShare("Alice", 30, {
            id: 3,
            subtotal: 25,
            tax_share: 2,
            tip_share: 3,
          }),
          makeShare("Bob", 20, {
            id: 4,
            subtotal: 15,
            tax_share: 1,
            tip_share: 4,
          }),
        ],
      }),
    ]);

    const result = computeTabPersonTotals(tab);
    expect(result).toHaveLength(2);
    expect(result[0].person_name).toBe("Alice");
    expect(result[0].total).toBe(90);
    expect(result[0].bill_count).toBe(2);
    expect(result[1].person_name).toBe("Bob");
    expect(result[1].total).toBe(60);
    expect(result[1].bill_count).toBe(2);
  });

  it("merges names case-insensitively", () => {
    const tab = makeTab([
      makeBill({
        id: 1,
        name: "Dinner",
        subtotal: 80,
        total: 80,
        person_shares: [
          makeShare("alice", 40),
          makeShare("Alice", 40, { id: 2 }),
        ],
      }),
    ]);

    const result = computeTabPersonTotals(tab);
    expect(result).toHaveLength(1);
    expect(result[0].person_name).toBe("Alice");
    expect(result[0].total).toBe(80);
    expect(result[0].bill_count).toBe(2);
  });

  it("sorts alphabetically by name", () => {
    const tab = makeTab([
      makeBill({
        id: 1,
        name: "Dinner",
        subtotal: 100,
        total: 100,
        person_shares: [
          makeShare("Charlie", 10),
          makeShare("Alice", 50, { id: 2 }),
          makeShare("Bob", 30, { id: 3 }),
        ],
      }),
    ]);

    const result = computeTabPersonTotals(tab);
    expect(result[0].person_name).toBe("Alice");
    expect(result[1].person_name).toBe("Bob");
    expect(result[2].person_name).toBe("Charlie");
  });

  it("returns empty array for tab with no bills", () => {
    const result = computeTabPersonTotals(makeTab([], "Empty"));
    expect(result).toEqual([]);
  });

  it("all_paid is true when all shares for a person are paid", () => {
    const tab = makeTab([
      makeBill({
        id: 1,
        name: "Dinner",
        subtotal: 50,
        total: 50,
        person_shares: [makeShare("Alice", 50, { paid: true })],
      }),
      makeBill({
        id: 2,
        name: "Lunch",
        subtotal: 50,
        total: 50,
        date: "2025-01-02",
        person_shares: [makeShare("Alice", 50, { paid: true })],
      }),
    ]);

    const result = computeTabPersonTotals(tab);
    expect(result[0].all_paid).toBe(true);
  });

  it("all_paid is false when any share for a person is unpaid", () => {
    const tab = makeTab([
      makeBill({
        id: 1,
        name: "Dinner",
        subtotal: 50,
        total: 50,
        person_shares: [makeShare("Alice", 50, { paid: true })],
      }),
      makeBill({
        id: 2,
        name: "Lunch",
        subtotal: 50,
        total: 50,
        date: "2025-01-02",
        person_shares: [makeShare("Alice", 50, { paid: false })],
      }),
    ]);

    const result = computeTabPersonTotals(tab);
    expect(result[0].all_paid).toBe(false);
  });

  it("all_paid is false when no shares are paid", () => {
    const tab = makeTab([
      makeBill({
        id: 1,
        name: "Dinner",
        subtotal: 50,
        total: 50,
        person_shares: [makeShare("Alice", 50)],
      }),
    ]);

    const result = computeTabPersonTotals(tab);
    expect(result[0].all_paid).toBe(false);
  });
});

// ── API fetch functions ─────────────────────────────────────────

describe("getBill", () => {
  it("throws on 403", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: false, status: 403 }),
    );

    await expect(getBill("1", "bad-token")).rejects.toThrow(
      "Invalid access token",
    );
  });

  it("throws on 404", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: false, status: 404 }),
    );

    await expect(getBill("999", "token")).rejects.toThrow("Bill not found");
  });

  it("returns data on success", async () => {
    const mockBill: Bill = {
      id: 1,
      name: "Dinner",
      subtotal: 100,
      tax: 8,
      tip_amount: 20,
      tip_percentage: 20,
      total: 128,
      date: "2025-01-01",
      payment_methods: [{ name: "Venmo", identifier: "@user" }],
      items: [],
      person_shares: [],
    };

    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve(mockBill),
      }),
    );

    const result = await getBill("1", "valid-token");
    expect(result).toEqual(mockBill);
  });
});

describe("getTab", () => {
  it("throws on 500", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: false, status: 500 }),
    );

    await expect(getTab("1", "token")).rejects.toThrow("Failed to fetch tab");
  });
});

describe("tab collections", () => {
  it.each([
    ["settlements", getSettlements, "/api/tabs/7/settlements"],
    ["members", getTabMembers, "/api/tabs/7/members"],
  ] as const)("loads %s with the access token", async (_name, get, path) => {
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve([{ id: 1 }]),
    });
    vi.stubGlobal("fetch", mockFetch);

    await expect(get("7", "token")).resolves.toEqual([{ id: 1 }]);
    expect(mockFetch).toHaveBeenCalledWith(expect.stringContaining(path), {
      headers: { Authorization: "Bearer token" },
    });
  });

  it.each([getSettlements, getTabMembers])(
    "keeps returning an empty list when the request fails",
    async (get) => {
      vi.stubGlobal(
        "fetch",
        vi.fn().mockResolvedValue({ ok: false, status: 500 }),
      );

      await expect(get("7", "token")).resolves.toEqual([]);
    },
  );
});

describe("updatePersonSharePaid", () => {
  it("sends PATCH with correct body", async () => {
    const mockFetch = vi.fn().mockResolvedValue({ ok: true });
    vi.stubGlobal("fetch", mockFetch);

    await updatePersonSharePaid(1, 5, true, "test-token");

    expect(mockFetch).toHaveBeenCalledWith(
      expect.stringContaining("/api/bills/1/shares/5"),
      expect.objectContaining({
        method: "PATCH",
        body: JSON.stringify({ paid: true }),
      }),
    );
  });

  it("throws on failure", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: false, status: 500 }),
    );

    await expect(updatePersonSharePaid(1, 5, true, "token")).rejects.toThrow();
  });
});

describe("updateSettlementPaid", () => {
  it("sends PATCH with correct body", async () => {
    const mockFetch = vi.fn().mockResolvedValue({ ok: true });
    vi.stubGlobal("fetch", mockFetch);

    await updateSettlementPaid("1", 3, false, "test-token");

    expect(mockFetch).toHaveBeenCalledWith(
      expect.stringContaining("/api/tabs/1/settlements/3"),
      expect.objectContaining({
        method: "PATCH",
        body: JSON.stringify({ paid: false }),
      }),
    );
  });

  it("throws on failure", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ ok: false, status: 500 }),
    );

    await expect(updateSettlementPaid("1", 3, true, "token")).rejects.toThrow();
  });
});

describe("updateTabPersonSharePaid", () => {
  it("sends the paid change with both tab and member credentials", async () => {
    const mockFetch = vi.fn().mockResolvedValue({ ok: true });
    vi.stubGlobal("fetch", mockFetch);

    await updateTabPersonSharePaid(
      "1",
      2,
      3,
      false,
      "tab-token",
      "member-token",
    );

    expect(mockFetch).toHaveBeenCalledWith(
      expect.stringContaining("/api/tabs/1/bills/2/shares/3/paid"),
      expect.objectContaining({
        method: "PATCH",
        headers: expect.objectContaining({
          Authorization: "Bearer tab-token",
          "X-Member-Token": "member-token",
        }),
        body: JSON.stringify({ paid: false }),
      }),
    );
  });
});

describe("updateTabBillItemAssignments", () => {
  it("sends PATCH with assignments payload", async () => {
    const mockFetch = vi.fn().mockResolvedValue({ ok: true });
    vi.stubGlobal("fetch", mockFetch);

    await updateTabBillItemAssignments(
      "1",
      2,
      3,
      [{ person_name: "Alice", percentage: 100 }],
      "tab-token",
    );

    expect(mockFetch).toHaveBeenCalledWith(
      expect.stringContaining("/api/tabs/1/bills/2/items/3/assignments"),
      expect.objectContaining({
        method: "PATCH",
        body: JSON.stringify({
          assignments: [{ person_name: "Alice", percentage: 100 }],
        }),
      }),
    );
  });

  it("includes the member token and keeps conflict handling", async () => {
    const mockFetch = vi.fn().mockResolvedValue({ ok: false, status: 409 });
    vi.stubGlobal("fetch", mockFetch);

    await expect(
      updateTabBillItemAssignments(
        "1",
        2,
        3,
        [{ person_name: "Alice", percentage: 100 }],
        "tab-token",
        "2026-10-10T17:30:54.055105Z",
        "member-token",
      ),
    ).rejects.toThrow("item changed; refresh and try again");
    expect(mockFetch.mock.calls[0][1]).toMatchObject({
      headers: expect.objectContaining({ "X-Member-Token": "member-token" }),
    });
  });
});

describe("updateTabBillItemAssignmentsBatch", () => {
  it("uses the authorized tab bill batch route", async () => {
    const mockFetch = vi.fn().mockResolvedValue({ ok: true });
    vi.stubGlobal("fetch", mockFetch);
    const updates = [
      {
        item_id: 159,
        expected_updated_at: "2026-10-10T17:30:54.055105Z",
        assignments: [
          { person_name: "Alex", percentage: 65 },
          { person_name: "Sam", percentage: 35 },
        ],
      },
    ];

    await updateTabBillItemAssignmentsBatch(
      "19",
      27,
      updates,
      "tab-token",
      "member-token",
    );
    expect(mockFetch).toHaveBeenCalledWith(
      expect.stringContaining("/api/tabs/19/bills/27/assignments"),
      expect.objectContaining({
        method: "PATCH",
        headers: expect.objectContaining({
          Authorization: "Bearer tab-token",
          "X-Member-Token": "member-token",
        }),
        body: JSON.stringify({ updates }),
      }),
    );
  });

  it("treats a removed item as a stale selection", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ status: 404, ok: false }),
    );
    await expect(
      updateTabBillItemAssignmentsBatch("19", 27, [], "tab-token"),
    ).rejects.toThrow("item changed; refresh and try again");
  });
});

describe("updateLazyBillItemAssignments", () => {
  it("writes claims to the standalone bill route with its share token", async () => {
    const mockFetch = vi.fn().mockResolvedValue({ ok: true });
    vi.stubGlobal("fetch", mockFetch);

    await updateLazyBillItemAssignments(
      27,
      159,
      [{ person_name: "Alex", percentage: 100 }],
      "bill-token",
      "2026-10-10T17:30:54.055105Z",
    );

    expect(mockFetch).toHaveBeenCalledWith(
      expect.stringContaining("/api/bills/27/items/159/assignments"),
      expect.objectContaining({
        method: "PATCH",
        headers: expect.objectContaining({
          Authorization: "Bearer bill-token",
        }),
        body: JSON.stringify({
          assignments: [{ person_name: "Alex", percentage: 100 }],
          expected_updated_at: "2026-10-10T17:30:54.055105Z",
        }),
      }),
    );
  });
});

describe("updateLazyBillItemAssignmentsBatch", () => {
  it("saves all changed items in one request and returns the updated bill", async () => {
    const bill = makeBill({ id: 27 });
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => bill,
    });
    vi.stubGlobal("fetch", mockFetch);
    const updates = [
      {
        item_id: 159,
        expected_updated_at: "2026-10-10T17:30:54.055105Z",
        assignments: [{ person_name: "Alex", percentage: 100 }],
      },
      {
        item_id: 160,
        expected_updated_at: "2026-10-10T17:30:54.055105Z",
        assignments: [],
      },
    ];

    await expect(
      updateLazyBillItemAssignmentsBatch(27, updates, "bill-token"),
    ).resolves.toEqual(bill);
    expect(mockFetch).toHaveBeenCalledWith(
      expect.stringContaining("/api/bills/27/assignments"),
      expect.objectContaining({
        method: "PATCH",
        headers: expect.objectContaining({
          Authorization: "Bearer bill-token",
        }),
        body: JSON.stringify({ updates }),
      }),
    );
  });

  it("treats a removed item as a stale selection", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ status: 404, ok: false }),
    );
    await expect(
      updateLazyBillItemAssignmentsBatch(27, [], "bill-token"),
    ).rejects.toThrow("item changed; refresh and try again");
  });
});

describe("joinTab", () => {
  it("persists a display name and returns the member capability", async () => {
    const member = { display_name: "Alex", member_token: "member-token" };
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => member,
    });
    vi.stubGlobal("fetch", mockFetch);

    await expect(joinTab("19", "trip-token", "Alex")).resolves.toEqual(member);
    expect(mockFetch).toHaveBeenCalledWith(
      expect.stringContaining("/api/tabs/19/join"),
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({
          Authorization: "Bearer trip-token",
        }),
        body: JSON.stringify({ display_name: "Alex" }),
      }),
    );
  });
});
