import type { Metadata } from "next";
import Link from "next/link";
import styles from "./public.module.css";
import { site } from "./site";

const title = "Billington — Scan the receipt. Share everyone's total.";
export const metadata: Metadata = {
  title,
  description: site.description,
  alternates: { canonical: site.origin },
  openGraph: {
    type: "website",
    locale: "en_US",
    siteName: site.name,
    title,
    description: site.description,
    url: site.origin,
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
    description: site.description,
    images: [
      {
        url: site.socialImage,
        alt: "Billington — Receipt splitting, without an account",
      },
    ],
  },
};

export default function HomePage() {
  const application = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: site.name,
    operatingSystem: "iOS",
    applicationCategory: "FinanceApplication",
    description: site.description,
    url: site.origin,
    downloadUrl: site.store,
  };

  return (
    <main id="main" className={styles.main}>
      <script type="application/ld+json">
        {JSON.stringify(application).replace(/</g, "\\u003c")}
      </script>
      <section className={styles.hero} aria-labelledby="hero-heading">
        <div className={styles.heroCopy}>
          <p className={styles.eyebrow}>A shared meal. A clear split.</p>
          <h1 id="hero-heading">
            Scan the receipt.
            <br />
            <span>Share everyone's total.</span>
          </h1>
          <p className={styles.lead}>{site.description}</p>
          <a className={styles.button} href={site.store}>
            Get Billington for iOS <span aria-hidden="true">↗</span>
          </a>
          <p className={styles.caption}>
            Your items, your share of tax and tip, one total.
          </p>
        </div>
        <figure className={styles.receipt}>
          <figcaption className={styles.receiptHeading}>
            <span className={styles.eyebrow}>Example split</span>
            <span className={styles.caption}>Dinner for three · USD</span>
          </figcaption>
          <dl className={styles.receiptMath}>
            <div>
              <dt>Items</dt>
              <dd>$100.00</dd>
            </div>
            <div>
              <dt>Tax</dt>
              <dd>$10.00</dd>
            </div>
            <div>
              <dt>Tip</dt>
              <dd>$18.00</dd>
            </div>
            <div className={styles.receiptTotal}>
              <dt>Total</dt>
              <dd>$128.00</dd>
            </div>
          </dl>
          <div className={styles.shares}>
            <p className={styles.eyebrow}>Everyone's total</p>
            <dl>
              <div>
                <dt>
                  <span aria-hidden="true">A</span>Ari
                </dt>
                <dd>$51.20</dd>
              </div>
              <div>
                <dt>
                  <span aria-hidden="true">S</span>Sam
                </dt>
                <dd>$44.80</dd>
              </div>
              <div>
                <dt>
                  <span aria-hidden="true">J</span>Jo
                </dt>
                <dd>$32.00</dd>
              </div>
            </dl>
          </div>
          <p className={styles.receiptNote}>
            Items + tax + tip, divided together.
          </p>
        </figure>
      </section>

      <section
        id="how-it-works"
        className={styles.section}
        aria-labelledby="how-heading"
      >
        <div className={styles.sectionHeading}>
          <p className={styles.eyebrow}>How it works</p>
          <h2 id="how-heading">From the receipt to each person's share.</h2>
        </div>
        <ol className={styles.steps}>
          <li>
            <span className={styles.stepNumber} aria-hidden="true">
              01
            </span>
            <h3>Scan or enter</h3>
            <p>
              Choose a receipt photo to extract the items, or enter them
              yourself.
            </p>
          </li>
          <li>
            <span className={styles.stepNumber} aria-hidden="true">
              02
            </span>
            <h3>Review the details</h3>
            <p>
              Check the items and amounts. Add tax and tip before you split.
            </p>
          </li>
          <li>
            <span className={styles.stepNumber} aria-hidden="true">
              03
            </span>
            <h3>Share the split</h3>
            <p>
              Share a link so friends can claim their items and see their
              totals.
            </p>
          </li>
        </ol>
      </section>

      <section
        id="features"
        className={styles.section}
        aria-labelledby="features-heading"
      >
        <div className={styles.sectionHeading}>
          <p className={styles.eyebrow}>Made for the table</p>
          <h2 id="features-heading">Less working it out. More clarity.</h2>
        </div>
        <div className={styles.benefits}>
          <article>
            <span className={styles.eyebrow}>01 / The whole amount</span>
            <h3>Keep tax and tip in the picture.</h3>
            <p>
              See how items, tax and tip contribute to each person's total, with
              room to review the receipt before sharing.
            </p>
          </article>
          <article>
            <span className={styles.eyebrow}>02 / A shared view</span>
            <h3>Give everyone a place to check.</h3>
            <p>
              Friends can open the shared link to see the split. Item claiming
              lets people choose what belongs to them, without creating an
              account.
            </p>
          </article>
        </div>
        <p className={styles.paymentNote}>
          Payments happen outside Billington. On a shared page, the Venmo button
          opens the Venmo app, if it is installed, with the recipient, amount
          and a note filled in; you review and send the payment there. For
          Zelle, Cash App and Apple Pay, Billington only shows the details the
          bill creator entered. Billington does not process a payment or confirm
          a transfer: a paid marker is recorded manually by participants.
        </p>
      </section>

      <section
        id="privacy"
        className={`${styles.section} ${styles.privacy}`}
        aria-labelledby="privacy-heading"
      >
        <p className={styles.eyebrow}>Privacy</p>
        <h2 id="privacy-heading">Know what you share</h2>
        <p>
          Billington works without an account. Bill history and preferences are
          saved on your device; online bills and tabs are stored by the service.
          Receipt scanning sends your selected photo to Anthropic for
          extraction. Keep shared links private: people with a valid link can
          see shared details and may be able to update them. Removing local
          history does not delete an online bill.
        </p>
        <p>
          <Link href="/privacy-policy">Read the full privacy policy</Link>.
          Privacy or deletion questions:{" "}
          <a href={site.contact}>checkmateapp@duck.com</a>.
        </p>
      </section>

      <section
        id="download"
        className={`${styles.section} ${styles.download}`}
        aria-labelledby="download-heading"
      >
        <div>
          <p className={styles.eyebrow}>Next time the bill arrives</p>
          <h2 id="download-heading">Start with the receipt.</h2>
          <p>Review it. Split it. Share everyone's total.</p>
        </div>
        <a className={styles.button} href={site.store}>
          Get Billington for iOS <span aria-hidden="true">↗</span>
        </a>
      </section>
      <section className={styles.contact} aria-labelledby="contact-heading">
        <h2 id="contact-heading">Contact Billington</h2>
        <p>
          For help, privacy questions or a request to remove shared information,
          email <a href={site.contact}>checkmateapp@duck.com</a>. Describe your
          request without including a private bill link in the first message.
        </p>
      </section>
    </main>
  );
}
