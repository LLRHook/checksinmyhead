import type { Metadata } from "next";
import Link from "next/link";
import styles from "./public.module.css";
import { site } from "./site";

export const metadata: Metadata = {
  robots: { index: true, follow: true },
};

export default function PublicLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <div className={styles.shell}>
      <a className={styles.skip} href="#main">
        Skip to content
      </a>
      <header className={styles.header}>
        <Link href="/" className={styles.wordmark} aria-label="Billington home">
          <span className={styles.brandMark} aria-hidden="true">
            b.
          </span>
          Billington
        </Link>
        <nav className={styles.nav} aria-label="Main">
          <Link href="/#how-it-works">How it works</Link>
          <Link href="/#features">Features</Link>
          <Link href="/#privacy">Privacy</Link>
          <a className={styles.button} href={site.store}>
            Get Billington for iOS <span aria-hidden="true">↗</span>
          </a>
        </nav>
      </header>
      {children}
      <footer className={styles.footer}>
        <div>
          <Link className={styles.wordmark} href="/">
            Billington
          </Link>
          <p>
            Payments happen outside Billington. Paid status is recorded manually
            by participants.
          </p>
        </div>
        <nav aria-label="Footer">
          <Link href="/privacy-policy">Privacy policy</Link>
          <a href={site.contact}>Contact</a>
        </nav>
      </footer>
    </div>
  );
}
