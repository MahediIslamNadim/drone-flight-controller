import Link from "next/link";
import { ArrowRight, MapPin, ShieldCheck, Sparkles } from "lucide-react";
import { SectionHeading } from "@/components/section-heading";
import { ShoeCard } from "@/components/shoe-card";
import { getFeaturedShoes } from "@/lib/store";
import { siteConfig } from "@/lib/site-config";

const quickCategories = [
  {
    title: "Formal",
    description: "Office, occasion, and polished daily wear.",
    accent: "from-[#12372A] to-[#1E4D5C]",
  },
  {
    title: "Casual",
    description: "Easy everyday styles for college, market, and travel.",
    accent: "from-[#B85C38] to-[#D68C45]",
  },
  {
    title: "Sports",
    description: "Performance pairs built for movement and comfort.",
    accent: "from-[#1E4D5C] to-[#4A8B8B]",
  },
  {
    title: "Sandal",
    description: "Open comfort for fast errands and warm afternoons.",
    accent: "from-[#7A4B2A] to-[#B85C38]",
  },
];

const benefits = [
  "Mobile-first browsing for family customers",
  "Simple size visibility before visiting the store",
  "Ready for Supabase-powered stock sync",
];

export default async function HomePage() {
  const featuredShoes = await getFeaturedShoes();

  return (
    <div className="mx-auto flex w-full max-w-7xl flex-col gap-20 px-4 py-8 sm:px-6 lg:px-8">
      <section className="grid gap-8 lg:grid-cols-[1.15fr_0.85fr] lg:items-center">
        <div className="animate-rise space-y-8">
          <div className="inline-flex items-center gap-2 rounded-full border border-pine/15 bg-white/80 px-4 py-2 text-sm text-pine shadow-sm">
            <Sparkles className="h-4 w-4" />
            Curated footwear for Katakhal Bazar families
          </div>
          <div className="space-y-4">
            <p className="font-[family-name:var(--font-heading)] text-sm uppercase tracking-[0.3em] text-ember">
              Air Dokan
            </p>
            <h1 className="max-w-3xl font-[family-name:var(--font-heading)] text-4xl font-bold leading-tight text-balance text-ink sm:text-5xl lg:text-6xl">
              A cleaner, faster shoe catalog built for real local selling.
            </h1>
            <p className="max-w-2xl text-lg leading-8 text-ink/75">
              Browse styles, compare sizes, and shortlist the right pair before coming
              to the shop. This foundation is designed so the public catalog feels
              premium while the admin side stays easy for family use.
            </p>
          </div>
          <div className="flex flex-col gap-3 sm:flex-row">
            <Link
              href="/shoes"
              className="inline-flex items-center justify-center gap-2 rounded-full bg-pine px-6 py-3 text-base font-semibold text-white transition hover:bg-pine/90"
            >
              Shop All Shoes
              <ArrowRight className="h-4 w-4" />
            </Link>
            <Link
              href="/visit"
              className="inline-flex items-center justify-center gap-2 rounded-full border border-pine/15 bg-white/90 px-6 py-3 text-base font-semibold text-pine transition hover:border-pine/30 hover:bg-white"
            >
              <MapPin className="h-4 w-4" />
              Visit Store Info
            </Link>
          </div>
          <ul className="grid gap-3 text-sm text-ink/80 sm:grid-cols-3">
            {benefits.map((benefit) => (
              <li
                key={benefit}
                className="surface rounded-2xl border border-white/70 px-4 py-4 shadow-sm"
              >
                {benefit}
              </li>
            ))}
          </ul>
        </div>

        <div className="relative animate-float">
          <div className="surface relative overflow-hidden rounded-[2rem] border border-white/70 p-6 shadow-glow">
            <div className="absolute inset-x-6 top-6 h-36 rounded-full bg-gradient-to-r from-ember/25 to-ocean/20 blur-3xl" />
            <div className="relative space-y-6">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="text-sm uppercase tracking-[0.25em] text-ember">Store Pulse</p>
                  <h2 className="mt-2 font-[family-name:var(--font-heading)] text-3xl font-bold text-ink">
                    In-store feel, online speed.
                  </h2>
                </div>
                <ShieldCheck className="mt-1 h-10 w-10 text-pine" />
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <div className="rounded-3xl bg-gradient-to-br from-pine to-ocean p-5 text-white">
                  <p className="text-sm text-white/70">Customer path</p>
                  <p className="mt-2 font-[family-name:var(--font-heading)] text-2xl font-semibold">
                    Browse {"->"} Shortlist {"->"} Visit Store
                  </p>
                </div>
                <div className="rounded-3xl border border-pine/10 bg-white p-5">
                  <p className="text-sm text-ink/60">Base stack</p>
                  <p className="mt-2 font-[family-name:var(--font-heading)] text-2xl font-semibold text-ink">
                    Next.js + Supabase
                  </p>
                </div>
              </div>
              <div className="rounded-3xl border border-pine/10 bg-sand px-5 py-4">
                <div className="flex items-start gap-3">
                  <MapPin className="mt-1 h-5 w-5 text-ember" />
                  <div>
                    <p className="font-semibold text-ink">{siteConfig.address}</p>
                    <p className="text-sm text-ink/70">
                      Mobile-first layout for browsing at home before coming to the shop.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="space-y-6">
        <SectionHeading
          eyebrow="Categories"
          title="Clear entry points for fast product discovery"
          description="These category blocks match the markdown plan and give us a strong base for filtering and future merchandising."
        />
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
          {quickCategories.map((category) => (
            <Link
              key={category.title}
              href={`/shoes?category=${category.title.toLowerCase()}`}
              className="group overflow-hidden rounded-[1.75rem] border border-white/70 bg-white/80 p-1 shadow-sm transition hover:-translate-y-1 hover:shadow-glow"
            >
              <div className={`h-full rounded-[1.5rem] bg-gradient-to-br ${category.accent} p-6 text-white`}>
                <p className="text-sm uppercase tracking-[0.24em] text-white/65">Browse</p>
                <h3 className="mt-6 font-[family-name:var(--font-heading)] text-3xl font-bold">
                  {category.title}
                </h3>
                <p className="mt-3 max-w-xs text-sm leading-6 text-white/80">
                  {category.description}
                </p>
                <div className="mt-8 inline-flex items-center gap-2 text-sm font-semibold">
                  Explore now
                  <ArrowRight className="h-4 w-4 transition group-hover:translate-x-1" />
                </div>
              </div>
            </Link>
          ))}
        </div>
      </section>

      <section className="space-y-6">
        <SectionHeading
          eyebrow="Featured Shoes"
          title="Sample catalog cards wired for mock data now, Supabase next"
          description="Until credentials are added, the app falls back to local sample inventory so the UI stays testable."
        />
        <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
          {featuredShoes.map((shoe) => (
            <ShoeCard key={shoe.id} shoe={shoe} />
          ))}
        </div>
      </section>

      <section className="grid gap-5 lg:grid-cols-[1.1fr_0.9fr]">
        <div className="rounded-[2rem] border border-white/70 bg-white/85 p-6 shadow-sm">
          <p className="text-sm uppercase tracking-[0.24em] text-ember">How To Use</p>
          <h2 className="mt-3 font-[family-name:var(--font-heading)] text-3xl font-bold text-ink">
            Easy browse flow for offline customers
          </h2>
          <div className="mt-5 grid gap-3 text-sm text-ink/75 sm:grid-cols-3">
            <div className="rounded-[1.5rem] bg-mist px-4 py-4">1. Shoes dekhen</div>
            <div className="rounded-[1.5rem] bg-mist px-4 py-4">
              2. Size ar price shortlist korun
            </div>
            <div className="rounded-[1.5rem] bg-mist px-4 py-4">
              3. Dokane ese final pair choose korun
            </div>
          </div>
        </div>

        <div className="rounded-[2rem] border border-pine/10 bg-gradient-to-br from-sand to-white p-6 shadow-sm">
          <p className="text-sm uppercase tracking-[0.24em] text-ember">Store Details</p>
          <p className="mt-3 font-[family-name:var(--font-heading)] text-3xl font-bold text-ink">
            Visit Air Dokan
          </p>
          <p className="mt-3 text-sm leading-7 text-ink/70">{siteConfig.visitMessage}</p>
          <div className="mt-5 space-y-2 text-sm text-ink/75">
            <p>{siteConfig.address}</p>
            <p>{siteConfig.phone}</p>
            <p>{siteConfig.hours}</p>
          </div>
          <Link
            href="/visit"
            className="mt-5 inline-flex items-center gap-2 rounded-full bg-pine px-5 py-3 text-sm font-semibold text-white transition hover:bg-pine/90"
          >
            Full Visit Info
            <ArrowRight className="h-4 w-4" />
          </Link>
        </div>
      </section>
    </div>
  );
}
