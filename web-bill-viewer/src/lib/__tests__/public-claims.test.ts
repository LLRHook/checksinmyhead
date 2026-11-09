import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import PublicLayout from "../../app/(public)/layout";
import Home from "../../app/(public)/page";
import Policy from "../../app/(public)/privacy-policy/page";
import { site } from "../../app/(public)/site";
import PaymentDetails from "../../components/PaymentDetails";
import SettlementCard from "../../components/SettlementCard";
import { buildVenmoPayUrl } from "../venmo";

vi.mock("../../app/(public)/public.module.css", () => ({ default: {} }));

const page = (Page: () => React.JSX.Element) =>
  renderToStaticMarkup(createElement(PublicLayout, null, createElement(Page)));
const plain = (html: string) =>
  html
    .replace(/<[^>]+>/g, "")
    .replace(/&#x27;/g, "'")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
const anchors = (html: string) =>
  [...html.matchAll(/<a\b([^>]*)>([\s\S]*?)<\/a>/g)].map((m) => ({
    attributes: m[1],
    href: m[1].match(/href="([^"]*)"/)?.[1] ?? "",
    label: m[1].match(/aria-label="([^"]*)"/)?.[1] ?? plain(m[2]),
  }));
const cents = (value: string) => Math.round(Number(value) * 100);

