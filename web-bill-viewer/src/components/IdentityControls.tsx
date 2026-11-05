"use client";
import { useState } from "react";
import {
  type Bill,
  type CurrentMember,
  createParticipant,
  decideBinding,
  type IdentityContext,
  type Participant,
  renameCurrentMember,
  renameParticipant,
  requestBinding,
} from "@/lib/api";
import { occurrenceLabel } from "@/lib/identity-storage";

const actionStyle =
  "px-3 py-2 rounded-xl border border-[var(--border-light)] dark:border-[var(--border-dark)] disabled:opacity-50";
export default function IdentityControls({
  bill,
  context,
  member,
  selected,
  onSelect,
  onChanged,
}: {
  bill: Bill;
  context: IdentityContext;
  member: CurrentMember | null;
  selected: number | null;
  onSelect: (id: number) => void;
  onChanged: () => Promise<void>;
}) {
  const [label, setLabel] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [source, setSource] = useState("");
  const [pendingCreate, setPendingCreate] = useState<{
    ref: string;
    label: string;
    revision: number;
  } | null>(null);
  const [retry, setRetry] = useState<(() => Promise<unknown>) | null>(null);
  const ready =
    bill.identity_version === 2 && bill.identity_review_status === "ready";
  const run = async (work: () => Promise<unknown>) => {
    setBusy(true);
    setError("");
    try {
      await work();
      setRetry(null);
      await onChanged();
    } catch (error) {
      setError(
        error instanceof Error ? error.message : "Identity action failed.",
      );
      setRetry(() => work);
      await onChanged();
    } finally {
      setBusy(false);
    }
  };
  const rename = (p: Participant) => {
    const name = window.prompt(`Rename ${occurrenceLabel(p)}`, p.label);
    if (name === null) return;
    void run(() =>
      renameParticipant(
        context,
        p.participant_id,
        name,
        bill.identity_revision ?? -1,
        source || undefined,
      ),
    );
  };
  return (
    <section
      className="rounded-2xl p-4 border border-[var(--border-light)] dark:border-[var(--border-dark)] mb-5"
      aria-label="Receipt participants"
    >
      <h2 className="font-semibold mb-2">Choose a receipt occurrence</h2>
      {!ready && (
        <p role="status">
          Recorded history; ownership needs review. Identity edits are
          unavailable.
        </p>
      )}
      <div className="space-y-3">
        {(bill.participants ?? []).map((p) => (
          <div
            key={p.participant_id}
            className="flex flex-wrap gap-2 items-center"
          >
            <button
              className={actionStyle}
              type="button"
              aria-pressed={selected === p.participant_id}
              disabled={busy || !ready}
              onClick={() => onSelect(p.participant_id)}
            >
              {occurrenceLabel(p)}
            </button>
            <span className="text-sm">
              {p.binding_state}
              {p.member_id ? ` · member #${p.member_id}` : ""}
              {p.pending_member_id
                ? ` · member #${p.pending_member_id} requested`
                : ""}
            </span>
            {ready &&
              (context.tabId === undefined ||
                member?.role === "creator" ||
                p.member_id === member?.member_id ||
                source) && (
                <button
                  className={actionStyle}
                  type="button"
                  disabled={busy}
                  onClick={() => rename(p)}
                >
                  Rename
                </button>
              )}
            {ready &&
              context.tabId &&
              member &&
              p.binding_state === "unbound" && (
                <button
                  className={actionStyle}
                  type="button"
                  disabled={busy}
                  onClick={() =>
                    void run(() =>
                      requestBinding(
                        context,
                        p.participant_id,
                        bill.identity_revision ?? -1,
                      ),
                    )
                  }
                >
                  Request my binding
                </button>
              )}
            {ready &&
              p.binding_state === "pending" &&
              (member?.role === "creator" || source) &&
              ["approve", "reject"].map((d) => (
                <button
                  className={actionStyle}
                  type="button"
                  disabled={busy}
                  key={d}
                  onClick={() =>
                    void run(() =>
                      decideBinding(
                        context,
                        p.participant_id,
                        bill.identity_revision ?? -1,
                        p.pending_request_revision ?? -1,
                        p.pending_member_id ?? 0,
                        d as "approve" | "reject",
                        source || undefined,
                      ),
                    )
                  }
                >
                  {d === "approve" ? "Approve" : "Reject"} member #
                  {p.pending_member_id} request #{p.pending_request_revision}
                </button>
              ))}
          </div>
        ))}
      </div>
      {ready && (
        <form
          className="flex gap-2 mt-4"
          onSubmit={(e) => {
            e.preventDefault();
            const op = pendingCreate ?? {
              ref: crypto.randomUUID(),
              label,
              revision: bill.identity_revision ?? -1,
            };
            setPendingCreate(op);
            void run(async () => {
              const r = await createParticipant(
                context,
                op.ref,
                op.label,
                op.revision,
              );
              onSelect(r.participant.participant_id);
              setPendingCreate(null);
            });
          }}
        >
          <label className="flex-1">
            New occurrence label (optional)
            <input
              className="block rounded-xl border p-2 w-full"
              value={label}
              onChange={(e) => setLabel(e.target.value)}
              disabled={busy || pendingCreate !== null}
            />
          </label>
          <button className={actionStyle} type="submit" disabled={busy}>
            Add occurrence
          </button>
        </form>
      )}
      {context.tabId && (
        <label className="block mt-3 text-sm">
          Source bill capability for approval (optional)
          <input
            type="password"
            autoComplete="off"
            className="block rounded-xl border p-2"
            value={source}
            onChange={(e) => setSource(e.target.value)}
          />
        </label>
      )}
      {context.tabId && member && context.memberToken && (
        <button
          type="button"
          className={actionStyle}
          disabled={busy}
          onClick={() => {
            const label = window.prompt("My tab label", member.display_name);
            if (label !== null)
              void run(() =>
                renameCurrentMember(
                  context.tabId ?? "",
                  context.token,
                  context.memberToken ?? "",
                  label,
                ),
              );
          }}
        >
          Rename my tab label
        </button>
      )}
      <p className="text-sm mt-2">
        Labels do not prove ownership. Pending requests cannot mark a receipt
        share paid.
      </p>
      {error && (
        <p role="alert">
          {error} Current state was refreshed; review it before retrying.
        </p>
      )}
      {retry && (
        <button
          type="button"
          className={actionStyle}
          disabled={busy}
          onClick={() => void run(retry)}
        >
          Retry original action
        </button>
      )}
    </section>
  );
}
