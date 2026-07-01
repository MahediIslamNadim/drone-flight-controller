"use client";

import Link from "next/link";
import { MapPin, Menu, Search } from "lucide-react";
import { useState } from "react";
import { siteConfig } from "@/lib/site-config";

const navItems = [
  { href: "/", label: "Home" },
  { href: "/shoes", label: "Shoes" },
  { href: "/visit", label: "Visit Store" },
];

export function SiteHeader() {
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  return (
    <header className="sticky top-0 z-50 border-b border-white/60 bg-white/70 backdrop-blur-xl">
      <div className="mx-auto flex w-full max-w-7xl items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
        <Link href="/" className="flex items-center gap-3">
          <div className="grid h-11 w-11 place-items-center rounded-2xl bg-gradient-to-br from-pine to-ocean text-sm font-bold text-white shadow-sm">
            AD
          </div>
          <div>
            <p className="font-[family-name:var(--font-heading)] text-xl font-bold text-ink">
              Air Dokan
            </p>
            <p className="text-xs uppercase tracking-[0.18em] text-ember">Shoe catalog</p>
          </div>
        </Link>

        <div className="hidden flex-1 justify-center lg:flex">
          <div className="flex w-full max-w-md items-center gap-3 rounded-full border border-pine/10 bg-white px-4 py-3 shadow-sm">
            <Search className="h-4 w-4 text-ink/40" />
            <span className="text-sm text-ink/45">Search catalog, colors, styles</span>
          </div>
        </div>

        <div className="hidden items-center gap-6 lg:flex">
          <nav className="flex items-center gap-5 text-sm font-medium text-ink/70">
            {navItems.map((item) => (
              <Link key={item.href} href={item.href} className="transition hover:text-pine">
                {item.label}
              </Link>
            ))}
          </nav>
          <Link
            href="/visit"
            className="inline-flex items-center gap-2 rounded-full bg-pine px-5 py-3 text-sm font-semibold text-white transition hover:bg-pine/90"
          >
            <MapPin className="h-4 w-4" />
            Visit Store
          </Link>
        </div>

        <button
          type="button"
          onClick={() => setIsMenuOpen((current) => !current)}
          className="inline-flex h-11 w-11 items-center justify-center rounded-2xl border border-pine/10 bg-white text-pine lg:hidden"
          aria-label="Open menu"
          aria-expanded={isMenuOpen}
        >
          <Menu className="h-5 w-5" />
        </button>
      </div>

      {isMenuOpen ? (
        <div className="border-t border-white/60 bg-white/90 px-4 py-4 shadow-sm lg:hidden">
          <nav className="flex flex-col gap-2">
            {navItems.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setIsMenuOpen(false)}
                className="rounded-2xl border border-pine/10 bg-mist px-4 py-3 text-sm font-semibold text-ink"
              >
                {item.label}
              </Link>
            ))}
          </nav>

          <div className="mt-4 rounded-[1.5rem] border border-pine/10 bg-white px-4 py-4">
            <p className="text-xs uppercase tracking-[0.2em] text-ember">Store Info</p>
            <a href={siteConfig.phoneHref} className="mt-3 block text-sm font-semibold text-pine">
              {siteConfig.phone}
            </a>
            <a
              href={siteConfig.mapHref}
              target="_blank"
              rel="noreferrer"
              className="mt-2 block text-sm text-ink/70"
            >
              {siteConfig.address}
            </a>
          </div>
        </div>
      ) : null}
    </header>
  );
}
