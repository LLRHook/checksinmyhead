import type { ItemAssignment, PersonShare } from "./api";

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
