"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import {
  FaArrowRight,
  FaCheck,
  FaChevronLeft,
  FaPeopleGroup,
} from "react-icons/fa6";
import {
  type Bill,
  type CurrentMember,
  getBill,
  getCurrentMember,
  getTab,
  type ItemAssignment,
  type ItemUpdate,
  joinTab,
  updateLazyBillItemAssignmentsBatch,
  updatePersonSharePaid,
  updateTabBillItemAssignmentsBatch,
  updateTabPersonSharePaid,
} from "@/lib/api";
import { formatMoney } from "@/lib/currency";
import {
  legacySuggestion,
  memberKey,
  readSelection,
  recoveryToken,
  type StoredMember,
  selectionKey,
} from "@/lib/identity-storage";
import {
  isLazyItemPaid,
  isLazyItemSelectionLocked,
  type LazyAssignmentDraft,
  lazyAssignmentsEqual,
  lazyBillRemainingCurrency,
  lazyBillRemainingTotal,
  remainingLazyPercentage,
  removeLazyAssignmentLeavingRemainder,
  setLazyAssignmentPercentage,
  updateLazyAssignmentDraft,
} from "@/lib/lazy-bill";
import { buildVenmoPayUrl } from "@/lib/venmo";
import IdentityControls from "./IdentityControls";
import RecordedShares from "./RecordedShares";

interface LazyBillBoardProps {
  bill: Bill;
  token: string;
  tabId?: string;
  refreshBill?: (updatedBill?: Bill) => Promise<void>;
}

type Stage = "receipt" | "picker" | "pay";
export interface LazyReadRecovery {
  message: string;
  afterRead: Stage;
  refreshedMessage?: string;
}
export interface LazyActionHost {
  bill: Bill;
  token: string;
  tabId?: string;
  member?: StoredMember | null;
  refresh: (updatedBill?: Bill) => Promise<void>;
  onRecovery: (recovery: LazyReadRecovery | null) => void;
  onError: (message: string | null) => void;
  onStage: (stage: Stage) => void;
  clearDrafts: () => void;
  onBusy: (busy: boolean) => void;
}

// These are the existing lazy action owners, with their current-read transition
// explicit. Recovery calls only the same scoped reader, never the mutation.
export async function readLazyViewerBill(
  billId: number,
  token: string,
  tabId?: string,
  memberToken?: string,
) {
  if (tabId) {
    const tab = await getTab(tabId, token, memberToken);
    const current = tab.bills.find((entry) => entry.id === billId);
    if (!current) throw new Error("Current receipt unavailable in this tab");
    return current;
  }
  return getBill(String(billId), token);
}

export async function recoverLazyRead(
  host: LazyActionHost,
  recovery: LazyReadRecovery,
  updatedBill?: Bill,
) {
  try {
    await host.refresh(updatedBill);
    host.onRecovery(null);
    host.onError(recovery.refreshedMessage ?? null);
    host.clearDrafts();
    host.onStage(recovery.afterRead);
  } catch {
    host.onRecovery(recovery);
    host.onError(recovery.message);
  }
}

export async function markLazyPaid(
  host: LazyActionHost,
  participantId: number | null,
) {
  if (participantId === null) return;
  const share = host.bill.person_shares.find(
    (s) => s.participant_id === participantId,
  );
  const participant = host.bill.participants?.find(
    (p) => p.participant_id === participantId,
  );
  if (
    !share?.id ||
    (host.tabId &&
      (participant?.binding_state !== "confirmed" ||
        participant.member_id !== host.member?.member_id))
  )
    return;
  host.onBusy(true);
  host.onError(null);
  try {
    try {
      if (host.tabId)
        await updateTabPersonSharePaid(
          host.tabId,
          host.bill.id,
          share.id,
          true,
          host.token,
          host.member?.member_token,
        );
      else
        await updatePersonSharePaid(host.bill.id, share.id, true, host.token);
    } catch {
      await recoverLazyRead(host, {
        message:
          "Paid marker could not be confirmed. Current receipt status is unavailable; retry the read before another action.",
        afterRead: "receipt",
        refreshedMessage:
          "Paid marker response was unavailable. Review the refreshed receipt before retrying.",
      });
      return;
    }
    host.onStage("receipt");
    await recoverLazyRead(host, {
      message:
        "Paid marker saved. Current receipt status is unavailable; retry the read.",
      afterRead: "receipt",
    });
  } finally {
    host.onBusy(false);
  }
}

