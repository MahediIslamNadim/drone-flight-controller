import Image from "next/image";
import Link from "next/link";
import { ArrowUpRight, CheckCircle2 } from "lucide-react";
import type { Shoe } from "@/lib/types";

export function ShoeCard({ shoe }: { shoe: Shoe }) {
  const availableSizes = shoe.sizes
    .filter((size) => size.isAvailable && size.stockQuantity > 0)
    .map((size) => size.size);
  const totalVisibleStock = shoe.sizes.reduce(
    (accumulator, size) => accumulator + size.stockQuantity,
    0
  );
  const stockTone =
    totalVisibleStock === 0
      ? "bg-red-50 text-red-700"
      : totalVisibleStock < 4
        ? "bg-amber-50 text-amber-700"
        : "bg-emerald-50 text-emerald-700";
  const stockLabel =
    totalVisibleStock === 0
      ? "Ask in store"
      : totalVisibleStock < 4
        ? "Low stock"
        : "In stock";

  return (
    <Link
      href={`/shoes/${shoe.id}`}
      className="group overflow-hidden rounded-[2rem] border border-white/70 bg-white/80 shadow-sm transition hover:-translate-y-1 hover:shadow-glow"
    >
      <div className="relative aspect-[4/3] overflow-hidden">
        <Image
          src={shoe.imageUrls[0]}
          alt={shoe.nameEn}
          fill
          className="object-cover transition duration-500 group-hover:scale-105"
          sizes="(min-width: 1280px) 30vw, (min-width: 768px) 45vw, 100vw"
        />
        <div className="absolute inset-x-0 bottom-0 h-1/2 bg-gradient-to-t from-black/35 to-transparent" />
        <div className="absolute left-4 top-4 flex flex-wrap gap-2">
          <div className="inline-flex rounded-full bg-white/90 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-pine">
            {shoe.category.name}
          </div>
          <div className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${stockTone}`}>
            {stockLabel}
          </div>
        </div>
      </div>

      <div className="space-y-4 p-5">
        <div className="flex items-start justify-between gap-3">
          <div>
            <p className="text-sm text-ink/55">{shoe.brand.name}</p>
            <h3 className="mt-1 font-[family-name:var(--font-heading)] text-2xl font-bold text-ink">
              {shoe.nameEn}
            </h3>
            <p className="text-sm text-ink/65">{shoe.nameBn}</p>
          </div>
          <ArrowUpRight className="h-5 w-5 text-ink/45 transition group-hover:-translate-y-0.5 group-hover:translate-x-0.5 group-hover:text-pine" />
        </div>

        <div className="flex flex-wrap gap-2">
          {shoe.colors.slice(0, 3).map((color) => (
            <span
              key={color}
              className="rounded-full border border-pine/10 bg-mist px-3 py-1 text-xs font-medium text-ink/70"
            >
              {color}
            </span>
          ))}
        </div>

        <div className="flex items-center justify-between gap-4">
          <div>
            <p className="text-sm text-ink/55">Price</p>
            <p className="font-[family-name:var(--font-heading)] text-2xl font-bold text-pine">
              Tk {Math.round(shoe.price).toLocaleString("en-US")}
            </p>
          </div>
          <div className="rounded-2xl bg-pine/5 px-4 py-2 text-right text-sm text-pine">
            <div className="inline-flex items-center gap-1 font-medium">
              <CheckCircle2 className="h-4 w-4" />
              {availableSizes.length} sizes
            </div>
            <p className="text-xs text-pine/70">
              {availableSizes.join(", ") || "Ask in store"}
            </p>
          </div>
        </div>

        <div className="rounded-[1.5rem] border border-pine/10 bg-mist px-4 py-3 text-sm text-ink/70">
          Catalog shortlist only. Final checking and buying happens in store.
        </div>
      </div>
    </Link>
  );
}
