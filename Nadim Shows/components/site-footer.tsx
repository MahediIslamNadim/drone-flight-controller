import Link from "next/link";
import { Clock3, MapPin, Phone, Store } from "lucide-react";
import { siteConfig } from "@/lib/site-config";

const links = [
  { href: "/", label: "Home" },
  { href: "/shoes", label: "Shoes" },
  { href: "/visit", label: "Visit Store" },
];

export function SiteFooter() {
  return (
    <footer className="mt-16 border-t border-white/60 bg-white/65">
      <div className="mx-auto grid w-full max-w-7xl gap-8 px-4 py-10 sm:px-6 lg:grid-cols-[1.2fr_0.8fr_1fr] lg:px-8">
        <div className="space-y-4">
          <p className="font-[family-name:var(--font-heading)] text-3xl font-bold text-ink">
            Air Dokan
          </p>
          <p className="max-w-md text-sm leading-7 text-ink/70">
            Premium-feel browsing for a local shoe store, built so customers can
            easily explore styles before visiting in person.
          </p>
        </div>

        <div className="space-y-3">
          <p className="text-sm uppercase tracking-[0.22em] text-ember">Navigate</p>
          <nav className="flex flex-col gap-2 text-sm">
            {links.map((link) => (
              <Link key={link.href} href={link.href} className="text-ink/75 transition hover:text-pine">
                {link.label}
              </Link>
            ))}
          </nav>
        </div>

        <div className="space-y-3 text-sm text-ink/75">
          <p className="text-sm uppercase tracking-[0.22em] text-ember">Store Info</p>
          <a
            href={siteConfig.mapHref}
            target="_blank"
            rel="noreferrer"
            className="flex items-start gap-3 transition hover:text-pine"
          >
            <MapPin className="mt-0.5 h-4 w-4 text-pine" />
            <span>{siteConfig.address}</span>
          </a>
          <a
            href={siteConfig.phoneHref}
            className="flex items-center gap-3 transition hover:text-pine"
          >
            <Phone className="h-4 w-4 text-pine" />
            <span>{siteConfig.phone}</span>
          </a>
          <p className="flex items-center gap-3">
            <Clock3 className="h-4 w-4 text-pine" />
            <span>{siteConfig.hours}</span>
          </p>
          <div className="inline-flex items-center gap-2 pt-2 font-semibold text-pine">
            <Store className="h-4 w-4" />
            In-store shopping available
          </div>
        </div>
      </div>
    </footer>
  );
}
