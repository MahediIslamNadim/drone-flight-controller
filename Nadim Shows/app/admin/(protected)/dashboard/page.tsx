import Link from "next/link";
import { ArrowRight, CircleAlert, PackagePlus, ShoppingBag } from "lucide-react";
import { getAdminDashboardStats } from "@/lib/store";

export default async function AdminDashboardPage() {
  const stats = await getAdminDashboardStats();
  const maxSales = Math.max(...stats.weeklySales.map((item) => item.total), 1);

  return (
    <div className="space-y-6">
      <section className="grid gap-4 md:grid-cols-3">
        <StatCard label="Total shoes" value={String(stats.totalShoes)} helper="Catalog e total pair" />
        <StatCard
          label="Today's sales"
          value={String(stats.todaysSales)}
          helper="Manual entry snapshot"
        />
        <StatCard
          label="Today's revenue"
          value={`Tk ${stats.todaysRevenue.toLocaleString("en-US")}`}
          helper="Quick daily estimate"
        />
      </section>

      <section className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
          <div className="flex items-center justify-between gap-4">
            <div>
              <p className="text-sm uppercase tracking-[0.22em] text-ember">Weekly trend</p>
              <h2 className="mt-2 font-[family-name:var(--font-heading)] text-3xl font-bold text-ink">
                Simple sales chart
              </h2>
            </div>
            <ShoppingBag className="h-8 w-8 text-pine" />
          </div>

          <div className="mt-8 flex h-64 items-end gap-3">
            {stats.weeklySales.map((item) => (
              <div key={item.day} className="flex flex-1 flex-col items-center gap-3">
                <div className="flex h-full w-full items-end">
                  <div
                    className="w-full rounded-t-[1.25rem] bg-gradient-to-t from-pine to-ocean"
                    style={{
                      height: `${Math.max((item.total / maxSales) * 100, 14)}%`,
                    }}
                  />
                </div>
                <div className="text-center text-sm">
                  <p className="font-semibold text-ink">{item.total}</p>
                  <p className="text-ink/55">{item.day}</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="space-y-6">
          <div className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
            <div className="flex items-center justify-between gap-4">
              <div>
                <p className="text-sm uppercase tracking-[0.22em] text-ember">Quick links</p>
                <h2 className="mt-2 font-[family-name:var(--font-heading)] text-3xl font-bold text-ink">
                  Fast actions
                </h2>
              </div>
              <PackagePlus className="h-8 w-8 text-pine" />
            </div>

            <div className="mt-5 grid gap-3">
              <QuickLink href="/admin/shoes/add" label="নতুন জুতা add korun" />
              <QuickLink href="/admin/stock" label="স্টক update korun" />
              <QuickLink href="/admin/sales" label="বিক্রি entry dekhun" />
            </div>
          </div>

          <div className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
            <div className="flex items-center gap-3">
              <CircleAlert className="h-7 w-7 text-amber-600" />
              <div>
                <p className="text-sm uppercase tracking-[0.22em] text-ember">Low stock</p>
                <h2 className="font-[family-name:var(--font-heading)] text-2xl font-bold text-ink">
                  Need attention
                </h2>
              </div>
            </div>

            <div className="mt-5 space-y-3">
              {stats.lowStockItems.length > 0 ? (
                stats.lowStockItems.map((shoe) => (
                  <div
                    key={shoe.id}
                    className="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-4"
                  >
                    <p className="font-semibold text-ink">{shoe.nameEn}</p>
                    <p className="text-sm text-ink/70">
                      {shoe.sizes
                        .filter(
                          (size) =>
                            size.isAvailable &&
                            size.stockQuantity > 0 &&
                            size.stockQuantity < 3
                        )
                        .map((size) => `${size.size} (${size.stockQuantity})`)
                        .join(", ")}
                    </p>
                  </div>
                ))
              ) : (
                <p className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-4 text-sm text-emerald-700">
                  Kon low-stock alert nei.
                </p>
              )}
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}

function StatCard({
  label,
  value,
  helper,
}: {
  label: string;
  value: string;
  helper: string;
}) {
  return (
    <div className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
      <p className="text-sm uppercase tracking-[0.22em] text-ember">{label}</p>
      <p className="mt-4 font-[family-name:var(--font-heading)] text-4xl font-bold text-ink">
        {value}
      </p>
      <p className="mt-2 text-sm text-ink/65">{helper}</p>
    </div>
  );
}

function QuickLink({ href, label }: { href: string; label: string }) {
  return (
    <Link
      href={href}
      className="flex items-center justify-between rounded-2xl border border-pine/10 bg-mist px-4 py-4 text-sm font-semibold text-ink transition hover:border-pine/25"
    >
      {label}
      <ArrowRight className="h-4 w-4 text-pine" />
    </Link>
  );
}

