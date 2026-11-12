import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { FaLock, FaTriangleExclamation } from "react-icons/fa6";
import AppHandoff from "@/components/AppHandoff";
import BillHeader from "@/components/BillHeader";
import DesktopLayout from "@/components/DesktopLayout";
import LazyBillBoard from "@/components/LazyBillBoard";
import MemberList from "@/components/MemberList";
import NetBalances from "@/components/NetBalances";
import PaymentDetails from "@/components/PaymentDetails";
import SettlementCard from "@/components/SettlementCard";
import TabBillList from "@/components/TabBillList";
import TabHeader from "@/components/TabHeader";
import TabPersonTotals from "@/components/TabPersonTotals";
import {
  ApiError,
  computeTabPersonTotals,
  getSettlementHistory,
  getTab,
  getTabMembers,
  type Tab,
} from "@/lib/api";
import { lazyBillRemainingTotal } from "@/lib/lazy-bill";

export const metadata: Metadata = {
  title: "Shared tab | Billington",
};

export default async function TabPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ t?: string }>;
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
            This tab requires a valid access token to view.
          </p>
        </div>
      </div>
    );
  }

  let tab: Tab;
  try {
    tab = await getTab(id, token);
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
              The access token provided is not valid for this tab.
            </p>
          </div>
        </div>
      );
    }
    if (error instanceof ApiError && error.status === 404) notFound();
    return (
      <main className="p-8" role="alert">
        This tab is unavailable or needs an upgraded client. Reload and retry;
        no balance has been inferred.
      </main>
    );
  }

  const personTotals = computeTabPersonTotals(tab);
  const primaryBill = tab.bills[0] ?? null;
  const isLegacyLazyTab = tab.description.toLowerCase().includes("lazy mode");
  let settlements: Awaited<ReturnType<typeof getSettlementHistory>> | null =
    null;
  let collectionError = false;
  let members: Awaited<ReturnType<typeof getTabMembers>> = [];
  try {
    if (tab.finalized) settlements = await getSettlementHistory(id, token);
    members = await getTabMembers(id, token);
  } catch {
    collectionError = true;
  }
  const paymentMethods = Array.from(
    new Map(
      tab.bills
        .flatMap((bill) => bill.payment_methods || [])
        .map(
          (method) => [`${method.name}-${method.identifier}`, method] as const,
        ),
    ).values(),
  );
  const venmoId =
    tab.bills
      .flatMap((b) => b.payment_methods || [])
      .find((pm) => pm.name?.toLowerCase().includes("venmo"))?.identifier ||
    null;

  const sidebar = (
    <>
      {isLegacyLazyTab && primaryBill ? (
        <BillHeader
          name={primaryBill.name}
          total={lazyBillRemainingTotal(primaryBill)}
          currency={primaryBill.display_currency ?? primaryBill.currency_code}
          totalLabel="Remaining"
        />
      ) : (
        <TabHeader
          name={tab.name}
          description={tab.description}
          total={tab.total_amount}
          billCount={tab.bills.length}
          finalized={tab.finalized}
          currency={tab.accounting_currency ?? "USD"}
        />
      )}

      {!isLegacyLazyTab && members.length > 0 && (
        <MemberList members={members} />
      )}

      {!isLegacyLazyTab && <AppHandoff tabId={id} token={token} />}

      {paymentMethods.length > 0 && (
        <PaymentDetails paymentMethods={paymentMethods} />
      )}
    </>
  );

  return (
    <DesktopLayout sidebar={sidebar}>
      {collectionError && (
        <p role="alert">
          Recorded settlements or membership are unavailable. Reload to retry.
        </p>
      )}
      {tab.net_balances === null && (
        <p role="status">
          Net balances unavailable: {tab.net_balance_status}. Recorded receipts
          remain below.
        </p>
      )}
      {settlements && settlements.identity_review_status !== "ready" && (
        <p role="status">Recorded result; ownership needs review.</p>
      )}
      {isLegacyLazyTab && primaryBill ? (
        <LazyBillBoard bill={primaryBill} token={token} tabId={id} />
      ) : (
        <>
          {(tab.net_balances ?? []).length > 0 && (
            <NetBalances
              balances={tab.net_balances ?? []}
              finalized={tab.finalized}
              venmoId={venmoId}
              currentMemberName={null}
              currency={tab.accounting_currency ?? "USD"}
            />
          )}

          {tab.finalized &&
          settlements &&
          settlements.settlements.length > 0 ? (
            <SettlementCard
              settlements={settlements.settlements}
              venmoId={venmoId}
              currency={tab.accounting_currency ?? "USD"}
            />
          ) : (
            personTotals &&
            personTotals.length > 0 && (
              <TabPersonTotals
                personTotals={personTotals}
                venmoId={venmoId}
                currency={tab.accounting_currency ?? "USD"}
              />
            )
          )}

          {personTotals === null && (
            <p role="status">
              Participant totals need identity or accounting review. Recorded
              receipts remain visible.
            </p>
          )}
          <TabBillList bills={tab.bills} tabToken={token} />
          {tab.bills.map((bill) => (
            <details key={bill.id}>
              <summary>Participants and claims · {bill.name}</summary>
              <LazyBillBoard bill={bill} token={token} tabId={id} />
            </details>
          ))}
        </>
      )}
    </DesktopLayout>
  );
}
