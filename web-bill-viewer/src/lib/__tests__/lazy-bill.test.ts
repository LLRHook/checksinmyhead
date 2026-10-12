import { describe, expect, it } from "vitest";
import { isLazyItemPaid } from "../lazy-bill";

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
