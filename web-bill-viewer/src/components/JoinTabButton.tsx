"use client";

import { useState, useEffect } from "react";
import { joinTab } from "@/lib/api";

interface JoinTabButtonProps {
  tabId: string;
  token: string;
}

export default function JoinTabButton({ tabId, token }: JoinTabButtonProps) {
  const [memberToken, setMemberToken] = useState<string | null>(null);
  const [displayName, setDisplayName] = useState<string | null>(null);
  const [showModal, setShowModal] = useState(false);
  const [inputName, setInputName] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const storageKey = `billington_member_${tabId}`;

  useEffect(() => {
    const stored = localStorage.getItem(storageKey);
    if (stored) {
      try {
        const data = JSON.parse(stored);
        setMemberToken(data.member_token);
        setDisplayName(data.display_name);
      } catch {}
    }
  }, [storageKey]);

  const handleJoin = async () => {
    const name = inputName.trim();
    if (!name || name.length > 30) {
      setError("Name must be 1-30 characters");
      return;
    }

    setIsLoading(true);
    setError(null);

    const result = await joinTab(tabId, token, name);

    if (result) {
      localStorage.setItem(storageKey, JSON.stringify(result));
      setMemberToken(result.member_token);
      setDisplayName(result.display_name);
      setShowModal(false);
      window.location.reload();
    } else {
      setError("Failed to join. Please try again.");
    }

    setIsLoading(false);
  };

  if (memberToken && displayName) {
    return (
      <div className="mb-6 flex justify-center">
        <span className="inline-flex items-center gap-2 text-sm font-medium text-emerald-700 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-900/30 px-4 py-2 rounded-full">
          <i className="fas fa-check-circle"></i>
          Joined as {displayName}
        </span>
      </div>
    );
  }

  return (
    <>
      <div className="mb-6 flex justify-center">
        <button
          onClick={() => setShowModal(true)}
          className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white font-semibold rounded-2xl hover:opacity-90 transition-opacity shadow-md"
        >
          <i className="fas fa-user-plus"></i>
          Join this trip
        </button>
      </div>

      {showModal && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4"
          onClick={() => setShowModal(false)}
        >
          <div
            className="bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-3xl p-8 shadow-2xl max-w-sm w-full"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 className="text-xl font-bold text-[var(--accent)] dark:text-white mb-2">
              Join this tab
            </h2>
            <p className="text-sm text-[var(--text-secondary)] mb-6">
              Enter your name so others know who you are.
            </p>
            <input
              type="text"
              placeholder="Your name"
              value={inputName}
              onChange={(e) => setInputName(e.target.value)}
              maxLength={30}
              className="w-full px-4 py-3 rounded-xl border border-[var(--border-light)] dark:border-[var(--border-dark)] bg-white dark:bg-black/20 text-[var(--accent)] dark:text-white placeholder-[var(--text-secondary)] focus:outline-none focus:ring-2 focus:ring-[var(--primary)] mb-4"
              autoFocus
              onKeyDown={(e) => e.key === "Enter" && handleJoin()}
            />
            {error && (
              <p className="text-sm text-red-500 mb-4">{error}</p>
            )}
            <div className="flex gap-3">
              <button
                onClick={() => setShowModal(false)}
                className="flex-1 px-4 py-3 rounded-xl border border-[var(--border-light)] dark:border-[var(--border-dark)] text-[var(--text-secondary)] font-medium hover:bg-gray-50 dark:hover:bg-white/5 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleJoin}
                disabled={isLoading || !inputName.trim()}
                className="flex-1 px-4 py-3 rounded-xl bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] text-white font-semibold hover:opacity-90 transition-opacity disabled:opacity-50"
              >
                {isLoading ? "Joining..." : "Join"}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
