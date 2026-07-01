import { notFound } from "next/navigation";
import Image from "next/image";
import Link from "next/link";
import { ArrowLeft, Clock3, MapPin, Phone, Store } from "lucide-react";
import { SectionHeading } from "@/components/section-heading";
import { ShoeCard } from "@/components/shoe-card";
import { getRelatedShoes, getShoeById } from "@/lib/store";
import { siteConfig } from "@/lib/site-config";

type ShoeDetailPageProps = {
  params: Promise<{
    id: string;
  }>;
};

export default async function ShoeDetailPage({ params }: ShoeDetailPageProps) {
  const { id } = await params;
  const shoe = await getShoeById(id);

  if (!shoe) {
    notFound();
  }

  const relatedShoes = await getRelatedShoes(shoe);
  const availableSizes = shoe.sizes.filter(
    (size) => size.isAvailable && size.stockQuantity > 0
  );
  const totalStock = availableSizes.reduce(
    (accumulator, size) => accumulator + size.stockQuantity,
    0
  );

  return (
    <div className="mx-auto flex w-full max-w-7xl flex-col gap-8 px-4 py-8 sm:px-6 lg:px-8">
      <Link
        href="/shoes"
        className="inline-flex items-center gap-2 text-sm font-semibold text-pine transition hover:text-pine/80"
      >
        <ArrowLeft className="h-4 w-4" />
        Back to shoes
      </Link>

      <section className="grid gap-8 lg:grid-cols-[1.1fr_0.9fr]">
        <div className="space-y-4">
          <div className="overflow-hidden rounded-[2rem] border border-white/70 bg-white/75 shadow-sm">
            <div className="relative aspect-[4/3]">
              <Image
                src={shoe.imageUrls[0]}
                alt={shoe.nameEn}
                fill
                className="object-cover"
                sizes="(min-width: 1024px) 56vw, 100vw"
              />
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-3">
            {shoe.imageUrls.slice(1, 4).map((imageUrl, index) => (
              <div
                key={`${imageUrl}-${index}`}
                className="relative aspect-square overflow-hidden rounded-[1.5rem] border border-white/70 bg-white/75"
              >
                <Image
                  src={imageUrl}
                  alt={`${shoe.nameEn} preview ${index + 2}`}
                  fill
                  className="object-cover"
                  sizes="(min-width: 640px) 30vw, 100vw"
                />
              </div>
            ))}
          </div>
        </div>

        <div className="space-y-6">
          <div className="rounded-[2rem] border border-white/70 bg-white/80 p-6 shadow-sm">
            <div className="flex flex-wrap items-center gap-3">
              <span className="rounded-full bg-sand px-3 py-1 text-sm font-medium text-ember">
                {shoe.category.name}
              </span>
              <span className="rounded-full border border-pine/15 px-3 py-1 text-sm font-medium text-pine">
                {shoe.brand.name}
              </span>
            </div>
            <h1 className="mt-5 font-[family-name:var(--font-heading)] text-4xl font-bold text-ink">
              {shoe.nameEn}
            </h1>
            <p className="mt-2 text-lg text-ink/75">{shoe.nameBn}</p>
            <p className="mt-6 font-[family-name:var(--font-heading)] text-4xl font-bold text-pine">
              Tk {Math.round(shoe.price).toLocaleString("en-US")}
            </p>

            <div className="mt-6 grid gap-4 sm:grid-cols-2">
              <InfoBlock label="Style" value={shoe.styleType ?? "Everyday"} />
              <InfoBlock label="Gender" value={shoe.gender ?? "Unisex"} />
              <InfoBlock label="Colors" value={shoe.colors.join(", ")} />
              <InfoBlock label="Materials" value={shoe.materials.join(", ")} />
            </div>

            <div className="mt-8 space-y-3">
              <h2 className="font-semibold text-ink">Available sizes</h2>
              <div className="grid grid-cols-3 gap-3 sm:grid-cols-4">
                {shoe.sizes.map((size) => {
                  const available = size.isAvailable && size.stockQuantity > 0;

                  return (
                    <div
                      key={size.size}
                      className={`rounded-2xl border px-4 py-3 text-center ${
                        available
                          ? "border-pine/15 bg-pine/5 text-pine"
                          : "border-ink/10 bg-ink/5 text-ink/40"
                      }`}
                    >
                      <p className="font-semibold">{size.size}</p>
                      <p className="text-xs">
                        {available ? `${size.stockQuantity} in stock` : "Out of stock"}
                      </p>
                    </div>
                  );
                })}
              </div>
            </div>

            <div className="mt-8 rounded-[1.75rem] border border-pine/10 bg-mist p-5">
              <div className="flex items-start gap-3">
                <Store className="mt-1 h-5 w-5 text-pine" />
                <div>
                  <p className="font-semibold text-ink">Available for in-store browsing</p>
                  <p className="mt-1 text-sm leading-6 text-ink/68">
                    {siteConfig.visitMessage}
                  </p>
                </div>
              </div>

              <div className="mt-4 grid gap-3 text-sm text-ink/72 sm:grid-cols-3">
                <div className="flex items-start gap-2">
                  <MapPin className="mt-0.5 h-4 w-4 text-ember" />
                  <a
                    href={siteConfig.mapHref}
                    target="_blank"
                    rel="noreferrer"
                    className="transition hover:text-pine"
                  >
                    {siteConfig.address}
                  </a>
                </div>
                <div className="flex items-center gap-2">
                  <Phone className="h-4 w-4 text-ember" />
                  <a href={siteConfig.phoneHref} className="transition hover:text-pine">
                    {siteConfig.phone}
                  </a>
                </div>
                <div className="flex items-center gap-2">
                  <Clock3 className="h-4 w-4 text-ember" />
                  <span>{siteConfig.hours}</span>
                </div>
              </div>

              <div className="mt-4 flex flex-col gap-3 sm:flex-row">
                <Link
                  href="/visit"
                  className="inline-flex items-center justify-center gap-2 rounded-full bg-pine px-6 py-3 text-base font-semibold text-white transition hover:bg-pine/90"
                >
                  Store Visit Details
                </Link>
                <div className="inline-flex items-center justify-center rounded-full border border-pine/15 bg-white px-6 py-3 text-base font-semibold text-pine">
                  {totalStock > 0
                    ? `${totalStock} pair in visible stock`
                    : "Ask in store for latest stock"}
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="space-y-6">
        <SectionHeading
          eyebrow="Related"
          title="More pairs customers may want next"
          description="This section already works with fallback data and will become stronger once real catalog variety lands."
        />
        <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
          {relatedShoes.map((relatedShoe) => (
            <ShoeCard key={relatedShoe.id} shoe={relatedShoe} />
          ))}
        </div>
      </section>
    </div>
  );
}

function InfoBlock({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl bg-mist px-4 py-3">
      <p className="text-xs uppercase tracking-[0.2em] text-ink/50">{label}</p>
      <p className="mt-2 font-medium text-ink">{value}</p>
    </div>
  );
}
