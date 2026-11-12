import type { CurrentMember, Participant } from "./api";
export type StoredMember = CurrentMember & { version: 2; member_token: string };
export const memberKey = (tabId: string) => `billington_member_${tabId}`;
export const selectionKey = (billId: number) =>
  `billington_participant_${billId}`;
export function readMember(
  raw: string | null,
  tabId: string,
): StoredMember | null {
  try {
    const p = JSON.parse(raw ?? "null");
    return p?.version === 2 &&
      p.tab_id === Number(tabId) &&
      Number.isSafeInteger(p.member_id) &&
      p.member_id > 0 &&
      typeof p.member_token === "string" &&
      p.member_token.length > 0 &&
      typeof p.display_name === "string"
      ? p
      : null;
  } catch {
    return null;
  }
}
export function legacySuggestion(raw: string | null): string {
  try {
    const p = JSON.parse(raw ?? "null");
    return typeof p === "string"
      ? p
      : typeof p?.display_name === "string"
        ? p.display_name
        : "";
  } catch {
    return "";
  }
}
// An old token can be authenticated through members/me. A name is never recovery.
export function recoveryToken(raw: string | null): string | undefined {
  try {
    const p = JSON.parse(raw ?? "null");
    return typeof p?.member_token === "string" ? p.member_token : undefined;
  } catch {
    return undefined;
  }
}
export function readSelection(
  raw: string | null,
  billId: number,
  participants: Participant[],
): number | null {
  try {
    const p = JSON.parse(raw ?? "null");
    return p?.version === 2 &&
      p.bill_id === billId &&
      participants.some(
        (row) =>
          row.bill_id === billId && row.participant_id === p.participant_id,
      )
      ? p.participant_id
      : null;
  } catch {
    return null;
  }
}
export const occurrenceLabel = (p: Participant) =>
  `${p.label || "Unnamed"} · #${p.participant_id}`;
