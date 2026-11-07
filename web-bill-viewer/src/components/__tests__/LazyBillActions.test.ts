import {
  Children,
  isValidElement,
  type ReactElement,
  type ReactNode,
} from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Bill, ItemUpdate } from "@/lib/api";
import { refreshSourceBill } from "../BillPageClient";
import {
  hasCurrentLazyShare,
  type LazyActionHost,
  LazyReadNotice,
  type LazyReadRecovery,
  markLazyPaid,
  readLazyViewerBill,
  recoverLazyRead,
  reviewLazySelection,
} from "../LazyBillBoard";

vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh: vi.fn() }) }));
afterEach(() => vi.unstubAllGlobals());
const bill: Bill = {
  id: 7,
  tab_id: 9,
  name: "Current lazy receipt",
  lazy_mode: true,
  identity_version: 2,
  identity_state: "ready",
  identity_review_status: "ready",
  identity_revision: 3,
  currency_code: "USD",
  subtotal: 10,
  tax: 1,
  tip_amount: 1,
  tip_percentage: 0,
  total: 12,
  date: "2001-01-01T00:00:00Z",
  payment_methods: [],
  participants: [
    {
      participant_id: 11,
      bill_id: 7,
      client_ref: "r",
      label: "Alex",
      binding_state: "confirmed",
      member_id: 22,
      pending_member_id: null,
      pending_request_revision: null,
    },
  ],
  items: [
    {
      id: 31,
      name: "Meal",
      price: 10,
      updated_at: "2001-01-01T00:00:00Z",
      assignments: [{ participant_id: 11, percentage: 100 }],
    },
  ],
  person_shares: [
    {
      id: 91,
      participant_id: 11,
      person_name: "Alex",
      items: [],
      subtotal: 10,
      tax_share: 1,
      tip_share: 1,
      total: 12,
      paid: false,
    },
  ],
};
const updates: ItemUpdate[] = [
  {
    item_id: 31,
    expected_updated_at: "2001-01-01T00:00:00Z",
    assignments: [{ participant_id: 11, percentage: 50 }],
  },
];
function harness(attached = false) {
  let current = bill;
  let recovery: LazyReadRecovery | null = null;
  let error: string | null = null;
  let stage: "receipt" | "picker" | "pay" = "picker";
  let busy = false;
  const host: LazyActionHost = {
    bill,
    token: attached ? "destination" : "source",
    tabId: attached ? "9" : undefined,
    member: attached
      ? {
          version: 2,
          member_id: 22,
          tab_id: 9,
          display_name: "Alex",
          role: "member",
          member_token: "member-proof",
        }
      : null,
    refresh: async (updated) => {
      if (attached)
        current =
          updated ??
          (await readLazyViewerBill(7, "destination", "9", "member-proof"));
      else
        await refreshSourceBill(
          "7",
          "source",
          (next) => {
            current = next;
          },
          updated,
        );
    },
    onRecovery: (value) => {
      recovery = value;
    },
    onError: (value) => {
      error = value;
    },
    onStage: (value) => {
      stage = value;
    },
    onBusy: (value) => {
      busy = value;
    },
    clearDrafts: vi.fn(),
  };
  return {
    host,
    get current() {
      return current;
    },
    get recovery() {
      return recovery;
    },
    get error() {
      return error;
    },
    get stage() {
      return stage;
    },
    get busy() {
      return busy;
    },
  };
}
type Props = {
  children?: ReactNode;
  onClick?: () => Promise<void>;
  "aria-label"?: string;
};
function retryButton(node: ReactNode): ReactElement<Props> | undefined {
  for (const child of Children.toArray(node)) {
    if (!isValidElement<Props>(child)) continue;
    if (child.type === "button") return child;
    const nested = retryButton(child.props.children);
    if (nested) return nested;
  }
}
async function retry(h: ReturnType<typeof harness>) {
  expect(h.recovery).not.toBeNull();
  const recovery = h.recovery as LazyReadRecovery;
  const view = LazyReadNotice({
    recovery,
    busy: h.busy,
    onRetry: () => recoverLazyRead(h.host, recovery),
  });
  expect(renderToStaticMarkup(view)).toContain("Retry current receipt read");
  await retryButton(view)?.props.onClick?.();
}

