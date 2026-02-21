"use client";

import { PersonShare as PersonShareType } from "@/lib/api";
import { useCollapsible } from "@/hooks/useCollapsible";
import { FaChevronDown } from "react-icons/fa6";
import { SiVenmo } from "react-icons/si";

interface PersonShareProps {
  personShare: PersonShareType;
  hasVenmo?: string | null;
}

export default function PersonShare({
  personShare,
  hasVenmo,
}: PersonShareProps) {
  const { isOpen, toggle, contentRef, height } = useCollapsible();

  const handleVenmoClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (hasVenmo) {
      const cleanUsername = hasVenmo.replace(/^@/, "");
      const amount = personShare.total.toFixed(2);
      const note = encodeURIComponent(`Split bill - ${personShare.person_name}`);
      window.open(
        `https://venmo.com/${cleanUsername}?txn=pay&amount=${amount}&note=${note}`,
        "_blank"
      );
    }
  };

  return (
    <div className="bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl overflow-hidden shadow-sm dark:shadow-none dark:border dark:border-[var(--border-dark)] transition-all duration-200">
      <button
        onClick={toggle}
        aria-expanded={isOpen}
        className="w-full px-5 py-4 flex items-center justify-between transition-colors"
      >
        <div className="flex items-center gap-4">
          <div className="w-11 h-11 rounded-full bg-[var(--secondary)] dark:bg-white/10 flex items-center justify-center text-[var(--text-secondary)] font-semibold text-base">
            {personShare.person_name[0]}
          </div>
          <div className="text-left">
            <h3 className="font-semibold text-base text-[var(--accent)] dark:text-white">
              {personShare.person_name}
            </h3>
            <div className="text-xl font-bold font-mono text-[var(--accent)] dark:text-white">
              ${personShare.total.toFixed(2)}
            </div>
          </div>
        </div>
        <FaChevronDown
          className={`text-[var(--text-secondary)] transition-transform duration-200 ease-out ${isOpen ? "rotate-180" : ""}`}
          size={14}
        />
      </button>

      <div
        ref={contentRef}
        style={{ maxHeight: height }}
        className="overflow-hidden transition-all duration-200 ease-out"
      >
        <div className="px-5 pb-5 pt-2 border-t border-[var(--border-light)] dark:border-[var(--border-dark)]">
          <div className="space-y-3">
            {personShare.items.map((item, idx) => (
              <div
                key={idx}
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
                  ${item.amount.toFixed(2)}
                </span>
              </div>
            ))}
            <div className="pt-3 mt-3 border-t border-[var(--border-light)] dark:border-[var(--border-dark)] space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-[var(--text-secondary)]">Tax</span>
                <span className="font-mono text-[var(--text-secondary)]">
                  ${personShare.tax_share.toFixed(2)}
                </span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-[var(--text-secondary)]">Tip</span>
                <span className="font-mono text-[var(--text-secondary)]">
                  ${personShare.tip_share.toFixed(2)}
                </span>
              </div>
              {hasVenmo && (
                <button
                  onClick={handleVenmoClick}
                  className="w-full mt-3 h-11 bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white font-semibold rounded-xl flex items-center justify-center hover:opacity-90 transition-opacity"
                >
                  <span className="flex items-center gap-1.5">
                    Pay with
                    <SiVenmo size={44} className="mt-0.5" />
                  </span>
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
