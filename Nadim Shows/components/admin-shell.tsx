import Link from "next/link";
import {
  BarChart3,
  LogOut,
  PackagePlus,
  PackageSearch,
  Settings2,
  ShoppingBag,
} from "lucide-react";

const navItems = [
  { href: "/admin/dashboard", label: "ড্যাশবোর্ড", icon: BarChart3 },
  { href: "/admin/shoes/add", label: "নতুন জুতা", icon: PackagePlus },
  { href: "/admin/stock", label: "স্টক", icon: PackageSearch },
  { href: "/admin/sales/add", label: "বিক্রি", icon: ShoppingBag },
  { href: "/admin/setup", label: "সেটআপ", icon: Settings2 },
];

export function AdminShell({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <div className="min-h-screen bg-[linear-gradient(180deg,#fff9f3_0%,#eef3f2_100%)]">
      <div className="mx-auto flex min-h-screen w-full max-w-7xl flex-col lg:flex-row">
        <aside className="border-b border-pine/10 bg-white/90 p-4 backdrop-blur lg:w-80 lg:border-b-0 lg:border-r lg:p-6">
          <div className="rounded-[2rem] bg-gradient-to-br from-pine to-ocean p-6 text-white shadow-glow">
            <p className="text-sm uppercase tracking-[0.22em] text-white/70">Admin</p>
            <h1 className="mt-2 font-[family-name:var(--font-heading)] text-3xl font-bold">
              Air Dokan
            </h1>
            <p className="mt-3 text-sm leading-6 text-white/80">
              Abbu-r jonne simple control panel. Mobile thekeo fast use kora jabe.
            </p>
          </div>

          <nav className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-1">
            {navItems.map((item) => {
              const Icon = item.icon;

              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className="flex items-center gap-3 rounded-2xl border border-pine/10 bg-white px-4 py-4 text-sm font-semibold text-ink transition hover:border-pine/20 hover:bg-mist"
                >
                  <span className="grid h-10 w-10 place-items-center rounded-2xl bg-pine/10 text-pine">
                    <Icon className="h-5 w-5" />
                  </span>
                  {item.label}
                </Link>
              );
            })}
          </nav>

          <form action="/api/admin/logout" method="post" className="mt-5">
            <button
              type="submit"
              className="inline-flex w-full items-center justify-center gap-2 rounded-full border border-pine/15 px-5 py-3 text-sm font-semibold text-pine transition hover:border-pine/30"
            >
              <LogOut className="h-4 w-4" />
              Log out
            </button>
          </form>
        </aside>

        <div className="flex-1 p-4 sm:p-6 lg:p-8">{children}</div>
      </div>
    </div>
  );
}
