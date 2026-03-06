"use client";

import { TabPersonTotal } from "@/lib/api";
import { buildVenmoPayUrl } from "@/lib/venmo";
import { SiVenmo } from "react-icons/si";
import { FaCheck } from "react-icons/fa6";

interface TabPersonTotalsProps {
  personTotals: TabPersonTotal[];
  venmoId?: string | null;
}

export default function TabPersonTotals({
  personTotals,
  venmoId,
}: TabPersonTotalsProps) {
  const paidCount = personTotals.filter((p) => p.all_paid).length;

  return (
    <div className="mb-6">
      <div className="flex items-center justify-between mb-3 px-1">
        <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">
          Per Person Totals
        </h2>
        {paidCount > 0 && (
          <span className="text-xs font-medium text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-900/30 px-2 py-0.5 rounded-full">
            {paidCount}/{personTotals.length} paid
          </span>
        )}
      </div>
      <div className="space-y-3">
        {personTotals.map((person) => (
          <div
            key={person.person_name}
            className={`bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl px-5 py-4 shadow-sm dark:shadow-none flex items-center justify-between transition-opacity ${
              person.all_paid
                ? "dark:border dark:border-emerald-800/50 opacity-75"
                : "dark:border dark:border-[var(--border-dark)]"
            }`}
          >
            <div className="flex items-center gap-4">
              <div
                className={`w-11 h-11 rounded-full flex items-center justify-center font-semibold text-base ${
                  person.all_paid
                    ? "bg-emerald-100 dark:bg-emerald-900/40 text-emerald-600 dark:text-emerald-400"
                    : "bg-[var(--secondary)] dark:bg-white/10 text-[var(--text-secondary)]"
                }`}
              >
                {person.all_paid ? (
                  <FaCheck size={16} />
                ) : (
                  person.person_name[0]
                )}
              </div>
              <div>
                <h3
                  className={`font-semibold text-base ${
                    person.all_paid
                      ? "text-[var(--text-secondary)] line-through"
                      : "text-[var(--accent)] dark:text-white"
                  }`}
                >
                  {person.person_name}
                </h3>
                <p className="text-xs text-[var(--text-secondary)]">
                  {person.bill_count} bill{person.bill_count === 1 ? "" : "s"}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <div
                className={`text-xl font-bold font-mono ${
                  person.all_paid
                    ? "text-emerald-600 dark:text-emerald-400"
                    : "text-[var(--accent)] dark:text-white"
                }`}
              >
                ${person.total.toFixed(2)}
              </div>
              {!person.all_paid && venmoId && (
                <a
                  href={buildVenmoPayUrl(venmoId, person.total.toFixed(2), "Tab settlement - " + person.person_name)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="h-10 px-4 bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white font-semibold rounded-xl flex items-center justify-center hover:opacity-90 transition-opacity no-underline"
                >
                  <SiVenmo size={32} />
                </a>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
