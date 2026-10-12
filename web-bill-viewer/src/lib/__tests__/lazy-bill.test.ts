import { describe, expect, it } from "vitest";
import {
  isLazyItemPaid,
  isLazyItemSelectionLocked,
  lazyBillRemainingCurrency,
  lazyBillRemainingTotal,
} from "../lazy-bill";

describe("lazyBillRemainingTotal", () => {
  it("subtracts paid shares while keeping unclaimed amounts due", () => {
    expect(
      lazyBillRemainingTotal({
        total: 54.18,
        person_shares: [
          { total: 12.34, paid: true },
          { total: 20.0, paid: false },
        ],
      }),
    ).toBe(41.84);
  });

  it("converts the remaining amount to the selected display currency", () => {
    expect(
      lazyBillRemainingTotal({
        total: 50,
        exchange_rate: 1.25,
        person_shares: [{ total: 10, paid: true }],
      }),
    ).toBe(50);
  });

  it("never shows a negative remaining balance", () => {
    expect(
      lazyBillRemainingTotal({
        total: 20,
        person_shares: [{ total: 25, paid: true }],
      }),
    ).toBe(0);
  });
});

describe("lazyBillRemainingCurrency", () => {
  it("uses the currency that the remaining total was converted into", () => {
    expect(
      lazyBillRemainingCurrency({
        total: 50,
        display_total: 46,
        currency_code: "USD",
        display_currency: "EUR",
        person_shares: [],
      }),
    ).toBe("EUR");
  });
});

describe("isLazyItemPaid", () => {
  it("marks an item paid when its assigned share is paid", () => {
    expect(
      isLazyItemPaid(
        [{ person_name: "Alex", percentage: 100 }],
        [{ person_name: "alex", paid: true }],
      ),
    ).toBe(true);
  });

  it("keeps unclaimed and partly paid split items unpaid", () => {
    const shares = [
      { person_name: "Alex", paid: true },
      { person_name: "Sam", paid: false },
    ];
    expect(isLazyItemPaid([], shares)).toBe(false);
    expect(
      isLazyItemPaid(
        [
          { person_name: "Alex", percentage: 50 },
          { person_name: "Sam", percentage: 50 },
        ],
        shares,
      ),
    ).toBe(false);
  });
});

describe("isLazyItemSelectionLocked", () => {
  it("locks unclaimed items after the current share is paid", () => {
    expect(isLazyItemSelectionLocked(false, true)).toBe(true);
  });
});
