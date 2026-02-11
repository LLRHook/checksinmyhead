"use client";

import { TabPersonTotal } from "@/lib/api";
import { SiVenmo } from "react-icons/si";

interface TabPersonTotalsProps {
  personTotals: TabPersonTotal[];
  venmoId?: string | null;
}

export default function TabPersonTotals({
  personTotals,
  venmoId,
}: TabPersonTotalsProps) {
  const handleVenmoClick = (total: number) => {
    if (venmoId) {
      window.open(
        `venmo://paycharge?txn=pay&recipients=${venmoId}&amount=${total.toFixed(2)}&note=The Billington`,
        "_blank"
      );
    }
  };

  return (
    <div className="mb-6">
      <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)] mb-3 px-1">
        Per Person Totals
      </h2>
      <div className="space-y-3">
        {personTotals.map((person) => (
          <div
            key={person.person_name}
            className="bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl px-6 py-4 shadow-sm border border-[var(--border-light)] dark:border-[var(--border-dark)] flex items-center justify-between"
          >
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-full bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] flex items-center justify-center text-white font-semibold text-lg">
                {person.person_name[0]}
              </div>
              <div>
                <h3 className="font-semibold text-lg text-[var(--accent)] dark:text-white">
                  {person.person_name}
                </h3>
                <p className="text-xs text-[var(--text-secondary)]">
                  {person.bill_count} bill{person.bill_count === 1 ? "" : "s"}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <div className="text-2xl font-bold text-[var(--primary)]">
                ${person.total.toFixed(2)}
              </div>
              {venmoId && (
                <button
                  onClick={() => handleVenmoClick(person.total)}
                  className="h-10 px-4 bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white font-semibold rounded-xl flex items-center justify-center hover:opacity-90 transition-opacity shadow-sm"
                >
                  <SiVenmo size={36} />
                </button>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
