import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import PublicLayout, {
  metadata as publicMetadata,
} from "../../app/(public)/layout";
import Home, { metadata as homeMetadata } from "../../app/(public)/page";
import Policy, {
  metadata as policyMetadata,
} from "../../app/(public)/privacy-policy/page";
import { site } from "../../app/(public)/site";
import { metadata as rootMetadata } from "../../app/layout";
import robots from "../../app/robots";
import sitemap from "../../app/sitemap";

vi.mock("next/font/google", () => ({
  Inter: () => ({ variable: "inter" }),
  JetBrains_Mono: () => ({ variable: "mono" }),
}));
vi.mock("../../app/globals.css", () => ({}));
vi.mock("../../app/(public)/public.module.css", () => ({ default: {} }));
afterEach(() => vi.unstubAllGlobals());

const plain = (html: string) =>
  html
    .replace(/<[^>]+>/g, "")
    .replace(/&#x27;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
const paragraphs = (html: string) =>
  [...html.matchAll(/<p[^>]*>([\s\S]*?)<\/p>/g)].map((m) => plain(m[1]));

describe("public and private acquisition isolation", () => {
  it("confines public indexing, canonical and social metadata to public routes", () => {
    expect(publicMetadata.robots).toEqual({ index: true, follow: true });
    expect(rootMetadata.robots).toEqual({ index: false, follow: false });
    expect(rootMetadata.referrer).toBe("no-referrer");
    expect(rootMetadata.alternates).toBeUndefined();
    expect(rootMetadata.openGraph).toBeUndefined();
    expect(rootMetadata.twitter).toBeUndefined();
    expect(homeMetadata.alternates?.canonical).toBe(site.origin);
    expect(policyMetadata.alternates?.canonical).toBe(
      `${site.origin}/privacy-policy`,
    );
    expect(homeMetadata.title).not.toEqual(policyMetadata.title);
    expect(homeMetadata.description).not.toEqual(policyMetadata.description);
    for (const metadata of [homeMetadata, policyMetadata]) {
      expect(metadata.openGraph).toMatchObject({
        images: [{ url: site.socialImage }],
      });
      expect(metadata.twitter).toMatchObject({ card: "summary_large_image" });
    }
  });

  it.each([
    ["home", Home],
    ["policy", Policy],
  ] as const)(
    "%s renders complete public content without API or browser storage",
    (_name, Page) => {
      const fetch = vi.fn(() => {
        throw new Error("API unavailable");
      });
      vi.stubGlobal("fetch", fetch);
      for (const name of ["localStorage", "sessionStorage"]) {
        vi.stubGlobal(
          name,
          new Proxy(
            {},
            {
              get: () => {
                throw new Error("public storage access");
              },
            },
          ),
        );
      }
      const html = renderToStaticMarkup(
        createElement(PublicLayout, null, createElement(Page)),
      );
      expect(html).toContain("<main");
      expect(html).toContain("checkmateapp@duck.com");
      expect(html).toContain("Payments happen outside Billington.");
      expect(html).not.toMatch(/Loading|Access Token Required/);
      expect(fetch).not.toHaveBeenCalled();
      const mailLinks = [...html.matchAll(/href="(mailto:[^"]+)"/g)].map(
        (m) => m[1],
      );
      expect(mailLinks.length).toBeGreaterThan(0);
      expect(new Set(mailLinks)).toEqual(new Set([site.contact]));
    },
  );

  it("publishes only visible, bounded software claims on the homepage", () => {
    const home = renderToStaticMarkup(createElement(Home));
    const policy = renderToStaticMarkup(createElement(Policy));
    const match = home.match(
      /<script type="application\/ld\+json">([\s\S]*?)<\/script>/,
    );
    expect(match).not.toBeNull();
    const data = JSON.parse(match?.[1] ?? "");
    expect(data).toMatchObject({
      "@type": "SoftwareApplication",
      name: "Billington",
      operatingSystem: "iOS",
      url: site.origin,
      downloadUrl: site.store,
    });
    expect(data.description).toBe(site.description);
    expect(home).toContain(site.description);
    expect(data).not.toHaveProperty("offers");
    expect(data).not.toHaveProperty("aggregateRating");
    expect(data).not.toHaveProperty("softwareVersion");
    expect(policy).not.toContain("application/ld+json");
  });

  it("enumerates only public documents and lets crawlers read private noindex", () => {
    expect(sitemap()).toEqual([
      { url: site.origin },
      { url: `${site.origin}/privacy-policy` },
    ]);
    expect(robots()).toEqual({
      rules: { userAgent: "*", allow: "/" },
      sitemap: `${site.origin}/sitemap.xml`,
    });
  });
});