export async function reviewLazySelection(
  host: LazyActionHost,
  updates: ItemUpdate[],
) {
  host.onBusy(true);
  host.onError(null);
  try {
    if (updates.some((update) => !update.expected_updated_at)) {
      await recoverLazyRead(host, {
        message:
          "Could not verify the receipt version. Current receipt is unavailable; retry the read.",
        afterRead: "picker",
        refreshedMessage:
          "Receipt refreshed. Review item versions before deliberately retrying.",
      });
      return;
    }
    let updatedBill: Bill | undefined;
    try {
      if (host.tabId && updates.length)
        await updateTabBillItemAssignmentsBatch(
          host.tabId,
          host.bill.id,
          updates,
          host.token,
          host.member?.member_token,
          host.bill.identity_revision,
        );
      else if (updates.length)
        updatedBill = await updateLazyBillItemAssignmentsBatch(
          host.bill.id,
          updates,
          host.token,
          host.bill.identity_revision,
        );
    } catch {
      host.clearDrafts();
      await recoverLazyRead(host, {
        message:
          "Selection could not be confirmed. Current receipt is unavailable; retry the read before deliberately editing again.",
        afterRead: "picker",
        refreshedMessage:
          "Receipt refreshed. Review the current selection before deliberately retrying.",
      });
      return;
    }
    host.clearDrafts();
    await recoverLazyRead(
      host,
      {
        message: updates.length
          ? "Selection saved. Current total is unavailable; retry the read."
          : "Current total is unavailable; retry the read.",
        afterRead: "pay",
      },
      updatedBill,
    );
  } finally {
    host.onBusy(false);
  }
}

export function LazyReadNotice({
  recovery,
  busy,
  onRetry,
}: {
  recovery: LazyReadRecovery;
  busy: boolean;
  onRetry: () => Promise<void>;
}) {
  return (
    <div className="mb-4 rounded-2xl border border-[var(--border-light)] p-4 dark:border-[var(--border-dark)]">
      <p role="status">{recovery.message}</p>
      <button
        type="button"
        disabled={busy}
        aria-label="Retry current receipt read"
        onClick={onRetry}
        className="mt-3 rounded-xl border px-4 py-2 font-semibold disabled:opacity-50"
      >
        Retry current receipt read
      </button>
    </div>
  );
}

export function hasCurrentLazyShare(bill: Bill, participantId: number | null) {
  const share = bill.person_shares.find(
    (s) => s.participant_id === participantId,
  );
  return Boolean(
    bill.identity_version === 2 &&
      bill.identity_state === "ready" &&
      bill.identity_review_status === "ready" &&
      share &&
      [share.total, share.subtotal, share.tax_share, share.tip_share].every(
        Number.isFinite,
      ),
  );
}
function round(value: number) {
  return Math.round(value * 100) / 100;
}

