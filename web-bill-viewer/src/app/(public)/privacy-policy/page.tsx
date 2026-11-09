import type { Metadata } from "next";
import styles from "../public.module.css";
import { site } from "../site";

const title = "Billington Privacy Policy";
const description =
  "How Billington handles receipt scans, shared bills and tabs, access links, local storage and privacy requests.";
// The version on the public App Store that this policy describes. Statements
// about later builds are marked "Not yet released" in the copy. Re-run the
// inventory in docs/privacy.md before changing this value or those markers.
const storeVersion = "1.4.0";
export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: `${site.origin}/privacy-policy` },
  openGraph: {
    type: "website",
    locale: "en_US",
    siteName: site.name,
    title,
    description,
    url: `${site.origin}/privacy-policy`,
    images: [
      {
        url: site.socialImage,
        width: 1200,
        height: 630,
        alt: "Billington — Receipt splitting, without an account",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title,
    description,
    images: [
      {
        url: site.socialImage,
        alt: "Billington — Receipt splitting, without an account",
      },
    ],
  },
};

export default function PrivacyPolicyPage() {
  return (
    <main id="main" className={`${styles.main} ${styles.policy}`}>
      <nav className={styles.policyNav} aria-label="Policy contents">
        <p className={styles.eyebrow}>In this policy</p>
        <a href="#version-covered">Version covered</a>
        <a href="#information-on-your-device">Information on your device</a>
        <a href="#bills-and-tabs-online">Bills and tabs online</a>
        <a href="#who-can-use-a-shared-link">Who can use a shared link</a>
        <a href="#receipt-scanning">Receipt scanning</a>
        <a href="#currency-rates">Currency rates</a>
        <a href="#service-operation-and-providers">
          Service operation and providers
        </a>
        <a href="#browser-storage-and-sharing-outside-billington">
          Browser storage and sharing outside Billington
        </a>
        <a href="#retention-removal-and-requests">
          Retention, removal and requests
        </a>
        <a href="#changes-and-contact">Changes and contact</a>
      </nav>
      <article className={styles.article}>
        <h1>Billington Privacy Policy</h1>
        <p>
          Billington helps people divide bills and keep track of shared expenses
          without creating a Billington account. This policy explains how
          information is handled in the app and on shared bill pages. The
          information sent depends on the features you use.
        </p>
        <h2 id="version-covered">Version covered</h2>
        <p>
          This policy describes Billington version {storeVersion}, the version
          available on the App Store, and the Billington service as it currently
          runs. Statements marked "Not yet released" describe later builds that
          are not on the App Store; they do not apply to version {storeVersion}.
        </p>
        <h2 id="information-on-your-device">Information on your device</h2>
        <p>
          The app keeps bill history, participant names, saved groups, display
          and sharing preferences, payment details you enter, and information
          about your tabs on your device. For a bill or tab that is online, this
          includes its link, which contains an access credential that lets the
          app reopen shared content and recognize tab membership. Names and
          payment details saved in settings can also be included in bills or
          summaries you create or share.
        </p>
        <p>
          <strong>Not yet released:</strong> later builds also keep the
          information needed to finish a pending save, such as currency
          information and an intended tab destination, and keep some recovery
          credentials in the device's secure storage. That does not mean all
          saved bill details or links use the same protection.
        </p>
        <h2 id="bills-and-tabs-online">Bills and tabs online</h2>
        <p>
          In version {storeVersion}, saving a finished bill sends it to
          Billington's service automatically, whether or not you share its link.
          If that attempt fails, the app tries again the next time it opens.
          Creating a tab, adding a bill to a tab and joining a tab also send
          information to the service. Treat saving a bill as a separate step
          from sending the resulting link to another person.
        </p>
        <p>
          This information can include the bill or tab name and description,
          receipt items, amounts, tax and tip, participant and member names,
          item assignments, who added or paid for a bill, payment details you
          include, and manually recorded paid status. The service stores this
          information so people can view the shared expense and collaborate.
        </p>
        <p>
          <strong>Not yet released:</strong> later builds can also send the
          receipt's currency and conversion details, and can hold a pending save
          on the device until you retry it.
        </p>
        <h2 id="who-can-use-a-shared-link">Who can use a shared link</h2>
        <p>
          A shared link contains an access credential. The web host receives the
          link when you open it, and Billington's API uses the credential to
          check access. People with the relevant valid link can see shared
          information, including names, items, amounts and payment details.
          Depending on the bill or tab and their permissions, they may also
          claim items, join a tab or change a manually recorded status.
        </p>
        <p>
          Keep shared links private and give them only to people you intend to
          include. A display name is a label supplied by a participant, not
          verification of that person's real identity. Removing a link from your
          history or keeping a page out of search results does not take access
          away from someone who already has it. Shared access links do not
          automatically expire.
        </p>
        <h2 id="receipt-scanning">Receipt scanning</h2>
        <p>
          When you scan a receipt, the selected photo goes to Billington's API
          and then to Anthropic's Claude API for extraction. The image itself is
          sent, including anything visible in it. Choose an image containing
          only information you want to send. You can enter receipt items
          manually instead.
        </p>
        <p>
          Scanning returns details such as the business name, receipt items and
          amounts. You can review and edit these details before using them in a
          split. Billington does not save the scanned image as part of the
          shared bill database. Extracted details can become part of the bill
          you save or share. The original photo or a temporary image copy may
          remain on your device.
        </p>
        <p>
          Version {storeVersion} also has an option to add a receipt photo to a
          tab. The service as it currently runs does not accept those photos, so
          that upload fails. Photos added to a tab under an earlier version of
          the service were stored by the service; email us if you want one
          removed.
        </p>
        <p>
          Anthropic's{" "}
          <a href="https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data">
            published API retention terms
          </a>{" "}
          describe standard deletion of inputs and outputs within 30 days, with
          exceptions for legal requirements, policy enforcement, other
          agreements and certain services. Additional rules can apply to
          designated models. These terms are not a guaranteed deletion deadline
          for every scan.
        </p>
        <h2 id="currency-rates">Currency rates</h2>
        <p>
          <strong>Not yet released:</strong> version {storeVersion} does not
          convert currencies. Later builds ask Billington's service for a rate,
          and the service requests it from{" "}
          <a href="https://frankfurter.dev/">Frankfurter</a>. The service as it
          currently runs also contains an older rate lookup that uses{" "}
          <a href="https://www.exchangerate-api.com/">ExchangeRate-API</a>.
          Those requests contain the currency pair, rather than your receipt
          photo, participant names or bill amounts. Bills can retain the
          accepted rate and its date and source, along with separate information
          used to display a converted amount. A displayed conversion is not a
          payment or a currency exchange transaction.
        </p>
        <h2 id="service-operation-and-providers">
          Service operation and providers
        </h2>
        <p>
          Billington uses information to calculate and share splits, maintain
          bills and tabs, remember preferences, check access, retry unfinished
          saves, limit receipt-scanning abuse and diagnose service problems. We
          do not sell bill or tab content.
        </p>
        <p>
          Service providers include Anthropic for scanning, and Render and
          Vercel for API and web hosting. Hosting and database services process
          the content and technical information needed to deliver the features
          you use. Technical information can include an IP address, the
          requested page or route, request time, response status and duration.
          The address of a shared page contains its private access credential.
        </p>
        <p>
          Hosting providers may retain request and diagnostic information. The
          service as it currently runs can also record the database statement
          for a failed or slow operation in its logs, and that statement can
          contain bill content or access credentials. A change to the app or
          service does not by itself erase existing logs. Provider and backup
          retention can differ from storage in the app or the online bill
          database. See{" "}
          <a href="https://render.com/privacy">Render's privacy policy</a> and{" "}
          <a href="https://vercel.com/legal/privacy-notice">
            Vercel's privacy notice
          </a>{" "}
          for their published information.
        </p>
        <p>
          <strong>Not yet released:</strong> a later version of the service
          stops recording statement text and values in those logs. It has not
          been deployed.
        </p>
        <h2 id="browser-storage-and-sharing-outside-billington">
          Browser storage and sharing outside Billington
        </h2>
        <p>
          When you use item claiming in a browser, the viewer can remember your
          chosen display name in that browser's local storage. Some tab flows
          also save a member credential there. You can clear this information
          through your browser's website-data settings. Clearing it does not
          remove claims or other information already saved online.
        </p>
        <p>
          If you copy a link or use the device's sharing options, the clipboard
          or the app and recipients you choose receive the link or summary. A
          summary can include participant names, amounts and payment details.
          Those recipients can keep their own copies.
        </p>
        <p>
          Payments happen outside Billington. A Venmo handoff can include the
          recipient's handle, an amount and a note containing bill or
          participant details. The external payment service handles that
          interaction under its own terms. Payment details shown for other
          services are shared information. A paid marker in Billington is
          recorded manually by participants. Billington does not process
          payments or confirm transfers.
        </p>
        <h2 id="retention-removal-and-requests">
          Retention, removal and requests
        </h2>
        <p>
          Shared bills and tabs stay in the online database until service
          operators remove them. The app's history controls remove local
          entries. Removing a local bill or tab does not delete shared bills,
          their recorded information, or copies held by others. There is no
          in-app control for deleting an entire shared online bill or tab.
        </p>
        <p>
          <strong>Not yet released:</strong> later builds let a member leave a
          tab. Leaving does not delete shared bills or their recorded
          information either.
        </p>
        <p>
          Clearing local app data or uninstalling is not an online deletion
          request and does not revoke shared links. Removing a history entry
          also does not necessarily remove credentials stored separately on the
          device. We do not promise that uninstalling erases every credential or
          backup copy.
        </p>
        <p>
          For a privacy question, support request or request to remove shared
          information, email{" "}
          <a href="mailto:checkmateapp@duck.com">checkmateapp@duck.com</a>.
          Describe your request first and share only the information needed to
          handle it. We may need additional information to locate the content
          and verify your authority before making a change. Do not send
          payment-card numbers or unrelated personal information.
        </p>
        <p>
          Removing an online record does not necessarily remove existing copies
          in backups, provider logs, photos, messages or another person's
          device. Retention in those places depends on the relevant service or
          recipient. No fixed removal deadline for all copies is promised here.
        </p>
        <h2 id="changes-and-contact">Changes and contact</h2>
        <p>
          This policy may change as Billington's features and data practices
          change. The policy page will identify its effective date.
        </p>
        <p>
          Privacy, deletion and support:{" "}
          <a href="mailto:checkmateapp@duck.com">checkmateapp@duck.com</a>.
        </p>
      </article>
    </main>
  );
}
