import type { ItemAssignment, PersonShare } from "./api";

type LazyBillBalance = {
  total: number;
  person_shares: Pick<PersonShare, "total" | "paid">[];
  exchange_rate?: number;
  display_total?: number;
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
