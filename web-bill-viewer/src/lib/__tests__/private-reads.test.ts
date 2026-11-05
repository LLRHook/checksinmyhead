import { afterEach, describe, expect, it, vi } from "vitest";
import {
  API_BASE_URL,
  getBill,
  getSettlements,
  getTab,
  getTabMembers,
} from "../api";

afterEach(() => vi.unstubAllGlobals());

describe("private authorized reads", () => {
  it.each([
    ["bill", getBill, "/api/bills/702", { name: "Private dinner" }],
    ["tab", getTab, "/api/tabs/702", { name: "Private trip" }],
    [
      "members",
      getTabMembers,
      "/api/tabs/702/members",
      [{ display_name: "Alice" }],
    ],
    [
      "settlements",
      getSettlements,
      "/api/tabs/702/settlements",
      [{ person_name: "Alice" }],
    ],
  ] as const)(
    "fetches %s afresh with independent bearer credentials",
    async (_name, read, path, data) => {
      const fetchMock = vi
        .fn()
        .mockResolvedValueOnce(
          new Response(
            JSON.stringify(
              _name === "settlements"
                ? {
                    settlements: data,
                    identity_review_status: "ready",
                    accounting_currency: "USD",
                  }
                : data,
            ),
          ),
        )
        .mockResolvedValueOnce(
          new Response(
            JSON.stringify(
              _name === "settlements"
                ? {
                    settlements: data,
                    identity_review_status: "ready",
                    accounting_currency: "USD",
                  }
                : data,
            ),
          ),
        );
      vi.stubGlobal("fetch", fetchMock);
      await expect(read("702", "first-synthetic")).resolves.toEqual(data);
      await expect(read("702", "second-synthetic")).resolves.toEqual(data);
      expect(fetchMock).toHaveBeenCalledTimes(2);
      for (const [index, token] of [
        "first-synthetic",
        "second-synthetic",
      ].entries()) {
        const [url, options] = fetchMock.mock.calls[index];
        const request = new Request(url, options);
        expect(request.url).toBe(`${API_BASE_URL}${path}`);
        expect(request.method).toBe("GET");
        expect(request.headers.get("Authorization")).toBe(`Bearer ${token}`);
        expect(request.cache).toBe("no-store");
        expect(request.url).not.toContain(token);
        expect(options.next).toBeUndefined();
      }
    },
  );
});
