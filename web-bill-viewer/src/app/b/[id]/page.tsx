import { getBill } from "@/lib/api";
import BillHeader from "@/components/BillHeader";
import BillBreakdown from "@/components/BillBreakdown";
import PersonShare from "@/components/PersonShare";
import PaymentDetails from "@/components/PaymentDetails";
import { notFound } from "next/navigation";
import { FaLock, FaTriangleExclamation } from "react-icons/fa6";

export default async function BillPage({
  params,
  searchParams,
}: {
  params: { id: string };
  searchParams: { t?: string };
}) {
  const { id } = await params;
  const { t: token } = await searchParams;

  if (!token) {
    return (
      <div className="min-h-screen flex items-center justify-center px-4 bg-[var(--secondary)] dark:bg-[var(--dark-bg)]">
        <div className="text-center bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-3xl p-12 shadow-xl dark:shadow-none dark:border dark:border-[var(--border-dark)] max-w-md">
          <FaLock className="text-5xl text-[var(--primary)] mb-6 mx-auto" />
          <h1 className="text-2xl font-bold mb-4 text-[var(--accent)] dark:text-white">
            Access Token Required
          </h1>
          <p className="text-[var(--text-secondary)]">
            This bill requires a valid access token to view.
          </p>
        </div>
      </div>
    );
  }

  let bill;
  try {
    bill = await getBill(id, token);
  } catch (error) {
    if (error instanceof Error && error.message === "Invalid access token") {
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
    notFound();
  }

  const hasVenmo =
    bill.payment_methods?.find((pm) => pm.name?.toLowerCase().includes("venmo"))
      ?.identifier || null;

  return (
    <div className="min-h-screen bg-gradient-to-b from-[var(--secondary)] to-white dark:from-[var(--dark-bg)] dark:to-[var(--card-bg-dark)]">
      <div className="max-w-2xl mx-auto px-4 py-8">
        <BillHeader name={bill.name} total={bill.total} />

        <div className="mb-6">
          <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)] mb-3 px-1">
            Individual Shares
          </h2>
          <div className="space-y-3">
            {bill.person_shares.map((share) => (
              <PersonShare
                key={share.id}
                personShare={share}
                index={0}
                hasVenmo={hasVenmo}
              />
            ))}
          </div>
        </div>

        <PaymentDetails paymentMethods={bill.payment_methods} />

        <BillBreakdown
          items={bill.items}
          subtotal={bill.subtotal}
          tax={bill.tax}
          tipAmount={bill.tip_amount}
          tipPercentage={bill.tip_percentage}
        />
      </div>
    </div>
  );
}
