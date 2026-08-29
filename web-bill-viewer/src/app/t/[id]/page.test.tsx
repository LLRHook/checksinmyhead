import { isValidElement, type ReactElement, type ReactNode } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import JoinTabButton from "@/components/JoinTabButton";
import LazyBillBoard from "@/components/LazyBillBoard";
import TabBillList from "@/components/TabBillList";
import TabHeader from "@/components/TabHeader";
import type { Bill, Tab } from "@/lib/api";
import { getSettlements, getTab, getTabImages, getTabMembers } from "@/lib/api";
import TabPage from "./page";

vi.mock("next/navigation", () => ({
  notFound: vi.fn(),
  useRouter: () => ({ refresh: vi.fn() }),
}));

vi.mock("@/lib/api", async (importOriginal) => {
  const actual = await importOriginal<typeof import("@/lib/api")>();
  return {
    ...actual,
    getTab: vi.fn(),
    getTabImages: vi.fn(),
    getTabMembers: vi.fn(),
    getSettlements: vi.fn(),
  };
});

function bill(id: number, overrides: Partial<Bill> = {}): Bill {
  return {
    id,
    name: `Receipt ${id}`,
    subtotal: 10,
    tax: 1,
    tip_amount: 2,
    tip_percentage: 20,
    total: 13,
    date: "2026-08-01",
    payment_methods: [],
    items: [{ id, name: "Item", price: 10, assignments: [] }],
    person_shares: [],
    ...overrides,
  };
}

function elementsOfType<Props = unknown>(
  node: ReactNode,
  type: unknown,
): ReactElement<Props>[] {
  if (Array.isArray(node)) {
    return node.flatMap((child) => elementsOfType<Props>(child, type));
  }
  if (!isValidElement<{ children?: ReactNode; sidebar?: ReactNode }>(node)) {
    return [];
  }

  const matches = node.type === type ? [node as ReactElement<Props>] : [];
  return [
    ...matches,
    ...elementsOfType<Props>(node.props.children, type),
    ...elementsOfType<Props>(node.props.sidebar, type),
  ];
}

describe("shared tab page", () => {
  beforeEach(() => {
    vi.mocked(getTabImages).mockResolvedValue([]);
    vi.mocked(getTabMembers).mockResolvedValue([]);
    vi.mocked(getSettlements).mockResolvedValue([]);
  });

  it("gives invitees an editable receipt board for every active tab bill", async () => {
    const tab: Tab = {
      id: 7,
      name: "Beach trip",
      description: "Created w/ Lazy Mode",
      bills: [
        bill(1, {
          currency_code: "EUR",
          usd_exchange_rate: 1.085,
          usd_total: 14.11,
        }),
        bill(2, {
          currency_code: "JPY",
          usd_exchange_rate: 0.0068,
          usd_total: 0.09,
        }),
      ],
      total_amount: 14.2,
      finalized: false,
      finalized_at: null,
      created_at: "2026-08-01",
      net_balances: [],
    };
    vi.mocked(getTab).mockResolvedValue(tab);

    const page = await TabPage({
      params: Promise.resolve({ id: "7" }) as never,
      searchParams: Promise.resolve({ t: "shared-token" }) as never,
    });

    const boards = elementsOfType<{ bill: Bill }>(page, LazyBillBoard);
    expect(boards).toHaveLength(2);
    expect(boards.map((board) => board.props.bill.currency_code)).toEqual([
      "EUR",
      "JPY",
    ]);
    expect(
      elementsOfType<{ total: number }>(page, TabHeader)[0].props.total,
    ).toBe(14.2);
    expect(elementsOfType(page, TabBillList)).toHaveLength(0);
    expect(elementsOfType(page, JoinTabButton)).toHaveLength(1);
  });

  it("keeps finalized tabs read-only", async () => {
    const tab: Tab = {
      id: 7,
      name: "Beach trip",
      description: "Weekend expenses",
      bills: [
        bill(1, {
          currency_code: "EUR",
          usd_exchange_rate: 1.085,
          usd_total: 14.11,
        }),
        bill(2),
      ],
      total_amount: 27.11,
      finalized: true,
      finalized_at: "2026-08-02",
      created_at: "2026-08-01",
      net_balances: [],
    };
    vi.mocked(getTab).mockResolvedValue(tab);

    const page = await TabPage({
      params: Promise.resolve({ id: "7" }) as never,
      searchParams: Promise.resolve({ t: "shared-token" }) as never,
    });

    expect(elementsOfType(page, LazyBillBoard)).toHaveLength(0);
    const staticLists = elementsOfType<{ bills: Bill[] }>(page, TabBillList);
    expect(staticLists).toHaveLength(1);
    expect(staticLists[0].props.bills[0].currency_code).toBe("EUR");
    expect(
      elementsOfType<{ total: number }>(page, TabHeader)[0].props.total,
    ).toBe(27.11);
    expect(elementsOfType(page, JoinTabButton)).toHaveLength(0);
  });
});
