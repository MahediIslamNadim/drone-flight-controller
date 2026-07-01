import { Clock3, MapPin, Phone, Store } from "lucide-react";
import { SectionHeading } from "@/components/section-heading";
import { siteConfig } from "@/lib/site-config";

export default function VisitPage() {
  return (
    <div className="mx-auto flex w-full max-w-6xl flex-col gap-8 px-4 py-8 sm:px-6 lg:px-8">
      <SectionHeading
        eyebrow="Visit Store"
        title="Browse online, then come see the pair in person"
        description="Air Dokan is now set up as an offline-first catalog. Customers can explore styles here and then visit the shop for final checking and buying."
      />

      <section className="grid gap-6 lg:grid-cols-[1fr_0.95fr]">
        <div className="rounded-[2rem] border border-white/70 bg-white/85 p-6 shadow-sm">
          <div className="flex items-start gap-3">
            <Store className="mt-1 h-6 w-6 text-pine" />
            <div>
              <h2 className="font-[family-name:var(--font-heading)] text-3xl font-bold text-ink">
                Store visit details
              </h2>
              <p className="mt-3 max-w-2xl text-sm leading-7 text-ink/70">
                Catalog theke shoe shortlist korun, tarpor dokane ese size, comfort,
                and final availability directly check korun.
              </p>
            </div>
          </div>

          <div className="mt-6 grid gap-4">
            <InfoRow
              icon={<MapPin className="h-5 w-5 text-ember" />}
              label="Address"
              value={siteConfig.address}
              href={siteConfig.mapHref}
            />
            <InfoRow
              icon={<Phone className="h-5 w-5 text-ember" />}
              label="Phone"
              value={siteConfig.phone}
              href={siteConfig.phoneHref}
            />
            <InfoRow
              icon={<Clock3 className="h-5 w-5 text-ember" />}
              label="Opening Hours"
              value={siteConfig.hours}
            />
          </div>
        </div>

        <div className="rounded-[2rem] border border-dashed border-pine/20 bg-gradient-to-br from-sand to-white p-6 shadow-sm">
          <p className="text-sm uppercase tracking-[0.24em] text-ember">Location</p>
          <h2 className="mt-2 font-[family-name:var(--font-heading)] text-3xl font-bold text-ink">
            Map placeholder
          </h2>
          <p className="mt-3 text-sm leading-7 text-ink/70">
            Ekhane pore Google Map embed ba custom direction block bosano jabe.
            Ekhon address block diye visit information clear rakha hoyeche.
          </p>
          <div className="mt-6 grid min-h-64 place-items-center rounded-[1.75rem] border border-pine/10 bg-white/80">
            <div className="text-center">
              <MapPin className="mx-auto h-8 w-8 text-pine" />
              <p className="mt-3 font-semibold text-ink">{siteConfig.address}</p>
              <p className="mt-1 text-sm text-ink/60">Interactive map can be added later.</p>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}

function InfoRow({
  icon,
  label,
  value,
  href,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  href?: string;
}) {
  return (
    <div className="flex items-start gap-3 rounded-[1.5rem] bg-mist px-4 py-4">
      {icon}
      <div>
        <p className="text-xs uppercase tracking-[0.2em] text-ink/45">{label}</p>
        {href ? (
          <a href={href} className="mt-2 block font-medium text-pine transition hover:text-pine/80">
            {value}
          </a>
        ) : (
          <p className="mt-2 font-medium text-ink">{value}</p>
        )}
      </div>
    </div>
  );
}
