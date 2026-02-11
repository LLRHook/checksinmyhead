"use client";

import { useState, useRef, useEffect } from "react";

interface CollapsibleSectionProps {
  title: string;
  icon: string;
  children: React.ReactNode;
  defaultOpen?: boolean;
}

export default function CollapsibleSection({
  title,
  icon,
  children,
  defaultOpen = false,
}: CollapsibleSectionProps) {
  const [isOpen, setIsOpen] = useState(defaultOpen);
  const contentRef = useRef<HTMLDivElement>(null);
  const [height, setHeight] = useState("0px");

  useEffect(() => {
    if (contentRef.current) {
      setHeight(isOpen ? `${contentRef.current.scrollHeight}px` : "0px");
    }
  }, [isOpen]);

  return (
    <div className="bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl overflow-hidden shadow-sm border border-[var(--border-light)] dark:border-[var(--border-dark)]">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="w-full px-6 py-4 flex items-center justify-between transition-colors"
      >
        <div className="flex items-center gap-3">
          <i className={`${icon} text-[var(--primary)]`}></i>
          <h2 className="font-semibold text-base text-[var(--accent)] dark:text-white">
            {title}
          </h2>
        </div>
        {isOpen ? (
          <i className="fas fa-chevron-up w-5 h-5 text-[var(--text-secondary)]"></i>
        ) : (
          <i className="fas fa-chevron-down w-5 h-5 text-[var(--text-secondary)]"></i>
        )}
      </button>

      <div
        ref={contentRef}
        style={{ maxHeight: height }}
        className="overflow-hidden transition-all duration-500 ease-in-out"
      >
        <div className="px-6 pb-5 border-t border-[var(--border-light)] dark:border-[var(--border-dark)]">
          {children}
        </div>
      </div>
    </div>
  );
}
