import { allocateBillUSDShareAmounts } from "./currency";

export interface ItemDetail {
  name: string;
  amount: number;
  is_shared: boolean;
}

export interface ItemAssignment {
  person_name: string;
  percentage: number;
}

export interface PersonShare {
  id: number;
  person_name: string;
  items: ItemDetail[];
  subtotal: number;
  tax_share: number;
  tip_share: number;
  total: number;
  paid: boolean;
}

export interface BillItem {
  id: number;
  name: string;
  price: number;
  updated_at?: string;
  assignments?: ItemAssignment[];
}

export interface PaymentMethod {
  name: string;
  identifier: string;
}

export interface Bill {
  id: number;
  lazy_mode?: boolean;
  name: string;
  subtotal: number;
  tax: number;
  tip_amount: number;
  tip_percentage: number;
  total: number;
  currency_code?: string;
  usd_exchange_rate?: number;
  usd_total?: number;
  display_currency?: string;
  display_total?: number;
  exchange_rate?: number;
  exchange_rate_source?: string;
  exchange_rate_date?: string;
  date: string;
  payment_methods: PaymentMethod[];
  items: BillItem[];
  person_shares: PersonShare[];
  paid_by_member_id?: number;
}

export interface Tab {
  id: number;
  name: string;
  description: string;
  bills: Bill[];
  total_amount: number;
  display_currency?: string;
  finalized: boolean;
  finalized_at: string | null;
  created_at: string;
  net_balances: NetBalance[];
}

export interface TabSettlement {
  id: number;
  tab_id: number;
  person_name: string;
  amount: number;
  paid: boolean;
  created_at: string;
}

export interface TabPersonTotal {
  person_name: string;
  total: number;
  bill_count: number;
  all_paid: boolean;
}

export interface TabMember {
  id: number;
  tab_id: number;
  display_name: string;
  role: string;
  joined_at: string;
}

export interface NetBalance {
  from: string;
  to: string;
  amount: number;
}

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";

export { API_BASE_URL };

export async function getBill(id: string, token: string): Promise<Bill> {
  return getAuthorizedResource<Bill>(`/api/bills/${id}`, token, "bill");
}

export async function getTab(id: string, token: string): Promise<Tab> {
  return getAuthorizedResource<Tab>(`/api/tabs/${id}`, token, "tab");
}

async function getAuthorizedResource<T>(
  path: string,
  token: string,
  resourceName: "bill" | "tab",
): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!response.ok) {
    if (response.status === 403) throw new Error("Invalid access token");
    if (response.status === 404) {
      throw new Error(
        resourceName === "bill" ? "Bill not found" : "Tab not found",
      );
    }
    throw new Error(`Failed to fetch ${resourceName}`);
  }

  return response.json();
}

export async function getSettlements(
  id: string,
  token: string,
): Promise<TabSettlement[]> {
  return getTabCollection<TabSettlement>(id, "settlements", token);
}

export async function getTabMembers(
  id: string,
  token: string,
): Promise<TabMember[]> {
  return getTabCollection<TabMember>(id, "members", token);
}

async function getTabCollection<T>(
  id: string,
  collection: "settlements" | "members",
  token: string,
): Promise<T[]> {
  const response = await fetch(`${API_BASE_URL}/api/tabs/${id}/${collection}`, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (!response.ok) {
    return [];
  }

  return response.json();
}

export async function joinTab(
  id: string,
  token: string,
  displayName: string,
): Promise<{ display_name: string; member_token: string }> {
  const response = await fetch(`${API_BASE_URL}/api/tabs/${id}/join`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ display_name: displayName }),
  });
  if (!response.ok) throw new Error("Failed to join tab");
  return response.json();
}

export async function updatePersonSharePaid(
  billId: number,
  shareId: number,
  paid: boolean,
  token: string,
): Promise<void> {
  await patchPaidStatus(
    `/api/bills/${billId}/shares/${shareId}`,
    paid,
    token,
    "Failed to update share paid status",
  );
}

