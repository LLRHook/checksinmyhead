"use client";

import { type ReactNode } from "react";
import { useCollapsible } from "@/hooks/useCollapsible";
import { FaChevronDown } from "react-icons/fa6";

interface CollapsibleSectionProps {
  title: string;
  icon: ReactNode;
  children: ReactNode;
  defaultOpen?: boolean;
}

export default function CollapsibleSection({
  title,
  icon,
  children,
  defaultOpen = false,
}: CollapsibleSectionProps) {
  const { isOpen, toggle, contentRef, height } = useCollapsible(defaultOpen);

  return (
    <div className="bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl overflow-hidden shadow-sm dark:shadow-none dark:border dark:border-[var(--border-dark)]">
      <button
        onClick={toggle}
        aria-expanded={isOpen}
        className="w-full px-5 py-4 flex items-center justify-between transition-colors"
      >
        <div className="flex items-center gap-3">
          <span className="text-[var(--primary)]">{icon}</span>
          <h2 className="font-semibold text-base text-[var(--accent)] dark:text-white">
            {title}
          </h2>
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
        <div className="px-5 pb-5 border-t border-[var(--border-light)] dark:border-[var(--border-dark)]">
          {children}
        </div>
      </div>
    </div>
  );
}
