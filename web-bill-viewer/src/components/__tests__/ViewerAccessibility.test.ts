import { readFileSync } from "node:fs";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { useCollapsible } from "@/hooks/useCollapsible";
import type { Bill } from "@/lib/api";
import BillHeader from "../BillHeader";
import CollapsibleSection from "../CollapsibleSection";
import PaymentDetails from "../PaymentDetails";
import PersonShare from "../PersonShare";
import { RecordedShareRows } from "../RecordedShares";
import TabBillList from "../TabBillList";
import TabHeader from "../TabHeader";

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

type RGB = number[];
const rgb = (hex: string): RGB =>
  [1, 3, 5].map((i) => Number.parseInt(hex.slice(i, i + 2), 16));
const blend = (ink: RGB, surface: RGB, opacity: number) =>
  ink.map((v, i) => v * opacity + surface[i] * (1 - opacity));
const luminance = (color: RGB) =>
  color.reduce((sum, v, i) => {
    const s = v / 255;
    return (
      sum +
      [0.2126, 0.7152, 0.0722][i] *
        (s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4)
    );
  }, 0);
const contrast = (ink: RGB, surface: RGB) => {
  const [lo, hi] = [luminance(ink), luminance(surface)].sort((a, b) => a - b);
  return (hi + 0.05) / (lo + 0.05);
};
const css = readFileSync("src/app/globals.css", "utf8");
const root = css.split("@media")[0];
const dark = css.split("@media (prefers-color-scheme: dark)")[1];
const token = (name: string, theme = root) =>
  rgb(theme.match(new RegExp(`--${name}:\\s*(#[0-9a-f]{6})`))?.[1] ?? "");

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
      // Paid cards composite the whole card (including its text) over the page gradient.
      for (const backdrop of [page, card]) {
        expect(
          contrast(blend(ink, backdrop, 0.75), blend(card, backdrop, 0.75)),
        ).toBeGreaterThanOrEqual(4.5);
      }
    },
  );

  it("renders the bill and settlement instructions at the secondary token opacity", () => {
    for (const file of ["BillPageClient", "SettlementCard"]) {
      const source = readFileSync(`src/components/${file}.tsx`, "utf8");
      expect(source).not.toMatch(
        /text-\[var\(--text-secondary\)\][^"`]*opacity-60/,
      );
    }
  });
});
