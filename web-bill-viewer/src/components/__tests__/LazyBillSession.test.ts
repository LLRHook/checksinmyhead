import {
  Children,
  isValidElement,
  type ReactElement,
  type ReactNode,
} from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { type Bill, getCurrentMember } from "@/lib/api";
import { memberKey } from "@/lib/identity-storage";
import LazyBillBoard from "../LazyBillBoard";
import { blend, contrast, dark, rgb, token } from "./viewer-contrast";

// Run the real component's effects across prop updates without a DOM dependency.
// Dependency comparison and cleanup follow React's Object.is/effect contract;
// events below come from the actual returned input/button elements.
const hooks = vi.hoisted(() => {
  type Effect = {
    dependencies: readonly unknown[] | undefined;
    cleanup?: () => void;
  };
  const values = new Map<number, unknown>();
  const effects = new Map<number, Effect>();
  let pending: (() => void)[] = [];
  let index = 0;
  let changed = false;
  return {
    reset() {
      for (const effect of effects.values()) effect.cleanup?.();
      effects.clear();
      values.clear();
      pending = [];
    },
    begin() {
      index = 0;
      changed = false;
    },
    flush() {
      const scheduled = pending;
      pending = [];
      for (const effect of scheduled) effect();
      return changed;
    },
    useState<T>(initial: T | (() => T)) {
      const slot = index++;
      if (!values.has(slot))
        values.set(
          slot,
          typeof initial === "function" ? (initial as () => T)() : initial,
        );
      const set = (value: T | ((previous: T) => T)) => {
        const previous = values.get(slot) as T;
        const next =
          typeof value === "function"
            ? (value as (previous: T) => T)(previous)
            : value;
        changed ||= !Object.is(previous, next);
        values.set(slot, next);
      };
      return [values.get(slot) as T, set] as const;
    },
    useEffect(
      create: () => undefined | (() => void),
      dependencies?: readonly unknown[],
    ) {
      const slot = index++;
      const previous = effects.get(slot);
      if (
        previous &&
        dependencies &&
        previous.dependencies?.length === dependencies.length &&
        dependencies.every((value, i) =>
          Object.is(value, previous.dependencies?.[i]),
        )
      )
        return;
      pending.push(() => {
        previous?.cleanup?.();
        effects.set(slot, {
          dependencies: dependencies?.slice(),
          cleanup: create(),
        });
      });
    },
  };
});

vi.mock("react", async (actual) => ({
  ...(await actual<typeof import("react")>()),
  useState: hooks.useState,
  useEffect: hooks.useEffect,
}));
vi.mock("next/navigation", () => ({
  useRouter: () => ({ refresh: vi.fn() }),
}));
vi.mock("@/lib/api", async (actual) => ({
  ...(await actual<typeof import("@/lib/api")>()),
  getCurrentMember: vi.fn(),
}));

type Props = Parameters<typeof LazyBillBoard>[0];
type ElementProps = {
  children?: ReactNode;
  className?: string;
  style?: { opacity?: number };
  disabled?: boolean;
  "aria-label"?: string;
  placeholder?: string;
  value?: string;
  role?: string;
  selected?: number | null;
  member?: { tab_id: number } | null;
  onChange?: (event: { target: { value: string } }) => void;
  onClick?: () => void;
};
const bill: Bill = {
  id: 7,
  tab_id: 9,
  name: "Trip receipt",
  lazy_mode: true,
  identity_version: 2,
  identity_state: "ready",
  identity_review_status: "ready",
  identity_revision: 3,
  subtotal: 10,
  tax: 0,
  tip_amount: 0,
  tip_percentage: 0,
  total: 10,
  date: "2001-01-01T00:00:00Z",
  currency_code: "USD",
  payment_methods: [],
  items: [],
  person_shares: [],
  participants: [
    {
      participant_id: 11,
      bill_id: 7,
      client_ref: "saved-occurrence",
      label: "Alex",
      binding_state: "unbound",
      member_id: null,
      pending_member_id: null,
      pending_request_revision: null,
    },
  ],
};
let storage: Map<string, string>;

