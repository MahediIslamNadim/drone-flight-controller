import Link from "next/link";
import Image from "next/image";
import type { Shoe } from "@/lib/types";

export function AdminRecentShoes({ shoes }: { shoes: Shoe[] }) {
  return (
    <section className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
      <p className="text-sm uppercase tracking-[0.22em] text-ember">Recent Catalog</p>
      <h2 className="mt-2 font-[family-name:var(--font-heading)] text-3xl font-bold text-ink">
        Recently added shoes
      </h2>
      <p className="mt-2 text-sm leading-7 text-ink/68">
        Save korar por ei list refresh hoye latest catalog item dekhabe.
      </p>

      <div className="mt-5 grid gap-4 md:grid-cols-2">
        {shoes.map((shoe) => (
          <div
            key={shoe.id}
            className="overflow-hidden rounded-[1.75rem] border border-pine/10 bg-mist"
          >
            <div className="relative aspect-[4/3]">
              <Image
                src={shoe.imageUrls[0]}
                alt={shoe.nameEn}
                fill
                className="object-cover"
                sizes="(min-width: 768px) 40vw, 100vw"
              />
            </div>
            <div className="space-y-2 p-4">
              <p className="font-[family-name:var(--font-heading)] text-2xl font-bold text-ink">
                {shoe.nameEn}
              </p>
              <p className="text-sm text-ink/65">{shoe.nameBn}</p>
              <p className="text-sm text-ink/70">
                {shoe.brand.name} • {shoe.category.name}
              </p>
              <p className="text-sm font-semibold text-pine">
                Tk {Math.round(shoe.price).toLocaleString("en-US")}
              </p>
              <div className="pt-1">
                <Link
                  href={`/admin/shoes/${shoe.id}/edit`}
                  className="text-sm font-semibold text-pine transition hover:text-pine/80"
                >
                  Edit this shoe
                </Link>
              </div>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
