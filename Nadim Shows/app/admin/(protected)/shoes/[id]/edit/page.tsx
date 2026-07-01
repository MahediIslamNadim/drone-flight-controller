import { notFound } from "next/navigation";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { AdminShoeForm } from "@/components/admin-shoe-form";
import { getBrands, getCategories, getShoeById } from "@/lib/store";

type AdminEditShoePageProps = {
  params: Promise<{
    id: string;
  }>;
};

export default async function AdminEditShoePage({ params }: AdminEditShoePageProps) {
  const { id } = await params;
  const [shoe, brands, categories] = await Promise.all([
    getShoeById(id),
    getBrands(),
    getCategories(),
  ]);

  if (!shoe) {
    notFound();
  }

  return (
    <div className="space-y-6">
      <Link
        href="/admin/shoes"
        className="inline-flex items-center gap-2 text-sm font-semibold text-pine transition hover:text-pine/80"
      >
        <ArrowLeft className="h-4 w-4" />
        Back to shoes list
      </Link>

      <section className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
        <p className="text-sm uppercase tracking-[0.22em] text-ember">Edit Shoe</p>
        <h1 className="mt-2 font-[family-name:var(--font-heading)] text-4xl font-bold text-ink">
          {shoe.nameEn}
        </h1>
        <p className="mt-3 max-w-2xl text-sm leading-7 text-ink/68">
          Existing catalog info prefilled ache. Details change kore update korlei hobe.
        </p>
      </section>

      <AdminShoeForm
        brands={brands}
        categories={categories}
        initialShoe={shoe}
        mode="edit"
      />
    </div>
  );
}

