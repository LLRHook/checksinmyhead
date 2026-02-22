import { getBill } from "@/lib/api";
import type { Metadata } from "next";
import BillPageClient from "@/components/BillPageClient";
import { FaLock } from "react-icons/fa6";

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
    const bill = await getBill(id, token);
    return { title: `${bill.name} - Billington` };
  } catch {
    return { title: "Billington" };
  }
}

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

  return <BillPageClient id={id} token={token} />;
}