export async function updateTabPersonSharePaid(
  tabId: string,
  billId: number,
  shareId: number,
  paid: boolean,
  token: string,
  memberToken?: string,
): Promise<void> {
  await patchPaidStatus(
    `/api/tabs/${tabId}/bills/${billId}/shares/${shareId}/paid`,
    paid,
    token,
    "Failed to update lazy payment status",
    memberToken,
  );
}

export async function updateSettlementPaid(
  tabId: string,
  settlementId: number,
  paid: boolean,
  token: string,
): Promise<void> {
  await patchPaidStatus(
    `/api/tabs/${tabId}/settlements/${settlementId}`,
    paid,
    token,
    "Failed to update settlement paid status",
  );
}

async function patchPaidStatus(
  path: string,
  paid: boolean,
  token: string,
  failureMessage: string,
  memberToken?: string,
): Promise<void> {
  const headers: HeadersInit = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${token}`,
  };
  if (memberToken) headers["X-Member-Token"] = memberToken;
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: "PATCH",
    headers,
    body: JSON.stringify({ paid }),
  });
  if (!response.ok) {
    throw new Error(failureMessage);
  }
}

export async function updateTabBillItemAssignments(
  tabId: string,
  billId: number,
  itemId: number,
  assignments: ItemAssignment[],
  token: string,
  expectedUpdatedAt?: string,
  memberToken?: string,
): Promise<void> {
  await updateItemAssignments(
    `/api/tabs/${tabId}/bills/${billId}/items/${itemId}/assignments`,
    assignments,
    token,
    expectedUpdatedAt,
    memberToken,
  );
}

export async function updateLazyBillItemAssignments(
  billId: number,
  itemId: number,
  assignments: ItemAssignment[],
  token: string,
  expectedUpdatedAt?: string,
): Promise<void> {
  await updateItemAssignments(
    `/api/bills/${billId}/items/${itemId}/assignments`,
    assignments,
    token,
    expectedUpdatedAt,
  );
}

async function updateItemAssignments(
  path: string,
  assignments: ItemAssignment[],
  token: string,
  expectedUpdatedAt: string | undefined,
  memberToken?: string,
): Promise<void> {
  const headers: HeadersInit = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${token}`,
  };
  if (memberToken) headers["X-Member-Token"] = memberToken;
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: "PATCH",
    headers,
    body: JSON.stringify({
      assignments,
      expected_updated_at: expectedUpdatedAt,
    }),
  });

  if (response.status === 409) {
    throw new Error("item changed; refresh and try again");
  }
  if (!response.ok) {
    throw new Error("Failed to update item assignments");
  }
}

export function computeTabPersonTotals(tab: Tab): TabPersonTotal[] {
  const totals: Record<
    string,
    { total: number; bill_count: number; all_paid: boolean }
  > = {};
  const displayNames: Record<string, string> = {};

  for (const bill of tab.bills) {
    const usdShares = allocateBillUSDShareAmounts(bill);
    for (const [index, share] of bill.person_shares.entries()) {
      const key = share.person_name.toLowerCase();
      if (!totals[key]) {
        totals[key] = { total: 0, bill_count: 0, all_paid: true };
        displayNames[key] = share.person_name;
      } else if (displayNames[key] === key && share.person_name !== key) {
        // Prefer a capitalized variant over all-lowercase
        displayNames[key] = share.person_name;
      }
      totals[key].total += usdShares[index];
      totals[key].bill_count += 1;
      if (!share.paid) {
        totals[key].all_paid = false;
      }
    }
  }

  return Object.entries(totals)
    .map(([key, val]) => ({
      person_name: displayNames[key],
      total: val.total,
      bill_count: val.bill_count,
      all_paid: val.all_paid,
    }))
    .sort((a, b) =>
      a.person_name.localeCompare(b.person_name, undefined, {
        sensitivity: "base",
      }),
    );
}
