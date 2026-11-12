import type { Metadata } from "next";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import { getBill, getTab, getTabMembers } from "@/lib/api";
import nextConfig from "../../../next.config";
import * as billRoute from "../../app/b/[id]/page";
import { metadata as rootMetadata } from "../../app/layout";
import * as tabRoute from "../../app/t/[id]/page";

vi.mock("next/font/google", () => ({
  Inter: () => ({ variable: "inter" }),
  JetBrains_Mono: () => ({ variable: "mono" }),
}));
vi.mock("../../app/globals.css", () => ({}));
vi.mock("@/lib/api", async () => ({
  ...(await vi.importActual("@/lib/api")),
  getBill: vi.fn(),
  getTab: vi.fn(),
  getTabMembers: vi.fn().mockResolvedValue([]),
}));

afterEach(() => vi.clearAllMocks());

const props = (token?: string) => ({
  params: Promise.resolve({ id: "702" }),
  searchParams: Promise.resolve(token ? { t: token } : {}),
});

// Resolve these routes' metadata over their immediate root layout. Production HTTP
// verification also checks Next's actual inheritance and serialized head output.
async function routeMetadata(route: unknown, token?: string) {
  const page = route as {
    metadata?: Metadata;
    generateMetadata?: (input: ReturnType<typeof props>) => Promise<Metadata>;
  };
  return {
    ...rootMetadata,
    ...page.metadata,
    ...(await page.generateMetadata?.(props(token))),
  };
}

describe("private viewer acquisition metadata", () => {
  for (const [name, route, read] of [
    ["bill", billRoute, getBill],
    ["tab", tabRoute, getTab],
  ] as const) {
    it.each(["valid", "invalid", "missing"] as const)(
      `${name} keeps %s-token metadata generic and excluded from indexing`,
      async (state) => {
        const token = state === "missing" ? undefined : `${state}-synthetic`;
        if (state === "invalid") {
          vi.mocked(read).mockRejectedValue(new Error("Invalid access token"));
        } else {
          vi.mocked(read).mockResolvedValue({
            name: "Private dinner",
          } as never);
        }
        const result = await routeMetadata(route, token);
        expect(result.title).toBe(`Shared ${name} | Billington`);
        expect(result.robots).toMatchObject({ index: false, follow: false });
        expect(JSON.stringify(result)).not.toMatch(/Private dinner|synthetic/);
        expect(result.alternates?.canonical).toBeUndefined();
        expect(result.openGraph).toBeUndefined();
        expect(result.twitter).toBeUndefined();
      },
    );

    it(`${name} constructs metadata without an authorized resource lookup`, async () => {
      vi.mocked(read).mockResolvedValue({ name: "Private dinner" } as never);
      await routeMetadata(route, "valid-synthetic");
      expect(read).not.toHaveBeenCalled();
    });
  }
});

describe("private viewer body access", () => {
  it.each([
    ["bill", billRoute],
    ["tab", tabRoute],
  ] as const)(
    "%s requires a token without reading private data",
    async (_name, route) => {
      const html = renderToStaticMarkup(await route.default(props()));
      expect(html).toContain("Access Token Required");
      expect(getBill).not.toHaveBeenCalled();
      expect(getTab).not.toHaveBeenCalled();
      expect(getTabMembers).not.toHaveBeenCalled();
    },
  );

  it("passes the bill ID and bearer to the existing client body", async () => {
    const element = await billRoute.default(props("bill-synthetic"));
    expect(element.props).toEqual({ id: "702", token: "bill-synthetic" });
    expect(getBill).not.toHaveBeenCalled();
  });

  it("keeps authorized tab names in the body and credentials on its reads", async () => {
    vi.mocked(getTab).mockResolvedValue({
      id: 702,
      name: "Private trip",
      description: "Synthetic trip",
      bills: [],
      total_amount: 0,
      finalized: false,
      finalized_at: null,
      created_at: "2026-11-04",
      net_balances: [],
    });
    const html = renderToStaticMarkup(
      await tabRoute.default(props("tab-synthetic")),
    );
    expect(html).toContain("Private trip");
    expect(getTab).toHaveBeenCalledExactlyOnceWith("702", "tab-synthetic");
    expect(getTabMembers).toHaveBeenCalledExactlyOnceWith(
      "702",
      "tab-synthetic",
    );
  });

  it("keeps an invalid tab bearer out of the private body and collection reads", async () => {
    vi.mocked(getTab).mockRejectedValue(new Error("Invalid access token"));
    const html = renderToStaticMarkup(
      await tabRoute.default(props("invalid-synthetic")),
    );
    expect(html).toContain("Invalid Access Token");
    expect(html).not.toContain("Private trip");
    expect(getTabMembers).not.toHaveBeenCalled();
  });
});

describe("private viewer response policy", () => {
  it("covers access-required and error routes with crawler and referrer headers", async () => {
    const rules = await nextConfig.headers?.();
    // Match the configured catch-all for both private routes, including errors.
    const headers = rules?.find((rule) => rule.source === "/(.*)")?.headers;
    expect(headers).toEqual(
      expect.arrayContaining([
        { key: "X-Robots-Tag", value: "noindex, nofollow" },
        { key: "Referrer-Policy", value: "no-referrer" },
        { key: "X-Content-Type-Options", value: "nosniff" },
        { key: "X-Frame-Options", value: "DENY" },
      ]),
    );
    const csp = headers?.find(
      (header) => header.key === "Content-Security-Policy",
    )?.value;
    expect(csp).toContain("frame-ancestors 'none'");
    expect(csp).toContain("font-src 'self'");
    expect(csp).toContain("img-src 'self' data: https:");
  });
});
