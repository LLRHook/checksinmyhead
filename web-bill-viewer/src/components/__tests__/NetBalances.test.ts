import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import type { NetBalance, Party } from "@/lib/api";
import NetBalances from "../NetBalances";

const member = (id: number, label = "Alex"): Party => ({
  kind: "member",
  tab_id: 9,
  member_id: id,
  label,
});
const guest = (bill: number, id: number, label = "Alex"): Party => ({
  kind: "guest",
  bill_id: bill,
  participant_id: id,
  label,
});
const render = (balances: NetBalance[], currentMemberId?: number) =>
  renderToStaticMarkup(
    createElement(NetBalances, {
      balances,
      currentMemberId,
      finalized: true,
      venmoId: "synthetic",
    }),
  );
const names = (html: string) =>
  [
    ...html.matchAll(
      /<span class="font-medium text-\[var\(--accent\)\] dark:text-white">([^<]+)<\/span>/g,
    ),
  ].map((m) => m[1]);

describe("tab balance identity labels", () => {
  it("distinguishes same-named members with existing member references without changing rows amounts or order", () => {
    const balances = [
      { from: member(11), to: member(22), amount: 12.34 },
      { from: member(22), to: member(33, "Bob"), amount: 5.6 },
    ];
    const html = render(balances);
    expect(names(html)).toEqual([
      "Alex · member #11",
      "Alex · member #22",
      "Alex · member #22",
      "Bob",
    ]);
    expect([...html.matchAll(/\$[\d.]+/g)].map((m) => m[0])).toEqual([
      "$12.34",
      "$5.60",
    ]);
    expect(html).not.toContain("<button");
    expect(balances[0].from).toEqual(member(11));
  });

  it("uses receipt-scoped occurrence references for ambiguous guests including blank and casefold labels", () => {
    const html = render([
      { from: guest(7, 1), to: guest(8, 1), amount: 1 },
      { from: member(11, ""), to: guest(8, 2, ""), amount: 2 },
      { from: member(22, "alex"), to: member(33, "Bob"), amount: 3 },
    ]);
    expect(names(html)).toEqual([
      "Alex · receipt 7 #1",
      "Alex · receipt 8 #1",
      "Unnamed · member #11",
      "Unnamed · receipt 8 #2",
      "alex · member #22",
      "Bob",
    ]);
  });

  it("preserves unique labels repeated identities You grouping and the existing payment handoff", () => {
    const balances = [
      { from: member(11, "Sam"), to: member(22, "Jo"), amount: 12.34 },
      { from: member(33, "Ari"), to: member(22, "Jo"), amount: 5.6 },
    ];
    const html = render(balances);
    expect(names(html)).toEqual(["Sam", "Jo", "Ari", "Jo"]);
    const mine = render(balances, 11);
    expect(names(mine)).toEqual(["You", "Jo", "Ari", "Jo"]);
    expect(mine).toContain("Your Balances");
    expect(mine).toContain("All Balances");
    expect(mine.match(/<button/g)).toHaveLength(1);
    expect(render([], 11)).toBe("");
  });

  it("escapes ambiguous labels and keeps name-only historical rows unchanged", () => {
    const html = render([
      { from: member(11, "<script>"), to: member(22, "<script>"), amount: 1 },
    ]);
    expect(html).not.toContain("<script>");
    expect(names(html)).toEqual([
      "&lt;script&gt; · member #11",
      "&lt;script&gt; · member #22",
    ]);
    expect(names(render([{ from: "Alex", to: "Bob", amount: 2 }]))).toEqual([
      "Alex",
      "Bob",
    ]);
  });
});
