"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import {
  FaArrowRight,
  FaCheck,
  FaChevronLeft,
  FaCodeBranch,
} from "react-icons/fa6";
import {
  type Bill,
  getTab,
  type ItemAssignment,
  joinTab,
  updateLazyBillItemAssignments,
  updateLazyBillItemAssignmentsBatch,
  updatePersonSharePaid,
  updateTabBillItemAssignments,
  updateTabBillItemAssignmentsBatch,
  updateTabPersonSharePaid,
} from "@/lib/api";
import { formatMoney } from "@/lib/currency";
import {
  isLazyItemPaid,
  isLazyItemSelectionLocked,
  lazyBillRemainingCurrency,
  lazyBillRemainingTotal,
} from "@/lib/lazy-bill";
import { buildVenmoPayUrl } from "@/lib/venmo";

interface LazyBillBoardProps {
  bill: Bill;
  token: string;
  tabId?: string;
  refreshBill?: (updatedBill?: Bill) => Promise<void>;
}

type StoredMember = { display_name: string; member_token?: string };
type Stage = "receipt" | "picker" | "pay";

function round(value: number) {
  return Math.round(value * 100) / 100;
}

export default function LazyBillBoard({
  bill: initialBill,
  token,
  tabId,
  refreshBill,
}: LazyBillBoardProps) {
  const router = useRouter();
  const [billOverride, setBillOverride] = useState<{
    source: Bill;
    bill: Bill;
  } | null>(null);
  const bill =
    billOverride?.source === initialBill ? billOverride.bill : initialBill;
  const [stage, setStage] = useState<Stage>("receipt");
  const [member, setMember] = useState<StoredMember | null>(null);
  const [nameInput, setNameInput] = useState("");
  const [showJoin, setShowJoin] = useState(false);
  const [splitItemId, setSplitItemId] = useState<number | null>(null);
  const [splitNames, setSplitNames] = useState("");
  const [savingItemId, setSavingItemId] = useState<number | null>(null);
  const [selectedItemIds, setSelectedItemIds] = useState<Set<number> | null>(
    null,
  );
  const [isSavingSelection, setIsSavingSelection] = useState(false);
  const [isPaying, setIsPaying] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const currency = bill.currency_code ?? "USD";
  const remainingCurrency = lazyBillRemainingCurrency(bill);

  useEffect(() => {
    const storageKey = tabId
      ? `billington_member_${tabId}`
      : `billington_lazy_bill_${bill.id}`;
    const stored = localStorage.getItem(storageKey);
    if (!stored) return;
    try {
      const parsed = JSON.parse(stored) as StoredMember | string;
      setMember(typeof parsed === "string" ? { display_name: parsed } : parsed);
    } catch {
      localStorage.removeItem(storageKey);
    }
  }, [bill.id, tabId]);

  useEffect(() => {
    if (!tabId) return;
    const refresh = () => {
      if (document.visibilityState === "visible") router.refresh();
    };
    const interval = window.setInterval(refresh, 10_000);
    window.addEventListener("focus", refresh);
    document.addEventListener("visibilitychange", refresh);
    return () => {
      window.clearInterval(interval);
      window.removeEventListener("focus", refresh);
      document.removeEventListener("visibilitychange", refresh);
    };
  }, [router, tabId]);

  const name = member?.display_name?.trim() ?? "";
  const currentShare = bill.person_shares.find(
    (share) => share.person_name.toLowerCase() === name.toLowerCase(),
  );
  const assignedItemIds = new Set(
    bill.items
      .filter((item) =>
        (item.assignments ?? []).some(
          (assignment) =>
            assignment.person_name.toLowerCase() === name.toLowerCase(),
        ),
      )
      .map((item) => item.id),
  );
  const selectedIds = selectedItemIds ?? assignedItemIds;
  const selectionChanged =
    selectedIds.size !== assignedItemIds.size ||
    [...selectedIds].some((itemId) => !assignedItemIds.has(itemId));
  const totals = useMemo(() => {
    if (!name) return null;
    if (currentShare) return currentShare;
    const subtotal = bill.items.reduce((sum, item) => {
      const assignment = (item.assignments ?? []).find(
        (entry) => entry.person_name.toLowerCase() === name.toLowerCase(),
      );
      return (
        sum + (assignment ? (item.price * assignment.percentage) / 100 : 0)
      );
    }, 0);
    const assigned = bill.items.reduce(
      (sum, item) =>
        sum +
        (item.assignments ?? []).reduce(
          (itemSum, assignment) =>
            itemSum + (item.price * assignment.percentage) / 100,
          0,
        ),
      0,
    );
    const proportion = assigned > 0 ? subtotal / assigned : 0;
    const tax = round(bill.tax * proportion);
    const tip = round(bill.tip_amount * proportion);
    return {
      id: 0,
      person_name: name,
      subtotal: round(subtotal),
      tax_share: tax,
      tip_share: tip,
      total: round(subtotal + tax + tip),
      paid: false,
    };
  }, [bill, currentShare, name]);

  const saveAssignments = async (
    itemId: number,
    assignments: ItemAssignment[],
  ) => {
    const item = bill.items.find((entry) => entry.id === itemId);
    if (!item) return;
    setSavingItemId(itemId);
    setError(null);
    try {
      if (tabId) {
        await updateTabBillItemAssignments(
          tabId,
          bill.id,
          itemId,
          assignments,
          token,
          item.updated_at,
          member?.member_token,
        );
      } else {
        await updateLazyBillItemAssignments(
          bill.id,
          itemId,
          assignments,
          token,
          item.updated_at,
        );
      }
      await refreshViewerBill();
    } catch (caught) {
      setError(
        caught instanceof Error && caught.message.includes("item changed")
          ? "Someone updated that item. The receipt has been refreshed."
          : "Could not save that selection. Try again.",
      );
      await refreshViewerBill();
    } finally {
      setSavingItemId(null);
    }
  };

  const refreshViewerBill = async (updatedBill?: Bill) => {
    if (refreshBill) {
      await refreshBill(updatedBill);
      return;
    }
    if (updatedBill) {
      setBillOverride({ source: initialBill, bill: updatedBill });
      return;
    }
    if (tabId) {
      try {
        const tab = await getTab(tabId, token);
        const refreshedBill = tab.bills.find((entry) => entry.id === bill.id);
        if (refreshedBill) {
          setBillOverride({ source: initialBill, bill: refreshedBill });
          return;
        }
      } catch {
        // Fall back to the route refresh if the tab read fails.
      }
    }
    router.refresh();
  };

  const beginPicking = () => {
    setError(null);
    if (!name) setShowJoin(true);
    else setStage("picker");
  };

  const reviewSelection = async () => {
    if (isSavingSelection || currentShare?.paid) return;
    if (!selectionChanged) {
      setStage("pay");
      return;
    }
    const updates = bill.items.flatMap((item) => {
      const assignments = item.assignments ?? [];
      const currentlyMine = assignments.some(
        (assignment) =>
          assignment.person_name.toLowerCase() === name.toLowerCase(),
      );
      const shouldBeMine = selectedIds.has(item.id);
      if (currentlyMine === shouldBeMine) return [];
      return [
        {
          itemId: item.id,
          expectedUpdatedAt: item.updated_at,
          assignments: shouldBeMine
            ? [{ person_name: name, percentage: 100 }]
            : [],
        },
      ];
    });
    setIsSavingSelection(true);
    setError(null);
    try {
      let updatedBill: Bill | undefined;
      if (tabId) {
        if (updates.length) {
          await updateTabBillItemAssignmentsBatch(
            tabId,
            bill.id,
            updates.map(({ itemId, expectedUpdatedAt, assignments }) => ({
              item_id: itemId,
              expected_updated_at: expectedUpdatedAt,
              assignments,
            })),
            token,
            member?.member_token,
          );
        }
      } else if (updates.length) {
        updatedBill = await updateLazyBillItemAssignmentsBatch(
          bill.id,
          updates.map(({ itemId, expectedUpdatedAt, assignments }) => ({
            item_id: itemId,
            expected_updated_at: expectedUpdatedAt,
            assignments,
          })),
          token,
        );
      }
      await refreshViewerBill(updatedBill);
      setSelectedItemIds(null);
      setStage("pay");
    } catch (caught) {
      setError(
        caught instanceof Error && caught.message.includes("item changed")
          ? "Someone updated an item. The receipt has been refreshed."
          : "Could not save your choices. Try again.",
      );
      await refreshViewerBill();
      setSelectedItemIds(null);
    } finally {
      setIsSavingSelection(false);
    }
  };

  const saveName = async () => {
    const displayName = nameInput.trim();
    if (!displayName || displayName.length > 30) {
      setError("Use a name between 1 and 30 characters.");
      return;
    }
    setError(null);
    try {
      if (tabId) {
        const result = await joinTab(tabId, token, displayName);
        if (!result) throw new Error("join failed");
        localStorage.setItem(
          `billington_member_${tabId}`,
          JSON.stringify(result),
        );
        setMember(result);
      } else {
        localStorage.setItem(
          `billington_lazy_bill_${bill.id}`,
          JSON.stringify({ display_name: displayName }),
        );
        setMember({ display_name: displayName });
      }
      setShowJoin(false);
      setStage("picker");
    } catch {
      setError("Could not save your name. Try again.");
    }
  };

  const setSplit = () => {
    const item = bill.items.find((entry) => entry.id === splitItemId);
    if (!item) return;
    const names = Array.from(
      new Map(
        splitNames
          .split(",")
          .map((part) => part.trim().slice(0, 30))
          .filter(Boolean)
          .map((person) => [person.toLowerCase(), person]),
      ).values(),
    );
    if (!names.length) {
      setError("Add at least one person.");
      return;
    }
    const percentage = round(100 / names.length);
    void saveAssignments(
      item.id,
      names.map((person, index) => ({
        person_name: person,
        percentage:
          index === names.length - 1
            ? round(100 - percentage * (names.length - 1))
            : percentage,
      })),
    );
    setSplitItemId(null);
    setSplitNames("");
  };

  const markPaid = async () => {
    if (!currentShare?.id) return;
    setIsPaying(true);
    setError(null);
    try {
      if (tabId) {
        await updateTabPersonSharePaid(
          tabId,
          bill.id,
          currentShare.id,
          true,
          token,
          member?.member_token,
        );
      } else {
        await updatePersonSharePaid(bill.id, currentShare.id, true, token);
      }
      setStage("receipt");
      await refreshViewerBill();
    } catch {
      setError("We could not save that payment yet.");
    } finally {
      setIsPaying(false);
    }
  };

  const venmo = bill.payment_methods?.find((method) =>
    method.name.toLowerCase().includes("venmo"),
  );

  return (
    <div className="space-y-5">
      {stage === "receipt" && (
        <>
          <div className="rounded-3xl bg-[var(--card-bg-light)] p-5 shadow-sm dark:bg-[var(--card-bg-dark)] dark:border dark:border-[var(--border-dark)] sm:p-7">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--text-secondary)]">
              Receipt
            </p>
            <h2 className="mt-1 text-xl font-bold text-[var(--accent)] dark:text-white">
              {bill.name}
            </h2>
            <div className="mt-4 divide-y divide-[var(--border-light)] dark:divide-[var(--border-dark)]">
              {bill.items.map((item) => (
                <div
                  className="flex items-center justify-between gap-3 py-3 text-sm text-[var(--accent)] dark:text-white"
                  key={item.id}
                >
                  <span
                    className={
                      isLazyItemPaid(item.assignments, bill.person_shares)
                        ? "line-through opacity-60"
                        : ""
                    }
                  >
                    {item.name}
                  </span>
                  <span className="flex shrink-0 items-center gap-2">
                    {isLazyItemPaid(item.assignments, bill.person_shares) && (
                      <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-medium text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300">
                        Paid
                      </span>
                    )}
                    <span className="font-mono">
                      {formatMoney(item.price, currency)}
                    </span>
                  </span>
                </div>
              ))}
            </div>
            <div className="mt-3 border-t border-[var(--border-light)] pt-3 text-sm dark:border-[var(--border-dark)]">
              <div className="flex justify-between text-[var(--text-secondary)]">
                <span>Remaining balance</span>
                <span className="font-mono">
                  {formatMoney(lazyBillRemainingTotal(bill), remainingCurrency)}
                </span>
              </div>
            </div>
          </div>
          <div className="rounded-3xl bg-[var(--primary)] p-5 text-white shadow-lg sm:p-7">
            <p className="text-sm text-white/75">
              Choose what you had. We’ll handle the math.
            </p>
            <button
              type="button"
              onClick={beginPicking}
              className="mt-4 inline-flex w-full items-center justify-center gap-3 rounded-2xl bg-white px-5 py-4 text-base font-bold text-[var(--primary-dark)]"
            >
              {name ? "Pick my items" : "Choose my items"}
              <FaArrowRight size={14} />
            </button>
          </div>
        </>
      )}

      {stage === "picker" && (
        <>
          <button
            type="button"
            onClick={() => setStage("receipt")}
            className="inline-flex items-center gap-2 text-sm font-semibold text-[var(--text-secondary)]"
          >
            <FaChevronLeft size={12} /> Receipt
          </button>
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--text-secondary)]">
              Your items
            </p>
            <h2 className="mt-1 text-2xl font-bold text-[var(--accent)] dark:text-white">
              What did you have, {name}?
            </h2>
          </div>
          <div className="overflow-hidden rounded-3xl bg-[var(--card-bg-light)] shadow-sm dark:bg-[var(--card-bg-dark)] dark:border dark:border-[var(--border-dark)]">
            {bill.items.map((item) => {
              const assignments = item.assignments ?? [];
              const paid = isLazyItemPaid(assignments, bill.person_shares);
              const mine = selectedIds.has(item.id);
              const unavailable = assignments.some(
                (entry) =>
                  entry.person_name.toLowerCase() !== name.toLowerCase(),
              );
              const locked = isLazyItemSelectionLocked(
                paid,
                Boolean(currentShare?.paid),
              );
              return (
                <div
                  key={item.id}
                  className={`flex items-center gap-3 border-b border-[var(--border-light)] px-4 py-4 last:border-0 dark:border-[var(--border-dark)] ${locked ? "opacity-50" : ""}`}
                >
                  <button
                    type="button"
                    aria-label={`${mine ? "Unselect" : "Select"} ${item.name}`}
                    disabled={
                      unavailable ||
                      locked ||
                      isSavingSelection ||
                      savingItemId === item.id ||
                      (mine && assignments.length > 1) ||
                      (assignments.length > 1 && !mine)
                    }
                    onClick={() => {
                      const next = new Set(selectedIds);
                      if (mine) next.delete(item.id);
                      else next.add(item.id);
                      setSelectedItemIds(next);
                      setError(null);
                    }}
                    className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border-2 ${mine ? "border-[var(--primary)] bg-[var(--primary)] text-white" : "border-[var(--border-light)] dark:border-[var(--border-dark)]"}`}
                  >
                    {mine && <FaCheck size={12} />}
                  </button>
                  <div
                    className={`min-w-0 flex-1 ${locked ? "line-through" : ""}`}
                  >
                    <p className="font-medium text-[var(--accent)] dark:text-white">
                      {item.name}
                    </p>
                    <p className="text-xs text-[var(--text-secondary)]">
                      {locked
                        ? paid
                          ? "Paid"
                          : "Your share paid"
                        : unavailable
                          ? `Taken by ${assignments[0]?.person_name ?? "someone"}`
                          : formatMoney(item.price, currency)}
                    </p>
                  </div>
                  <button
                    type="button"
                    disabled={
                      unavailable ||
                      locked ||
                      isSavingSelection ||
                      savingItemId === item.id
                    }
                    onClick={() => {
                      setSplitItemId(item.id);
                      setSplitNames(
                        [
                          name,
                          ...assignments
                            .filter(
                              (entry) =>
                                entry.person_name.toLowerCase() !==
                                name.toLowerCase(),
                            )
                            .map((entry) => entry.person_name),
                        ]
                          .filter(Boolean)
                          .join(", "),
                      );
                    }}
                    aria-label={`Split ${item.name}`}
                    className="rounded-xl p-3 text-[var(--text-secondary)] hover:bg-[var(--secondary)] disabled:opacity-30"
                  >
                    <FaCodeBranch size={14} />
                  </button>
                </div>
              );
            })}
          </div>
          {((totals?.total ?? 0) > 0 || selectionChanged) && (
            <button
              type="button"
              disabled={isSavingSelection}
              onClick={() => void reviewSelection()}
              className="flex w-full items-center justify-center gap-3 rounded-2xl bg-[var(--primary)] px-5 py-4 font-bold text-white shadow-md disabled:opacity-70"
            >
              {isSavingSelection ? "Saving choices…" : "Review my total"}
              {!isSavingSelection && <FaArrowRight size={14} />}
            </button>
          )}
        </>
      )}

      {stage === "pay" && totals && (
        <>
          <button
            type="button"
            onClick={() => setStage("picker")}
            className="inline-flex items-center gap-2 text-sm font-semibold text-[var(--text-secondary)]"
          >
            <FaChevronLeft size={12} /> Back to items
          </button>
          <div className="rounded-3xl bg-[var(--card-bg-light)] p-6 shadow-sm dark:bg-[var(--card-bg-dark)] dark:border dark:border-[var(--border-dark)]">
            <p className="text-sm font-semibold uppercase tracking-[0.18em] text-[var(--text-secondary)]">
              Your total
            </p>
            <p className="mt-2 text-5xl font-bold tracking-tight text-[var(--accent)] dark:text-white">
              {formatMoney(totals.total, currency)}
            </p>
            <div className="mt-6 space-y-2 border-t border-[var(--border-light)] pt-4 text-sm dark:border-[var(--border-dark)]">
              <div className="flex justify-between">
                <span>Your items</span>
                <span>{formatMoney(totals.subtotal, currency)}</span>
              </div>
              <div className="flex justify-between">
                <span>Tax</span>
                <span>{formatMoney(totals.tax_share, currency)}</span>
              </div>
              <div className="flex justify-between">
                <span>Tip</span>
                <span>{formatMoney(totals.tip_share, currency)}</span>
              </div>
            </div>
          </div>
          <div className="rounded-3xl bg-[var(--card-bg-light)] p-5 shadow-sm dark:bg-[var(--card-bg-dark)] dark:border dark:border-[var(--border-dark)]">
            <h2 className="font-bold text-[var(--accent)] dark:text-white">
              Pay {name}
            </h2>
            {venmo && (
              <a
                href={buildVenmoPayUrl(
                  venmo.identifier,
                  totals.total.toFixed(2),
                  bill.name,
                )}
                className="mt-4 flex items-center justify-center rounded-2xl bg-[#4b938d] px-4 py-4 font-bold text-white"
              >
                Pay with Venmo
              </a>
            )}
            {bill.payment_methods?.map((method) => (
              <p
                key={`${method.name}-${method.identifier}`}
                className="mt-3 text-sm text-[var(--text-secondary)]"
              >
                {method.name}: {method.identifier}
              </p>
            ))}
            <button
              type="button"
              disabled={isPaying || !currentShare?.id}
              onClick={markPaid}
              className="mt-5 w-full rounded-2xl border border-[var(--border-light)] px-4 py-3 text-sm font-semibold text-[var(--accent)] disabled:opacity-50 dark:border-[var(--border-dark)] dark:text-white"
            >
              {isPaying ? "Saving…" : "Mark as paid"}
            </button>
          </div>
        </>
      )}

      {error && (
        <p
          role="alert"
          className="rounded-2xl bg-red-50 px-4 py-3 text-sm text-red-600 dark:bg-red-950/30 dark:text-red-300"
        >
          {error}
        </p>
      )}
      {showJoin && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-4 sm:items-center">
          <div className="w-full max-w-md rounded-3xl bg-[var(--card-bg-light)] p-6 shadow-2xl dark:bg-[var(--card-bg-dark)]">
            <h2 className="text-xl font-bold text-[var(--accent)] dark:text-white">
              What should we call you?
            </h2>
            <p className="mt-2 text-sm text-[var(--text-secondary)]">
              Use a name friends will recognize.
            </p>
            <input
              value={nameInput}
              maxLength={30}
              onChange={(event) => setNameInput(event.target.value)}
              onKeyDown={(event) => event.key === "Enter" && void saveName()}
              placeholder="Your name"
              className="mt-5 w-full rounded-2xl border border-[var(--border-light)] bg-white px-4 py-3 dark:border-[var(--border-dark)] dark:bg-black/20 dark:text-white"
            />
            <div className="mt-5 flex gap-3">
              <button
                type="button"
                onClick={() => setShowJoin(false)}
                className="flex-1 rounded-2xl border border-[var(--border-light)] px-4 py-3 text-sm font-semibold text-[var(--text-secondary)]"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => void saveName()}
                className="flex-1 rounded-2xl bg-[var(--primary)] px-4 py-3 text-sm font-semibold text-white"
              >
                Continue
              </button>
            </div>
          </div>
        </div>
      )}
      {splitItemId !== null && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-4 sm:items-center">
          <div className="w-full max-w-md rounded-3xl bg-[var(--card-bg-light)] p-6 shadow-2xl dark:bg-[var(--card-bg-dark)]">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--text-secondary)]">
              Split item
            </p>
            <h2 className="mt-2 text-xl font-bold text-[var(--accent)] dark:text-white">
              Who had this?
            </h2>
            <input
              value={splitNames}
              onChange={(event) => setSplitNames(event.target.value)}
              placeholder="You, Alex"
              className="mt-5 w-full rounded-2xl border border-[var(--border-light)] bg-white px-4 py-3 dark:border-[var(--border-dark)] dark:bg-black/20 dark:text-white"
            />
            <div className="mt-5 flex gap-3">
              <button
                type="button"
                onClick={() => setSplitItemId(null)}
                className="flex-1 rounded-2xl border border-[var(--border-light)] px-4 py-3 text-sm font-semibold text-[var(--text-secondary)]"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={setSplit}
                className="flex-1 rounded-2xl bg-[var(--primary)] px-4 py-3 text-sm font-semibold text-white"
              >
                Split evenly
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
