"use client";

import Image from "next/image";
import type { Bill } from "@/lib/api";
import {
  billCurrencyCode,
  billUSDExchangeRate,
  billUSDTotal,
  formatOriginalMoney,
  formatUSDExchangeRate,
  formatUSDMoney,
} from "@/lib/currency";

interface BillHeaderProps {
  bill: Bill;
}

export default function BillHeader({ bill }: BillHeaderProps) {
  const currency = billCurrencyCode(bill);
  const isForeignCurrency = currency !== "USD";

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
        {bill.name}
      </h1>
      <div className="inline-flex items-center gap-2 bg-[var(--secondary)] dark:bg-white/10 px-5 py-2 rounded-full">
        <span className="text-sm text-[var(--text-secondary)]">Total</span>
        <span className="text-xl font-bold font-mono text-[var(--accent)] dark:text-white">
          {formatOriginalMoney(bill.total, bill)}
        </span>
      </div>
      {isForeignCurrency && (
        <div className="mt-2 text-sm text-[var(--text-secondary)]">
          <p className="font-semibold text-[var(--primary)]">
            Recorded as {formatUSDMoney(billUSDTotal(bill))}
          </p>
          <p className="mt-1 text-xs">
            Frozen at 1 {currency} ={" "}
            {formatUSDExchangeRate(billUSDExchangeRate(bill))}
            {bill.exchange_rate_date ? ` on ${bill.exchange_rate_date}` : ""}
            {bill.exchange_rate_source ? ` · ${bill.exchange_rate_source}` : ""}
          </p>
        </div>
      )}
    </div>
  );
}
