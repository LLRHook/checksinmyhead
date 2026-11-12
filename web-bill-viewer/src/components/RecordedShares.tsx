"use client";

import { useState } from "react";
import { type Bill, updatePersonSharePaid } from "@/lib/api";
import { formatMoney } from "@/lib/currency";

interface RecordedShareRowsProps {
  bill: Bill;
  sourceToken?: string;
  busy?: boolean;
  onBusy?: (busy: boolean) => void;
  onError?: (message: string | null) => void;
  savedMarkerId?: number | null;
  onMarkerSaved?: (rowId: number) => void;
  onReadRecovered?: () => void;
  onChanged: () => Promise<void>;
}

// This view uses original ordered rows, including local rows without a remote ID.
// A label, participant selector or destination/member proof never selects a write.
export function RecordedShareRows({
  bill,
  sourceToken,
  busy = false,
  onBusy,
  onError,
  savedMarkerId = null,
  onMarkerSaved,
  onReadRecovered,
  onChanged,
}: RecordedShareRowsProps) {
  return (
    <section aria-label="Recorded receipt shares" className="space-y-3">
      <h2 className="sr-only">Recorded receipt shares</h2>
      <p role="status" className="text-sm text-[var(--text-secondary)]">
        Recorded history; ownership needs review. Original amounts and manual
        paid flags are retained.
      </p>
      {savedMarkerId !== null && (
        <div>
          <p role="status">
            Marker saved for recorded row {savedMarkerId}. Current status is
            unavailable until reread.
          </p>
          <button
            type="button"
            disabled={busy}
            aria-label="Retry current receipt status"
            className="rounded-xl border px-4 py-2 font-semibold disabled:opacity-50"
            onClick={async () => {
              if (busy) return;
              onBusy?.(true);
              onError?.(null);
              try {
                await onChanged();
                onReadRecovered?.();
              } catch {
                onError?.(
                  "Marker saved. Current receipt status is unavailable; retry the read after review.",
                );
              } finally {
                onBusy?.(false);
              }
            }}
          >
            Retry current receipt status
          </button>
        </div>
      )}
      {bill.person_shares.map((share, index) => {
        const remoteId = Number.isSafeInteger(share.id) && share.id > 0;
        const occurrence = remoteId
          ? `recorded row ${share.id}`
          : `recorded occurrence ${index + 1}`;
        const label = `${share.person_name || "Unnamed"} · ${occurrence}`;
        return (
          <article
            key={remoteId ? `row:${share.id}` : `occurrence:${index}`}
            aria-label={label}
            className="rounded-2xl bg-[var(--card-bg-light)] p-5 shadow-sm dark:bg-[var(--card-bg-dark)] dark:border dark:border-[var(--border-dark)]"
          >
            <h3 className="font-semibold text-[var(--accent)] dark:text-white">
              {label}
            </h3>
            <p className="font-mono text-lg">
              {Number.isFinite(share.total)
                ? formatMoney(share.total, bill.currency_code ?? "USD")
                : "Amount unavailable"}
            </p>
            <p className="text-sm text-[var(--text-secondary)]">
              {share.paid ? "Marked paid (manual)" : "Not marked paid"}
            </p>
            {remoteId && sourceToken && (
              <button
                type="button"
                disabled={busy || savedMarkerId !== null}
                className="mt-3 rounded-xl border border-[var(--border-light)] px-4 py-2 font-semibold disabled:opacity-50 dark:border-[var(--border-dark)]"
                aria-label={`Mark ${occurrence} ${share.paid ? "unpaid" : "paid"} with source proof`}
                onClick={async () => {
                  if (busy || savedMarkerId !== null || !sourceToken) return;
                  onBusy?.(true);
                  onError?.(null);
                  let saved = false;
                  try {
                    await updatePersonSharePaid(
                      bill.id,
                      share.id,
                      !share.paid,
                      sourceToken,
                    );
                    saved = true;
                    onMarkerSaved?.(share.id);
                    await onChanged();
                    onReadRecovered?.();
                  } catch {
                    onError?.(
                      saved
                        ? "Marker saved. Current receipt status is unavailable; retry the read after review."
                        : "Recorded payment status is unavailable. Refresh and review before retrying.",
                    );
                  } finally {
                    onBusy?.(false);
                  }
                }}
              >
                {share.paid
                  ? "Mark recorded row unpaid"
                  : "Mark recorded row paid"}
              </button>
            )}
          </article>
        );
      })}
    </section>
  );
}

export default function RecordedShares({
  bill,
  sourceToken,
  allowSourceEntry = false,
  onChanged,
}: {
  bill: Bill;
  sourceToken?: string;
  allowSourceEntry?: boolean;
  onChanged: () => Promise<void>;
}) {
  const [source, setSource] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [savedMarkerId, setSavedMarkerId] = useState<number | null>(null);
  return (
    <div className="space-y-4">
      {allowSourceEntry && (
        <label className="block text-sm text-[var(--text-secondary)]">
          Source bill capability for recorded paid status
          <input
            type="password"
            autoComplete="off"
            value={source}
            onChange={(event) => setSource(event.target.value)}
            className="mt-2 block w-full rounded-xl border border-[var(--border-light)] bg-transparent p-3 dark:border-[var(--border-dark)]"
          />
        </label>
      )}
      <RecordedShareRows
        bill={bill}
        sourceToken={
          sourceToken ?? (allowSourceEntry && source ? source : undefined)
        }
        busy={busy}
        onBusy={setBusy}
        onError={setError}
        savedMarkerId={savedMarkerId}
        onMarkerSaved={setSavedMarkerId}
        onReadRecovered={() => setSavedMarkerId(null)}
        onChanged={onChanged}
      />
      {error && <p role="alert">{error}</p>}
    </div>
  );
}
