"use client";

import { FaCalculator, FaReceipt } from "react-icons/fa6";
import type { Bill } from "@/lib/api";
import { formatOriginalMoney } from "@/lib/currency";
import CollapsibleSection from "./CollapsibleSection";

interface BillBreakdownProps {
  bill: Bill;
}

export default function BillBreakdown({ bill }: BillBreakdownProps) {
  return (
    <div className="space-y-3 mb-6">
      <CollapsibleSection title="Items" icon={<FaReceipt size={14} />}>
        <div className="space-y-3 mt-4">
          {bill.items.map((item) => (
            <div
              key={item.id}
              className="flex justify-between items-center py-1"
            >
              <span className="font-medium text-[var(--accent)] dark:text-white">
                {item.name}
              </span>
              <span className="font-semibold font-mono text-[var(--accent)] dark:text-white">
                {formatOriginalMoney(item.price, bill)}
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
              {formatOriginalMoney(bill.subtotal, bill)}
            </span>
          </div>
          <div className="flex justify-between py-1">
            <span className="text-[var(--text-secondary)]">Tax</span>
            <span className="font-semibold font-mono text-[var(--accent)] dark:text-white">
              {formatOriginalMoney(bill.tax, bill)}
            </span>
          </div>
          <div className="flex justify-between py-1">
            <span className="text-[var(--text-secondary)]">
              Tip ({bill.tip_percentage}%)
            </span>
            <span className="font-semibold font-mono text-[var(--accent)] dark:text-white">
              {formatOriginalMoney(bill.tip_amount, bill)}
            </span>
          </div>
        </div>
      </CollapsibleSection>
    </div>
  );
}
