"use client";

interface TabHeaderProps {
  name: string;
  description: string;
  total: number;
  billCount: number;
}

export default function TabHeader({
  name,
  description,
  total,
  billCount,
}: TabHeaderProps) {
  return (
    <div className="text-center mb-8">
      <div className="mb-2">
        <img src="/logo.png" alt="Billington" className="h-20 mx-auto" />
      </div>
      <h1 className="text-2xl font-bold text-[var(--accent)] dark:text-white mb-1">
        {name}
      </h1>
      {description && (
        <p className="text-sm text-[var(--text-secondary)] mb-3">
          {description}
        </p>
      )}
      <div className="inline-flex items-center gap-2 bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white px-6 py-2 rounded-full">
        <span className="text-sm font-medium">Total</span>
        <span className="text-xl font-bold">${total.toFixed(2)}</span>
      </div>
      <div className="mt-2">
        <span className="inline-flex items-center gap-1 text-xs font-medium text-[var(--text-secondary)] bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] px-3 py-1 rounded-full">
          <i className="fas fa-receipt text-[var(--primary)]"></i>
          {billCount} bill{billCount === 1 ? "" : "s"}
        </span>
      </div>
    </div>
  );
}
