import { describe, expect, it } from "vitest";
import type { Bill } from "./api";
import {
  billCurrencyCode,
  billUSDTotal,
  formatOriginalMoney,
  formatUSDExchangeRate,
  formatUSDMoney,
  toUSD,
} from "./currency";

function bill(overrides: Partial<Bill> = {}): Bill {
  return {
    id: 1,
    name: "Receipt",
    subtotal: 100,
    tax: 0,
    tip_amount: 0,
    tip_percentage: 0,
    total: 100,
    date: "2026-08-29",
    payment_methods: [],
    items: [],
    person_shares: [],
    ...overrides,
  };
}

describe("bill currency display", () => {
  it("shows the original EUR amount and its frozen USD value", () => {
    const eurBill = bill({
      currency_code: "EUR",
      usd_exchange_rate: 1.085,
      usd_total: 108.5,
    });

    expect(formatOriginalMoney(eurBill.total, eurBill)).toBe("EUR 100.00");
    expect(formatUSDMoney(billUSDTotal(eurBill))).toBe("$108.50 USD");
    expect(toUSD(25, eurBill)).toBe(27.13);
  });

  it("treats legacy bills without currency fields as USD", () => {
    const legacyBill = bill();

    expect(billCurrencyCode(legacyBill)).toBe("USD");
    expect(formatOriginalMoney(legacyBill.total, legacyBill)).toBe(
      "$100.00 USD",
    );
    expect(billUSDTotal(legacyBill)).toBe(100);
  });

  it("uses the frozen JPY rate for another non-USD currency", () => {
    const jpyBill = bill({
      total: 1000,
      currency_code: "JPY",
      usd_exchange_rate: 0.0068,
      usd_total: 6.8,
    });

    expect(formatOriginalMoney(jpyBill.total, jpyBill)).toBe("JPY 1,000");
    expect(billUSDTotal(jpyBill)).toBe(6.8);
    expect(formatUSDExchangeRate(0.00627)).toBe("$0.00627 USD");
  });
});
