export default function Loading() {
  return (
    <div className="min-h-screen bg-gradient-to-b from-[var(--secondary)] to-white dark:from-[var(--dark-bg)] dark:to-[var(--card-bg-dark)]">
      <div className="max-w-6xl mx-auto px-4 py-8 lg:px-8">
        <div className="lg:flex lg:gap-8">
          {/* Sidebar skeleton */}
          <aside className="lg:w-80 lg:flex-shrink-0 mb-8 lg:mb-0">
            <div className="lg:sticky lg:top-8">
              {/* Header placeholder */}
              <div className="text-center lg:text-left mb-8">
                <div className="h-16 w-16 rounded-xl bg-[var(--secondary)] dark:bg-white/10 animate-pulse mx-auto lg:mx-0 mb-3" />
                <div className="h-7 w-48 rounded-lg bg-[var(--secondary)] dark:bg-white/10 animate-pulse mx-auto lg:mx-0 mb-2" />
                <div className="h-10 w-36 rounded-full bg-[var(--secondary)] dark:bg-white/10 animate-pulse mx-auto lg:mx-0" />
              </div>

              {/* Payment methods placeholder */}
              <div className="mb-6">
                <div className="h-4 w-32 rounded bg-[var(--secondary)] dark:bg-white/10 animate-pulse mb-3 px-1" />
                <div className="space-y-3">
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-lg bg-[var(--secondary)] dark:bg-white/10 animate-pulse" />
                    <div>
                      <div className="h-3 w-16 rounded bg-[var(--secondary)] dark:bg-white/10 animate-pulse mb-1" />
                      <div className="h-4 w-24 rounded bg-[var(--secondary)] dark:bg-white/10 animate-pulse" />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </aside>

          {/* Main content skeleton */}
          <main className="flex-1 min-w-0">
            <div className="mb-6">
              <div className="h-4 w-28 rounded bg-[var(--secondary)] dark:bg-white/10 animate-pulse mb-3 px-1" />
              <div className="space-y-3">
                {/* Person share card placeholders */}
                {[1, 2, 3].map((i) => (
                  <div
                    key={i}
                    className="bg-[var(--card-bg-light)] dark:bg-[var(--card-bg-dark)] rounded-2xl overflow-hidden shadow-sm dark:shadow-none dark:border dark:border-[var(--border-dark)]"
                  >
                    <div className="px-5 py-4 flex items-center gap-4">
                      <div className="w-11 h-11 rounded-full bg-[var(--secondary)] dark:bg-white/10 animate-pulse" />
                      <div>
                        <div className="h-5 w-24 rounded bg-[var(--secondary)] dark:bg-white/10 animate-pulse mb-1" />
                        <div className="h-6 w-16 rounded bg-[var(--secondary)] dark:bg-white/10 animate-pulse" />
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Loading spinner */}
            <div className="flex flex-col items-center justify-center py-8">
              <div className="w-8 h-8 border-3 border-[var(--secondary)] dark:border-white/10 border-t-[var(--primary)] rounded-full animate-spin mb-3" />
              <p className="text-sm text-[var(--text-secondary)]">
                Loading your bill...
              </p>
            </div>
          </main>
        </div>
      </div>
    </div>
  );
}
