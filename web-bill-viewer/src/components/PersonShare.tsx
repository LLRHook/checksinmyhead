"use client";

import { useState } from "react";
import { FaCheck, FaChevronDown } from "react-icons/fa6";
import { SiVenmo } from "react-icons/si";
import { useCollapsible } from "@/hooks/useCollapsible";
import {
  type Bill,
  formatMoney,
  type PersonShare as PersonShareType,
  updatePersonSharePaid,
} from "@/lib/api";
import { billCurrencyCode, formatUSDMoney, toUSD } from "@/lib/currency";
import { buildVenmoPayUrl } from "@/lib/venmo";

interface PersonShareProps {
  personShare: PersonShareType;
  bill: Bill;
  hasVenmo?: string | null;
  billId: number;
  token: string;
  readOnly?: boolean;
  currency?: string;
}

export default function PersonShare({
  personShare,
  bill,
  hasVenmo,
  billId,
  token,
  readOnly = false,
  currency = "USD",
}: PersonShareProps) {
  const { isOpen, toggle, contentRef, height } = useCollapsible();
  const [paid, setPaid] = useState(personShare.paid);
  const [toggling, setToggling] = useState(false);
  const isForeignCurrency = billCurrencyCode(bill) !== "USD";
  const usdTotal = toUSD(personShare.total, bill);

  const togglePaid = async (e: React.MouseEvent) => {
    e.stopPropagation();
    if (toggling) return;
    const newPaid = !paid;
    setToggling(true);
    setPaid(newPaid);

    try {
      await updatePersonSharePaid(billId, personShare.id, newPaid, token);
    } catch {
      setPaid(!newPaid);
    } finally {
      setToggling(false);
    }
  };

  return (
    <div
      className={`bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl overflow-hidden shadow-sm dark:shadow-none transition-all duration-200 ${
        paid
          ? "dark:border dark:border-emerald-800/50 opacity-75"
          : "dark:border dark:border-[var(--border-dark)]"
      }`}
    >
      <div className="w-full px-5 py-4 flex items-center justify-between">
        <div className="flex items-center gap-4">
          {readOnly ? (
            <div
              className={`w-11 h-11 rounded-full flex items-center justify-center font-semibold text-base ${paid ? "bg-emerald-100 dark:bg-emerald-900/40 text-emerald-600 dark:text-emerald-400" : "bg-[var(--secondary)] dark:bg-white/10 text-[var(--text-secondary)]"}`}
              aria-hidden="true"
            >
              {paid ? <FaCheck size={16} /> : personShare.person_name[0]}
            </div>
          ) : (
            <button
              type="button"
              onClick={togglePaid}
              disabled={toggling}
              className={`w-11 h-11 rounded-full flex items-center justify-center font-semibold text-base transition-colors cursor-pointer border-none ${
                paid
                  ? "bg-emerald-100 dark:bg-emerald-900/40 text-emerald-600 dark:text-emerald-400"
                  : "bg-[var(--secondary)] dark:bg-white/10 text-[var(--text-secondary)] hover:bg-emerald-50 dark:hover:bg-emerald-900/20 hover:text-emerald-500"
              } ${toggling ? "opacity-50" : ""}`}
              aria-label={`Mark ${personShare.person_name} as ${paid ? "unpaid" : "paid"}`}
            >
              {paid ? <FaCheck size={16} /> : personShare.person_name[0]}
            </button>
          )}
          <div className="text-left">
            <h3
              className={`font-semibold text-base ${
                paid
                  ? "text-[var(--text-secondary)] line-through"
                  : "text-[var(--accent)] dark:text-white"
              }`}
            >
              {personShare.person_name}
            </h3>
            <div
              className={`text-xl font-bold font-mono ${
                paid
                  ? "text-emerald-600 dark:text-emerald-400"
                  : "text-[var(--accent)] dark:text-white"
              }`}
            >
              {formatMoney(personShare.total, currency)}
            </div>
            {isForeignCurrency && (
              <div className="text-xs font-medium text-[var(--primary)]">
                {formatUSDMoney(usdTotal)}
              </div>
            )}
          </div>
        </div>
        <button
          type="button"
          onClick={toggle}
          aria-expanded={isOpen}
          className="p-2 cursor-pointer bg-transparent border-none"
        >
          <FaChevronDown
            className={`text-[var(--text-secondary)] transition-transform duration-200 ease-out ${isOpen ? "rotate-180" : ""}`}
            size={14}
          />
        </button>
      </div>

      <div
        ref={contentRef}
        style={{ maxHeight: height }}
        className="overflow-hidden transition-all duration-200 ease-out"
      >
        <div className="px-5 pb-5 pt-2 border-t border-[var(--border-light)] dark:border-[var(--border-dark)]">
          <div className="space-y-3">
            {personShare.items.map((item) => (
              <div
                key={`${item.name}-${item.amount}-${item.is_shared}`}
                className="flex justify-between items-center text-sm"
              >
                <span className="text-[var(--accent)] dark:text-gray-300">
                  {item.name}
                  {item.is_shared && (
                    <span className="ml-2 text-xs text-[var(--text-secondary)]">
                      (shared)
                    </span>
                  )}
                </span>
                <span className="font-medium font-mono text-[var(--text-secondary)]">
                  {formatMoney(item.amount, currency)}
                </span>
              </div>
            ))}
            <div className="pt-3 mt-3 border-t border-[var(--border-light)] dark:border-[var(--border-dark)] space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-[var(--text-secondary)]">Tax</span>
                <span className="font-mono text-[var(--text-secondary)]">
                  {formatMoney(personShare.tax_share, currency)}
                </span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-[var(--text-secondary)]">Tip</span>
                <span className="font-mono text-[var(--text-secondary)]">
                  {formatMoney(personShare.tip_share, currency)}
                </span>
              </div>
              {hasVenmo && (
                <a
                  href={buildVenmoPayUrl(
                    hasVenmo,
                    usdTotal.toFixed(2),
                    `Split bill - ${personShare.person_name}`,
                  )}
                  target="_blank"
                  rel="noopener noreferrer"
                  onClick={(e) => e.stopPropagation()}
                  className="w-full mt-3 h-11 bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white font-semibold rounded-xl flex items-center justify-center hover:opacity-90 transition-opacity no-underline"
                >
                  <span className="flex items-center gap-1.5">
                    Pay with
                    <SiVenmo size={44} className="mt-0.5" />
                  </span>
                </a>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
