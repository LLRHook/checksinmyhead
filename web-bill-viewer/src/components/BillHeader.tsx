"use client";

interface BillHeaderProps {
  name: string;
  total: number;
}

export default function BillHeader({ name, total }: BillHeaderProps) {
  return (
    <div className="text-center lg:text-left mb-8">
      <div className="mb-3">
        <img src="/logo.png" alt="Billington" className="h-16 mx-auto lg:mx-0" />
      </div>
      <h1 className="text-2xl font-bold text-[var(--accent)] dark:text-white mb-2">
        {name}
      </h1>
      <div className="inline-flex items-center gap-2 bg-[var(--secondary)] dark:bg-white/10 px-5 py-2 rounded-full">
        <span className="text-sm text-[var(--text-secondary)]">Total</span>
        <span className="text-xl font-bold font-mono text-[var(--accent)] dark:text-white">
          ${total.toFixed(2)}
        </span>
      </div>
    </div>
  );
}
