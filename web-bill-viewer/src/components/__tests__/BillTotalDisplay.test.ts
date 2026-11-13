import { readFileSync } from "node:fs";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import type { Bill } from "@/lib/api";
import { formatMoney } from "@/lib/currency";
import { lazyBillRemainingTotal } from "@/lib/lazy-bill";
import BillPageClient from "../BillPageClient";
import TabBillList from "../TabBillList";

let currentBill: Bill;
vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh: vi.fn() }) }));
vi.mock("react", async (actual) => {
  const react = await actual<typeof import("react")>();
  return {
    ...react,
    useState: (initial: unknown) =>
      react.useState(
        initial &&
          typeof initial === "object" &&
          "status" in initial &&
          initial.status === "loading"
          ? { status: "success", bill: currentBill }
          : initial,
      ),
  };
});

const cases = JSON.parse(
  readFileSync(
    new URL("../../../../testdata/bill_display_totals.json", import.meta.url),
    "utf8",
  ),
) as {
  case: string;
  total: number;
  shares: number[];
  expected: number;
  currency: string;
}[];

describe("cent-exact bill display", () => {
  for (const row of cases) {
    it(`tab bill total ${row.case}`, () => {
      const bill: Bill = {
        id: 66,
        name: "Synthetic",
        total: row.total,
        subtotal: row.total,
        tax: 0,
        tip_amount: 0,
        tip_percentage: 0,
        currency_code: row.currency,
        date: "2026-11-10",
        payment_methods: [],
        items: [],
        person_shares: row.shares.map((total, id) => ({
          id,
          total,
          person_name: `Person ${id}`,
          subtotal: total,
          tax_share: 0,
          tip_share: 0,
          items: [],
          paid: false,
        })),
      };
      const before = JSON.stringify(bill);
      const markup = renderToStaticMarkup(
        createElement(TabBillList, { bills: [bill], tabToken: "synthetic" }),
      );
      const displayedTotal = markup.match(
        /<span class="text-lg font-bold font-mono[^"]*">([^<]*)<\/span>/,
      )?.[1];
      expect(displayedTotal).toBe(formatMoney(row.expected, row.currency));
      expect(JSON.stringify(bill)).toBe(before);
      currentBill = bill;
      const page = renderToStaticMarkup(
        createElement(BillPageClient, { id: "66", token: "synthetic" }),
      );
      const headerTotal = page.match(
        /<span class="text-xl font-bold font-mono[^"]*">([^<]*)<\/span>/,
      )?.[1];
      expect(headerTotal).toBe(formatMoney(row.expected, row.currency));
      expect(JSON.stringify(bill)).toBe(before);
    });
  }
  it("lazy remaining uses canonical cents without hiding accounting disagreements", () => {
    const bill = {
      total: 2.675,
      person_shares: [
        { total: 1.34, paid: false },
        { total: 1.34, paid: true },
      ],
    };
    expect(lazyBillRemainingTotal(bill)).toBe(1.34);
    expect(lazyBillRemainingTotal({ ...bill, exchange_rate: 145.357 })).toBe(
      194.05,
    );
    expect(
      lazyBillRemainingTotal({
        ...bill,
        person_shares: bill.person_shares.map((share) => ({
          ...share,
          paid: true,
        })),
      }),
    ).toBe(0);
    expect(
      lazyBillRemainingTotal({
        total: 1.005,
        person_shares: [{ total: 1.01, paid: false }],
      }),
    ).toBe(1.01);
  });
  it("partly paid lazy balance agrees with the remaining shares", () => {
    expect(
      lazyBillRemainingTotal({
        total: 0.38499999999999995,
        person_shares: [
          { total: 0.11, paid: true },
          { total: 0.27, paid: false },
        ],
      }),
    ).toBe(0.27);
  });
  it("unclaimed lazy balance keeps its value before and after a claim", () => {
    // Receipt 0.34 + 0.58 tax + 25% tip; server full-claim share is 1.01.
    expect(lazyBillRemainingTotal({ total: 1.005, person_shares: [] })).toBe(
      1.01,
    );
    expect(
      lazyBillRemainingTotal({
        total: 1.005,
        person_shares: [{ total: 1.01, paid: false }],
      }),
    ).toBe(1.01);
    expect(
      lazyBillRemainingTotal({
        total: 1.005,
        person_shares: [{ total: 1.01, paid: true }],
      }),
    ).toBe(0);
  });
});