describe("maintained lazy action read recovery", () => {
  it("paid ACK plus failed shared /b refresh retains saved marker and rendered retry performs GET only", async () => {
    const h = harness();
    let gets = 0;
    const fetch = vi.fn(async (_url: string, init: RequestInit) => {
      if (init.method === "PATCH") return new Response("{}", { status: 200 });
      gets++;
      return gets === 1
        ? new Response("{}", { status: 503 })
        : new Response(
            JSON.stringify({
              ...bill,
              person_shares: bill.person_shares.map((s) => ({
                ...s,
                paid: true,
              })),
            }),
          );
    });
    vi.stubGlobal("fetch", fetch);
    await expect(markLazyPaid(h.host, 11)).resolves.toBeUndefined();
    expect(h.error).toContain("Paid marker saved");
    expect(h.error).not.toContain("could not save");
    expect(h.stage).toBe("receipt");
    expect(h.current.person_shares[0].paid).toBe(false);
    await retry(h);
    expect(h.current.person_shares[0].paid).toBe(true);
    expect(h.recovery).toBeNull();
    expect(
      fetch.mock.calls.filter(([, init]) => init.method === "PATCH"),
    ).toHaveLength(1);
    expect(fetch.mock.calls.slice(1).map(([url]) => url)).toEqual([
      expect.stringMatching(/\/api\/bills\/7$/),
      expect.stringMatching(/\/api\/bills\/7$/),
    ]);
  });
  for (const failure of [403, 409, "network"] as const) {
    it(`selection ${failure} and failed refresh settles without unhandled promise or repeated mutation`, async () => {
      const h = harness();
      let gets = 0;
      const fetch = vi.fn(async (_url: string, init: RequestInit) => {
        if (init.method === "PATCH") {
          if (failure === "network")
            throw new TypeError("synthetic uncertain network response");
          return new Response("{}", { status: failure });
        }
        gets++;
        return gets === 1
          ? new Response("{}", { status: 503 })
          : new Response(JSON.stringify(bill));
      });
      vi.stubGlobal("fetch", fetch);
      await expect(
        reviewLazySelection(h.host, updates),
      ).resolves.toBeUndefined();
      expect(h.error).toContain("Selection could not be confirmed");
      expect(h.stage).toBe("picker");
      await retry(h);
      expect(h.recovery).toBeNull();
      expect(h.error).toContain("before deliberately retrying");
      expect(
        fetch.mock.calls.filter(([, init]) => init.method === "PATCH"),
      ).toHaveLength(1);
      expect(gets).toBe(2);
    });
  }
  it("missing item version and unavailable read settle without any mutation", async () => {
    const h = harness();
    const fetch = vi
      .fn()
      .mockResolvedValue(new Response("{}", { status: 503 }));
    vi.stubGlobal("fetch", fetch);
    await expect(
      reviewLazySelection(h.host, [
        { ...updates[0], expected_updated_at: undefined },
      ]),
    ).resolves.toBeUndefined();
    expect(h.error).toContain("Could not verify the receipt version");
    expect(fetch.mock.calls).toHaveLength(1);
    expect(fetch.mock.calls[0][1].method).toBe("GET");
  });
  it("attached claim ACK and unavailable current graph recover through the same member-scoped tab read", async () => {
    const h = harness(true);
    let gets = 0;
    const fetch = vi.fn(async (_url: string, init: RequestInit) => {
      if (init.method === "PATCH") return new Response('{"status":"ok"}');
      gets++;
      return gets === 1
        ? new Response("{}", { status: 503 })
        : new Response(
            JSON.stringify({
              id: 9,
              bills: [{ ...bill, identity_revision: 4 }],
            }),
          );
    });
    vi.stubGlobal("fetch", fetch);
    await expect(reviewLazySelection(h.host, updates)).resolves.toBeUndefined();
    expect(h.error).toContain("Selection saved");
    expect(h.stage).toBe("picker");
    await retry(h);
    expect(h.stage).toBe("pay");
    expect(hasCurrentLazyShare(h.current, 11)).toBe(true);
    expect(hasCurrentLazyShare({ ...h.current, person_shares: [] }, 11)).toBe(
      false,
    );
    expect(fetch.mock.calls.map(([url]) => url)).toEqual([
      expect.stringMatching(/\/api\/tabs\/9\/bills\/7\/assignments$/),
      expect.stringMatching(/\/api\/tabs\/9$/),
      expect.stringMatching(/\/api\/tabs\/9$/),
    ]);
    for (const [, init] of fetch.mock.calls) {
      expect((init.headers as Record<string, string>).Authorization).toBe(
        "Bearer destination",
      );
      expect((init.headers as Record<string, string>)["X-Member-Token"]).toBe(
        "member-proof",
      );
    }
  });
});
