import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy | Billington",
  description: "How Billington handles app and shared bill data.",
};

const sections = [
  {
    title: "Information we handle",
    paragraphs: [
      "Bills and tabs include names, receipt line items and amounts, participant names, split and payment status, optional payment handles, and tab member display names. This information is stored in Billington's online database and shown to people with the relevant share link.",
      "Random access and member tokens replace accounts. The app stores some tokens on your device; web links contain an access token. The web host receives that link to render the shared page, and Billington's API receives the token to authorize access. Anyone with a valid share link may be able to view or update associated content, so treat it like a private key.",
      "If you choose receipt scanning, the selected image is sent to Billington's API and then to Anthropic's Claude API to extract receipt details. Billington's parser returns extracted text and amounts; it does not save the uploaded image in Billington's database. Anthropic says it normally deletes API inputs and outputs within 30 days, subject to exceptions in its retention terms.",
      "Currency requests may be sent by our API to Frankfurter or, when configured, ExchangeRate-API. These requests contain currency codes, not bill contents.",
      "The API logs request IP address, path, response status, and timing. Share tokens are not included in the API's request path logs. Slow database query logs may include SQL statements and values. Hosting and infrastructure providers may also process technical data needed to operate the service.",
      "The app stores bill history, participant names, preferences, and tab/token data on your device. The web viewer stores some lazy-bill participant details in your browser's local storage.",
    ],
  },
  {
    title: "How we use and share information",
    paragraphs: [
      "We use this information to create and share bills and tabs, calculate splits, remember local preferences, prevent abuse of receipt scanning, and operate and secure the service. We do not sell bill or tab content.",
      "Information is processed by providers needed for the feature you use: Anthropic for receipt scanning, currency-rate providers for conversion, and infrastructure providers for hosting and database operations. Current builds connect to an API hosted on Render and a viewer hosted on Vercel; the database provider is selected through deployment configuration. If you follow a payment link, the payment service you choose handles that interaction under its own policy.",
    ],
  },
  {
    title: "Storage, retention, and choices",
    paragraphs: [
      "Shared bills and tabs remain in the online database until removed by service operators. There is no in-app control to delete a bill or tab, and share tokens do not currently expire automatically. Local app data can be removed by clearing app data or uninstalling; browser data can be cleared in browser settings. Removing local data does not remove a copy already shared online.",
      "To ask about or request removal of shared information, email checkmateapp@duck.com and include the relevant bill or tab link. Because there are no accounts, we may need enough information to verify control of the content before acting. Copies in backups or provider logs may persist according to the relevant provider's retention practices.",
    ],
  },
];

export default function PrivacyPage() {
  return (
    <main className="min-h-screen bg-[var(--secondary)] px-4 py-12 text-[var(--accent)] dark:bg-[var(--dark-bg)] dark:text-white sm:py-20">
      <article className="mx-auto max-w-3xl rounded-3xl border border-[var(--border-light)] bg-[var(--card-bg-light)] px-6 py-8 shadow-sm dark:border-[var(--border-dark)] dark:bg-[var(--card-bg-dark)] sm:px-12 sm:py-12">
        <a
          href="/"
          className="text-sm font-medium text-[var(--primary-dark)] underline-offset-4 hover:underline dark:text-[var(--primary-light)]"
        >
          Billington
        </a>
        <h1 className="mt-8 text-3xl font-semibold tracking-tight sm:text-4xl">
          Privacy Policy
        </h1>
        <p className="mt-2 text-sm text-[var(--text-secondary)]">
          Effective October 12, 2026
        </p>
        <p className="mt-8 text-base leading-7 text-[var(--text-dark)] dark:text-[var(--text-light)]">
          Billington is account-free, but it is not fully local. Some
          information stays on your device; bills and shared tabs you choose to
          create are sent to Billington&apos;s online service so they can be
          shared.
        </p>

        <div className="mt-10 space-y-10">
          {sections.map((section) => (
            <section key={section.title}>
              <h2 className="text-xl font-semibold">{section.title}</h2>
              <div className="mt-3 space-y-4 text-sm leading-7 text-[var(--text-secondary)] sm:text-base">
                {section.paragraphs.map((paragraph) => (
                  <p key={paragraph}>{paragraph}</p>
                ))}
              </div>
            </section>
          ))}
          <section>
            <h2 className="text-xl font-semibold">Provider privacy terms</h2>
            <ul className="mt-3 list-inside list-disc space-y-2 text-sm leading-7 text-[var(--text-secondary)] sm:text-base">
              <li>
                <a
                  className="underline underline-offset-4"
                  href="https://privacy.anthropic.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data"
                >
                  Anthropic API retention
                </a>
              </li>
              <li>
                <a
                  className="underline underline-offset-4"
                  href="https://render.com/privacy"
                >
                  Render privacy policy
                </a>
              </li>
              <li>
                <a
                  className="underline underline-offset-4"
                  href="https://vercel.com/legal/privacy-notice"
                >
                  Vercel privacy notice
                </a>
              </li>
            </ul>
          </section>
          <section>
            <h2 className="text-xl font-semibold">Changes</h2>
            <p className="mt-3 text-sm leading-7 text-[var(--text-secondary)] sm:text-base">
              We may update this policy as the service changes; the latest
              version and its effective date will appear here.
            </p>
          </section>
          <section>
            <h2 className="text-xl font-semibold">Contact</h2>
            <p className="mt-3 text-sm leading-7 text-[var(--text-secondary)] sm:text-base">
              Privacy questions and requests:{" "}
              <a
                className="text-[var(--primary-dark)] underline underline-offset-4 dark:text-[var(--primary-light)]"
                href="mailto:checkmateapp@duck.com"
              >
                checkmateapp@duck.com
              </a>
              .
            </p>
          </section>
        </div>
      </article>
    </main>
  );
}
