import Link from "next/link";
import { ArrowRight, PackagePlus } from "lucide-react";
import { getShoes } from "@/lib/store";

export default async function AdminShoesPage() {
  const shoes = await getShoes();

  return (
    <div className="space-y-6">
      <section className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className="text-sm uppercase tracking-[0.22em] text-ember">Catalog Manage</p>
            <h1 className="mt-2 font-[family-name:var(--font-heading)] text-4xl font-bold text-ink">
              Shoes list
            </h1>
            <p className="mt-3 max-w-2xl text-sm leading-7 text-ink/68">
              Ekhane theke existing shoe edit korte parben, ar notun shoe add korte parben.
            </p>
          </div>
          <Link
            href="/admin/shoes/add"
            className="inline-flex items-center gap-2 rounded-full bg-pine px-5 py-3 text-sm font-semibold text-white transition hover:bg-pine/90"
          >
            <PackagePlus className="h-4 w-4" />
            Add new shoe
          </Link>
        </div>
      </section>

      <div className="grid gap-4">
        {shoes.map((shoe) => (
          <div
            key={shoe.id}
            className="rounded-[1.75rem] border border-white/70 bg-white/85 p-5 shadow-sm"
          >
            <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <p className="font-[family-name:var(--font-heading)] text-2xl font-bold text-ink">
                  {shoe.nameEn}
                </p>
                <p className="text-sm text-ink/65">{shoe.nameBn}</p>
                <p className="mt-1 text-sm text-ink/70">
                  {shoe.brand.name} • {shoe.category.name} • Tk{" "}
                  {Math.round(shoe.price).toLocaleString("en-US")}
                </p>
              </div>

              <div className="flex flex-wrap gap-3">
                <Link
                  href={`/admin/shoes/${shoe.id}/edit`}
                  className="inline-flex items-center gap-2 rounded-full border border-pine/15 bg-white px-5 py-3 text-sm font-semibold text-pine transition hover:border-pine/30"
                >
                  Edit details
                  <ArrowRight className="h-4 w-4" />
                </Link>
                <Link
                  href="/admin/stock"
                  className="inline-flex items-center gap-2 rounded-full border border-pine/15 bg-mist px-5 py-3 text-sm font-semibold text-ink transition hover:border-pine/30"
                >
                  Update stock
                </Link>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

