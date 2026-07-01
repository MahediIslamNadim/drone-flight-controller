import { PackageSearch } from "lucide-react";
import { AdminStockManager } from "@/components/admin-stock-manager";
import { getLowStockShoes, getShoes } from "@/lib/store";

export default async function AdminStockPage() {
  const [shoes, lowStockShoes] = await Promise.all([getShoes(), getLowStockShoes()]);

  return (
    <div className="space-y-6">
      <section className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
        <div className="flex items-center gap-3">
          <PackageSearch className="h-8 w-8 text-pine" />
          <div>
            <p className="text-sm uppercase tracking-[0.22em] text-ember">স্টক</p>
            <h1 className="font-[family-name:var(--font-heading)] text-4xl font-bold text-ink">
              Stock overview
            </h1>
          </div>
        </div>
        <p className="mt-3 text-sm leading-7 text-ink/68">
          Search, quick edit, ar color-coded size health ekhanei ready.
        </p>
      </section>

      <div className="rounded-[2rem] border border-amber-200 bg-amber-50 px-5 py-4 text-sm text-amber-800">
        Low stock alert: {lowStockShoes.length} pair needs attention.
      </div>

      <AdminStockManager initialShoes={shoes} />
    </div>
  );
}
