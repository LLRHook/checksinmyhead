import { describe, it, expect, vi, beforeEach } from "vitest";
import { computeTabPersonTotals, getBill, getTab, updatePersonSharePaid, updateSettlementPaid } from "../api";
import type { Tab, Bill } from "../api";

// ── computeTabPersonTotals ──────────────────────────────────────

describe("computeTabPersonTotals", () => {
  it("aggregates across multiple bills", () => {
    const tab: Tab = {
      id: 1,
      name: "Trip",
      description: "",
      total_amount: 150,
      finalized: false,
      finalized_at: null,
      created_at: "2025-01-01",
      bills: [
        {
          id: 1,
          name: "Dinner",
          subtotal: 80,
          tax: 5,
          tip_amount: 15,
          tip_percentage: 20,
          total: 100,
          date: "2025-01-01",
          payment_methods: [],
          items: [],
          person_shares: [
            { id: 1, person_name: "Alice", items: [], subtotal: 40, tax_share: 2.5, tip_share: 7.5, total: 60, paid: false },
            { id: 2, person_name: "Bob", items: [], subtotal: 30, tax_share: 2.5, tip_share: 7.5, total: 40, paid: false },
          ],
        },
        {
          id: 2,
          name: "Lunch",
          subtotal: 40,
          tax: 3,
          tip_amount: 7,
          tip_percentage: 18,
          total: 50,
          date: "2025-01-02",
          payment_methods: [],
          items: [],
          person_shares: [
            { id: 3, person_name: "Alice", items: [], subtotal: 25, tax_share: 2, tip_share: 3, total: 30, paid: false },
            { id: 4, person_name: "Bob", items: [], subtotal: 15, tax_share: 1, tip_share: 4, total: 20, paid: false },
          ],
        },
      ],
    };

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
    const tab: Tab = {
      id: 1,
      name: "Trip",
      description: "",
      total_amount: 100,
      finalized: false,
      finalized_at: null,
      created_at: "2025-01-01",
      bills: [
        {
          id: 1,
          name: "Dinner",
          subtotal: 80,
          tax: 0,
          tip_amount: 0,
          tip_percentage: 0,
          total: 80,
          date: "2025-01-01",
          payment_methods: [],
          items: [],
          person_shares: [
            { id: 1, person_name: "alice", items: [], subtotal: 40, tax_share: 0, tip_share: 0, total: 40, paid: false },
            { id: 2, person_name: "Alice", items: [], subtotal: 40, tax_share: 0, tip_share: 0, total: 40, paid: false },
          ],
        },
      ],
    };

    const result = computeTabPersonTotals(tab);
    expect(result).toHaveLength(1);
    expect(result[0].person_name).toBe("Alice");
    expect(result[0].total).toBe(80);
    expect(result[0].bill_count).toBe(2);
  });

  it("sorts alphabetically by name", () => {
    const tab: Tab = {
      id: 1,
      name: "Trip",
      description: "",
      total_amount: 100,
      finalized: false,
      finalized_at: null,
      created_at: "2025-01-01",
      bills: [
        {
          id: 1,
          name: "Dinner",
          subtotal: 100,
          tax: 0,
          tip_amount: 0,
          tip_percentage: 0,
          total: 100,
          date: "2025-01-01",
          payment_methods: [],
          items: [],
          person_shares: [
            { id: 1, person_name: "Charlie", items: [], subtotal: 10, tax_share: 0, tip_share: 0, total: 10, paid: false },
            { id: 2, person_name: "Alice", items: [], subtotal: 50, tax_share: 0, tip_share: 0, total: 50, paid: false },
            { id: 3, person_name: "Bob", items: [], subtotal: 30, tax_share: 0, tip_share: 0, total: 30, paid: false },
          ],
        },
      ],
    };

    const result = computeTabPersonTotals(tab);
    expect(result[0].person_name).toBe("Alice");
    expect(result[1].person_name).toBe("Bob");
    expect(result[2].person_name).toBe("Charlie");
  });

  it("returns empty array for tab with no bills", () => {
    const tab: Tab = {
      id: 1,
      name: "Empty",
      description: "",
      total_amount: 0,
      finalized: false,
      finalized_at: null,
      created_at: "2025-01-01",
      bills: [],
    };

    const result = computeTabPersonTotals(tab);
    expect(result).toEqual([]);
  });

  it("all_paid is true when all shares for a person are paid", () => {
    const tab: Tab = {
      id: 1, name: "Trip", description: "", total_amount: 100,
      finalized: false, finalized_at: null, created_at: "2025-01-01",
      bills: [
        {
          id: 1, name: "Dinner", subtotal: 50, tax: 0, tip_amount: 0,
          tip_percentage: 0, total: 50, date: "2025-01-01",
          payment_methods: [], items: [],
          person_shares: [
            { id: 1, person_name: "Alice", items: [], subtotal: 50, tax_share: 0, tip_share: 0, total: 50, paid: true },
          ],
        },
        {
          id: 2, name: "Lunch", subtotal: 50, tax: 0, tip_amount: 0,
          tip_percentage: 0, total: 50, date: "2025-01-02",
          payment_methods: [], items: [],
          person_shares: [
            { id: 2, person_name: "Alice", items: [], subtotal: 50, tax_share: 0, tip_share: 0, total: 50, paid: true },
          ],
        },
      ],
    };

    const result = computeTabPersonTotals(tab);
    expect(result[0].all_paid).toBe(true);
  });

  it("all_paid is false when any share for a person is unpaid", () => {
    const tab: Tab = {
      id: 1, name: "Trip", description: "", total_amount: 100,
      finalized: false, finalized_at: null, created_at: "2025-01-01",
      bills: [
        {
          id: 1, name: "Dinner", subtotal: 50, tax: 0, tip_amount: 0,
          tip_percentage: 0, total: 50, date: "2025-01-01",
          payment_methods: [], items: [],
          person_shares: [
            { id: 1, person_name: "Alice", items: [], subtotal: 50, tax_share: 0, tip_share: 0, total: 50, paid: true },
          ],
        },
        {
          id: 2, name: "Lunch", subtotal: 50, tax: 0, tip_amount: 0,
          tip_percentage: 0, total: 50, date: "2025-01-02",
          payment_methods: [], items: [],
          person_shares: [
            { id: 2, person_name: "Alice", items: [], subtotal: 50, tax_share: 0, tip_share: 0, total: 50, paid: false },
          ],
        },
      ],
    };

    const result = computeTabPersonTotals(tab);
    expect(result[0].all_paid).toBe(false);
  });

  it("all_paid is false when no shares are paid", () => {
    const tab: Tab = {
      id: 1, name: "Trip", description: "", total_amount: 50,
      finalized: false, finalized_at: null, created_at: "2025-01-01",
      bills: [
        {
          id: 1, name: "Dinner", subtotal: 50, tax: 0, tip_amount: 0,
          tip_percentage: 0, total: 50, date: "2025-01-01",
          payment_methods: [], items: [],
          person_shares: [
            { id: 1, person_name: "Alice", items: [], subtotal: 50, tax_share: 0, tip_share: 0, total: 50, paid: false },
          ],
        },
      ],
    };

    const result = computeTabPersonTotals(tab);
    expect(result[0].all_paid).toBe(false);
  });
});

// ── API fetch functions ─────────────────────────────────────────

describe("getBill", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it("throws on 403", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 403 }));

    await expect(getBill("1", "bad-token")).rejects.toThrow("Invalid access token");
  });

  it("throws on 404", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 404 }));

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
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it("throws on 500", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 500 }));

    await expect(getTab("1", "token")).rejects.toThrow("Failed to fetch tab");
  });
});

describe("updatePersonSharePaid", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

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
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 500 }));

    await expect(updatePersonSharePaid(1, 5, true, "token")).rejects.toThrow();
  });
});

describe("updateSettlementPaid", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

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
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ ok: false, status: 500 }));

    await expect(updateSettlementPaid("1", 3, true, "token")).rejects.toThrow();
  });
});
