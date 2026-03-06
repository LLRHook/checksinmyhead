export interface ItemDetail {
  name: string;
  amount: number;
  is_shared: boolean;
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
}

export interface PaymentMethod {
  name: string;
  identifier: string;
}

export interface Bill {
  id: number;
  name: string;
  subtotal: number;
  tax: number;
  tip_amount: number;
  tip_percentage: number;
  total: number;
  date: string;
  payment_methods: PaymentMethod[];
  items: BillItem[];
  person_shares: PersonShare[];
}

export interface Tab {
  id: number;
  name: string;
  description: string;
  bills: Bill[];
  total_amount: number;
  finalized: boolean;
  finalized_at: string | null;
  created_at: string;
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

export interface TabImage {
  id: number;
  tab_id: number;
  filename: string;
  url: string;
  size: number;
  mime_type: string;
  processed: boolean;
  uploaded_by: string;
  created_at: string;
}

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";

export { API_BASE_URL };

export async function getBill(id: string, token: string): Promise<Bill> {
  const response = await fetch(`${API_BASE_URL}/api/bills/${id}`, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (!response.ok) {
    if (response.status === 403) {
      throw new Error("Invalid access token");
    }
    if (response.status === 404) {
      throw new Error("Bill not found");
    }
    throw new Error("Failed to fetch bill");
  }

  return response.json();
}

export async function getTab(id: string, token: string): Promise<Tab> {
  const response = await fetch(`${API_BASE_URL}/api/tabs/${id}`, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (!response.ok) {
    if (response.status === 403) {
      throw new Error("Invalid access token");
    }
    if (response.status === 404) {
      throw new Error("Tab not found");
    }
    throw new Error("Failed to fetch tab");
  }

  return response.json();
}

export async function getTabImages(
  id: string,
  token: string,
): Promise<TabImage[]> {
  const response = await fetch(
    `${API_BASE_URL}/api/tabs/${id}/images`,
    { headers: { Authorization: `Bearer ${token}` } },
  );

  if (!response.ok) {
    return [];
  }

  return response.json();
}

export async function getSettlements(
  id: string,
  token: string,
): Promise<TabSettlement[]> {
  const response = await fetch(
    `${API_BASE_URL}/api/tabs/${id}/settlements`,
    { headers: { Authorization: `Bearer ${token}` } },
  );

  if (!response.ok) {
    return [];
  }

  return response.json();
}

export async function getTabMembers(
  id: string,
  token: string,
): Promise<TabMember[]> {
  const response = await fetch(
    `${API_BASE_URL}/api/tabs/${id}/members`,
    { headers: { Authorization: `Bearer ${token}` } },
  );

  if (!response.ok) {
    return [];
  }

  return response.json();
}

export async function joinTab(
  id: string,
  token: string,
  displayName: string,
): Promise<{ member_id: number; member_token: string; display_name: string; role: string } | null> {
  const response = await fetch(
    `${API_BASE_URL}/api/tabs/${id}/join`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ display_name: displayName }),
    },
  );

  if (!response.ok) {
    return null;
  }

  return response.json();
}

export async function updatePersonSharePaid(
  billId: number,
  shareId: number,
  paid: boolean,
  token: string,
): Promise<void> {
  const response = await fetch(
    `${API_BASE_URL}/api/bills/${billId}/shares/${shareId}`,
    {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ paid }),
    },
  );

  if (!response.ok) {
    throw new Error("Failed to update share paid status");
  }
}

export async function updateSettlementPaid(
  tabId: string,
  settlementId: number,
  paid: boolean,
  token: string,
): Promise<void> {
  const response = await fetch(
    `${API_BASE_URL}/api/tabs/${tabId}/settlements/${settlementId}`,
    {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ paid }),
    },
  );

  if (!response.ok) {
    throw new Error("Failed to update settlement paid status");
  }
}

export function computeTabPersonTotals(tab: Tab): TabPersonTotal[] {
  const totals: Record<string, { total: number; bill_count: number; all_paid: boolean }> = {};
  const displayNames: Record<string, string> = {};

  for (const bill of tab.bills) {
    for (const share of bill.person_shares) {
      const key = share.person_name.toLowerCase();
      if (!totals[key]) {
        totals[key] = { total: 0, bill_count: 0, all_paid: true };
        displayNames[key] = share.person_name;
      } else if (
        displayNames[key] === key &&
        share.person_name !== key
      ) {
        // Prefer a capitalized variant over all-lowercase
        displayNames[key] = share.person_name;
      }
      totals[key].total += share.total;
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
    .sort((a, b) => a.person_name.localeCompare(b.person_name, undefined, { sensitivity: "base" }));
}
