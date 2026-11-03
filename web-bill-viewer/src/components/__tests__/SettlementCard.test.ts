import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import SettlementCard from "../SettlementCard";

const settlements = [
  {
    id: 1,
    tab_id: 9,
    person_name: "Alex",
    amount: 12.34,
    paid: false,
    created_at: "2026-11-03T00:00:00Z",
  },
  {
    id: 2,
    tab_id: 9,
    person_name: "Zoë",
    amount: 5.6,
    paid: true,
    created_at: "2026-11-03T00:00:00Z",
  },
];
const render = (venmoId?: string) =>
  renderToStaticMarkup(
    createElement(SettlementCard, {
      settlements,
      venmoId,
    }),
  );

describe("maintained read-only settlements", () => {
  it("shows names, amounts and the paid count", () => {
    const html = render();
    for (const text of ["Alex", "Zoë", "$12.34", "$5.60", "1/2 paid"]) {
      expect(html).toContain(text);
    }
  });
  it("shows each status and directs status updates to Billington", () => {
    const html = render();
    expect(html).toContain('title="Alex is unpaid"');
    expect(html).toContain('title="Zoë is paid"');
    expect(html).toContain("Open Billington to update payment status");
    expect(html).not.toContain("Mark Alex");
    expect(html).not.toContain("Mark Zoë");
    expect(html).not.toContain("Tap an avatar");
  });
  it("keeps the amount, recipient and note in the labeled Venmo handoff", () => {
    const html = render("@synthetic");
    expect(html).toContain(
      'aria-label="Pay Alex&#x27;s settlement with Venmo"',
    );
    expect(html).toContain(
      'href="venmo://paycharge?txn=pay&amp;recipients=synthetic&amp;amount=12.34&amp;note=Tab%20settlement%20-%20Alex"',
    );
  });
  it("offers external payment only for unpaid rows with a configured recipient", () => {
    expect(render()).not.toContain("<button");
    expect(render("@synthetic").match(/<a /g)).toHaveLength(1);
    expect(render("@synthetic")).not.toContain("<button");
  });
});
