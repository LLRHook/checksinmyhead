"use client";

interface BillHeaderProps {
  name: string;
  total: number;
}

export default function BillHeader({ name, total }: BillHeaderProps) {
  return (
    <div className="text-center mb-8">
      <div className="mb-2">
        <img src="/logo.png" alt="Billington" className="h-20 mx-auto" />
      </div>
      <h1 className="text-2xl font-bold text-[var(--accent)] dark:text-white mb-2">
        {name}
      </h1>
      <div className="inline-flex items-center gap-2 bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white px-6 py-2 rounded-full">
        <span className="text-sm font-medium">Total</span>
        <span className="text-xl font-bold">${total.toFixed(2)}</span>
      </div>
    </div>
  );
}
