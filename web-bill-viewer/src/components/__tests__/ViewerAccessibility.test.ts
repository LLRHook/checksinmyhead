import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { useCollapsible } from "@/hooks/useCollapsible";
import type { Bill } from "@/lib/api";
import BillHeader from "../BillHeader";
import BillPageClient from "../BillPageClient";
import CollapsibleSection from "../CollapsibleSection";
import PaymentDetails from "../PaymentDetails";
import PersonShare from "../PersonShare";
import { RecordedShareRows } from "../RecordedShares";
import SettlementCard from "../SettlementCard";
import TabBillList from "../TabBillList";
import TabHeader from "../TabHeader";
import TabPersonTotals from "../TabPersonTotals";
import { blend, contrast, dark, rgb, root, token } from "./viewer-contrast";

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
          ? { status: "success", bill }
          : initial,
      ),
  };
});

vi.mock("@/hooks/useCollapsible", () => ({ useCollapsible: vi.fn() }));
beforeEach(() => {
  vi.mocked(useCollapsible).mockImplementation((open = false) => ({
    isOpen: open,
    toggle: vi.fn(),
    contentRef: { current: null },
    height: open ? "auto" : "0px",
  }));
});
const bill: Bill = {
  id: 7,
  name: "Dinner",
  currency_code: "USD",
  subtotal: 10,
  tax: 0,
  tip_amount: 0,
  tip_percentage: 0,
  total: 10,
  date: "2026-11-10",
  items: [],
  payment_methods: [{ name: "Venmo", identifier: "synthetic" }],
  person_shares: [
    {
      id: 81,
      person_name: "Old name",
      label: "Alex",
      subtotal: 10,
      tax_share: 0,
      tip_share: 0,
      total: 10,
      items: [],
      paid: false,
    },
  ],
};
const share = (label: string) =>
  createElement(PersonShare, {
    bill,
    billId: bill.id,
    token: "synthetic",
    personShare: { ...bill.person_shares[0], label },
    readOnly: true,
  });

const levels = (html: string) =>
  [...html.matchAll(/<h([1-6])\b/g)].map((m) => Number(m[1]));
const sequential = (headings: number[]) => {
  expect(headings[0]).toBe(1);
  for (let i = 1; i < headings.length; i++) {
    expect(headings[i]).toBeLessThanOrEqual(headings[i - 1] + 1);
  }
};

describe("private viewer accessibility", () => {
  it("names each share expansion for its visible owner and reflects both expanded states", () => {
    for (const open of [false, true]) {
      vi.mocked(useCollapsible).mockReturnValue({
        isOpen: open,
        toggle: vi.fn(),
        contentRef: { current: null },
        height: open ? "auto" : "0px",
      });
      for (const [label, visible] of [
        ["Alex", "Alex"],
        ["", "Unnamed"],
      ]) {
        const html = renderToStaticMarkup(share(label));
        const button = html.match(/<button[^>]*aria-expanded[^>]*>/)?.[0];
        expect(button).toContain(`aria-label="Share details for ${visible}"`);
        expect(button).toContain(`aria-expanded="${open}"`);
        expect(html).toContain("$10.00");
        expect(html.match(/<button/g)).toHaveLength(1);
      }
    }
  });

  it("keeps the other expansion controls named by their section or bill", () => {
    const sectionProps = {
      title: "Bill breakdown",
      icon: null,
      children: "Subtotal",
      defaultOpen: true,
    };
    const section = renderToStaticMarkup(
      createElement(CollapsibleSection, sectionProps),
    );
    expect(section).toMatch(/<button[^>]*aria-expanded="true"/);
    expect(section).toContain("Bill breakdown");
    const bills = renderToStaticMarkup(
      createElement(TabBillList, { bills: [bill], tabToken: "synthetic" }),
    );
    expect(bills).toMatch(/<button[^>]*aria-expanded="false"/);
    expect(bills).toContain("Dinner</h3>");
    expect(bills).toContain("Open bill");
  });

  it("keeps private bill and tab payment headings sequential without changing typography", () => {
    const payments = renderToStaticMarkup(
      createElement(PaymentDetails, { paymentMethods: bill.payment_methods }),
    );
    expect(payments).toContain(
      '<h2 class="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)] mb-3 px-1">',
    );
    for (const header of [
      createElement(BillHeader, { name: bill.name, total: bill.total }),
      createElement(TabHeader, {
        name: "Trip",
        description: "",
        total: 10,
        billCount: 1,
        finalized: false,
      }),
    ])
      sequential(levels(renderToStaticMarkup(header) + payments));
  });

  it("gives recorded share rows a section heading even before receipt controls render", () => {
    const rows = renderToStaticMarkup(
      createElement(RecordedShareRows, { bill, onChanged: async () => {} }),
    );
    expect(rows).toContain('<h2 class="sr-only">Recorded receipt shares</h2>');
    sequential(
      levels(
        renderToStaticMarkup(
          createElement(BillHeader, { name: bill.name, total: bill.total }),
        ) + rows,
      ),
    );
  });
});

