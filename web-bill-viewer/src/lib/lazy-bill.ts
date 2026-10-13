import type { ItemAssignment, PersonShare } from "./api";

type LazyBillBalance = {
  total: number;
  person_shares: Pick<PersonShare, "total" | "paid">[];
  exchange_rate?: number;
  display_total?: number;
  display_currency?: string;
  currency_code?: string;
};

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
  shares: Pick<PersonShare, "person_name" | "paid">[],
): boolean {
  if (!assignments?.length) return false;
  const paidPeople = new Set(
    shares
      .filter((share) => share.paid)
      .map((share) => share.person_name.trim().toLowerCase()),
  );
  return assignments.every((assignment) =>
    paidPeople.has(assignment.person_name.trim().toLowerCase()),
  );
}

export function hasPaidLazyAssignment(
  assignments: ItemAssignment[] | undefined,
  shares: Pick<PersonShare, "person_name" | "paid">[],
): boolean {
  const paidPeople = new Set(
    shares
      .filter((share) => share.paid)
      .map((share) => share.person_name.trim().toLowerCase()),
  );
  return (assignments ?? []).some((assignment) =>
    paidPeople.has(assignment.person_name.trim().toLowerCase()),
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
    x.person_name.localeCompare(y.person_name, undefined, {
      sensitivity: "base",
    }),
  );
  const b = [...(right ?? [])].sort((x, y) =>
    x.person_name.localeCompare(y.person_name, undefined, {
      sensitivity: "base",
    }),
  );
  return (
    a.length === b.length &&
    a.every(
      (assignment, index) =>
        assignment.person_name.toLowerCase() ===
          b[index].person_name.toLowerCase() &&
        Math.abs(assignment.percentage - b[index].percentage) < 0.01,
    )
  );
}

export function removeLazyAssignment(
  assignments: ItemAssignment[],
  personName: string,
): ItemAssignment[] {
  const remaining = assignments.filter(
    (assignment) =>
      assignment.person_name.toLowerCase() !== personName.toLowerCase(),
  );
  if (!remaining.length) return [];
  const total = remaining.reduce((sum, entry) => sum + entry.percentage, 0);
  if (total <= 0) return [];
  let assigned = 0;
  return remaining.map((entry, index) => {
    const percentage =
      index === remaining.length - 1
        ? 100 - assigned
        : (entry.percentage / total) * 100;
    assigned += percentage;
    return { ...entry, percentage };
  });
}

export function createLazySplitAssignments(
  personName: string,
  otherNames: string,
  personPercentage: number,
): ItemAssignment[] | null {
  const names = new Map<string, string>();
  for (const part of otherNames.split(",")) {
    const person = part.trim().slice(0, 30);
    const key = person.toLowerCase();
    if (person && key !== personName.toLowerCase() && !names.has(key)) {
      names.set(key, person);
    }
  }
  if (!names.size || !Number.isFinite(personPercentage)) return null;
  const percentage = Math.min(99, Math.max(1, Math.round(personPercentage)));
  const people = [...names.values()];
  const eachOtherPercentage = (100 - percentage) / people.length;
  return [
    { person_name: personName, percentage },
    ...people.map((person, index) => ({
      person_name: person,
      percentage:
        index === people.length - 1
          ? 100 - percentage - eachOtherPercentage * (people.length - 1)
          : eachOtherPercentage,
    })),
  ];
}
