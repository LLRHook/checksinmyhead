"use client";

import { BillItem } from "@/lib/api";
import CollapsibleSection from "./CollapsibleSection";
import { FaReceipt, FaCalculator } from "react-icons/fa6";

interface BillBreakdownProps {
  items: BillItem[];
  subtotal: number;
  tax: number;
  tipAmount: number;
  tipPercentage: number;
}

export default function BillBreakdown({
  items,
  subtotal,
  tax,
  tipAmount,
  tipPercentage,
}: BillBreakdownProps) {
  return (
    <div className="space-y-3 mb-6">
      <CollapsibleSection title="Items" icon={<FaReceipt size={14} />}>
        <div className="space-y-3 mt-4">
          {items.map((item) => (
            <div
              key={item.id}
              className="flex justify-between items-center py-1"
            >
              <span className="font-medium text-[var(--accent)] dark:text-white">
                {item.name}
              </span>
              <span className="font-semibold font-mono text-[var(--accent)] dark:text-white">
                ${item.price.toFixed(2)}
              </span>
            </div>
          ))}
        </div>
      </CollapsibleSection>

      <CollapsibleSection title="Breakdown" icon={<FaCalculator size={14} />}>
        <div className="space-y-3 mt-4">
          <div className="flex justify-between py-1">
            <span className="text-[var(--text-secondary)]">Subtotal</span>
            <span className="font-semibold font-mono text-[var(--accent)] dark:text-white">
              ${subtotal.toFixed(2)}
            </span>
          </div>
          <div className="flex justify-between py-1">
            <span className="text-[var(--text-secondary)]">Tax</span>
            <span className="font-semibold font-mono text-[var(--accent)] dark:text-white">
              ${tax.toFixed(2)}
            </span>
          </div>
          <div className="flex justify-between py-1">
            <span className="text-[var(--text-secondary)]">
              Tip ({tipPercentage}%)
            </span>
            <span className="font-semibold font-mono text-[var(--accent)] dark:text-white">
              ${tipAmount.toFixed(2)}
            </span>
          </div>
        </div>
      </CollapsibleSection>
    </div>
  );
}
