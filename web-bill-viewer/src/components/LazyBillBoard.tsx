"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import {
  FaCircleCheck,
  FaPenToSquare,
  FaTrash,
  FaUser,
  FaUsers,
  FaXmark,
} from "react-icons/fa6";
import {
  type Bill,
  type ItemAssignment,
  updateTabBillItemAssignments,
} from "@/lib/api";

interface LazyBillBoardProps {
  tabId: string;
  token: string;
  bill: Bill;
}

type StoredMember = {
  display_name: string;
  member_token?: string;
};

type Totals = {
  person_name: string;
  subtotal: number;
  tax_share: number;
  tip_share: number;
  total: number;
};

function roundToCents(value: number): number {
  return Math.round(value * 100) / 100;
}

function computeTotals(bill: Bill): {
  people: Totals[];
  claimedSubtotal: number;
  unclaimedSubtotal: number;
} {
  const subtotalByPerson = new Map<string, Totals>();
  let claimedSubtotal = 0;
  let unclaimedSubtotal = 0;

  for (const item of bill.items) {
    const assignments = item.assignments ?? [];
    const assignedPercent = assignments.reduce(
      (sum, assignment) => sum + Math.max(assignment.percentage, 0),
      0,
    );
    const clampedPercent = Math.min(assignedPercent, 100);
    const assignedAmount = roundToCents((item.price * clampedPercent) / 100);

    claimedSubtotal += assignedAmount;
    unclaimedSubtotal += roundToCents(item.price - assignedAmount);

    for (const assignment of assignments) {
      const name = assignment.person_name.trim();
      if (!name || assignment.percentage <= 0) continue;

      const key = name.toLowerCase();
      const current = subtotalByPerson.get(key) ?? {
        person_name: name,
        subtotal: 0,
        tax_share: 0,
        tip_share: 0,
        total: 0,
      };

      if (current.person_name === key && name !== key) {
        current.person_name = name;
      }
      current.subtotal += roundToCents(
        (item.price * assignment.percentage) / 100,
      );
      subtotalByPerson.set(key, current);
    }
  }

  const assignedSubtotal = Array.from(subtotalByPerson.values()).reduce(
    (sum, entry) => sum + entry.subtotal,
    0,
  );

  const people = Array.from(subtotalByPerson.entries())
    .map(([key, entry]) => {
      const proportion =
        assignedSubtotal > 0 ? entry.subtotal / assignedSubtotal : 0;
      const taxShare = roundToCents(bill.tax * proportion);
      const tipShare = roundToCents(bill.tip_amount * proportion);
      return {
        person_name: entry.person_name || key,
        subtotal: roundToCents(entry.subtotal),
        tax_share: taxShare,
        tip_share: tipShare,
        total: roundToCents(entry.subtotal + taxShare + tipShare),
      };
    })
    .sort((a, b) =>
      a.person_name.localeCompare(b.person_name, undefined, {
        sensitivity: "base",
      }),
    );

  return { people, claimedSubtotal, unclaimedSubtotal };
}

