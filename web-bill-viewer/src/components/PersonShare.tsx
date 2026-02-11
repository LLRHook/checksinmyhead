"use client";

import { PersonShare as PersonShareType } from "@/lib/api";
import { useState, useRef, useEffect } from "react";
import { SiVenmo } from "react-icons/si";

interface PersonShareProps {
  personShare: PersonShareType;
  index: number;
  hasVenmo?: string | null;
}

export default function PersonShare({
  personShare,
  index,
  hasVenmo,
}: PersonShareProps) {
  const [isExpanded, setIsExpanded] = useState(false);
  const contentRef = useRef<HTMLDivElement>(null);
  const [height, setHeight] = useState("0px");

  useEffect(() => {
    if (contentRef.current) {
      setHeight(isExpanded ? `${contentRef.current.scrollHeight}px` : "0px");
    }
  }, [isExpanded]);

  const handleVenmoClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (hasVenmo) {
      window.open(
        `venmo://paycharge?txn=pay&recipients=${hasVenmo}&amount=${personShare.total.toFixed(2)}&note=The Billington`,
        "_blank",
      );
    }
  };

  return (
    <div className="bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl overflow-hidden shadow-sm border border-[var(--border-light)] dark:border-[var(--border-dark)] transition-all duration-300">
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="w-full px-6 py-4 flex items-center justify-between transition-colors"
      >
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-full bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] flex items-center justify-center text-white font-semibold text-lg">
            {personShare.person_name[0]}
          </div>
          <div className="text-left">
            <h3 className="font-semibold text-lg text-[var(--accent)] dark:text-white">
              {personShare.person_name}
            </h3>
            <div className="text-2xl font-bold text-[var(--primary)]">
              ${personShare.total.toFixed(2)}
            </div>
          </div>
        </div>
        <i
          className={`fas fa-chevron-down text-[var(--text-secondary)] transition-transform duration-300 ${isExpanded ? "rotate-180" : ""}`}
        ></i>
      </button>

      <div
        ref={contentRef}
        style={{ maxHeight: height }}
        className="overflow-hidden transition-all duration-500 ease-in-out"
      >
        <div className="px-6 pb-5 pt-2 border-t border-[var(--border-light)] dark:border-[var(--border-dark)]">
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
                <span className="font-medium text-[var(--text-secondary)]">
                  ${item.amount.toFixed(2)}
                </span>
              </div>
            ))}
            <div className="pt-3 mt-3 border-t border-[var(--border-light)] dark:border-[var(--border-dark)] space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-[var(--text-secondary)]">Tax</span>
                <span className="text-[var(--text-secondary)]">
                  ${personShare.tax_share.toFixed(2)}
                </span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-[var(--text-secondary)]">Tip</span>
                <span className="text-[var(--text-secondary)]">
                  ${personShare.tip_share.toFixed(2)}
                </span>
              </div>
              {hasVenmo && (
                <button
                  onClick={handleVenmoClick}
                  className="w-full mt-3 h-12 bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white font-semibold rounded-xl flex items-center justify-center hover:opacity-90 transition-opacity shadow-sm"
                >
                  <span className="flex items-center gap-1">
                    Pay with
                    <SiVenmo size={48} className="mt-0.5" />
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