describe("public download and payment claims", () => {
  it("sends every download action straight to the App Store listing", () => {
    const html = page(Home);
    expect(site.store).toBe("https://apps.apple.com/app/id6746379502");
    const downloads = anchors(html).filter((a) =>
      /Get Billington|Download|App Store/i.test(a.label),
    );
    // Header, hero and closing section.
    expect(downloads).toHaveLength(3);
    for (const download of downloads) {
      expect(download.href).toBe(site.store);
    }
    // No in-page stop between the visitor and the listing.
    expect(anchors(html).map((a) => a.href)).not.toContain("#download");
    expect(anchors(html).map((a) => a.href)).not.toContain("/#download");
    const main = html.slice(html.indexOf("<main"));
    expect(anchors(main)[0].href).toBe(site.store);
  });

  it("shows a completed example split that adds up to the receipt", () => {
    const html = renderToStaticMarkup(createElement(Home));
    const figure = html.match(/<figure[\s\S]*?<\/figure>/)?.[0] ?? "";
    expect(plain(figure)).toContain("Example split");
    expect(plain(figure)).toContain("USD");
    const rows = Object.fromEntries(
      [...figure.matchAll(/<dt>([\s\S]*?)<\/dt><dd>\$([\d.]+)<\/dd>/g)].map(
        (m) => [plain(m[1].replace(/<span[\s\S]*?<\/span>/, "")), cents(m[2])],
      ),
    );
    expect(Object.keys(rows)).toEqual([
      "Items",
      "Tax",
      "Tip",
      "Total",
      "Ari",
      "Sam",
      "Jo",
    ]);
    expect(rows.Items + rows.Tax + rows.Tip).toBe(rows.Total);
    const shares = [rows.Ari, rows.Sam, rows.Jo];
    expect(shares.reduce((sum, share) => sum + share, 0)).toBe(rows.Total);
    // Tax and tip follow each person's items: the split the app computes.
    const items = shares.map((share) => (share * rows.Items) / rows.Total);
    for (const amount of items) {
      expect(Number.isInteger(amount)).toBe(true);
      expect(amount).toBeGreaterThan(0);
    }
    expect(items.reduce((sum, amount) => sum + amount, 0)).toBe(rows.Items);
  });

  it("says what each payment service does and claims no processing or confirmation", () => {
    const home = plain(page(Home));
    for (const statement of [
      "Payments happen outside Billington.",
      "the Venmo button opens the Venmo app, if it is installed, with the recipient, amount and a note filled in",
      "you review and send the payment there",
      "For Zelle, Cash App and Apple Pay, Billington only shows the details the bill creator entered.",
      "Billington does not process a payment or confirm a transfer",
      "a paid marker is recorded manually by participants",
    ]) {
      expect(home).toContain(statement);
    }
    for (const text of [home, plain(page(Policy)), site.description]) {
      expect(text).not.toMatch(
        /one[- ]tap|instant|in-app payment|send money|pay(s|ing)? through Billington|settle up in|payment (is )?confirmed|PayPal/i,
      );
    }
  });

  it("links out only for Venmo and shows the other services as details", () => {
    const methods = [
      { name: "Venmo", identifier: "@synthetic-venmo" },
      { name: "Zelle", identifier: "synthetic-zelle@example.invalid" },
      { name: "Cash App", identifier: "$synthetic-cash" },
      { name: "Apple Pay", identifier: "+1 555 0100" },
    ];
    const details = renderToStaticMarkup(
      createElement(PaymentDetails, { paymentMethods: methods }),
    );
    for (const method of methods) {
      expect(plain(details)).toContain(method.name);
      expect(plain(details)).toContain(method.identifier);
    }
    expect(details).not.toMatch(/<a\b|<button\b|href=|onclick/i);

    const handoff = buildVenmoPayUrl("@synthetic-venmo", "12.34", "Dinner");
    expect(handoff).toBe(
      "venmo://paycharge?txn=pay&recipients=synthetic-venmo&amount=12.34&note=Dinner",
    );
    const settlement = renderToStaticMarkup(
      createElement(SettlementCard, {
        settlements: [
          {
            id: 1,
            tab_id: 9,
            person_name: "Alex",
            amount: 12.34,
            paid: false,
            created_at: "2026-11-03T00:00:00Z",
          },
        ],
        venmoId: "@synthetic-venmo",
      }),
    );
    const outbound = anchors(settlement).map((a) => a.href);
    expect(outbound.length).toBeGreaterThan(0);
    for (const href of outbound) {
      expect(href.startsWith("venmo://paycharge?txn=pay&amp;")).toBe(true);
    }
  });

  it("keeps public navigation keyboard-reachable with known outbound destinations", () => {
    const home = page(Home);
    const policy = page(Policy);
    for (const html of [home, policy]) {
      const links = anchors(html);
      // The skip link is the first stop and lands on the main landmark.
      expect(links[0]).toMatchObject({
        href: "#main",
        label: "Skip to content",
      });
      expect(html).toContain('<main id="main"');
      // Native links in document order only: nothing to trap or reorder focus.
      expect(html).not.toMatch(
        /tabindex=|onclick=|role="button"|target="_blank"|<button\b|<input\b/i,
      );
      for (const link of links) {
        expect(link.href).not.toBe("");
        expect(link.label).not.toBe("");
      }
      const ids = new Set(
        [...html.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1]),
      );
      for (const { href } of links) {
        if (href.startsWith("#")) expect(ids).toContain(href.slice(1));
      }
    }
    const homeIds = new Set(
      [...home.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1]),
    );
    for (const { href } of [...anchors(home), ...anchors(policy)]) {
      if (href.startsWith("/#")) expect(homeIds).toContain(href.slice(2));
    }
    const external = (html: string) =>
      new Set(
        anchors(html)
          .map((a) => a.href)
          .filter((href) => /^[a-z][a-z0-9+.-]*:/i.test(href)),
      );
    expect(external(home)).toEqual(new Set([site.store, site.contact]));
    expect(external(policy)).toEqual(
      new Set([
        site.store,
        site.contact,
        "https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data",
        "https://frankfurter.dev/",
        "https://www.exchangerate-api.com/",
        "https://render.com/privacy",
        "https://vercel.com/legal/privacy-notice",
      ]),
    );
    const internal = [...anchors(home), ...anchors(policy)]
      .map((a) => a.href)
      .filter((href) => href.startsWith("/") && !href.startsWith("/#"));
    expect(new Set(internal)).toEqual(new Set(["/", "/privacy-policy"]));
  });
});
