import {
  Children,
  createElement,
  isValidElement,
  type ReactElement,
  type ReactNode,
} from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Bill } from "@/lib/api";
import LazyBillBoard from "../LazyBillBoard";
import RecordedShares, { RecordedShareRows } from "../RecordedShares";

vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh: vi.fn() }) }));
afterEach(() => vi.unstubAllGlobals());
const bill = {
  id: 7,
  name: "Recorded legacy",
  identity_version: 1,
  identity_state: "legacy_review",
  identity_revision: 0,
  identity_review_status: "identity_review_required",
  lazy_mode: true,
  currency_code: "USD",
  subtotal: 5,
  tax: 0,
  tip_amount: 0,
  total: 5,
  items: [],
  participants: [],
  payment_methods: [],
  person_shares: [
    { id: 811, person_name: "", total: 2, paid: true },
    { id: 812, person_name: "", total: 3, paid: false },
    { id: 0, person_name: "", total: 4, paid: false },
  ],
} as Bill;

type NodeProps = {
  children?: ReactNode;
  onClick?: () => Promise<void>;
  "aria-label"?: string;
};
function buttons(node: ReactNode): ReactElement<NodeProps>[] {
  return Children.toArray(node).flatMap((child) => {
    if (!isValidElement<NodeProps>(child)) return [];
    return [
      ...(child.type === "button" ? [child] : []),
      ...buttons(child.props.children),
    ];
  });
}

describe("recorded browser receipt rows", () => {
  it("renders legacy lazy raw blank rows amounts flags exact IDs and ordered local occurrence", () => {
    const html = renderToStaticMarkup(
      createElement(LazyBillBoard, { bill, token: "source" }),
    );
    for (const text of [
      "Unnamed · recorded row 811",
      "Unnamed · recorded row 812",
      "Unnamed · recorded occurrence 3",
      "$2.00",
      "$3.00",
      "$4.00",
      "Marked paid (manual)",
      "Not marked paid",
      "ownership needs review",
    ]) {
      expect(html).toContain(text);
    }
    expect(html).toContain(
      'aria-label="Mark recorded row 812 paid with source proof"',
    );
    expect(html).not.toContain(
      "Mark recorded occurrence 3 paid with source proof",
    );
  });

  it("rendered exact-row action sends only independent source proof and preserves the other blank row", async () => {
    const fetch = vi
      .fn()
      .mockResolvedValue(new Response("{}", { status: 200 }));
    vi.stubGlobal("fetch", fetch);
    const changed = vi.fn().mockResolvedValue(undefined);
    const errors = vi.fn();
    const tree = RecordedShareRows({
      bill,
      sourceToken: "independent-source",
      onChanged: changed,
      onError: errors,
    });
    const action = buttons(tree).find(
      (button) =>
        button.props["aria-label"] ===
        "Mark recorded row 812 paid with source proof",
    );
    expect(action).toBeDefined();
    await action?.props.onClick?.();
    expect(fetch).toHaveBeenCalledTimes(1);
    const [url, init] = fetch.mock.calls[0];
    expect(url).toMatch(/\/api\/bills\/7\/shares\/812$/);
    expect(JSON.parse(init.body)).toEqual({ paid: true });
    expect(init.headers.Authorization).toBe("Bearer independent-source");
    expect(init.headers["X-Member-Token"]).toBeUndefined();
    expect(init.cache).toBe("no-store");
    expect(init.referrerPolicy).toBe("no-referrer");
    expect(changed).toHaveBeenCalledTimes(1);
    expect(bill.person_shares[0].paid).toBe(true);
    expect(bill.person_shares[1].paid).toBe(false);
  });

  it("destination member and labels expose no paid action until an independent source is entered", () => {
    const html = renderToStaticMarkup(
      createElement(LazyBillBoard, { bill, token: "destination", tabId: "9" }),
    );
    expect(html).toContain("Source bill capability for recorded paid status");
    expect(html).toContain("recorded row 812");
    expect(html).not.toContain("Mark recorded row paid</button>");
    const ordinary = renderToStaticMarkup(
      createElement(RecordedShares, {
        bill,
        sourceToken: "source",
        onChanged: async () => {},
      }),
    );
    expect(ordinary).toContain("recorded row 811");
    expect(ordinary).toContain("Mark recorded row paid</button>");
  });

  it("denied source proof has finite error and does not refresh or substitute another credential", async () => {
    const fetch = vi
      .fn()
      .mockResolvedValue(new Response("{}", { status: 403 }));
    vi.stubGlobal("fetch", fetch);
    const changed = vi.fn();
    const errors = vi.fn();
    const action = buttons(
      RecordedShareRows({
        bill,
        sourceToken: "wrong-source",
        onChanged: changed,
        onError: errors,
      }),
    )[1];
    await action.props.onClick?.();
    expect(fetch).toHaveBeenCalledTimes(1);
    expect(changed).not.toHaveBeenCalled();
    expect(errors).toHaveBeenLastCalledWith(
      expect.stringContaining("unavailable"),
    );
  });
});
