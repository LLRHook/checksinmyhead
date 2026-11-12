import type { ItemAssignment, PersonShare } from "./api";

// Legacy string keys are for raw historical presentation/tests only. The API
// mutation seam requires positive participant IDs and never sends a label.
const identityKey = (row: {
  participant_id?: number | null;
  person_name?: string;
}) =>
  row.participant_id != null
    ? row.participant_id
    : (row.person_name ?? "").trim().toLowerCase();
const selectorKey = (value: string | number) =>
  typeof value === "number" ? value : value.toLowerCase();
type LazyBillBalance = {
  total: number;
  person_shares: Pick<PersonShare, "total" | "paid">[];
  exchange_rate?: number;
  display_total?: number;
  display_currency?: string;
  currency_code?: string;
};

export type LazyAssignmentDraft = {
  assignments: ItemAssignment[];
  expectedUpdatedAt?: string;
};

export function updateLazyAssignmentDraft(
  drafts: Record<number, LazyAssignmentDraft> | null,
  itemId: number,
  assignments: ItemAssignment[],
  currentUpdatedAt?: string,
): Record<number, LazyAssignmentDraft> {
  return {
    ...drafts,
    [itemId]: {
      assignments,
      expectedUpdatedAt:
        drafts && itemId in drafts
          ? drafts[itemId].expectedUpdatedAt
          : currentUpdatedAt,
    },
  };
}

export function lazyBillRemainingTotal(bill: LazyBillBalance): number {
  const paidTotal = bill.person_shares
    .filter((share) => share.paid)
    .reduce((sum, share) => sum + share.total, 0);
  const remaining = Math.max(0, bill.total - paidTotal);
  const exchangeRate = bill.exchange_rate;
  const rate =
    typeof exchangeRate === "number" &&
    Number.isFinite(exchangeRate) &&
    exchangeRate > 0
      ? exchangeRate
      : bill.total > 0 && bill.display_total != null
        ? bill.display_total / bill.total
        : 1;
  return Math.round((remaining * rate + Number.EPSILON) * 100) / 100;
}

export function lazyBillRemainingCurrency(bill: LazyBillBalance): string {
  return bill.display_currency ?? bill.currency_code ?? "USD";
}

export function isLazyItemPaid(
  assignments: ItemAssignment[] | undefined,
  shares: Pick<PersonShare, "person_name" | "participant_id" | "paid">[],
): boolean {
  if (!assignments?.length) return false;
  const assignedPercentage = assignments.reduce(
    (sum, assignment) => sum + assignment.percentage,
    0,
  );
  if (assignedPercentage < 99.99) return false;
  const paidPeople = new Set(
    shares.filter((share) => share.paid).map((share) => identityKey(share)),
  );
  return assignments.every((assignment) =>
    paidPeople.has(identityKey(assignment)),
  );
}

export function isLazyItemSelectionLocked(
  itemPaid: boolean,
  currentSharePaid: boolean,
): boolean {
  return itemPaid || currentSharePaid;
}

export function lazyAssignmentsEqual(
  left: ItemAssignment[] | undefined,
  right: ItemAssignment[] | undefined,
): boolean {
  const a = [...(left ?? [])].sort((x, y) =>
    String(identityKey(x)).localeCompare(String(identityKey(y))),
  );
  const b = [...(right ?? [])].sort((x, y) =>
    String(identityKey(x)).localeCompare(String(identityKey(y))),
  );
  return (
    a.length === b.length &&
    a.every(
      (assignment, index) =>
        identityKey(assignment) === identityKey(b[index]) &&
        Math.abs(assignment.percentage - b[index].percentage) < 0.01,
    )
  );
}

export function remainingLazyPercentage(
  assignments: ItemAssignment[] | undefined,
  excludingPerson?: string | number,
): number {
  const assigned = (assignments ?? []).reduce(
    (sum, assignment) =>
      identityKey(assignment) ===
      (excludingPerson === undefined ? undefined : selectorKey(excludingPerson))
        ? sum
        : sum + assignment.percentage,
    0,
  );
  return Math.max(0, Math.min(100, 100 - assigned));
}

export function setLazyAssignmentPercentage(
  assignments: ItemAssignment[] | undefined,
  personName: string | number,
  percentage: number,
): ItemAssignment[] {
  const others = (assignments ?? []).filter(
    (assignment) => identityKey(assignment) !== selectorKey(personName),
  );
  const available = remainingLazyPercentage(others);
  const share = Math.min(available, Math.max(1, Math.round(percentage)));
  if (share < 1) return others;
  return [
    ...others,
    {
      ...(typeof personName === "number"
        ? { participant_id: personName }
        : { person_name: personName }),
      percentage: share,
    },
  ];
}

export function removeLazyAssignmentLeavingRemainder(
  assignments: ItemAssignment[],
  personName: string | number,
): ItemAssignment[] {
  return assignments.filter(
    (assignment) => identityKey(assignment) !== selectorKey(personName),
  );
}
