import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import type { Bill } from "@/lib/api";
import { buildPaymentDetails, ReceiptSummary } from "./LazyBillBoard";

function bill(overrides: Partial<Bill> = {}): Bill {
  return {
    id: 1,
    name: "Paris dinner",
    subtotal: 90,
    tax: 10,
    tip_amount: 0,
    tip_percentage: 0,
    total: 100,
    date: "2026-08-29",
    payment_methods: [],
    items: [{ id: 1, name: "Steak frites", price: 90 }],
    person_shares: [],
    ...overrides,
  };
}

describe("shared receipt currency summary", () => {
  it("uses the reconciled cent for both Pay and the Venmo URL", () => {
    const share = 0.8 / 3;
    const receipt = bill({
      name: "Tiny dinner",
      total: 0.8,
      subtotal: 0.8,
      currency_code: "EUR",
      usd_exchange_rate: 1.25,
      usd_total: 1,
      payment_methods: [{ name: "Venmo", identifier: "@alice" }],
      person_shares: ["Alice", "Bob", "Cara"].map((person_name, index) => ({
        id: index + 1,
        person_name,
        items: [],
        subtotal: share,
        tax_share: 0,
        tip_share: 0,
        total: share,
        paid: false,
      })),
    });

    const payment = buildPaymentDetails(receipt, "Alice", share);
    expect(payment.usdTotal).toBe(0.34);
    expect(payment.venmoUrl).toContain("amount=0.34");
    expect(payment.venmoUrl).toContain("recipients=alice");
  });

  it("shows original EUR values with the frozen USD conversion audit", () => {
    const markup = renderToStaticMarkup(
      <ReceiptSummary
        bill={bill({
          currency_code: "EUR",
          usd_exchange_rate: 1.085,
          usd_total: 108.5,
          exchange_rate_date: "2026-08-29",
          exchange_rate_source: "frankfurter-v2",
        })}
      />,
    );

    expect(markup).toContain("EUR");
    expect(markup).toContain("Steak frites");
    expect(markup).toContain("Recorded in USD");
    expect(markup).toContain("$108.50 USD");
    expect(markup).toContain("2026-08-29");
    expect(markup).toContain("frankfurter-v2");
  });

  it("renders legacy receipts as native USD without a conversion banner", () => {
    const markup = renderToStaticMarkup(<ReceiptSummary bill={bill()} />);

    expect(markup).toContain("$100.00 USD");
    expect(markup).not.toContain("Recorded in USD");
  });
});
