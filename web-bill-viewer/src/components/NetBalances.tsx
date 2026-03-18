"use client";

import { NetBalance } from "@/lib/api";
import { buildVenmoPayUrl } from "@/lib/venmo";
import { SiVenmo } from "react-icons/si";
import { FaArrowRight } from "react-icons/fa6";

interface NetBalancesProps {
  balances: NetBalance[];
  finalized: boolean;
  venmoId?: string | null;
  currentMemberName?: string | null;
}

export default function NetBalances({
  balances,
  finalized,
  venmoId,
  currentMemberName,
}: NetBalancesProps) {
  if (balances.length === 0) return null;

  const currentKey = currentMemberName?.toLowerCase();

  // Split into "your" balances and "other" balances
  const yourBalances = currentKey
    ? balances.filter(
        (b) =>
          b.from.toLowerCase() === currentKey ||
          b.to.toLowerCase() === currentKey
      )
    : [];
  const otherBalances = currentKey
    ? balances.filter(
        (b) =>
          b.from.toLowerCase() !== currentKey &&
          b.to.toLowerCase() !== currentKey
      )
    : balances;

  const renderBalance = (balance: NetBalance, showVenmo: boolean) => {
    const isYouFrom = currentKey && balance.from.toLowerCase() === currentKey;
    const isYouTo = currentKey && balance.to.toLowerCase() === currentKey;

    const fromLabel = isYouFrom ? "You" : balance.from;
    const toLabel = isYouTo ? "You" : balance.to;

    return (
      <div
        key={`${balance.from}-${balance.to}`}
        className="bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl px-5 py-4 shadow-sm dark:shadow-none dark:border dark:border-[var(--border-dark)] flex items-center justify-between"
      >
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-full bg-red-100 dark:bg-red-900/30 flex items-center justify-center font-semibold text-sm text-red-600 dark:text-red-400">
            {fromLabel[0]}
          </div>
          <span className="font-medium text-[var(--accent)] dark:text-white">
            {fromLabel}
          </span>
          <FaArrowRight className="text-[var(--text-secondary)] text-xs" />
          <div className="w-9 h-9 rounded-full bg-emerald-100 dark:bg-emerald-900/30 flex items-center justify-center font-semibold text-sm text-emerald-600 dark:text-emerald-400">
            {toLabel[0]}
          </div>
          <span className="font-medium text-[var(--accent)] dark:text-white">
            {toLabel}
          </span>
        </div>
        <div className="flex items-center gap-3">
          <div className="text-xl font-bold font-mono text-[var(--accent)] dark:text-white">
            ${balance.amount.toFixed(2)}
          </div>
          {showVenmo && venmoId && isYouFrom && (
            <button
              onClick={() => {
                window.location.href = buildVenmoPayUrl(
                  venmoId,
                  balance.amount.toFixed(2),
                  "Tab settlement - " + balance.to
                );
              }}
              className="h-10 px-4 bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white font-semibold rounded-xl flex items-center justify-center hover:opacity-90 transition-opacity border-none cursor-pointer"
            >
              <SiVenmo size={32} />
            </button>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="mb-6">
      {yourBalances.length > 0 && (
        <>
          <div className="mb-3 px-1">
            <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">
              Your Balances
            </h2>
          </div>
          <div className="space-y-3 mb-6">
            {yourBalances.map((b) => renderBalance(b, finalized))}
          </div>
        </>
      )}

      {otherBalances.length > 0 && (
        <>
          <div className="mb-3 px-1">
            <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">
              {yourBalances.length > 0 ? "All Balances" : "Balances"}
            </h2>
          </div>
          <div className="space-y-3">
            {otherBalances.map((b) => renderBalance(b, false))}
          </div>
        </>
      )}
    </div>
  );
}
