"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import {
  FaArrowRight,
  FaCheck,
  FaChevronLeft,
  FaCodeBranch,
  FaReceipt,
} from "react-icons/fa6";
import {
  type Bill,
  type ItemAssignment,
  joinTab,
  updateTabBillItemAssignments,
  updateTabPersonSharePaid,
} from "@/lib/api";
import {
  billCurrencyCode,
  billUSDExchangeRate,
  billUSDTotal,
  formatOriginalMoney,
  formatUSDExchangeRate,
  formatUSDMoney,
  toUSD,
} from "@/lib/currency";
import { buildVenmoPayUrl } from "@/lib/venmo";

interface LazyBillBoardProps {
  tabId: string;
  token: string;
  bill: Bill;
}

type StoredMember = { display_name: string; member_token?: string };
type Stage = "landing" | "picker" | "pay";

function round(value: number) {
  return Math.round(value * 100) / 100;
}

function currentTotals(bill: Bill, name: string) {
  const share = bill.person_shares.find(
    (entry) => entry.person_name.toLowerCase() === name.toLowerCase(),
  );
  if (share) return share;

  const subtotal = bill.items.reduce((sum, item) => {
    const assignment = (item.assignments ?? []).find(
      (entry) => entry.person_name.toLowerCase() === name.toLowerCase(),
    );
    return sum + (assignment ? (item.price * assignment.percentage) / 100 : 0);
  }, 0);
  const assignedSubtotal = bill.items.reduce(
    (sum, item) =>
      sum +
      (item.assignments ?? []).reduce(
        (itemSum, entry) => itemSum + (item.price * entry.percentage) / 100,
        0,
      ),
    0,
  );
  const proportion = assignedSubtotal > 0 ? subtotal / assignedSubtotal : 0;
  const tax = round(bill.tax * proportion);
  const tip = round(bill.tip_amount * proportion);
  return {
    id: 0,
    person_name: name,
    items: [],
    subtotal: round(subtotal),
    tax_share: tax,
    tip_share: tip,
    total: round(subtotal + tax + tip),
    paid: false,
  };
}

export function ReceiptSummary({ bill }: { bill: Bill }) {
  const currency = billCurrencyCode(bill);

  return (
    <div className="rounded-3xl bg-[var(--card-bg-light)] p-5 shadow-sm dark:bg-[var(--card-bg-dark)] dark:border dark:border-[var(--border-dark)] sm:p-7">
      <div className="mb-5 flex items-center gap-3">
        <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-[var(--secondary)] text-[var(--primary)] dark:bg-white/10">
          <FaReceipt />
        </div>
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--text-secondary)]">
            Receipt
          </p>
          <h2 className="text-xl font-bold text-[var(--accent)] dark:text-white">
            {bill.name}
          </h2>
        </div>
      </div>
      <div className="divide-y divide-[var(--border-light)] dark:divide-[var(--border-dark)]">
        {bill.items.map((item) => (
          <div className="flex justify-between py-3 text-sm" key={item.id}>
            <span className="text-[var(--accent)] dark:text-white">
              {item.name}
            </span>
            <span className="font-mono font-medium text-[var(--accent)] dark:text-white">
              {formatOriginalMoney(item.price, bill)}
            </span>
          </div>
        ))}
      </div>
      <div className="mt-4 space-y-2 border-t border-[var(--border-light)] pt-4 text-sm dark:border-[var(--border-dark)]">
        <SummaryRow bill={bill} label="Subtotal" value={bill.subtotal} />
        <SummaryRow bill={bill} label="Tax" value={bill.tax} />
        <SummaryRow
          bill={bill}
          label={`Tip${bill.tip_percentage ? ` (${bill.tip_percentage}%)` : ""}`}
          value={bill.tip_amount}
        />
        <SummaryRow bill={bill} label="Total" value={bill.total} strong />
      </div>
      {currency !== "USD" && (
        <div className="mt-4 rounded-2xl bg-[var(--secondary)] px-4 py-3 text-sm dark:bg-white/10">
          <div className="flex items-center justify-between gap-4">
            <span className="text-[var(--text-secondary)]">
              Recorded in USD
            </span>
            <strong className="font-mono text-[var(--accent)] dark:text-white">
              {formatUSDMoney(billUSDTotal(bill))}
            </strong>
          </div>
          <p className="mt-1 text-xs text-[var(--text-secondary)]">
            Frozen at 1 {currency} ={" "}
            {formatUSDExchangeRate(billUSDExchangeRate(bill))}
            {bill.exchange_rate_date ? ` on ${bill.exchange_rate_date}` : ""}
            {bill.exchange_rate_source ? ` · ${bill.exchange_rate_source}` : ""}
          </p>
        </div>
      )}
    </div>
  );
}

