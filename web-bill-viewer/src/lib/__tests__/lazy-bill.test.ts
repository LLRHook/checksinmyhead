import { describe, expect, it } from "vitest";
import {
  createLazySplitAssignments,
  hasPaidLazyAssignment,
  isLazyItemPaid,
  isLazyItemSelectionLocked,
  lazyAssignmentsEqual,
  lazyBillRemainingCurrency,
  lazyBillRemainingTotal,
  removeLazyAssignment,
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

describe("hasPaidLazyAssignment", () => {
  it("locks a split item as soon as any assigned person has paid", () => {
    expect(
      hasPaidLazyAssignment(
        [
          { person_name: "Alex", percentage: 40 },
          { person_name: "Sam", percentage: 60 },
        ],
        [
          { person_name: "Alex", paid: true },
          { person_name: "Sam", paid: false },
        ],
      ),
    ).toBe(true);
  });
});

describe("isLazyItemSelectionLocked", () => {
  it("locks unclaimed items after the current share is paid", () => {
    expect(isLazyItemSelectionLocked(false, true)).toBe(true);
  });
});

describe("lazy split assignment drafts", () => {
  it("assigns the chosen viewer percentage and splits the remainder evenly", () => {
    expect(createLazySplitAssignments("Me", "Alex, Sam", 70)).toEqual([
      { person_name: "Me", percentage: 70 },
      { person_name: "Alex", percentage: 15 },
      { person_name: "Sam", percentage: 15 },
    ]);
  });

  it("removes duplicate and self names and requires someone to share with", () => {
    expect(createLazySplitAssignments("Me", "Me, Alex, alex", 25)).toEqual([
      { person_name: "Me", percentage: 25 },
      { person_name: "Alex", percentage: 75 },
    ]);
    expect(createLazySplitAssignments("Me", "Me", 50)).toBeNull();
  });

  it("compares shares without depending on participant ordering", () => {
    expect(
      lazyAssignmentsEqual(
        [
          { person_name: "Alex", percentage: 40 },
          { person_name: "Sam", percentage: 60 },
        ],
        [
          { person_name: "Sam", percentage: 60 },
          { person_name: "Alex", percentage: 40 },
        ],
      ),
    ).toBe(true);
  });

  it("redistributes a shared item to the remaining people when one opts out", () => {
    const remaining = removeLazyAssignment(
      [
        { person_name: "Alex", percentage: 35 },
        { person_name: "Sam", percentage: 25 },
        { person_name: "Jordan", percentage: 40 },
      ],
      "Alex",
    );
    expect(remaining[0].person_name).toBe("Sam");
    expect(remaining[0].percentage).toBeCloseTo(38.4615, 3);
    expect(remaining[1].person_name).toBe("Jordan");
    expect(remaining[1].percentage).toBeCloseTo(61.5385, 3);
  });

  it("clears the item when its only participant opts out", () => {
    expect(
      removeLazyAssignment([{ person_name: "Alex", percentage: 100 }], "alex"),
    ).toEqual([]);
  });
});
