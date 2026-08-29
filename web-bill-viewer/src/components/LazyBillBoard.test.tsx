import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import type { Bill } from "@/lib/api";
import { ReceiptSummary } from "./LazyBillBoard";

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