export default function LazyBillBoard({
  bill: initialBill,
  token,
  tabId,
  refreshBill,
}: LazyBillBoardProps) {
  const router = useRouter();
  const [billOverride, setBillOverride] = useState<{
    source: Bill;
    bill: Bill;
  } | null>(null);
  const bill =
    billOverride?.source === initialBill ? billOverride.bill : initialBill;
  const [stage, setStage] = useState<Stage>("receipt");
  const [member, setMember] = useState<StoredMember | null>(null);
  const [participantId, setParticipantId] = useState<number | null>(null);
  const [nameInput, setNameInput] = useState("");
  const [showJoin, setShowJoin] = useState(false);
  const [splitItemId, setSplitItemId] = useState<number | null>(null);
  const [splitPercentage, setSplitPercentage] = useState(50);
  const [splitMaximum, setSplitMaximum] = useState(100);
  const [splitUnclaimedCapacity, setSplitUnclaimedCapacity] = useState(100);
  const [draftAssignments, setDraftAssignments] = useState<Record<
    number,
    LazyAssignmentDraft
  > | null>(null);
  const [isSavingSelection, setIsSavingSelection] = useState(false);
  const [isPaying, setIsPaying] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [readRecovery, setReadRecovery] = useState<LazyReadRecovery | null>(
    null,
  );
  const [isReadingCurrent, setIsReadingCurrent] = useState(false);
  const currency = bill.currency_code ?? "USD";
  const remainingCurrency = lazyBillRemainingCurrency(bill);

  useEffect(() => {
    let active = true;
    const selected = readSelection(
      localStorage.getItem(selectionKey(bill.id)),
      bill.id,
      bill.participants ?? [],
    );
    setParticipantId(selected);
    if (tabId) {
      const raw = localStorage.getItem(memberKey(tabId));
      const proof = recoveryToken(raw);
      setNameInput(legacySuggestion(raw));
      if (proof !== undefined) {
        void getCurrentMember(tabId, token, proof)
          .then((me) => {
            if (!active) return;
            const stored: StoredMember = {
              ...me,
              version: 2,
              member_token: proof,
            };
            localStorage.setItem(memberKey(tabId), JSON.stringify(stored));
            setMember(stored);
          })
          .catch(() => {
            if (active) {
              setMember(null);
              setError(
                "Stored membership could not be authenticated. Retry recovery; joining by its label cannot replace it.",
              );
            }
          });
      }
    } else
      setNameInput(
        legacySuggestion(
          localStorage.getItem(`billington_lazy_bill_${bill.id}`),
        ),
      );
    return () => {
      active = false;
    };
  }, [bill.id, bill.participants, tabId, token]);

  const selectParticipant = (id: number) => {
    if (readRecovery) return;
    localStorage.setItem(
      selectionKey(bill.id),
      JSON.stringify({ version: 2, bill_id: bill.id, participant_id: id }),
    );
    setParticipantId(id);
    setDraftAssignments(null);
    if (id !== participantId) setStage("picker");
  };

  useEffect(() => {
    if (!tabId) return;
    const refresh = () => {
      if (document.visibilityState === "visible") router.refresh();
    };
    const interval = window.setInterval(refresh, 10_000);
    window.addEventListener("focus", refresh);
    document.addEventListener("visibilitychange", refresh);
    return () => {
      window.clearInterval(interval);
      window.removeEventListener("focus", refresh);
      document.removeEventListener("visibilitychange", refresh);
    };
  }, [router, tabId]);

  const participant = bill.participants?.find(
    (p) => p.participant_id === participantId,
  );
  const name = participant ? participant.label || "Unnamed" : "";
  const identityReady =
    bill.identity_version === 2 && bill.identity_review_status === "ready";
  const currentShare = bill.person_shares.find(
    (share) => participantId !== null && share.participant_id === participantId,
  );
  const getAssignments = (item: Bill["items"][number]) =>
    draftAssignments?.[item.id]?.assignments ?? item.assignments ?? [];
  const assignedItemIds = new Set(
    bill.items
      .filter((item) =>
        getAssignments(item).some(
          (assignment) =>
            participantId !== null &&
            assignment.participant_id === participantId,
        ),
      )
      .map((item) => item.id),
  );
  const selectionChanged = bill.items.some(
    (item) => !lazyAssignmentsEqual(getAssignments(item), item.assignments),
  );
  const totals = (() => {
    if (!name) return null;
    if (currentShare) return currentShare;
    const subtotal = bill.items.reduce((sum, item) => {
      const assignment = getAssignments(item).find(
        (entry) =>
          participantId !== null && entry.participant_id === participantId,
      );
      return (
        sum + (assignment ? (item.price * assignment.percentage) / 100 : 0)
      );
    }, 0);
    const assigned = bill.items.reduce(
      (sum, item) =>
        sum +
        getAssignments(item).reduce(
          (itemSum, assignment) =>
            itemSum + (item.price * assignment.percentage) / 100,
          0,
        ),
      0,
    );
    const proportion = assigned > 0 ? subtotal / assigned : 0;
    const tax = round(bill.tax * proportion);
    const tip = round(bill.tip_amount * proportion);
    return {
      id: 0,
      person_name: name,
      subtotal: round(subtotal),
      tax_share: tax,
      tip_share: tip,
      total: round(subtotal + tax + tip),
      paid: false,
    };
  })();

  const updateDraftAssignments = (
    item: Bill["items"][number],
    assignments: ItemAssignment[],
  ) => {
    setDraftAssignments((draft) =>
      updateLazyAssignmentDraft(draft, item.id, assignments, item.updated_at),
    );
  };

  const toggleItem = (item: Bill["items"][number]) => {
    if (readRecovery) return;
    const assignments = getAssignments(item);
    const mine = assignments.some(
      (assignment) =>
        participantId !== null && assignment.participant_id === participantId,
    );
    if (mine) {
      updateDraftAssignments(
        item,
        removeLazyAssignmentLeavingRemainder(assignments, participantId ?? 0),
      );
    } else {
      const available = remainingLazyPercentage(assignments);
      if (available > 0) {
        updateDraftAssignments(
          item,
          setLazyAssignmentPercentage(
            assignments,
            participantId ?? 0,
            available,
          ),
        );
      }
    }
    setError(null);
  };

  const refreshViewerBill = async (updatedBill?: Bill) => {
    if (refreshBill) {
      await refreshBill(updatedBill);
      return;
    }
    if (updatedBill) {
      setBillOverride({ source: initialBill, bill: updatedBill });
      return;
    }
    const current = await readLazyViewerBill(
      bill.id,
      token,
      tabId,
      member?.member_token,
    );
    setBillOverride({ source: initialBill, bill: current });
  };

  const actionHost = (onBusy: (busy: boolean) => void): LazyActionHost => ({
    bill,
    token,
    tabId,
    member,
    refresh: refreshViewerBill,
    onRecovery: setReadRecovery,
    onError: setError,
    onStage: setStage,
    clearDrafts: () => setDraftAssignments(null),
    onBusy,
  });
  const retryCurrentRead = async () => {
    if (!readRecovery || isReadingCurrent) return;
    setIsReadingCurrent(true);
    try {
      await recoverLazyRead(actionHost(setIsReadingCurrent), readRecovery);
    } finally {
      setIsReadingCurrent(false);
    }
  };
  const refreshIdentity = async () => {
    try {
      await refreshViewerBill();
    } catch {
      const recovery: LazyReadRecovery = {
        message:
          "Identity action needs a current receipt read. Current state is unavailable; retry the read.",
        afterRead: "picker",
      };
      setReadRecovery(recovery);
      setError(recovery.message);
    }
  };

  const beginPicking = () => {
    if (readRecovery) return;
    setError(null);
    if (tabId && !member) setShowJoin(true);
    else if (!participant)
      setError("Choose or add a receipt occurrence below.");
    else setStage("picker");
  };

  const reviewSelection = async () => {
    if (
      !identityReady ||
      participantId === null ||
      isSavingSelection ||
      readRecovery ||
      currentShare?.paid
    )
      return;
    if (!selectionChanged && hasCurrentLazyShare(bill, participantId)) {
      setStage("pay");
      return;
    }
    const updates = bill.items.flatMap((item) => {
      const assignments = getAssignments(item);
      if (lazyAssignmentsEqual(assignments, item.assignments)) return [];
      return [
        {
          itemId: item.id,
          expectedUpdatedAt: draftAssignments?.[item.id]?.expectedUpdatedAt,
          assignments,
        },
      ];
    });
    await reviewLazySelection(
      actionHost(setIsSavingSelection),
      updates.map(({ itemId, expectedUpdatedAt, assignments }) => ({
        item_id: itemId,
        expected_updated_at: expectedUpdatedAt,
        assignments,
      })),
    );
  };

  const saveName = async () => {
    const displayName = nameInput.trim();
    if (!displayName || displayName.length > 30) {
      setError("Use a name between 1 and 30 characters.");
      return;
    }
    setError(null);
    try {
      if (tabId) {
        const raw = localStorage.getItem(memberKey(tabId));
        const oldToken = recoveryToken(raw);
        if (oldToken !== undefined) {
          const me = await getCurrentMember(tabId, token, oldToken);
          const recovered: StoredMember = {
            ...me,
            version: 2,
            member_token: oldToken,
          };
          localStorage.setItem(memberKey(tabId), JSON.stringify(recovered));
          setMember(recovered);
          setShowJoin(false);
          return;
        }
        const result = await joinTab(tabId, token, displayName);
        if (!result) throw new Error("join failed");
        localStorage.setItem(
          memberKey(tabId),
          JSON.stringify({ ...result, version: 2 }),
        );
        setMember({ ...result, version: 2 });
      }
      setShowJoin(false);
      setStage("picker");
    } catch {
      setError("Could not save your name. Try again.");
    }
  };

  const openSplit = (item: Bill["items"][number]) => {
    if (readRecovery) return;
    const assignments = getAssignments(item);
    setSplitItemId(item.id);
    const available = remainingLazyPercentage(assignments, participantId ?? 0);
    const maximum = Math.max(1, Math.floor(available));
    setSplitMaximum(maximum);
    setSplitUnclaimedCapacity(available);
    const mine = assignments.find(
      (entry) =>
        participantId !== null && entry.participant_id === participantId,
    );
    setSplitPercentage(
      Math.min(maximum, Math.max(1, Math.round(mine?.percentage ?? available))),
    );
  };

  const setSplit = () => {
    if (readRecovery) return;
    const item = bill.items.find((entry) => entry.id === splitItemId);
    if (!item) return;
    updateDraftAssignments(
      item,
      setLazyAssignmentPercentage(
        getAssignments(item),
        participantId ?? 0,
        splitPercentage,
      ),
    );
    setSplitItemId(null);
    setError(null);
  };

  const markPaid = async () => {
    if (readRecovery || isPaying) return;
    await markLazyPaid(actionHost(setIsPaying), participantId);
  };

  const venmo = bill.payment_methods?.find((method) =>
    method.name.toLowerCase().includes("venmo"),
  );

  return (
    <>
      {readRecovery && (
        <LazyReadNotice
          recovery={readRecovery}
          busy={isReadingCurrent || isPaying || isSavingSelection}
          onRetry={retryCurrentRead}
        />
      )}
      {!identityReady && (
        <RecordedShares
          bill={bill}
          sourceToken={tabId ? undefined : token}
          allowSourceEntry={Boolean(tabId)}
          onChanged={() => refreshViewerBill()}
        />
      )}
      <fieldset disabled={readRecovery !== null} className="m-0 border-0 p-0">
        <IdentityControls
          bill={bill}
          context={{
            billId: bill.id,
            token,
            tabId,
            memberToken: member?.member_token,
          }}
          member={member as CurrentMember | null}
          selected={participantId}
          onSelect={selectParticipant}
          onChanged={refreshIdentity}
        />
      </fieldset>
      <div className="space-y-5">
        {stage === "receipt" && (
          <>
            <div className="rounded-3xl bg-[var(--card-bg-light)] p-5 shadow-sm dark:bg-[var(--card-bg-dark)] dark:border dark:border-[var(--border-dark)] sm:p-7">
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--text-secondary)]">
                Receipt
              </p>
              <h2 className="mt-1 text-xl font-bold text-[var(--accent)] dark:text-white">
                {bill.name}
              </h2>
              <div className="mt-4 divide-y divide-[var(--border-light)] dark:divide-[var(--border-dark)]">
                {bill.items.map((item) => (
                  <div
                    className="flex items-center justify-between gap-3 py-3 text-sm text-[var(--accent)] dark:text-white"
                    key={item.id}
                  >
                    <span
                      className={
                        isLazyItemPaid(item.assignments, bill.person_shares)
                          ? "line-through opacity-60"
                          : ""
                      }
                    >
                      {item.name}
                    </span>
                    <span className="flex shrink-0 items-center gap-2">
                      {isLazyItemPaid(item.assignments, bill.person_shares) && (
                        <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-medium text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300">
                          Paid
                        </span>
                      )}
                      <span className="font-mono">
                        {formatMoney(item.price, currency)}
                      </span>
                    </span>
                  </div>
                ))}
              </div>
              <div className="mt-3 border-t border-[var(--border-light)] pt-3 text-sm dark:border-[var(--border-dark)]">
                <div className="flex justify-between text-[var(--text-secondary)]">
                  <span>Remaining balance</span>
                  <span className="font-mono">
                    {formatMoney(
                      lazyBillRemainingTotal(bill),
                      remainingCurrency,
                    )}
                  </span>
                </div>
              </div>
            </div>
            <div className="rounded-3xl bg-[var(--primary)] p-5 text-white shadow-lg sm:p-7">
              <p className="text-sm text-white/75">
                Choose what you had. We’ll handle the math.
              </p>
              <button
                type="button"
                onClick={beginPicking}
                disabled={readRecovery !== null}
                className="mt-4 inline-flex w-full items-center justify-center gap-3 rounded-2xl bg-white px-5 py-4 text-base font-bold text-[var(--primary-dark)]"
              >
                {name ? "Pick my items" : "Choose my items"}
                <FaArrowRight size={14} />
              </button>
            </div>
          </>
        )}

        {stage === "picker" && (
          <>
            <button
              type="button"
              onClick={() => setStage("receipt")}
              className="inline-flex items-center gap-2 text-sm font-semibold text-[var(--text-secondary)]"
            >
              <FaChevronLeft size={12} /> Receipt
            </button>
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--text-secondary)]">
                Your items
              </p>
              <h2 className="mt-1 text-2xl font-bold text-[var(--accent)] dark:text-white">
                What did you have, {name}?
              </h2>
            </div>
            <div className="overflow-hidden rounded-3xl bg-[var(--card-bg-light)] shadow-sm dark:bg-[var(--card-bg-dark)] dark:border dark:border-[var(--border-dark)]">
              {bill.items.map((item) => {
                const assignments = getAssignments(item);
                const paid = isLazyItemPaid(assignments, bill.person_shares);
                const mine = assignedItemIds.has(item.id);
                const available = remainingLazyPercentage(
                  assignments,
                  participantId ?? 0,
                );
                const myAssignment = assignments.find(
                  (entry) =>
                    participantId !== null &&
                    entry.participant_id === participantId,
                );
                const locked = isLazyItemSelectionLocked(
                  paid,
                  Boolean(currentShare?.paid),
                );
                const unavailable = !mine && available < 1;
                return (
                  <div
                    key={item.id}
                    className={`flex items-center gap-3 border-b border-[var(--border-light)] px-4 py-4 last:border-0 dark:border-[var(--border-dark)] ${locked ? "opacity-50" : ""}`}
                  >
                    <button
                      type="button"
                      aria-label={`${mine ? "Unselect" : "Select"} ${item.name}`}
                      disabled={
                        !identityReady ||
                        participantId === null ||
                        unavailable ||
                        locked ||
                        isSavingSelection
                      }
                      onClick={() => toggleItem(item)}
                      className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border-2 ${mine ? "border-[var(--primary)] bg-[var(--primary)] text-white" : "border-[var(--border-light)] dark:border-[var(--border-dark)]"}`}
                    >
                      {mine && <FaCheck size={12} />}
                    </button>
                    <div
                      className={`min-w-0 flex-1 ${locked ? "line-through" : ""}`}
                    >
                      <p className="font-medium text-[var(--accent)] dark:text-white">
                        {item.name}
                      </p>
                      <p className="text-xs text-[var(--text-secondary)]">
                        {locked
                          ? paid
                            ? "Paid"
                            : currentShare?.paid
                              ? "Your share paid"
                              : "Part of this item paid"
                          : unavailable
                            ? `Taken by ${assignments[0]?.person_name ?? "someone"}`
                            : mine &&
                                myAssignment &&
                                myAssignment.percentage < 100
                              ? `${myAssignment.percentage}% · ${formatMoney((item.price * myAssignment.percentage) / 100, currency)} of ${formatMoney(item.price, currency)}`
                              : available < 100
                                ? `${Math.floor(available)}% unclaimed · ${formatMoney((item.price * available) / 100, currency)}`
                                : formatMoney(item.price, currency)}
                      </p>
                    </div>
                    <button
                      type="button"
                      disabled={
                        !identityReady ||
                        participantId === null ||
                        unavailable ||
                        locked ||
                        isSavingSelection
                      }
                      onClick={() => openSplit(item)}
                      aria-label={`Edit split for ${item.name}`}
                      className="rounded-xl p-3 text-[var(--text-secondary)] hover:bg-[var(--secondary)] disabled:opacity-30"
                    >
                      <FaPeopleGroup size={15} />
                    </button>
                  </div>
                );
              })}
            </div>
            {((totals?.total ?? 0) > 0 || selectionChanged) && (
              <button
                type="button"
                disabled={isSavingSelection || readRecovery !== null}
                onClick={() => void reviewSelection()}
                className="flex w-full items-center justify-center gap-3 rounded-2xl bg-[var(--primary)] px-5 py-4 font-bold text-white shadow-md disabled:opacity-70"
              >
                {isSavingSelection ? "Saving choices…" : "Review my total"}
                {!isSavingSelection && <FaArrowRight size={14} />}
              </button>
            )}
          </>
        )}

        {stage === "pay" &&
          !hasCurrentLazyShare(bill, participantId) &&
          !readRecovery && (
            <div>
              <p role="status">
                The current amount for this occurrence is unavailable. Review
                its items before payment.
              </p>
              <button
                type="button"
                onClick={() => setStage("picker")}
                className="mt-3 rounded-xl border px-4 py-2 font-semibold"
              >
                Back to items
              </button>
            </div>
          )}
        {stage === "pay" &&
          totals &&
          hasCurrentLazyShare(bill, participantId) &&
          !readRecovery && (
            <>
              <button
                type="button"
                onClick={() => setStage("picker")}
                className="inline-flex items-center gap-2 text-sm font-semibold text-[var(--text-secondary)]"
              >
                <FaChevronLeft size={12} /> Back to items
              </button>
              <div className="rounded-3xl bg-[var(--card-bg-light)] p-6 shadow-sm dark:bg-[var(--card-bg-dark)] dark:border dark:border-[var(--border-dark)]">
                <p className="text-sm font-semibold uppercase tracking-[0.18em] text-[var(--text-secondary)]">
                  Your total
                </p>
                <p className="mt-2 text-5xl font-bold tracking-tight text-[var(--accent)] dark:text-white">
                  {formatMoney(totals.total, currency)}
                </p>
                <div className="mt-6 space-y-2 border-t border-[var(--border-light)] pt-4 text-sm text-[var(--accent)] dark:border-[var(--border-dark)] dark:text-white">
                  <div className="flex justify-between">
                    <span>Your items</span>
                    <span>{formatMoney(totals.subtotal, currency)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Tax</span>
                    <span>{formatMoney(totals.tax_share, currency)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Tip</span>
                    <span>{formatMoney(totals.tip_share, currency)}</span>
                  </div>
                </div>
              </div>
              <div className="rounded-3xl bg-[var(--card-bg-light)] p-5 shadow-sm dark:bg-[var(--card-bg-dark)] dark:border dark:border-[var(--border-dark)]">
                <h2 className="font-bold text-[var(--accent)] dark:text-white">
                  Pay {name}
                </h2>
                {venmo && (
                  <a
                    href={buildVenmoPayUrl(
                      venmo.identifier,
                      totals.total.toFixed(2),
                      bill.name,
                    )}
                    className="mt-4 flex items-center justify-center rounded-2xl bg-[#4b938d] px-4 py-4 font-bold text-white"
                  >
                    Pay with Venmo
                  </a>
                )}
                {bill.payment_methods?.map((method) => (
                  <p
                    key={`${method.name}-${method.identifier}`}
                    className="mt-3 text-sm text-[var(--text-secondary)]"
                  >
                    {method.name}: {method.identifier}
                  </p>
                ))}
                <button
                  type="button"
                  disabled={
                    isPaying ||
                    readRecovery !== null ||
                    !currentShare?.id ||
                    Boolean(
                      tabId &&
                        (participant?.binding_state !== "confirmed" ||
                          participant.member_id !== member?.member_id),
                    )
                  }
                  onClick={markPaid}
                  className="mt-5 w-full rounded-2xl border border-[var(--border-light)] px-4 py-3 text-sm font-semibold text-[var(--accent)] disabled:opacity-50 dark:border-[var(--border-dark)] dark:text-white"
                >
                  {isPaying ? "Saving…" : "Mark as paid"}
                </button>
              </div>
            </>
          )}

        {error && (
          <p
            role="alert"
            className="rounded-2xl bg-red-50 px-4 py-3 text-sm text-red-600 dark:bg-red-950/30 dark:text-red-300"
          >
            {error}
          </p>
        )}
        {showJoin && (
          <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-4 sm:items-center">
            <div className="w-full max-w-md rounded-3xl bg-[var(--card-bg-light)] p-6 shadow-2xl dark:bg-[var(--card-bg-dark)]">
              <h2 className="text-xl font-bold text-[var(--accent)] dark:text-white">
                What should we call you?
              </h2>
              <p className="mt-2 text-sm text-[var(--text-secondary)]">
                Use a name friends will recognize.
              </p>
              <input
                value={nameInput}
                maxLength={30}
                onChange={(event) => setNameInput(event.target.value)}
                onKeyDown={(event) => event.key === "Enter" && void saveName()}
                placeholder="Your name"
                className="mt-5 w-full rounded-2xl border border-[var(--border-light)] bg-white px-4 py-3 dark:border-[var(--border-dark)] dark:bg-black/20 dark:text-white"
              />
              <div className="mt-5 flex gap-3">
                <button
                  type="button"
                  onClick={() => setShowJoin(false)}
                  className="flex-1 rounded-2xl border border-[var(--border-light)] px-4 py-3 text-sm font-semibold text-[var(--text-secondary)]"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={() => void saveName()}
                  className="flex-1 rounded-2xl bg-[var(--primary)] px-4 py-3 text-sm font-semibold text-white"
                >
                  Continue
                </button>
              </div>
            </div>
          </div>
        )}
        {splitItemId !== null && (
          <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-4 sm:items-center">
            <div className="w-full max-w-md rounded-3xl bg-[var(--card-bg-light)] p-6 shadow-2xl dark:bg-[var(--card-bg-dark)]">
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--text-secondary)]">
                Split item
              </p>
              <h2 className="mt-2 text-xl font-bold text-[var(--accent)] dark:text-white">
                {`Split ${bill.items.find((item) => item.id === splitItemId)?.name ?? "item"}`}
              </h2>
              <p className="mt-2 text-sm text-[var(--text-secondary)]">
                Choose how much you had. The rest stays available for someone
                else to claim.
              </p>
              <div className="mt-2 flex items-center justify-between text-sm font-semibold text-[var(--accent)] dark:text-white">
                <span>You · {splitPercentage}%</span>
                <span>
                  {Math.max(0, splitUnclaimedCapacity - splitPercentage)}%
                  unclaimed
                </span>
              </div>
              <input
                aria-label="Your share percentage"
                type="range"
                min="1"
                max={splitMaximum}
                step="1"
                value={splitPercentage}
                onChange={(event) =>
                  setSplitPercentage(Number(event.target.value))
                }
                className="mt-2 w-full accent-[var(--primary)]"
              />
              <div className="mt-5 flex gap-3">
                <button
                  type="button"
                  onClick={() => {
                    setSplitItemId(null);
                  }}
                  className="flex-1 rounded-2xl border border-[var(--border-light)] px-4 py-3 text-sm font-semibold text-[var(--text-secondary)]"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={setSplit}
                  disabled={splitMaximum < 1}
                  className="flex-1 rounded-2xl bg-[var(--primary)] px-4 py-3 text-sm font-semibold text-white"
                >
                  Apply split
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </>
  );
}
