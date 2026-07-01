import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { ActiveFilterChips } from "@/components/active-filter-chips";
import { FilterPanel } from "@/components/filter-panel";
import { SectionHeading } from "@/components/section-heading";
import { ShoeCard } from "@/components/shoe-card";
import { getBrands, getCategories, getShoes } from "@/lib/store";

type ShoesPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function ShoesPage({ searchParams }: ShoesPageProps) {
  const params = (await searchParams) ?? {};
  const shoes = await getShoes(params);
  const brands = await getBrands();
  const categories = await getCategories();
  const quickCategories = categories.slice(0, 6);

  return (
    <div className="mx-auto flex w-full max-w-7xl flex-col gap-8 px-4 py-8 sm:px-6 lg:px-8">
      <SectionHeading
        eyebrow="Catalog"
        title="Filterable shoe listing with real-data fallback support"
        description="Brand, category, price, and size filters are wired through query params so this page works before and after Supabase setup."
      />

      <section className="rounded-[2rem] border border-white/70 bg-white/80 p-5 shadow-sm">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className="text-sm uppercase tracking-[0.22em] text-ember">Quick Browse</p>
            <h2 className="mt-2 font-[family-name:var(--font-heading)] text-2xl font-bold text-ink">
              Start with popular categories
            </h2>
          </div>
          <Link
            href="/visit"
            className="inline-flex items-center gap-2 text-sm font-semibold text-pine transition hover:text-pine/80"
          >
            Store visit info
            <ArrowRight className="h-4 w-4" />
          </Link>
        </div>

        <div className="mt-5 flex flex-wrap gap-3">
          {quickCategories.map((category) => (
            <Link
              key={category.id}
              href={`/shoes?category=${category.slug}`}
              className="rounded-full border border-pine/15 bg-mist px-4 py-2 text-sm font-semibold text-ink transition hover:border-pine/30 hover:text-pine"
            >
              {category.name}
            </Link>
          ))}
        </div>
      </section>

      <div className="grid gap-6 xl:grid-cols-[280px_1fr]">
        <FilterPanel brands={brands} categories={categories} searchParams={params} />

        <section className="space-y-5">
          <div className="flex flex-wrap items-center justify-between gap-3 rounded-3xl border border-white/70 bg-white/75 px-5 py-4 shadow-sm">
            <div>
              <p className="text-sm uppercase tracking-[0.2em] text-ember">Results</p>
              <h2 className="font-[family-name:var(--font-heading)] text-2xl font-bold text-ink">
                {shoes.length} pairs ready to browse
              </h2>
            </div>
            <p className="text-sm text-ink/65">
              Shortlist online, then check the final pair in store.
            </p>
          </div>

          <ActiveFilterChips
            searchParams={params}
            brands={brands}
            categories={categories}
          />

          {shoes.length > 0 ? (
            <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
              {shoes.map((shoe) => (
                <ShoeCard key={shoe.id} shoe={shoe} />
              ))}
            </div>
          ) : (
            <div className="rounded-[2rem] border border-dashed border-pine/20 bg-white/65 px-6 py-12 text-center">
              <h3 className="font-[family-name:var(--font-heading)] text-2xl font-semibold text-ink">
                No shoes matched this filter
              </h3>
              <p className="mt-3 text-ink/70">
                Try clearing one or two filters, or add more inventory once Supabase is connected.
              </p>
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
