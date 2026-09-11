"use client";

import Image from "next/image";
import { FaCircleCheck, FaReceipt } from "react-icons/fa6";
import { formatMoney } from "@/lib/api";

interface TabHeaderProps {
  name: string;
  description: string;
  total: number;
  billCount: number;
  finalized?: boolean;
  currency?: string;
}

export default function TabHeader({
  name,
  description,
  total,
  billCount,
  finalized,
  currency = "USD",
}: TabHeaderProps) {
  return (
    <div className="text-center lg:text-left mb-8">
      <div className="mb-3">
        <Image
          src="/logo.png"
          alt="Billington"
          width={192}
          height={64}
          className="h-16 mx-auto lg:mx-0"
          priority
        />
      </div>
      <h1 className="text-2xl font-bold text-[var(--accent)] dark:text-white mb-1">
        {name}
      </h1>
      {description && (
        <p className="text-sm text-[var(--text-secondary)] mb-3">
          {description}
        </p>
      )}
      <div className="inline-flex items-center gap-2 bg-[var(--secondary)] dark:bg-white/10 px-5 py-2 rounded-full">
        <span className="text-sm text-[var(--text-secondary)]">Total</span>
        <span className="text-xl font-bold font-mono text-[var(--accent)] dark:text-white">
          {formatMoney(total, currency)}
        </span>
      </div>
      <div className="mt-2 flex items-center justify-center lg:justify-start gap-2">
        <span className="inline-flex items-center gap-1.5 text-xs font-medium text-[var(--text-secondary)] bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] px-3 py-1 rounded-full">
          <FaReceipt className="text-[var(--primary)]" size={11} />
          {billCount} bill{billCount === 1 ? "" : "s"}
        </span>
        {finalized && (
          <span className="inline-flex items-center gap-1.5 text-xs font-medium text-emerald-700 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-900/30 px-3 py-1 rounded-full">
            <FaCircleCheck size={11} />
            Finalized
          </span>
        )}
      </div>
    </div>
  );
}
