"use client";

import { useState, useEffect, useCallback } from "react";
import { Bill, API_BASE_URL } from "@/lib/api";
import BillHeader from "@/components/BillHeader";
import BillBreakdown from "@/components/BillBreakdown";
import PersonShare from "@/components/PersonShare";
import PaymentDetails from "@/components/PaymentDetails";
import DesktopLayout from "@/components/DesktopLayout";
import { FaTriangleExclamation } from "react-icons/fa6";

interface BillPageClientProps {
  id: string;
  token: string;
}

type LoadingState =
  | { status: "loading" }
  | { status: "retrying"; attempt: number; maxAttempts: number }
  | { status: "error"; errorType: "invalid_token" | "not_found" | "failed" }
  | { status: "success"; bill: Bill };

const RETRY_DELAYS = [5000, 10000, 15000];

export default function BillPageClient({ id, token }: BillPageClientProps) {
  const [state, setState] = useState<LoadingState>({ status: "loading" });
  const [progress, setProgress] = useState(0);

  const fetchBill = useCallback(async () => {
    setState({ status: "loading" });
    setProgress(0);

    for (let attempt = 0; attempt <= RETRY_DELAYS.length; attempt++) {
      try {
        const response = await fetch(
          `${API_BASE_URL}/api/bills/${id}?t=${token}`
        );

        if (response.status === 403) {
          setState({ status: "error", errorType: "invalid_token" });
          return;
        }

        if (response.status === 404) {
          setState({ status: "error", errorType: "not_found" });
          return;
        }

        if (!response.ok) {
          throw new Error(`Server error: ${response.status}`);
        }

        const bill: Bill = await response.json();
        setState({ status: "success", bill });
        return;
      } catch {
        // If we have retries left, wait and try again
        if (attempt < RETRY_DELAYS.length) {
          const delay = RETRY_DELAYS[attempt];
          setState({
            status: "retrying",
            attempt: attempt + 1,
            maxAttempts: RETRY_DELAYS.length,
          });

          // Animate progress bar during the delay
          setProgress(0);
          const startTime = Date.now();
          await new Promise<void>((resolve) => {
            const interval = setInterval(() => {
              const elapsed = Date.now() - startTime;
              const pct = Math.min((elapsed / delay) * 100, 100);
              setProgress(pct);
              if (elapsed >= delay) {
                clearInterval(interval);
                resolve();
              }
            }, 100);
          });
        }
      }
    }

    // All retries exhausted
    setState({ status: "error", errorType: "failed" });
  }, [id, token]);

  useEffect(() => {
    fetchBill();
  }, [fetchBill]);

  // --- Loading state ---
  if (state.status === "loading") {
    return (
      <div className="min-h-screen flex items-center justify-center px-4 bg-[var(--secondary)] dark:bg-[var(--dark-bg)]">
        <div className="text-center">
          <div className="w-10 h-10 border-3 border-[var(--secondary)] dark:border-white/10 border-t-[var(--primary)] rounded-full animate-spin mx-auto mb-4" />
          <p className="text-sm text-[var(--text-secondary)]">
            Loading your bill...
          </p>
        </div>
      </div>
    );
  }

  // --- Retrying state ---
  if (state.status === "retrying") {
    return (
      <div className="min-h-screen flex items-center justify-center px-4 bg-[var(--secondary)] dark:bg-[var(--dark-bg)]">
        <div className="text-center max-w-sm">
          <div className="w-10 h-10 border-3 border-[var(--secondary)] dark:border-white/10 border-t-[var(--primary)] rounded-full animate-spin mx-auto mb-4" />
          <p className="text-base font-semibold text-[var(--accent)] dark:text-white mb-1">
            Waking up the server...
          </p>
          <p className="text-sm text-[var(--text-secondary)] mb-5">
            This usually takes 10-15 seconds. Hang tight!
          </p>

          {/* Progress bar */}
          <div className="w-full h-1.5 bg-[var(--border-light)] dark:bg-[var(--border-dark)] rounded-full overflow-hidden">
            <div
              className="h-full bg-[var(--primary)] rounded-full transition-all duration-100 ease-linear"
              style={{ width: `${progress}%` }}
            />
          </div>
          <p className="text-xs text-[var(--text-secondary)] mt-2">
            Retry {state.attempt} of {state.maxAttempts}
          </p>
        </div>
      </div>
    );
  }

  // --- Error states ---
  if (state.status === "error") {
    if (state.errorType === "invalid_token") {
      return (
        <div className="min-h-screen flex items-center justify-center px-4 bg-[var(--secondary)] dark:bg-[var(--dark-bg)]">
          <div className="text-center bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-3xl p-12 shadow-xl dark:shadow-none dark:border dark:border-[var(--border-dark)] max-w-md">
            <FaTriangleExclamation className="text-5xl text-red-500 mb-6 mx-auto" />
            <h1 className="text-2xl font-bold mb-4 text-[var(--accent)] dark:text-white">
              Invalid Access Token
            </h1>
            <p className="text-[var(--text-secondary)]">
              The access token provided is not valid for this bill.
            </p>
          </div>
        </div>
      );
    }

    if (state.errorType === "not_found") {
      return (
        <div className="min-h-screen flex items-center justify-center px-4 bg-[var(--secondary)] dark:bg-[var(--dark-bg)]">
          <div className="text-center bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-3xl p-12 shadow-xl dark:shadow-none dark:border dark:border-[var(--border-dark)] max-w-md">
            <FaTriangleExclamation className="text-5xl text-red-500 mb-6 mx-auto" />
            <h1 className="text-2xl font-bold mb-4 text-[var(--accent)] dark:text-white">
              Bill Not Found
            </h1>
            <p className="text-[var(--text-secondary)]">
              The bill you are looking for does not exist or has been removed.
            </p>
          </div>
        </div>
      );
    }

    // errorType === "failed" — all retries exhausted
    return (
      <div className="min-h-screen flex items-center justify-center px-4 bg-[var(--secondary)] dark:bg-[var(--dark-bg)]">
        <div className="text-center bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-3xl p-12 shadow-xl dark:shadow-none dark:border dark:border-[var(--border-dark)] max-w-md">
          <FaTriangleExclamation className="text-5xl text-red-500 mb-6 mx-auto" />
          <h1 className="text-2xl font-bold mb-4 text-[var(--accent)] dark:text-white">
            Something Went Wrong
          </h1>
          <p className="text-[var(--text-secondary)] mb-6">
            We couldn&apos;t load this bill after several attempts. The server
            may be temporarily unavailable.
          </p>
          <button
            onClick={fetchBill}
            className="px-6 py-3 bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white font-semibold rounded-xl hover:opacity-90 transition-opacity"
          >
            Try Again
          </button>
        </div>
      </div>
    );
  }

  // --- Success state ---
  const { bill } = state;

  const hasVenmo =
    bill.payment_methods?.find((pm) =>
      pm.name?.toLowerCase().includes("venmo")
    )?.identifier || null;

  const sidebar = (
    <>
      <BillHeader name={bill.name} total={bill.total} />
      <PaymentDetails paymentMethods={bill.payment_methods} />
    </>
  );

  return (
    <DesktopLayout sidebar={sidebar}>
      <div className="mb-6">
        <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)] mb-3 px-1">
          Individual Shares
        </h2>
        <div className="space-y-3">
          {[...bill.person_shares]
            .sort((a, b) =>
              a.person_name.localeCompare(b.person_name, undefined, {
                sensitivity: "base",
              })
            )
            .map((share) => (
              <PersonShare
                key={share.id}
                personShare={share}
                hasVenmo={hasVenmo}
              />
            ))}
        </div>
      </div>

      <BillBreakdown
        items={bill.items}
        subtotal={bill.subtotal}
        tax={bill.tax}
        tipAmount={bill.tip_amount}
        tipPercentage={bill.tip_percentage}
      />
    </DesktopLayout>
  );
}
