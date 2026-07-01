export const siteConfig = {
  name: process.env.NEXT_PUBLIC_APP_NAME ?? "Air Dokan",
  address:
    process.env.NEXT_PUBLIC_STORE_ADDRESS ?? "Katakhal Bazar, Mithamin, Kishoreganj",
  phone: process.env.NEXT_PUBLIC_STORE_PHONE ?? "+880 1X-XXXXXXX",
  hours:
    process.env.NEXT_PUBLIC_STORE_HOURS ?? "Every day, 10:00 AM - 10:00 PM",
  visitMessage: "Catalog dekhe pochondo korun, tarpor dokane ese pair ta directly check korun.",
  phoneHref: `tel:${(process.env.NEXT_PUBLIC_STORE_PHONE ?? "+880 1X-XXXXXXX").replace(/[^+\d]/g, "")}`,
  mapHref: `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
    process.env.NEXT_PUBLIC_STORE_ADDRESS ?? "Katakhal Bazar, Mithamin, Kishoreganj"
  )}`,
};