function SummaryRow({
  bill,
  label,
  value,
  strong = false,
}: {
  bill: Bill;
  label: string;
  value: number;
  strong?: boolean;
}) {
  return (
    <div
      className={`flex justify-between ${strong ? "pt-2 text-base font-bold" : "text-[var(--text-secondary)]"}`}
    >
      <span>{label}</span>
      <span className="font-mono text-[var(--accent)] dark:text-white">
        {formatOriginalMoney(value, bill)}
      </span>
    </div>
  );
}

export default function LazyBillBoard({
  tabId,
  token,
  bill,
}: LazyBillBoardProps) {
  const router = useRouter();
  const [stage, setStage] = useState<Stage>("landing");
  const [member, setMember] = useState<StoredMember | null>(null);
  const [nameInput, setNameInput] = useState("");
  const [showJoin, setShowJoin] = useState(false);
  const [splitItemId, setSplitItemId] = useState<number | null>(null);
  const [splitNames, setSplitNames] = useState("");
  const [savingItemId, setSavingItemId] = useState<number | null>(null);
  const [isPaying, setIsPaying] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const stored = localStorage.getItem(`billington_member_${tabId}`);
    if (!stored) return;
    try {
      setMember(JSON.parse(stored) as StoredMember);
    } catch {
      /* ignore malformed local state */
    }
  }, [tabId]);

  const name = member?.display_name?.trim() ?? "";
  const totals = useMemo(() => currentTotals(bill, name), [bill, name]);
  const currentShare = bill.person_shares.find(
    (share) => share.person_name.toLowerCase() === name.toLowerCase(),
  );
  const venmo = bill.payment_methods.find((method) =>
    method.name.toLowerCase().includes("venmo"),
  );

  const saveAssignments = async (
    itemId: number,
    assignments: ItemAssignment[],
  ) => {
    const item = bill.items.find((entry) => entry.id === itemId);
    setSavingItemId(itemId);
    setError(null);
    try {
      await updateTabBillItemAssignments(
        tabId,
        bill.id,
        itemId,
        assignments,
        token,
        item?.updated_at,
      );
      router.refresh();
    } catch (caught) {
      setError(
        caught instanceof Error && caught.message.includes("item changed")
          ? "Someone updated that item. The receipt has been refreshed."
          : "Could not save that selection. Try again.",
      );
      router.refresh();
    } finally {
      setSavingItemId(null);
    }
  };

  const joinAndContinue = async () => {
    const displayName = nameInput.trim();
    if (!displayName || displayName.length > 30) {
      setError("Use a name between 1 and 30 characters.");
      return;
    }
    setError(null);
    const result = await joinTab(tabId, token, displayName);
    if (!result) {
      setError("Could not join this bill. Try again.");
      return;
    }
    localStorage.setItem(`billington_member_${tabId}`, JSON.stringify(result));
    setMember(result);
    setShowJoin(false);
    setStage("picker");
  };

  const startPicking = () => {
    setError(null);
    if (!name) setShowJoin(true);
    else setStage("picker");
  };

  const claimItem = (itemId: number) => {
    if (!name) return setShowJoin(true);
    const item = bill.items.find((entry) => entry.id === itemId);
    if (!item || (item.assignments ?? []).length > 0) return;
    void saveAssignments(itemId, [{ person_name: name, percentage: 100 }]);
  };

  const saveSplit = () => {
    const item = bill.items.find((entry) => entry.id === splitItemId);
    if (!item) return;
    const names = Array.from(
      new Map(
        splitNames
          .split(",")
          .map((entry) => entry.trim())
          .filter(Boolean)
          .map((entry) => [entry.toLowerCase(), entry]),
      ).values(),
    );
    if (!names.length) {
      setError("Add at least one person.");
      return;
    }
    const percentage = round(100 / names.length);
    void saveAssignments(
      item.id,
      names.map((person, index) => ({
        person_name: person,
        percentage:
          index === names.length - 1
            ? round(100 - percentage * (names.length - 1))
            : percentage,
      })),
    );
    setSplitItemId(null);
    setSplitNames("");
  };

  const markPaid = async () => {
    if (!currentShare?.id) {
      setError("Select an item first so we can calculate your share.");
      return;
    }
    setIsPaying(true);
    try {
      await updateTabPersonSharePaid(
        tabId,
        bill.id,
        currentShare.id,
        true,
        token,
        member?.member_token,
      );
      setStage("landing");
      router.refresh();
    } catch {
      setError("We could not save that payment yet.");
    } finally {
      setIsPaying(false);
    }
  };

  if (stage === "landing") {
    return (
      <div className="space-y-5">
        <ReceiptSummary bill={bill} />
        <div className="rounded-3xl bg-[var(--primary)] p-5 text-white shadow-lg sm:p-7">
          <p className="text-sm text-white/75">
            Everyone picks their own line items. We’ll handle the math.
          </p>
          <button
            type="button"
            onClick={startPicking}
            className="mt-4 inline-flex w-full items-center justify-center gap-3 rounded-2xl bg-white px-5 py-4 text-base font-bold text-[var(--primary-dark)] transition-transform hover:-translate-y-0.5"
          >
            {name ? "Pick my share" : "What was yours?"}
            <FaArrowRight size={14} />
          </button>
        </div>
        {error && <ErrorMessage message={error} />}
        {showJoin && (
          <JoinDialog
            name={nameInput}
            setName={setNameInput}
            onClose={() => setShowJoin(false)}
            onJoin={joinAndContinue}
          />
        )}
      </div>
    );
  }

  if (stage === "pay") {
    return (
      <div className="space-y-5">
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
            {formatOriginalMoney(totals.total, bill)}
          </p>
          <p className="mt-2 text-sm font-semibold text-[var(--primary)]">
            Pay {formatUSDMoney(toUSD(totals.total, bill))}
          </p>
          <div className="mt-6 space-y-2 border-t border-[var(--border-light)] pt-4 text-sm dark:border-[var(--border-dark)]">
            <SummaryRow
              bill={bill}
              label="Your items"
              value={totals.subtotal}
            />
            <SummaryRow bill={bill} label="Tax" value={totals.tax_share} />
            <SummaryRow bill={bill} label="Tip" value={totals.tip_share} />
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
                toUSD(totals.total, bill).toFixed(2),
                bill.name,
              )}
              className="mt-4 flex items-center justify-center rounded-2xl bg-[#4b938d] px-4 py-4 font-bold text-white"
            >
              Pay with Venmo
            </a>
          )}
          <p className="mt-4 text-sm text-[var(--text-secondary)]">
            {venmo
              ? `${venmo.name}: ${venmo.identifier}`
              : "Use one of the payment methods shown with the bill."}
          </p>
          <button
            type="button"
            disabled={isPaying}
            onClick={markPaid}
            className="mt-5 w-full rounded-2xl border border-[var(--border-light)] px-4 py-3 text-sm font-semibold text-[var(--accent)] dark:border-[var(--border-dark)] dark:text-white"
          >
            {isPaying ? "Saving…" : "Mark as paid"}
          </button>
        </div>
        {error && <ErrorMessage message={error} />}
      </div>
    );
  }

  return (
    <div className="space-y-5">
      <button
        type="button"
        onClick={() => setStage("landing")}
        className="inline-flex items-center gap-2 text-sm font-semibold text-[var(--text-secondary)]"
      >
        <FaChevronLeft size={12} /> Receipt overview
      </button>
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--text-secondary)]">
          Your items
        </p>
        <h2 className="mt-1 text-2xl font-bold text-[var(--accent)] dark:text-white">
          Tap what you had
        </h2>
        <p className="mt-2 text-sm text-[var(--text-secondary)]">
          Select a line, or split it with someone else.
        </p>
      </div>
      <div className="overflow-hidden rounded-3xl bg-[var(--card-bg-light)] shadow-sm dark:bg-[var(--card-bg-dark)] dark:border dark:border-[var(--border-dark)]">
        {bill.items.map((item) => {
          const assignments = item.assignments ?? [];
          const mine = assignments.some(
            (entry) => entry.person_name.toLowerCase() === name.toLowerCase(),
          );
          const unavailable = assignments.length > 0 && !mine;
          const locked = Boolean(currentShare?.paid && mine);
          return (
            <div
              key={item.id}
              className={`flex items-center gap-3 border-b border-[var(--border-light)] px-4 py-4 last:border-0 dark:border-[var(--border-dark)] ${locked ? "opacity-50" : ""}`}
            >
              <button
                type="button"
                aria-label={`${mine ? "Unselect" : "Select"} ${item.name}`}
                disabled={unavailable || locked || savingItemId === item.id}
                onClick={() =>
                  mine ? void saveAssignments(item.id, []) : claimItem(item.id)
                }
                className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-lg border-2 ${mine ? "border-[var(--primary)] bg-[var(--primary)] text-white" : "border-[var(--border-light)] dark:border-[var(--border-dark)]"}`}
              >
                {mine && <FaCheck size={12} />}
              </button>
              <div className={`min-w-0 flex-1 ${locked ? "line-through" : ""}`}>
                <p className="font-medium text-[var(--accent)] dark:text-white">
                  {item.name}
                </p>
                <p className="text-xs text-[var(--text-secondary)]">
                  {locked
                    ? "Paid"
                    : unavailable
                      ? `Taken by ${assignments[0]?.person_name ?? "someone"}`
                      : formatOriginalMoney(item.price, bill)}
                </p>
              </div>
              <button
                type="button"
                disabled={unavailable || locked}
                onClick={() => {
                  setSplitItemId(item.id);
                  setSplitNames(
                    [name, ...assignments.map((entry) => entry.person_name)]
                      .filter(Boolean)
                      .join(", "),
                  );
                }}
                className="rounded-xl p-3 text-[var(--text-secondary)] hover:bg-[var(--secondary)] disabled:opacity-30"
                aria-label={`Split ${item.name}`}
              >
                <FaCodeBranch size={14} />
              </button>
            </div>
          );
        })}
      </div>
      {totals.total > 0 && (
        <button
          type="button"
          onClick={() => setStage("pay")}
          className="flex w-full items-center justify-center gap-3 rounded-2xl bg-[var(--primary)] px-5 py-4 font-bold text-white shadow-md"
        >
          Review my total <FaArrowRight size={14} />
        </button>
      )}
      {error && <ErrorMessage message={error} />}
      {splitItemId !== null && (
        <SplitDialog
          value={splitNames}
          setValue={setSplitNames}
          onClose={() => setSplitItemId(null)}
          onSave={saveSplit}
        />
      )}
    </div>
  );
}

function ErrorMessage({ message }: { message: string }) {
  return (
    <p className="rounded-2xl bg-red-50 px-4 py-3 text-sm text-red-600 dark:bg-red-950/30 dark:text-red-300">
      {message}
    </p>
  );
}
function JoinDialog({
  name,
  setName,
  onClose,
  onJoin,
}: {
  name: string;
  setName: (value: string) => void;
  onClose: () => void;
  onJoin: () => void;
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-4 sm:items-center">
      <div className="w-full max-w-md rounded-3xl bg-[var(--card-bg-light)] p-6 shadow-2xl dark:bg-[var(--card-bg-dark)]">
        <h2 className="text-xl font-bold text-[var(--accent)] dark:text-white">
          Who are you?
        </h2>
        <p className="mt-2 text-sm text-[var(--text-secondary)]">
          Use a name your friends will recognize.
        </p>
        <input
          value={name}
          onChange={(event) => setName(event.target.value)}
          onKeyDown={(event) => event.key === "Enter" && onJoin()}
          placeholder="Your name"
          className="mt-5 w-full rounded-2xl border border-[var(--border-light)] bg-white px-4 py-3 dark:border-[var(--border-dark)] dark:bg-black/20 dark:text-white"
        />
        <div className="mt-5 flex gap-3">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 rounded-2xl border border-[var(--border-light)] px-4 py-3 text-sm font-semibold text-[var(--text-secondary)] dark:border-[var(--border-dark)]"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onJoin}
            className="flex-1 rounded-2xl bg-[var(--primary)] px-4 py-3 text-sm font-semibold text-white"
          >
            Continue
          </button>
        </div>
      </div>
    </div>
  );
}
function SplitDialog({
  value,
  setValue,
  onClose,
  onSave,
}: {
  value: string;
  setValue: (value: string) => void;
  onClose: () => void;
  onSave: () => void;
}) {
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-4 sm:items-center">
      <div className="w-full max-w-md rounded-3xl bg-[var(--card-bg-light)] p-6 shadow-2xl dark:bg-[var(--card-bg-dark)]">
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[var(--text-secondary)]">
          Split item
        </p>
        <h2 className="mt-2 text-xl font-bold text-[var(--accent)] dark:text-white">
          Who had this?
        </h2>
        <input
          value={value}
          onChange={(event) => setValue(event.target.value)}
          placeholder="You, Alex"
          className="mt-5 w-full rounded-2xl border border-[var(--border-light)] bg-white px-4 py-3 dark:border-[var(--border-dark)] dark:bg-black/20 dark:text-white"
        />
        <div className="mt-5 flex gap-3">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 rounded-2xl border border-[var(--border-light)] px-4 py-3 text-sm font-semibold text-[var(--text-secondary)] dark:border-[var(--border-dark)]"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onSave}
            className="flex-1 rounded-2xl bg-[var(--primary)] px-4 py-3 text-sm font-semibold text-white"
          >
            Split evenly
          </button>
        </div>
      </div>
    </div>
  );
}