function elements(node: ReactNode): ReactElement<ElementProps>[] {
  return Children.toArray(node).flatMap((child) =>
    isValidElement<ElementProps>(child)
      ? [child, ...elements(child.props.children)]
      : [],
  );
}
function input(view: ReactNode) {
  const found = elements(view).find(
    (element) => element.props.placeholder === "Your name",
  );
  expect(found).toBeDefined();
  return found as ReactElement<ElementProps>;
}
function click(view: ReactNode, text: string) {
  const button = elements(view).find(
    (element) =>
      element.type === "button" &&
      Children.toArray(element.props.children).includes(text),
  );
  expect(button).toBeDefined();
  button?.props.onClick?.();
}
function render(props: Props) {
  for (let pass = 0; pass < 8; pass++) {
    hooks.begin();
    const view = LazyBillBoard(props);
    if (!hooks.flush()) return view;
  }
  throw new Error("Component did not settle after its effects");
}
async function settle() {
  await Promise.resolve();
  await Promise.resolve();
}
function storedMember() {
  return {
    version: 2,
    tab_id: 9,
    member_id: 22,
    display_name: "Alex",
    role: "member" as const,
    member_token: "private-member-proof",
  };
}

beforeEach(() => {
  hooks.reset();
  vi.mocked(getCurrentMember).mockReset();
  storage = new Map();
  vi.stubGlobal("localStorage", {
    getItem: (key: string) => storage.get(key) ?? null,
    setItem: (key: string, value: string) => storage.set(key, value),
  });
  vi.stubGlobal("window", {
    setInterval: vi.fn(),
    clearInterval: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  });
  vi.stubGlobal("document", {
    visibilityState: "visible",
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  });
});
afterEach(() => {
  hooks.reset();
  vi.unstubAllGlobals();
});

