"use client";

import { FaArrowUpRightFromSquare, FaDownload } from "react-icons/fa6";

interface AppHandoffProps {
  tabId: string;
  token: string;
}

export default function AppHandoff({ tabId, token }: AppHandoffProps) {
  const appUrl = `billington://tab/${tabId}?t=${encodeURIComponent(token)}`;

  return (
    <div className="mb-6 rounded-2xl border border-[var(--border-light)] dark:border-[var(--border-dark)] bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] px-5 py-4 shadow-sm">
      <p className="text-sm font-semibold text-[var(--accent)] dark:text-white">
        This trip lives in the Billington app
      </p>
      <p className="mt-1 text-xs leading-relaxed text-[var(--text-secondary)]">
        Open the app to join, add expenses, and settle up. This page is a
        read-only trip summary.
      </p>
      <a
        href={appUrl}
        className="mt-3 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] px-4 py-3 text-sm font-semibold text-white no-underline transition-opacity hover:opacity-90"
      >
        <FaArrowUpRightFromSquare size={13} />
        Open in Billington
      </a>
      <a
        href="https://billingtonapp.vercel.app"
        className="mt-2 inline-flex w-full items-center justify-center gap-2 rounded-xl border border-[var(--border-light)] dark:border-[var(--border-dark)] px-4 py-2.5 text-xs font-semibold text-[var(--text-secondary)] no-underline transition-colors hover:bg-black/5 dark:hover:bg-white/5"
      >
        <FaDownload size={12} />
        Get the app
      </a>
    </div>
  );
}
