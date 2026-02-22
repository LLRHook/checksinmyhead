"use client";

import { TabPersonTotal } from "@/lib/api";
import { buildVenmoDeepLink, startVenmoFallback } from "@/lib/venmo";
import { SiVenmo } from "react-icons/si";

interface TabPersonTotalsProps {
  personTotals: TabPersonTotal[];
  venmoId?: string | null;
}

export default function TabPersonTotals({
  personTotals,
  venmoId,
}: TabPersonTotalsProps) {
  return (
    <div className="mb-6">
      <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)] mb-3 px-1">
        Per Person Totals
      </h2>
      <div className="space-y-3">
        {personTotals.map((person) => (
          <div
            key={person.person_name}
            className="bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl px-5 py-4 shadow-sm dark:shadow-none dark:border dark:border-[var(--border-dark)] flex items-center justify-between"
          >
            <div className="flex items-center gap-4">
              <div className="w-11 h-11 rounded-full bg-[var(--secondary)] dark:bg-white/10 flex items-center justify-center text-[var(--text-secondary)] font-semibold text-base">
                {person.person_name[0]}
              </div>
              <div>
                <h3 className="font-semibold text-base text-[var(--accent)] dark:text-white">
                  {person.person_name}
                </h3>
                <p className="text-xs text-[var(--text-secondary)]">
                  {person.bill_count} bill{person.bill_count === 1 ? "" : "s"}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <div className="text-xl font-bold font-mono text-[var(--accent)] dark:text-white">
                ${person.total.toFixed(2)}
              </div>
              {venmoId && (
                <a
                  href={buildVenmoDeepLink(venmoId, person.total.toFixed(2), "Tab settlement - " + person.person_name)}
                  onClick={() => {
                    startVenmoFallback(venmoId, person.total.toFixed(2), "Tab settlement - " + person.person_name);
                  }}
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
