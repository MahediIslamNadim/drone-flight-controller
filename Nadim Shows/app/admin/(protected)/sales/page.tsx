import Link from "next/link";
import { ArrowRight, ShoppingBag } from "lucide-react";

export default function AdminSalesPage() {
  return (
    <div className="space-y-6">
      <section className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
        <div className="flex items-center gap-3">
          <ShoppingBag className="h-8 w-8 text-pine" />
          <div>
            <p className="text-sm uppercase tracking-[0.22em] text-ember">বিক্রি</p>
            <h1 className="font-[family-name:var(--font-heading)] text-4xl font-bold text-ink">
              Sales tools
            </h1>
          </div>
        </div>
        <p className="mt-3 text-sm leading-7 text-ink/68">
          Quick sale entry flow ekhon আলাদা route-এ আছে যাতে mobile-e 3 tap-e sale save kora jai.
        </p>
      </section>

      <Link
        href="/admin/sales/add"
        className="inline-flex items-center gap-2 rounded-full bg-pine px-6 py-4 text-base font-semibold text-white transition hover:bg-pine/90"
      >
        Open sale entry
        <ArrowRight className="h-5 w-5" />
      </Link>
    </div>
  );
}

