import type { Metadata } from "next";
import { Hind_Siliguri, Space_Grotesk } from "next/font/google";
import "./globals.css";
import { siteConfig } from "@/lib/site-config";

const headingFont = Space_Grotesk({
  subsets: ["latin"],
  variable: "--font-heading",
});

const bodyFont = Hind_Siliguri({
  subsets: ["bengali", "latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-body",
});

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000"),
  title: {
    default: `${siteConfig.name} | Modern shoe catalog for local selling`,
    template: `%s | ${siteConfig.name}`,
  },
  description:
    "Air Dokan is a mobile-friendly shoe storefront with catalog browsing, WhatsApp ordering, and a simple admin workflow.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${headingFont.variable} ${bodyFont.variable}`}
      suppressHydrationWarning
    >
      <body className="font-[family-name:var(--font-body)] text-ink antialiased">
        <div className="page-shell">{children}</div>
      </body>
    </html>
  );
}
