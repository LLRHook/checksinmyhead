import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
});

const jetbrainsMono = JetBrains_Mono({
  variable: "--font-mono",
  subsets: ["latin"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "Billington",
  description: "View your shared bill breakdown with Billington",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="scroll-smooth">
      <body
        className={`${inter.variable} ${jetbrainsMono.variable} antialiased`}
      >
        {children}
        <footer className="border-t border-[var(--border-light)] bg-[var(--card-bg-light)] px-4 py-5 text-center text-xs text-[var(--text-secondary)] dark:border-[var(--border-dark)] dark:bg-[var(--card-bg-dark)]">
          <a
            href="/privacy"
            className="underline underline-offset-4 hover:text-[var(--accent)] dark:hover:text-white"
          >
            Privacy Policy
          </a>
        </footer>
      </body>
    </html>
  );
}
