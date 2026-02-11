"use client";

import { PaymentMethod } from "@/lib/api";
import { SiVenmo, SiZelle, SiCashapp, SiApplepay } from "react-icons/si";

interface PaymentDetailsProps {
  paymentMethods: PaymentMethod[];
}

export default function PaymentDetails({
  paymentMethods,
}: PaymentDetailsProps) {
  if (!paymentMethods || paymentMethods.length === 0) {
    return null;
  }

  const getIcon = (name: string) => {
    const lowerName = name.toLowerCase();
    if (lowerName.includes("venmo")) {
      return { Icon: SiVenmo, bg: "bg-[#008CFF]" };
    }
    if (lowerName.includes("zelle")) {
      return { Icon: SiZelle, bg: "bg-[#6D1ED4]" };
    }
    if (lowerName.includes("cash app") || lowerName.includes("cashapp")) {
      return { Icon: SiCashapp, bg: "bg-[#00D632]" };
    }
    if (lowerName.includes("apple pay")) {
      return { Icon: SiApplepay, bg: "bg-black" };
    }
    return { Icon: null, bg: "bg-[var(--primary)]" };
  };

  return (
    <div className="mb-6">
      <h3 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)] mb-4">
        Payment Methods
      </h3>
      <div className="space-y-3">
        {paymentMethods.map((method, idx) => {
          const { Icon, bg } = getIcon(method.name);
          return (
            <div
              key={idx}
              className="flex items-center gap-3 text-[var(--accent)] dark:text-white"
            >
              <div
                className={`w-10 h-10 ${bg} rounded-lg flex items-center justify-center`}
              >
                {Icon ? (
                  <Icon className="text-white text-xl" />
                ) : (
                  <i className="fas fa-credit-card text-white text-lg"></i>
                )}
              </div>
              <div>
                <div className="text-xs text-[var(--text-secondary)] uppercase tracking-wide">
                  {method.name}
                </div>
                <div className="font-semibold">{method.identifier}</div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
