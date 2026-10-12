import { FaArrowUpRightFromSquare } from "react-icons/fa6";

interface BillAppHandoffProps {
  billId: number;
  token: string;
}

export default function BillAppHandoff({ billId, token }: BillAppHandoffProps) {
  const appUrl = `billington://bill/${billId}?t=${encodeURIComponent(token)}`;

  return (
    <a
      href={appUrl}
      className="mb-5 inline-flex w-full items-center justify-center gap-2 rounded-xl border border-[var(--border-light)] px-4 py-3 text-sm font-semibold text-[var(--accent)] no-underline transition-colors hover:bg-black/5 dark:border-[var(--border-dark)] dark:text-white dark:hover:bg-white/5"
    >
      <FaArrowUpRightFromSquare size={13} />
      Open in Billington
    </a>
  );
}
