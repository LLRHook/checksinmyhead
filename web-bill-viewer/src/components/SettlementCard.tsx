"use client";

import { TabSettlement } from "@/lib/api";
import { SiVenmo } from "react-icons/si";
import { FaCheck } from "react-icons/fa6";

interface SettlementCardProps {
  settlements: TabSettlement[];
  venmoId?: string | null;
}

export default function SettlementCard({
  settlements,
  venmoId,
}: SettlementCardProps) {
  const paidCount = settlements.filter((s) => s.paid).length;

  const handleVenmoClick = (amount: number) => {
    if (venmoId) {
      window.open(
        `venmo://paycharge?txn=pay&recipients=${venmoId}&amount=${amount.toFixed(2)}&note=The Billington`,
        "_blank",
      );
    }
  };

  return (
    <div className="mb-6">
      <div className="flex items-center justify-between mb-3 px-1">
        <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">
          Settlements
        </h2>
        <span className="text-xs font-medium text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-900/30 px-2 py-0.5 rounded-full">
          {paidCount}/{settlements.length} paid
        </span>
      </div>
      <div className="space-y-3">
        {settlements.map((settlement) => (
          <div
            key={settlement.id}
            className={`bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl px-5 py-4 shadow-sm dark:shadow-none flex items-center justify-between transition-opacity ${
              settlement.paid
                ? "dark:border dark:border-emerald-800/50 opacity-75"
                : "dark:border dark:border-[var(--border-dark)]"
            }`}
          >
            <div className="flex items-center gap-4">
              <div
                className={`w-11 h-11 rounded-full flex items-center justify-center font-semibold text-base ${
                  settlement.paid
                    ? "bg-emerald-100 dark:bg-emerald-900/40 text-emerald-600 dark:text-emerald-400"
                    : "bg-[var(--secondary)] dark:bg-white/10 text-[var(--text-secondary)]"
                }`}
              >
                {settlement.paid ? (
                  <FaCheck size={16} />
                ) : (
                  settlement.person_name[0]
                )}
              </div>
              <div>
                <h3
                  className={`font-semibold text-base ${
                    settlement.paid
                      ? "text-[var(--text-secondary)] line-through"
                      : "text-[var(--accent)] dark:text-white"
                  }`}
                >
                  {settlement.person_name}
                </h3>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <div
                className={`text-xl font-bold font-mono ${
                  settlement.paid
                    ? "text-emerald-600 dark:text-emerald-400"
                    : "text-[var(--accent)] dark:text-white"
                }`}
              >
                ${settlement.amount.toFixed(2)}
              </div>
              {!settlement.paid && venmoId && (
                <button
                  onClick={() => handleVenmoClick(settlement.amount)}
                  className="h-10 px-4 bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white font-semibold rounded-xl flex items-center justify-center hover:opacity-90 transition-opacity"
                >
                  <SiVenmo size={32} />
                </button>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
