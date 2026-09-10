import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { FaLock, FaTriangleExclamation } from "react-icons/fa6";
import AppHandoff from "@/components/AppHandoff";
import DesktopLayout from "@/components/DesktopLayout";
import MemberList from "@/components/MemberList";
import NetBalances from "@/components/NetBalances";
import PaymentDetails from "@/components/PaymentDetails";
import SettlementCard from "@/components/SettlementCard";
import TabBillList from "@/components/TabBillList";
import TabHeader from "@/components/TabHeader";
import TabPersonTotals from "@/components/TabPersonTotals";
import {
  computeTabPersonTotals,
  getSettlements,
  getTab,
  getTabMembers,
  type Tab,
} from "@/lib/api";

export async function generateMetadata({
  params,
  searchParams,
}: {
  params: { id: string };
  searchParams: { t?: string };
}): Promise<Metadata> {
  const { id } = await params;
  const { t: token } = await searchParams;
  if (!token) return { title: "Billington" };
  try {
    const tab = await getTab(id, token);
    return { title: `${tab.name} - Billington` };
  } catch {
    return { title: "Billington" };
  }
}

export default async function TabPage({
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
    notFound();
  }

  const personTotals = computeTabPersonTotals(tab);
  const settlements = tab.finalized ? await getSettlements(id, token) : [];
  const members = await getTabMembers(id, token);
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
      <TabHeader
        name={tab.name}
        description={tab.description}
        total={tab.total_amount}
        billCount={tab.bills.length}
        finalized={tab.finalized}
        currency={tab.display_currency}
      />

      {members.length > 0 && <MemberList members={members} />}

      <AppHandoff tabId={id} token={token} />

      {paymentMethods.length > 0 && (
        <PaymentDetails paymentMethods={paymentMethods} />
      )}
    </>
  );

  return (
    <DesktopLayout sidebar={sidebar}>
      {(tab.net_balances ?? []).length > 0 && (
        <NetBalances
          balances={tab.net_balances ?? []}
          finalized={tab.finalized}
          venmoId={venmoId}
          currentMemberName={null}
          currency={tab.display_currency}
        />
      )}

      {tab.finalized && settlements.length > 0 ? (
        <SettlementCard
          settlements={settlements}
          venmoId={venmoId}
          tabId={id}
          token={token}
          currency={tab.display_currency}
          readOnly
        />
      ) : (
        personTotals.length > 0 && (
          <TabPersonTotals
            personTotals={personTotals}
            venmoId={venmoId}
            currency={tab.display_currency}
          />
        )
      )}

      <TabBillList bills={tab.bills} />
    </DesktopLayout>
  );
}
