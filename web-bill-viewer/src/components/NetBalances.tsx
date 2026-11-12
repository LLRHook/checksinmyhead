"use client";

import { FaArrowRight } from "react-icons/fa6";
import { SiVenmo } from "react-icons/si";
import { type NetBalance, type Party, partyKey, partyLabel } from "@/lib/api";
import { formatMoney } from "@/lib/currency";
import { buildVenmoPayUrl } from "@/lib/venmo";

interface NetBalancesProps {
  balances: NetBalance[];
  finalized: boolean;
  venmoId?: string | null;
  currentMemberName?: string | null;
  currentMemberId?: number | null;
  currency?: string;
}

export default function NetBalances({
  balances,
  finalized,
  venmoId,
  currentMemberId,
  currency = "USD",
}: NetBalancesProps) {
  if (balances.length === 0) return null;

  // Names are display content; scoped references distinguish collisions across
  // the whole list, including the rows later grouped under "Your Balances".
  const identitiesByLabel = new Map<string, Set<string>>();
  for (const balance of balances) {
    for (const party of [balance.from, balance.to]) {
      const label = partyLabel(party).trim().toLowerCase();
      const identities = identitiesByLabel.get(label) ?? new Set<string>();
      identities.add(
        typeof party === "string" ? `legacy:${party}` : partyKey(party),
      );
      identitiesByLabel.set(label, identities);
    }
  }
  const balanceReference = (party: Party | string) => {
    const label = partyLabel(party);
    if (
      typeof party === "string" ||
      (identitiesByLabel.get(label.trim().toLowerCase())?.size ?? 0) < 2
    )
      return null;
    return party.kind === "member"
      ? `member #${party.member_id}`
      : `receipt ${party.bill_id} #${party.participant_id}`;
  };

  const currentKey = currentMemberId;
  const mine = (p: Party | string) =>
    typeof p !== "string" && p.kind === "member" && p.member_id === currentKey;

  // Split into "your" balances and "other" balances
  const yourBalances = currentKey
    ? balances.filter((b) => mine(b.from) || mine(b.to))
    : [];
  const otherBalances = currentKey
    ? balances.filter((b) => !mine(b.from) && !mine(b.to))
    : balances;

  const renderBalance = (balance: NetBalance, showVenmo: boolean) => {
    const isYouFrom = currentKey && mine(balance.from);
    const isYouTo = currentKey && mine(balance.to);

    const fromLabel = isYouFrom ? "You" : partyLabel(balance.from);
    const fromReference = isYouFrom ? null : balanceReference(balance.from);
    const toLabel = isYouTo ? "You" : partyLabel(balance.to);
    const toReference = isYouTo ? null : balanceReference(balance.to);
    const hasReference = Boolean(fromReference || toReference);

    return (
      <div
        key={`${typeof balance.from === "string" ? balance.from : partyKey(balance.from)}-${typeof balance.to === "string" ? balance.to : partyKey(balance.to)}`}
        className={`bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl px-5 py-4 shadow-sm dark:shadow-none dark:border dark:border-[var(--border-dark)] flex items-center justify-between${hasReference ? " flex-wrap gap-3" : ""}`}
      >
        <div
          className={`flex items-center gap-3${hasReference ? " w-full min-w-0 sm:w-auto sm:flex-1" : ""}`}
        >
          <div
            className={`w-9 h-9 rounded-full bg-red-100 dark:bg-red-900/30 flex items-center justify-center font-semibold text-sm text-red-600 dark:text-red-400${hasReference ? " shrink-0" : ""}`}
          >
            {fromLabel[0]}
          </div>
          <span
            className={`font-medium text-[var(--accent)] dark:text-white${hasReference ? " min-w-0 flex-1 [overflow-wrap:anywhere]" : ""}`}
          >
            {fromLabel}
            {fromReference && (
              <span className="block text-xs text-[var(--text-secondary)]">
                {` · ${fromReference}`}
              </span>
            )}
          </span>
          <FaArrowRight
            className={`text-[var(--text-secondary)] text-xs${hasReference ? " shrink-0" : ""}`}
          />
          <div
            className={`w-9 h-9 rounded-full bg-emerald-100 dark:bg-emerald-900/30 flex items-center justify-center font-semibold text-sm text-emerald-600 dark:text-emerald-400${hasReference ? " shrink-0" : ""}`}
          >
            {toLabel[0]}
          </div>
          <span
            className={`font-medium text-[var(--accent)] dark:text-white${hasReference ? " min-w-0 flex-1 [overflow-wrap:anywhere]" : ""}`}
          >
            {toLabel}
            {toReference && (
              <span className="block text-xs text-[var(--text-secondary)]">
                {` · ${toReference}`}
              </span>
            )}
          </span>
        </div>
        <div
          className={`flex items-center gap-3${hasReference ? " ml-auto shrink-0" : ""}`}
        >
          <div className="text-xl font-bold font-mono text-[var(--accent)] dark:text-white">
            {formatMoney(balance.amount, currency)}
          </div>
          {showVenmo && venmoId && isYouFrom && (
            <button
              type="button"
              onClick={() => {
                window.location.href = buildVenmoPayUrl(
                  venmoId,
                  balance.amount.toFixed(2),
                  `Tab settlement - ${partyLabel(balance.to)}`,
                );
              }}
              className="h-10 px-4 bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white font-semibold rounded-xl flex items-center justify-center hover:opacity-90 transition-opacity border-none cursor-pointer"
            >
              <SiVenmo size={32} />
            </button>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="mb-6">
      {yourBalances.length > 0 && (
        <>
          <div className="mb-3 px-1">
            <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">
              Your Balances
            </h2>
          </div>
          <div className="space-y-3 mb-6">
            {yourBalances.map((b) => renderBalance(b, finalized))}
          </div>
        </>
      )}

      {otherBalances.length > 0 && (
        <>
          <div className="mb-3 px-1">
            <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)]">
              {yourBalances.length > 0 ? "All Balances" : "Balances"}
            </h2>
          </div>
          <div className="space-y-3">
            {otherBalances.map((b) => renderBalance(b, false))}
          </div>
        </>
      )}
    </div>
  );
}
