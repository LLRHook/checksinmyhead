import { ReactNode } from "react";

interface DesktopLayoutProps {
  sidebar: ReactNode;
  children: ReactNode;
}

export default function DesktopLayout({ sidebar, children }: DesktopLayoutProps) {
  return (
    <div className="min-h-screen bg-gradient-to-b from-[var(--secondary)] to-white dark:from-[var(--dark-bg)] dark:to-[var(--card-bg-dark)]">
      <div className="max-w-6xl mx-auto px-4 py-8 lg:px-8">
        <div className="lg:flex lg:gap-8">
          <aside className="lg:w-80 lg:flex-shrink-0 mb-8 lg:mb-0">
            <div className="lg:sticky lg:top-8">{sidebar}</div>
          </aside>
          <main className="flex-1 min-w-0">{children}</main>
        </div>
      </div>
    </div>
  );
}