// An unprefixed opacity class or an inline opacity or filter dims its subtree.
const dimmed = /(?:^|[\s"])opacity-\d+|style="[^"]*(?:opacity|filter)/;

describe("secondary text contrast from theme tokens", () => {
  it.each(["light", "dark"])(
    "%s secondary text meets AA on page cards badges hover and paid surfaces",
    (theme) => {
      const ink = token("text-secondary", theme === "dark" ? dark : root);
      const card = token(theme === "dark" ? "card-bg-dark" : "card-bg-light");
      const page = token(theme === "dark" ? "dark-bg" : "secondary");
      const surfaces = [
        page,
        card,
        theme === "dark" ? blend(rgb("#ffffff"), card, 0.1) : page,
        theme === "dark" ? blend(rgb("#ffffff"), page, 0.1) : page,
        blend(rgb(theme === "dark" ? "#ffffff" : "#000000"), card, 0.05),
      ];
      for (const surface of surfaces)
        expect(contrast(ink, surface)).toBeGreaterThanOrEqual(4.5);
    },
  );

  it("renders the bill and settlement instructions at the secondary token opacity", () => {
    const billHTML = renderToStaticMarkup(
      createElement(BillPageClient, { id: "7", token: "synthetic" }),
    );
    const settlementsHTML = renderToStaticMarkup(
      createElement(SettlementCard, { settlements: [] }),
    );
    for (const [html, instruction] of [
      [billHTML, "Recorded paid flags are manual status;"],
      [settlementsHTML, "Open Billington to update payment status"],
    ]) {
      const paragraph = [...html.matchAll(/<p([^>]*)>([^<]*)<\/p>/g)].find(
        (match) => match[2].startsWith(instruction),
      );
      expect(paragraph).toBeDefined();
      // Assert the rendered element's complete attributes: opacity/filter classes
      // and inline styles must not silently dim this status instruction.
      expect(paragraph?.[1].trim()).toBe(
        'class="text-xs text-[var(--text-secondary)] mt-0.5"',
      );
      // Nor may an element around it: opacity applies to everything inside.
      const open: string[] = [];
      for (const [, closing, attributes] of html
        .slice(0, paragraph?.index)
        .matchAll(/<(\/?)[a-z][a-z0-9]*([^>]*)>/g)) {
        if (closing) open.pop();
        else if (!attributes.endsWith("/")) open.push(attributes);
      }
      for (const attributes of open) expect(attributes).not.toMatch(dimmed);
    }
  });
  it("keeps paid share settlement and total cards opaque while retaining paid markers", () => {
    const paidShare = { ...bill.person_shares[0], paid: true };
    const html = [
      renderToStaticMarkup(
        createElement(PersonShare, {
          bill,
          billId: 7,
          token: "synthetic",
          personShare: paidShare,
          readOnly: true,
        }),
      ),
      renderToStaticMarkup(
        createElement(SettlementCard, {
          settlements: [
            {
              id: 1,
              tab_id: 9,
              person_name: "Alex",
              amount: 10,
              paid: true,
              created_at: "2026-11-10",
            },
          ],
        }),
      ),
      renderToStaticMarkup(
        createElement(TabPersonTotals, {
          personTotals: [
            { person_name: "Alex", total: 10, bill_count: 1, all_paid: true },
          ],
        }),
      ),
    ];
    for (const card of html) {
      expect(card).not.toMatch(dimmed);
      expect(card).toContain("line-through");
      expect(card).toContain("text-emerald-600");
      expect(card).toContain("dark:border-emerald-800/50");
    }
  });
});
