import Link from "next/link";
import { AdminRecentShoes } from "@/components/admin-recent-shoes";
import { AdminShoeForm } from "@/components/admin-shoe-form";
import { getBrands, getCategories, getShoes } from "@/lib/store";

export default async function AdminAddShoePage() {
  const [brands, categories, shoes] = await Promise.all([
    getBrands(),
    getCategories(),
    getShoes(),
  ]);
  const recentShoes = shoes.slice(0, 4);

  return (
    <div className="space-y-6">
      <section className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <p className="text-sm uppercase tracking-[0.22em] text-ember">নতুন জুতা</p>
            <h1 className="mt-2 font-[family-name:var(--font-heading)] text-4xl font-bold text-ink">
              Add shoe
            </h1>
            <p className="mt-3 max-w-2xl text-sm leading-7 text-ink/68">
              Photo upload theke size-stock porjonto full mobile-first flow ekhane rakha
              hoyeche. Supabase thakle real insert korbe, na thakle mock mode success dekhabe.
            </p>
          </div>

          <Link
            href="/admin/shoes"
            className="inline-flex items-center gap-2 rounded-full border border-pine/15 bg-white px-5 py-3 text-sm font-semibold text-pine transition hover:border-pine/30"
          >
            Manage shoes
          </Link>
        </div>
      </section>

      <AdminShoeForm brands={brands} categories={categories} />
      <AdminRecentShoes shoes={recentShoes} />
    </div>
  );
}