describe("lazy viewer session across refreshed receipt props", () => {
  it("preserves typed join text when refreshed participants have a new array identity", () => {
    const props = { bill, tabId: "9", token: "tab-proof" };
    let view = render(props);
    click(view, "Choose my items");
    view = render(props);
    input(view).props.onChange?.({ target: { value: "Draft name" } });
    view = render(props);
    expect(input(view).props.value).toBe("Draft name");
    const refreshed = {
      ...bill,
      participants: bill.participants?.map((participant) => ({
        ...participant,
      })),
    };
    view = render({ ...props, bill: refreshed });
    expect(input(view).props.value).toBe("Draft name");
    expect(getCurrentMember).not.toHaveBeenCalled();
  });

  it("preserves deliberately emptied text but seeds the suggestion for a different tab", () => {
    storage.set(memberKey("9"), JSON.stringify("Previous suggestion"));
    storage.set(memberKey("10"), JSON.stringify("New tab suggestion"));
    const props = { bill, tabId: "9", token: "tab-proof" };
    let view = render(props);
    click(view, "Choose my items");
    view = render(props);
    expect(input(view).props.value).toBe("Previous suggestion");
    input(view).props.onChange?.({ target: { value: "" } });
    view = render({
      ...props,
      bill: { ...bill, participants: [...(bill.participants ?? [])] },
    });
    expect(input(view).props.value).toBe("");
    view = render({ ...props, tabId: "10", token: "other-tab-proof" });
    expect(input(view).props.value).toBe("New tab suggestion");
  });

  it("revalidates the selected occurrence without repeating membership recovery on graph refresh", async () => {
    storage.set(memberKey("9"), JSON.stringify(storedMember()));
    storage.set(
      "billington_participant_7",
      JSON.stringify({ version: 2, bill_id: 7, participant_id: 11 }),
    );
    vi.mocked(getCurrentMember).mockResolvedValue(storedMember());
    const props = { bill, tabId: "9", token: "tab-proof" };
    render(props);
    await settle();
    let view = render(props);
    expect(
      elements(view).find((element) => element.props.selected === 11),
    ).toBeDefined();
    view = render({ ...props, bill: { ...bill, participants: [] } });
    await settle();
    expect(getCurrentMember).toHaveBeenCalledExactlyOnceWith(
      "9",
      "tab-proof",
      "private-member-proof",
    );
    expect(
      elements(view).find((element) => element.props.selected === null),
    ).toBeDefined();
    expect(
      elements(view).find((element) => element.props.member?.tab_id === 9),
    ).toBeDefined();
  });

  it("clears its recovery warning after successful reauthentication without erasing another error", async () => {
    storage.set(memberKey("9"), JSON.stringify(storedMember()));
    vi.mocked(getCurrentMember)
      .mockRejectedValueOnce(new Error("synthetic unavailable read"))
      .mockResolvedValue(storedMember());
    const props = { bill, tabId: "9", token: "tab-proof" };
    render(props);
    await settle();
    let view = render(props);
    expect(
      elements(view).find((element) => element.props.role === "alert")?.props
        .children,
    ).toContain("Stored membership could not be authenticated");
    view = render({ ...props, token: "fresh-tab-proof" });
    await settle();
    view = render({ ...props, token: "fresh-tab-proof" });
    expect(
      elements(view).find((element) => element.props.role === "alert"),
    ).toBeUndefined();

    // An unrelated input validation failure is not owned by membership recovery.
    hooks.reset();
    vi.mocked(getCurrentMember).mockRejectedValueOnce(
      new Error("read unavailable"),
    );
    render(props);
    await settle();
    view = render(props);
    click(view, "Choose my items");
    view = render(props);
    input(view).props.onChange?.({ target: { value: "" } });
    view = render(props);
    click(view, "Continue");
    view = render({ ...props, token: "another-tab-proof" });
    await settle();
    view = render({ ...props, token: "another-tab-proof" });
    expect(
      elements(view).find((element) => element.props.role === "alert")?.props
        .children,
    ).toBe("Use a name between 1 and 30 characters.");
  });
  it("keeps locked item status readable in both themes and uses a contrasting dark split hover", () => {
    const pathTo = (
      node: ReactNode,
      text: string,
      parents: ReactElement<ElementProps>[] = [],
    ): ReactElement<ElementProps>[] | undefined => {
      for (const child of Children.toArray(node)) {
        if (!isValidElement<ElementProps>(child)) continue;
        const path = [...parents, child];
        if (child.type === "p" && child.props.children === text) return path;
        const found = pathTo(child.props.children, text, path);
        if (found) return found;
      }
    };
    for (const currentPaid of [false, true]) {
      hooks.reset();
      storage.set(
        "billington_participant_7",
        JSON.stringify({ version: 2, bill_id: 7, participant_id: 11 }),
      );
      const fixture: Bill = {
        ...bill,
        items: [
          {
            id: 1,
            name: "Paid item",
            price: 10,
            assignments: [{ participant_id: 22, percentage: 100 }],
          },
          { id: 2, name: "Other item", price: 10, assignments: [] },
        ],
        person_shares: [
          {
            id: 81,
            participant_id: 11,
            person_name: "Alex",
            subtotal: 10,
            tax_share: 0,
            tip_share: 0,
            total: 10,
            paid: currentPaid,
            items: [],
          },
          {
            id: 82,
            participant_id: 22,
            person_name: "Sam",
            subtotal: 10,
            tax_share: 0,
            tip_share: 0,
            total: 10,
            paid: true,
            items: [],
          },
        ],
      };
      const props = { bill: fixture, token: "synthetic" };
      let view = render(props);
      click(view, "Pick my items");
      view = render(props);
      for (const status of currentPaid
        ? ["Paid", "Your share paid"]
        : ["Paid"]) {
        const path = pathTo(view, status);
        expect(path).toBeDefined();
        const opacity =
          path?.reduce((product, node) => {
            const value = node.props.className?.match(
              /(?:^|\s)opacity-(\d+)(?:\s|$)/,
            )?.[1];
            return (
              product *
              (node.props.style?.opacity ?? (value ? Number(value) / 100 : 1))
            );
          }, 1) ?? 0;
        for (const theme of ["light", "dark"]) {
          const ink = token(
            "text-secondary",
            theme === "dark" ? dark : undefined,
          );
          const surface = token(
            theme === "dark" ? "card-bg-dark" : "card-bg-light",
          );
          expect(
            contrast(blend(ink, surface, opacity), surface),
          ).toBeGreaterThanOrEqual(4.5);
        }
      }
      const controls = elements(view).filter((node) => node.type === "button");
      expect(
        controls.find((node) => node.props["aria-label"] === "Select Paid item")
          ?.props.disabled,
      ).toBe(true);
      expect(
        controls.find((node) => node.props["aria-label"] === "Select Paid item")
          ?.props.className,
      ).toContain("opacity-50");
      const split = controls.find(
        (node) => node.props["aria-label"] === "Edit split for Other item",
      );
      const background = split?.props.className?.includes(
        "dark:hover:bg-white/10",
      )
        ? blend(rgb("#ffffff"), token("card-bg-dark"), 0.1)
        : token("secondary");
      expect(
        contrast(token("text-secondary", dark), background),
      ).toBeGreaterThanOrEqual(3);
    }
  });
});
