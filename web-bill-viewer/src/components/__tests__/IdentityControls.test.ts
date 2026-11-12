import {
  Children,
  isValidElement,
  type ReactElement,
  type ReactNode,
} from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, expect, it, vi } from "vitest";
import type { Bill } from "@/lib/api";
import IdentityControls from "../IdentityControls";

// Exercise the real event handler and its next rendered state without a DOM.
const hooks = vi.hoisted(() => ({
  values: [] as unknown[],
  index: 0,
  useState<T>(initial: T) {
    const slot = hooks.index++;
    if (slot >= hooks.values.length) hooks.values[slot] = initial;
    return [
      hooks.values[slot] as T,
      (value: T | ((previous: T) => T)) => {
        hooks.values[slot] =
          typeof value === "function"
            ? (value as (previous: T) => T)(hooks.values[slot] as T)
            : value;
      },
    ] as const;
  },
}));
vi.mock("react", async (actual) => ({
  ...(await actual<typeof import("react")>()),
  useState: hooks.useState,
}));
afterEach(() => {
  hooks.values = [];
  hooks.index = 0;
  vi.unstubAllGlobals();
});
type Props = {
  children?: ReactNode;
  onSubmit?: (event: { preventDefault: () => void }) => void;
};
function forms(node: ReactNode): ReactElement<Props>[] {
  return Children.toArray(node).flatMap((child) =>
    !isValidElement<Props>(child)
      ? []
      : [
          ...(child.type === "form" ? [child] : []),
          ...forms(child.props.children),
        ],
  );
}
it.each(["participants_locked_paid", "identity_revision_conflict"])(
  "participant conflict %s displays its reason and offers retry only when meaningful",
  async (code) => {
    const message =
      code === "participants_locked_paid"
        ? "participants cannot be added after a share is paid"
        : "participant state changed; refresh and try again";
    const fetch = vi.fn().mockImplementation(
      async () =>
        new Response(JSON.stringify({ code, error: message }), {
          status: 409,
        }),
    );
    vi.stubGlobal("fetch", fetch);
    const changed = vi.fn().mockResolvedValue(undefined);
    const render = () => {
      hooks.index = 0;
      return IdentityControls({
        bill: {
          id: 7,
          identity_version: 2,
          identity_revision: 1,
          identity_review_status: "ready",
          participants: [],
        } as unknown as Bill,
        context: { billId: 7, token: "source" },
        member: null,
        selected: null,
        onSelect: () => {},
        onChanged: changed,
      });
    };
    const add = forms(render())[0];
    expect(add).toBeDefined();
    add?.props.onSubmit?.({ preventDefault: () => {} });
    await vi.waitFor(() => expect(changed).toHaveBeenCalledTimes(1));
    const html = renderToStaticMarkup(render());
    expect(html).toContain(message);
    expect(html.includes("Retry original action")).toBe(
      code !== "participants_locked_paid",
    );
    expect(fetch).toHaveBeenCalledTimes(1);
  },
);