describe("privacy policy disclosures", () => {
  const policy = () => renderToStaticMarkup(createElement(Policy));

  it("scopes the policy to the App Store version and marks unreleased behavior", () => {
    const text = plain(policy());
    expect(text).toContain(
      "This policy describes Billington version 1.4.0, the version available on the App Store, and the Billington service as it currently runs.",
    );
    expect(text).toContain(
      'Statements marked "Not yet released" describe later builds that are not on the App Store',
    );
    const unreleasedOnly =
      /secure storage|Frankfurter|pending save|leave a tab|statement text/i;
    const marked = paragraphs(policy()).filter((p) => unreleasedOnly.test(p));
    expect(marked.length).toBeGreaterThanOrEqual(5);
    for (const paragraph of marked) {
      expect(paragraph).toMatch(/^Not yet released: /);
    }
  });

  it("states the released collection, provider, log, link and removal facts", () => {
    const text = plain(policy());
    for (const statement of [
      "In version 1.4.0, saving a finished bill sends it to Billington's service automatically, whether or not you share its link.",
      "If that attempt fails, the app tries again the next time it opens.",
      "the selected photo goes to Billington's API and then to Anthropic's Claude API for extraction",
      "The service as it currently runs does not accept those photos",
      "Version 1.4.0 does not convert currencies.",
      "can also record the database statement for a failed or slow operation in its logs, and that statement can contain bill content or access credentials",
      "A change to the app or service does not by itself erase existing logs.",
      "Shared access links do not automatically expire.",
      "We do not sell bill or tab content.",
      "Billington does not process payments or confirm transfers.",
      "There is no in-app control for deleting an entire shared online bill or tab.",
      "Clearing local app data or uninstalling is not an online deletion request and does not revoke shared links.",
      "We do not promise that uninstalling erases every credential or backup copy.",
      "within 30 days, with exceptions",
    ]) {
      expect(text).toContain(statement);
    }
    for (const id of [
      "version-covered",
      "information-on-your-device",
      "bills-and-tabs-online",
      "who-can-use-a-shared-link",
      "receipt-scanning",
      "currency-rates",
      "service-operation-and-providers",
      "browser-storage-and-sharing-outside-billington",
      "retention-removal-and-requests",
      "changes-and-contact",
    ]) {
      expect(policy()).toContain(`href="#${id}"`);
      expect(policy()).toContain(`id="${id}"`);
    }
  });

  it("makes no publication, effective-date, compliance or no-collection claim", () => {
    const home = plain(renderToStaticMarkup(createElement(Home)));
    const text = plain(policy());
    expect(text).toContain("The policy page will identify its effective date.");
    for (const page of [home, text]) {
      expect(page).not.toMatch(
        /effective (date: |as of |on )?(january|february|march|april|may|june|july|august|september|october|november|december|\d)/i,
      );
      expect(page).not.toMatch(
        /data not collected|never leaves your device|zero cloud storage|GDPR|CCPA|compliant|compliance/i,
      );
      expect(page).not.toMatch(/removed (completely )?when you uninstall/i);
    }
    expect(home).toContain("online bills and tabs are stored by the service");
    expect(home).toContain(
      "Removing local history does not delete an online bill.",
    );
  });
});
