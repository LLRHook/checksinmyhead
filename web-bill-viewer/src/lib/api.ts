import { allocateBillUSDShareAmounts } from "./currency";

export interface ItemDetail {
  name: string;
  amount: number;
  is_shared: boolean;
}

export interface ItemAssignment {
  person_name?: string;
  participant_id?: number | null;
  label?: string | null;
  percentage: number;
}

export interface Participant {
  participant_id: number;
  bill_id: number;
  client_ref: string | null;
  label: string;
  binding_state: "unbound" | "pending" | "confirmed";
  member_id: number | null;
  pending_member_id: number | null;
  pending_request_revision: number | null;
}
export type Party =
  | { kind: "member"; tab_id: number; member_id: number; label: string }
  | { kind: "guest"; bill_id: number; participant_id: number; label: string };
export function partyKey(party: Party): string {
  return party.kind === "member"
    ? `member:${party.tab_id}:${party.member_id}`
    : `guest:${party.bill_id}:${party.participant_id}`;
}
export function partyLabel(party: Party | string): string {
  return typeof party === "string"
    ? party || "Unnamed"
    : party.label || "Unnamed";
}
export interface PersonShare {
  participant_id?: number | null;
  label?: string | null;
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
  tab_id?: number;
  identity_version?: number;
  identity_revision?: number;
  identity_state?: string;
  identity_review_status?: string;
  accounting_review_status?: string;
  viewer_member_id?: number | null;
  participants?: Participant[];
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
  total_amount: number | null;
  total_status?: string;
  accounting_currency?: "USD";
  net_balance_status?: string;
  viewer_member_id?: number | null;
  display_currency?: string;
  finalized: boolean;
  finalized_at: string | null;
  created_at: string;
  net_balances: NetBalance[] | null;
}

export interface TabSettlement {
  snapshot_version?: number;
  party?: Party | null;
  id: number;
  tab_id: number;
  person_name: string;
  amount: number;
  paid: boolean;
  created_at: string;
}

export interface TabPersonTotal {
  key?: string;
  party?: Party;
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
  from: Party | string;
  to: Party | string;
  amount: number;
}

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";

export { API_BASE_URL };

