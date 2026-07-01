import { ShoppingBag } from "lucide-react";
import { AdminSalesEntry } from "@/components/admin-sales-entry";
import { getShoes } from "@/lib/store";
import type { SaleEntry } from "@/lib/types";

const initialSales: SaleEntry[] = [
  {
    id: "sale-1",
    shoeId: "shoe-bata-premium-oxford",
    shoeName: "Bata Premium Oxford",
    size: "40",
    quantity: 1,
    amount: 3290,
    soldAt: new Date().toISOString(),
  },
  {
    id: "sale-2",
    shoeId: "shoe-power-run-x",
    shoeName: "Power Run X",
    size: "39",
    quantity: 2,
    amount: 8380,
    soldAt: new Date().toISOString(),
  },
];

export default async function AdminSalesAddPage() {
  const shoes = await getShoes();

  return (
    <div className="space-y-6">
      <section className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
        <div className="flex items-center gap-3">
          <ShoppingBag className="h-8 w-8 text-pine" />
          <div>
            <p className="text-sm uppercase tracking-[0.22em] text-ember">বিক্রি add</p>
            <h1 className="font-[family-name:var(--font-heading)] text-4xl font-bold text-ink">
              Quick sale entry
            </h1>
          </div>
        </div>
        <p className="mt-3 text-sm leading-7 text-ink/68">
          Search shoe, select size, quantity din, then save. Stock automatically deduct hobe.
        </p>
      </section>

      <AdminSalesEntry initialShoes={shoes} initialSales={initialSales} />
    </div>
  );
}
