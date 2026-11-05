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
