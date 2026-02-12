"use client";

import type { TabMember } from "@/lib/api";
import { FaCrown } from "react-icons/fa6";

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
            className="inline-flex items-center gap-2 bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-full px-4 py-2 shadow-sm dark:shadow-none dark:border dark:border-[var(--border-dark)]"
          >
            {member.role === "creator" ? (
              <FaCrown className="text-[var(--accent-warm)]" size={12} />
            ) : (
              <div className="w-6 h-6 rounded-full bg-[var(--secondary)] dark:bg-white/10 flex items-center justify-center text-[var(--text-secondary)] text-xs font-semibold">
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