export class ApiError extends Error {
  constructor(
    public status: number,
    public code?: string,
    message?: string,
  ) {
    super(
      message ||
        (status === 403
          ? "Invalid access token"
          : status === 404
            ? "Resource not found"
            : status === 409
              ? "State changed or requires review. Refresh and deliberately retry."
              : "Service unavailable. Try again."),
    );
  }
  get retryable(): boolean {
    return this.code !== "participants_locked_paid";
  }
}
export function identityHeaders(
  token: string,
  memberToken?: string,
): Record<string, string> {
  return {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
    "X-Billington-Identity-Version": "2",
    ...(memberToken === undefined ? {} : { "X-Member-Token": memberToken }),
  };
}
async function request<T>(
  path: string,
  token: string,
  method = "GET",
  body?: unknown,
  memberToken?: string,
): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method,
    cache: "no-store",
    referrerPolicy: "no-referrer",
    redirect: "error",
    headers: identityHeaders(token, memberToken),
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  if (!response.ok) {
    let code: string | undefined;
    let message: string | undefined;
    try {
      const body = await response.json();
      if (typeof body.code === "string") code = body.code;
      if (typeof body.error === "string") message = body.error;
    } catch {}
    throw new ApiError(response.status, code, message);
  }
  // Status-only commands intentionally have no dependency on response JSON.
  if (
    method === "PATCH" &&
    path.match(/(?:shares\/\d+(?:\/paid)?|items\/\d+\/assignments)$/)
  )
    return undefined as T;
  return response.json();
}
export async function getBill(
  id: string,
  token: string,
  memberToken?: string,
): Promise<Bill> {
  return request(`/api/bills/${id}`, token, "GET", undefined, memberToken);
}
export async function getTab(
  id: string,
  token: string,
  memberToken?: string,
): Promise<Tab> {
  return request(`/api/tabs/${id}`, token, "GET", undefined, memberToken);
}
export interface SettlementHistory {
  settlements: TabSettlement[];
  identity_review_status: string;
  accounting_currency: "USD";
  viewer_member_id: number | null;
}
export async function getSettlementHistory(
  id: string,
  token: string,
): Promise<SettlementHistory> {
  return request(`/api/tabs/${id}/settlements`, token);
}
export async function getTabMembers(
  id: string,
  token: string,
): Promise<TabMember[]> {
  return request(`/api/tabs/${id}/members`, token);
}
export interface CurrentMember {
  member_id: number;
  tab_id: number;
  display_name: string;
  role: string;
}
export interface JoinedMember extends CurrentMember {
  member_token: string;
}
export async function getCurrentMember(
  id: string,
  token: string,
  memberToken: string,
): Promise<CurrentMember> {
  const me = await request<CurrentMember>(
    `/api/tabs/${id}/members/me`,
    token,
    "GET",
    undefined,
    memberToken,
  );
  if (
    me.tab_id !== Number(id) ||
    !Number.isSafeInteger(me.member_id) ||
    me.member_id <= 0 ||
    typeof me.display_name !== "string" ||
    !["creator", "member"].includes(me.role)
  )
    throw new Error("Invalid scoped membership");
  return me;
}
export async function renameCurrentMember(
  id: string,
  token: string,
  memberToken: string,
  label: string,
): Promise<CurrentMember> {
  return request(
    `/api/tabs/${id}/members/me`,
    token,
    "PATCH",
    { display_name: label },
    memberToken,
  );
}
export async function joinTab(
  id: string,
  token: string,
  displayName: string,
  memberToken?: string,
): Promise<JoinedMember> {
  const joined = await request<Omit<JoinedMember, "tab_id">>(
    `/api/tabs/${id}/join`,
    token,
    "POST",
    { display_name: displayName },
    memberToken,
  );
  if (
    !Number.isSafeInteger(joined.member_id) ||
    joined.member_id <= 0 ||
    typeof joined.member_token !== "string" ||
    !joined.member_token
  )
    throw new Error("Invalid membership response");
  return { ...joined, tab_id: Number(id) };
}
export async function updatePersonSharePaid(
  billId: number,
  shareId: number,
  paid: boolean,
  token: string,
): Promise<void> {
  await request(`/api/bills/${billId}/shares/${shareId}`, token, "PATCH", {
    paid,
  });
}
export async function updateTabPersonSharePaid(
  tabId: string,
  billId: number,
  shareId: number,
  paid: boolean,
  token: string,
  memberToken?: string,
): Promise<void> {
  await request(
    `/api/tabs/${tabId}/bills/${billId}/shares/${shareId}/paid`,
    token,
    "PATCH",
    { paid },
    memberToken,
  );
}
function claims(assignments: ItemAssignment[]) {
  return assignments.map((a) => {
    if (!Number.isSafeInteger(a.participant_id) || (a.participant_id ?? 0) <= 0)
      throw new Error(
        "Select a current participant occurrence before editing.",
      );
    return { participant_id: a.participant_id, percentage: a.percentage };
  });
}
function revision(value?: number) {
  if (!Number.isSafeInteger(value) || (value ?? -1) < 0)
    throw new Error("Refresh the current identity revision before editing.");
  return value;
}
export type ItemUpdate = {
  item_id: number;
  expected_updated_at?: string;
  assignments: ItemAssignment[];
};
export async function updateTabBillItemAssignmentsBatch(
  tabId: string,
  billId: number,
  updates: ItemUpdate[],
  token: string,
  memberToken?: string,
  expectedRevision?: number,
): Promise<Bill> {
  return request(
    `/api/tabs/${tabId}/bills/${billId}/assignments`,
    token,
    "PATCH",
    {
      expected_revision: revision(expectedRevision),
      updates: updates.map((u) => ({
        ...u,
        assignments: claims(u.assignments),
      })),
    },
    memberToken,
  );
}
export async function updateLazyBillItemAssignmentsBatch(
  billId: number,
  updates: ItemUpdate[],
  token: string,
  expectedRevision?: number,
): Promise<Bill> {
  return request(`/api/bills/${billId}/assignments`, token, "PATCH", {
    expected_revision: revision(expectedRevision),
    updates: updates.map((u) => ({ ...u, assignments: claims(u.assignments) })),
  });
}
export interface IdentityContext {
  billId: number;
  token: string;
  tabId?: string;
  memberToken?: string;
}
export interface ParticipantResult {
  participant: Participant;
  identity_revision: number;
}
function participantRoot(c: IdentityContext) {
  return c.tabId
    ? `/api/tabs/${c.tabId}/bills/${c.billId}/participants`
    : `/api/bills/${c.billId}/participants`;
}
export async function createParticipant(
  c: IdentityContext,
  ref: string,
  label: string,
  expectedRevision: number,
): Promise<ParticipantResult> {
  return request(
    participantRoot(c),
    c.token,
    "POST",
    {
      client_ref: ref,
      name: label,
      expected_revision: revision(expectedRevision),
    },
    c.memberToken,
  );
}
export async function renameParticipant(
  c: IdentityContext,
  pid: number,
  label: string,
  expectedRevision: number,
  billToken?: string,
): Promise<ParticipantResult> {
  return request(
    `${participantRoot(c)}/${pid}`,
    c.token,
    "PATCH",
    {
      name: label,
      expected_revision: revision(expectedRevision),
      ...(billToken === undefined ? {} : { bill_token: billToken }),
    },
    c.memberToken,
  );
}
export async function requestBinding(
  c: IdentityContext,
  pid: number,
  expectedRevision: number,
): Promise<ParticipantResult> {
  return request(
    `${participantRoot(c)}/${pid}/binding-request`,
    c.token,
    "POST",
    { expected_revision: revision(expectedRevision) },
    c.memberToken,
  );
}
export async function decideBinding(
  c: IdentityContext,
  pid: number,
  expectedRevision: number,
  requestRevision: number,
  memberId: number,
  decision: "approve" | "reject",
  billToken?: string,
): Promise<ParticipantResult> {
  return request(
    `${participantRoot(c)}/${pid}/binding`,
    c.token,
    "PUT",
    {
      expected_revision: revision(expectedRevision),
      request_revision: requestRevision,
      member_id: memberId,
      decision,
      ...(billToken === undefined ? {} : { bill_token: billToken }),
    },
    c.memberToken,
  );
}

