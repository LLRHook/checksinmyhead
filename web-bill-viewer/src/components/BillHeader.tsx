"use client";

import Image from "next/image";
import { formatMoney } from "@/lib/api";

interface BillHeaderProps {
  name: string;
  total: number;
  currency?: string;
}

export default function BillHeader({
  name,
  total,
  currency = "USD",
}: BillHeaderProps) {
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
      <h1 className="text-2xl font-bold text-[var(--accent)] dark:text-white mb-2">
        {name}
      </h1>
      <div className="inline-flex items-center gap-2 bg-[var(--secondary)] dark:bg-white/10 px-5 py-2 rounded-full">
        <span className="text-sm text-[var(--text-secondary)]">Total</span>
        <span className="text-xl font-bold font-mono text-[var(--accent)] dark:text-white">
          {formatMoney(total, currency)}
        </span>
      </div>
    </div>
  );
}
