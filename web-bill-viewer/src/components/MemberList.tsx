"use client";

import type { TabMember } from "@/lib/api";

interface MemberListProps {
  members: TabMember[];
}

export default function MemberList({ members }: MemberListProps) {
  if (members.length === 0) return null;

  return (
    <div className="mb-6">
      <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--text-secondary)] mb-3 px-1">
        Members
      </h2>
      <div className="flex flex-wrap gap-2">
        {members.map((member) => (
          <div
            key={member.id}
            className="inline-flex items-center gap-2 bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-full px-4 py-2 shadow-sm border border-[var(--border-light)] dark:border-[var(--border-dark)]"
          >
            {member.role === "creator" ? (
              <i className="fas fa-crown text-amber-500 text-xs"></i>
            ) : (
              <div className="w-6 h-6 rounded-full bg-gradient-to-br from-[var(--primary)] to-[var(--primary-dark)] flex items-center justify-center text-white text-xs font-semibold">
                {member.display_name[0]?.toUpperCase()}
              </div>
            )}
            <span className="text-sm font-medium text-[var(--accent)] dark:text-white">
              {member.display_name}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