export function computeTabPersonTotals(tab: Tab): TabPersonTotal[] | null {
  if (
    tab.bills.some(
      (b) =>
        b.identity_review_status === "identity_review_required" ||
        b.accounting_review_status === "accounting_review_required",
    )
  )
    return null;
  const totals = new Map<string, TabPersonTotal>();
  for (const bill of tab.bills) {
    const usdShares = allocateBillUSDShareAmounts(bill);
    for (const [index, share] of bill.person_shares.entries()) {
      const p = bill.participants?.find(
        (p) =>
          p.participant_id === share.participant_id && p.bill_id === bill.id,
      );
      // Missing legacy references cannot establish cross-receipt identity.
      const party: Party | undefined = p
        ? p.binding_state === "confirmed" && p.member_id
          ? {
              kind: "member",
              tab_id: tab.id,
              member_id: p.member_id,
              label: p.label,
            }
          : {
              kind: "guest",
              bill_id: bill.id,
              participant_id: p.participant_id,
              label: p.label,
            }
        : undefined;
      const key = party
        ? partyKey(party)
        : `legacy:${bill.id}:${share.id}:${index}`;
      const row = totals.get(key) ?? {
        key,
        party,
        person_name: p?.label ?? share.person_name,
        total: 0,
        bill_count: 0,
        all_paid: true,
      };
      if (
        row.person_name === row.person_name.toLowerCase() &&
        share.label &&
        share.label !== share.label.toLowerCase()
      )
        row.person_name = share.label;
      row.total += usdShares[index];
      row.bill_count++;
      row.all_paid &&= share.paid;
      totals.set(key, row);
    }
  }
  return [...totals.values()].sort((a, b) =>
    a.person_name.localeCompare(b.person_name, undefined, {
      sensitivity: "base",
    }),
  );
}
