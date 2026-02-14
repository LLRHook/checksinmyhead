"use client";

import { Bill } from "@/lib/api";
import { useCollapsible } from "@/hooks/useCollapsible";
import { FaReceipt, FaChevronDown } from "react-icons/fa6";

interface TabBillListProps {
  bills: Bill[];
}

function BillCard({ bill }: { bill: Bill }) {
  const { isOpen, toggle, contentRef, height } = useCollapsible();

  return (
    <div className="bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl overflow-hidden shadow-sm dark:shadow-none dark:border dark:border-[var(--border-dark)] transition-all duration-200">
      <button
        onClick={toggle}
        aria-expanded={isOpen}
        className="w-full px-5 py-4 flex items-center justify-between transition-colors"
      >
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-[var(--secondary)] dark:bg-white/10 flex items-center justify-center">
            <FaReceipt className="text-[var(--primary)]" size={16} />
          </div>
          <div className="text-left">
            <h3 className="font-semibold text-sm text-[var(--accent)] dark:text-white">
              {bill.name}
            </h3>
            <span className="text-xs text-[var(--text-secondary)]">
              {bill.person_shares.length} {bill.person_shares.length === 1 ? "person" : "people"}
            </span>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <span className="text-lg font-bold font-mono text-[var(--accent)] dark:text-white">
            ${bill.total.toFixed(2)}
          </span>
          <FaChevronDown
            className={`text-[var(--text-secondary)] transition-transform duration-200 ease-out ${isOpen ? "rotate-180" : ""}`}
            size={12}
          />
        </div>
      </button>

      <div
        ref={contentRef}
        style={{ maxHeight: height }}
        className="overflow-hidden transition-all duration-200 ease-out"
      >
        <div className="px-5 pb-4 border-t border-[var(--border-light)] dark:border-[var(--border-dark)]">
          <table className="w-full mt-3">
            <tbody>
              {bill.person_shares.map((share) => (
                <tr key={share.id}>
                  <td className="py-1.5 text-sm text-[var(--accent)] dark:text-gray-300">
                    <div className="flex items-center gap-2">
                      <span className="w-7 h-7 rounded-full bg-[var(--secondary)] dark:bg-white/10 flex items-center justify-center text-xs font-semibold text-[var(--text-secondary)]">
                        {share.person_name[0]}
                      </span>
                      {share.person_name}
                    </div>
                  </td>
                  <td className="py-1.5 text-sm font-mono font-medium text-right text-[var(--accent)] dark:text-white">
                    ${share.total.toFixed(2)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

export default function TabBillList({ bills }: TabBillListProps) {
  if (bills.length === 0) return null;

  return (
    <div>
      <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)] mb-3 px-1">
        Bills
      </h2>
      <div className="space-y-3">
        {bills.map((bill) => (
          <BillCard key={bill.id} bill={bill} />
        ))}
      </div>
    </div>
  );
}
