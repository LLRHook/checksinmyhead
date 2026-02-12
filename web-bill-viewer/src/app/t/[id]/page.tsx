import {
  getTab,
  getTabImages,
  getSettlements,
  getTabMembers,
  computeTabPersonTotals,
  API_BASE_URL,
} from "@/lib/api";
import TabHeader from "@/components/TabHeader";
import TabPersonTotals from "@/components/TabPersonTotals";
import SettlementCard from "@/components/SettlementCard";
import TabImageGallery from "@/components/TabImageGallery";
import CollapsibleSection from "@/components/CollapsibleSection";
import PersonShare from "@/components/PersonShare";
import JoinTabButton from "@/components/JoinTabButton";
import MemberList from "@/components/MemberList";
import { notFound } from "next/navigation";
import { FaLock, FaTriangleExclamation, FaReceipt } from "react-icons/fa6";

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

  let tab;
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
  const images = await getTabImages(id, token);
  const settlements = tab.finalized ? await getSettlements(id, token) : [];
  const members = await getTabMembers(id, token);

  const venmoId =
    tab.bills
      .flatMap((b) => b.payment_methods || [])
      .find((pm) => pm.name?.toLowerCase().includes("venmo"))?.identifier ||
    null;

  return (
    <div className="min-h-screen bg-gradient-to-b from-[var(--secondary)] to-white dark:from-[var(--dark-bg)] dark:to-[var(--card-bg-dark)]">
      <div className="max-w-2xl mx-auto px-4 py-8">
        <TabHeader
          name={tab.name}
          description={tab.description}
          total={tab.total_amount}
          billCount={tab.bills.length}
          finalized={tab.finalized}
        />

        {tab.finalized && settlements.length > 0 ? (
          <SettlementCard settlements={settlements} venmoId={venmoId} />
        ) : (
          personTotals.length > 0 && (
            <TabPersonTotals personTotals={personTotals} venmoId={venmoId} />
          )
        )}

        {tab.bills.map((bill) => {
          const hasVenmo =
            bill.payment_methods?.find((pm) =>
              pm.name?.toLowerCase().includes("venmo"),
            )?.identifier || null;

          return (
            <div key={bill.id} className="mb-3">
              <CollapsibleSection
                title={`${bill.name} — $${bill.total.toFixed(2)}`}
                icon={<FaReceipt size={14} />}
              >
                <div className="space-y-3 pt-3">
                  {bill.person_shares.map((share) => (
                    <PersonShare
                      key={share.id}
                      personShare={share}
                      index={0}
                      hasVenmo={hasVenmo}
                    />
                  ))}
                </div>
              </CollapsibleSection>
            </div>
          );
        })}

        {images.length > 0 && (
          <TabImageGallery images={images} apiBaseUrl={API_BASE_URL} />
        )}

        {members.length > 0 && <MemberList members={members} />}

        <JoinTabButton tabId={id} token={token} />
      </div>
    </div>
  );
}
