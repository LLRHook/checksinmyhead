"use client";

import { useState } from "react";
import { TabSettlement, updateSettlementPaid } from "@/lib/api";
import { buildVenmoPayUrl } from "@/lib/venmo";
import { SiVenmo } from "react-icons/si";
import { FaCheck } from "react-icons/fa6";

interface SettlementCardProps {
  settlements: TabSettlement[];
  venmoId?: string | null;
  tabId: string;
  token: string;
}

export default function SettlementCard({
  settlements: initialSettlements,
  venmoId,
  tabId,
  token,
}: SettlementCardProps) {
  const [settlements, setSettlements] = useState(initialSettlements);
  const [togglingId, setTogglingId] = useState<number | null>(null);

  const paidCount = settlements.filter((s) => s.paid).length;

  const togglePaid = async (settlement: TabSettlement) => {
    if (togglingId !== null) return;
    const newPaid = !settlement.paid;
    setTogglingId(settlement.id);

    // Optimistic update
    setSettlements((prev) =>
      prev.map((s) => (s.id === settlement.id ? { ...s, paid: newPaid } : s))
    );

    try {
      await updateSettlementPaid(tabId, settlement.id, newPaid, token);
    } catch {
      // Revert on error
      setSettlements((prev) =>
        prev.map((s) =>
          s.id === settlement.id ? { ...s, paid: !newPaid } : s
        )
      );
    } finally {
      setTogglingId(null);
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
              <button
                onClick={() => togglePaid(settlement)}
                disabled={togglingId !== null}
                className={`w-11 h-11 rounded-full flex items-center justify-center font-semibold text-base transition-colors cursor-pointer border-none ${
                  settlement.paid
                    ? "bg-emerald-100 dark:bg-emerald-900/40 text-emerald-600 dark:text-emerald-400"
                    : "bg-[var(--secondary)] dark:bg-white/10 text-[var(--text-secondary)] hover:bg-emerald-50 dark:hover:bg-emerald-900/20 hover:text-emerald-500"
                } ${togglingId !== null ? "opacity-50" : ""}`}
                aria-label={`Mark ${settlement.person_name} as ${settlement.paid ? "unpaid" : "paid"}`}
              >
                {settlement.paid ? (
                  <FaCheck size={16} />
                ) : (
                  settlement.person_name[0]
                )}
              </button>
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
                  onClick={() => {
                    window.location.href = buildVenmoPayUrl(venmoId, settlement.amount.toFixed(2), "Tab settlement - " + settlement.person_name);
                  }}
                  className="h-10 px-4 bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white font-semibold rounded-xl flex items-center justify-center hover:opacity-90 transition-opacity border-none cursor-pointer"
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