export default function LazyBillBoard({
  tabId,
  token,
  bill,
}: LazyBillBoardProps) {
  const router = useRouter();
  const [member, setMember] = useState<StoredMember | null>(null);
  const [savingItemId, setSavingItemId] = useState<number | null>(null);
  const [activeItemId, setActiveItemId] = useState<number | null>(null);
  const [splitNames, setSplitNames] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const storageKey = `billington_member_${tabId}`;
    const stored = localStorage.getItem(storageKey);
    if (!stored) return;

    try {
      const parsed = JSON.parse(stored) as StoredMember;
      if (parsed?.display_name) {
        setMember(parsed);
      }
    } catch {
      // Ignore malformed local storage and fall back to anonymous mode.
    }
  }, [tabId]);

  const summary = useMemo(() => computeTotals(bill), [bill]);
  const currentName = member?.display_name?.trim() ?? "";

  const persistAssignments = async (
    itemId: number,
    assignments: ItemAssignment[],
  ) => {
    setSavingItemId(itemId);
    setError(null);
    try {
      await updateTabBillItemAssignments(
        tabId,
        bill.id,
        itemId,
        assignments,
        token,
      );
      router.refresh();
    } catch {
      setError("Could not save that claim. Please try again.");
    } finally {
      setSavingItemId(null);
    }
  };

  const claimForMe = async (itemId: number) => {
    if (!currentName) {
      setError("Join the tab first so we know who you are.");
      return;
    }

    await persistAssignments(itemId, [
      { person_name: currentName, percentage: 100 },
    ]);
  };

  const clearMyClaim = async (itemId: number) => {
    if (!currentName) return;

    const item = bill.items.find((entry) => entry.id === itemId);
    if (!item) return;

    const remaining = (item.assignments ?? []).filter(
      (assignment) =>
        assignment.person_name.toLowerCase() !== currentName.toLowerCase(),
    );

    await persistAssignments(itemId, remaining);
  };

  const saveSplit = async () => {
    const item = bill.items.find((entry) => entry.id === activeItemId);
    if (!item) return;

    const names = splitNames
      .split(",")
      .map((name) => name.trim())
      .filter(Boolean);

    const uniqueNames = Array.from(
      new Map(names.map((name) => [name.toLowerCase(), name])).values(),
    );
    if (uniqueNames.length === 0) {
      setError("Add at least one name to split this item.");
      return;
    }

    const percentage = roundToCents(100 / uniqueNames.length);
    await persistAssignments(
      item.id,
      uniqueNames.map((name, index) => ({
        person_name: name,
        percentage:
          index === uniqueNames.length - 1
            ? roundToCents(100 - percentage * (uniqueNames.length - 1))
            : percentage,
      })),
    );

    setActiveItemId(null);
    setSplitNames("");
  };

  return (
    <div className="space-y-6">
      <div className="rounded-3xl bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] shadow-xl dark:shadow-none dark:border dark:border-[var(--border-dark)] p-5 sm:p-6">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--text-secondary)] mb-2">
              Lazy mode
            </p>
            <h2 className="text-2xl sm:text-3xl font-bold text-[var(--accent)] dark:text-white tracking-tight">
              Claim your items
            </h2>
            <p className="mt-2 text-sm text-[var(--text-secondary)] max-w-2xl">
              Join the tab, tap the items you had, and we&apos;ll keep the
              totals synced until everything is claimed.
            </p>
          </div>

          <div className="flex flex-wrap gap-2">
            <div className="inline-flex items-center gap-2 rounded-full bg-[var(--secondary)] dark:bg-white/10 px-4 py-2">
              <FaUsers className="text-[var(--primary)]" size={13} />
              <span className="text-sm font-medium text-[var(--accent)] dark:text-white">
                {summary.people.length} people
              </span>
            </div>
            <div className="inline-flex items-center gap-2 rounded-full bg-[var(--secondary)] dark:bg-white/10 px-4 py-2">
              <FaCircleCheck className="text-emerald-600" size={13} />
              <span className="text-sm font-medium text-[var(--accent)] dark:text-white">
                {summary.claimedSubtotal.toFixed(2)} claimed
              </span>
            </div>
            <div className="inline-flex items-center gap-2 rounded-full bg-[var(--secondary)] dark:bg-white/10 px-4 py-2">
              <FaUser className="text-[var(--primary)]" size={13} />
              <span className="text-sm font-medium text-[var(--accent)] dark:text-white">
                {summary.unclaimedSubtotal.toFixed(2)} left
              </span>
            </div>
          </div>
        </div>

        {currentName ? (
          <div className="mt-5 inline-flex items-center gap-2 rounded-2xl bg-emerald-50 dark:bg-emerald-900/25 px-4 py-3 text-sm text-emerald-700 dark:text-emerald-300">
            <FaCircleCheck size={14} />
            Claiming as <span className="font-semibold">{currentName}</span>
          </div>
        ) : (
          <div className="mt-5 rounded-2xl border border-dashed border-[var(--border-light)] dark:border-[var(--border-dark)] px-4 py-3 text-sm text-[var(--text-secondary)]">
            Join the tab in the sidebar first, then come back here to claim
            items.
          </div>
        )}

        {error && (
          <div className="mt-4 rounded-2xl bg-red-50 dark:bg-red-900/20 px-4 py-3 text-sm text-red-600 dark:text-red-300">
            {error}
          </div>
        )}
      </div>

      <div className="space-y-3">
        {bill.items.map((item) => {
          const assignments = item.assignments ?? [];
          const assignedPercent = assignments.reduce(
            (sum, assignment) => sum + assignment.percentage,
            0,
          );
          const clampedPercent = Math.min(assignedPercent, 100);
          const claimed = clampedPercent > 0;
          const currentAssigned = currentName
            ? assignments.some(
                (assignment) =>
                  assignment.person_name.toLowerCase() ===
                  currentName.toLowerCase(),
              )
            : false;

          return (
            <div
              key={item.id}
              className="rounded-3xl bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] shadow-lg dark:shadow-none dark:border dark:border-[var(--border-dark)] p-5 sm:p-6"
            >
              <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                <div className="min-w-0">
                  <div className="flex items-center gap-3">
                    <h3 className="text-lg font-semibold text-[var(--accent)] dark:text-white">
                      {item.name}
                    </h3>
                    <span className="rounded-full bg-[var(--secondary)] dark:bg-white/10 px-3 py-1 text-xs font-semibold text-[var(--text-secondary)]">
                      ${item.price.toFixed(2)}
                    </span>
                  </div>
                  <p className="mt-2 text-sm text-[var(--text-secondary)]">
                    {claimed
                      ? `${clampedPercent.toFixed(0)}% claimed`
                      : "Not claimed yet"}
                  </p>

                  {assignments.length > 0 && (
                    <div className="mt-3 flex flex-wrap gap-2">
                      {assignments.map((assignment) => (
                        <span
                          key={`${item.id}-${assignment.person_name}`}
                          className="inline-flex items-center gap-2 rounded-full bg-[var(--secondary)] dark:bg-white/10 px-3 py-1 text-xs font-medium text-[var(--accent)] dark:text-white"
                        >
                          {assignment.person_name}
                          <span className="text-[var(--text-secondary)]">
                            {assignment.percentage.toFixed(0)}%
                          </span>
                        </span>
                      ))}
                    </div>
                  )}
                </div>

                <div className="flex flex-wrap gap-2">
                  <button
                    type="button"
                    onClick={() => claimForMe(item.id)}
                    disabled={!currentName || savingItemId === item.id}
                    className="inline-flex items-center gap-2 rounded-2xl bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] px-4 py-3 text-sm font-semibold text-white shadow-md transition-opacity hover:opacity-90 disabled:opacity-50"
                  >
                    <FaCircleCheck size={14} />
                    Claim
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setActiveItemId(item.id);
                      setSplitNames(currentName ?? "");
                      setError(null);
                    }}
                    className="inline-flex items-center gap-2 rounded-2xl border border-[var(--border-light)] dark:border-[var(--border-dark)] px-4 py-3 text-sm font-semibold text-[var(--accent)] dark:text-white transition-colors hover:bg-[var(--secondary)]/70 dark:hover:bg-white/5"
                  >
                    <FaPenToSquare size={14} />
                    Split
                  </button>
                  {currentAssigned && (
                    <button
                      type="button"
                      onClick={() => clearMyClaim(item.id)}
                      disabled={savingItemId === item.id}
                      className="inline-flex items-center gap-2 rounded-2xl border border-[var(--border-light)] dark:border-[var(--border-dark)] px-4 py-3 text-sm font-semibold text-[var(--text-secondary)] transition-colors hover:bg-red-50 dark:hover:bg-red-950/30 hover:text-red-600 disabled:opacity-50"
                    >
                      <FaTrash size={13} />
                      Clear
                    </button>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {activeItemId !== null && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center px-4">
          <button
            type="button"
            aria-label="Close split editor"
            className="absolute inset-0 bg-black/50 backdrop-blur-sm"
            onClick={() => setActiveItemId(null)}
          />
          <div className="relative w-full max-w-md rounded-t-3xl sm:rounded-3xl bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] shadow-2xl dark:shadow-none dark:border dark:border-[var(--border-dark)] p-6">
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-xs font-semibold uppercase tracking-[0.2em] text-[var(--text-secondary)] mb-2">
                  Split item
                </p>
                <h3 className="text-xl font-bold text-[var(--accent)] dark:text-white">
                  {bill.items.find((item) => item.id === activeItemId)?.name}
                </h3>
              </div>
              <button
                type="button"
                onClick={() => setActiveItemId(null)}
                className="rounded-full p-2 text-[var(--text-secondary)] transition-colors hover:bg-[var(--secondary)] dark:hover:bg-white/5"
              >
                <FaXmark size={14} />
              </button>
            </div>

            <p className="mt-3 text-sm text-[var(--text-secondary)]">
              Enter names separated by commas. The item will be split evenly.
            </p>

            <input
              type="text"
              value={splitNames}
              onChange={(e) => setSplitNames(e.target.value)}
              placeholder="Alex, Jamie, Sam"
              className="mt-4 w-full rounded-2xl border border-[var(--border-light)] dark:border-[var(--border-dark)] bg-white dark:bg-black/20 px-4 py-3 text-[var(--accent)] dark:text-white placeholder:text-[var(--text-secondary)] focus:outline-none focus-visible:ring-2 focus-visible:ring-[var(--primary)]"
            />

            <div className="mt-5 flex gap-3">
              <button
                type="button"
                onClick={() => setActiveItemId(null)}
                className="flex-1 rounded-2xl border border-[var(--border-light)] dark:border-[var(--border-dark)] px-4 py-3 text-sm font-semibold text-[var(--text-secondary)] transition-colors hover:bg-[var(--secondary)] dark:hover:bg-white/5"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={saveSplit}
                disabled={savingItemId !== null}
                className="flex-1 rounded-2xl bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] px-4 py-3 text-sm font-semibold text-white shadow-md transition-opacity hover:opacity-90 disabled:opacity-50"
              >
                Save split
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
