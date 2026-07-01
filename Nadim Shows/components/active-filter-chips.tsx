import Link from "next/link";
import type { Brand, Category } from "@/lib/types";

type ActiveFilterChipsProps = {
  searchParams: Record<string, string | string[] | undefined>;
  brands: Brand[];
  categories: Category[];
};

function readValue(
  searchParams: Record<string, string | string[] | undefined>,
  key: string
) {
  const value = searchParams[key];

  if (Array.isArray(value)) {
    return value[0] ?? "";
  }

  return value ?? "";
}

function buildClearHref(
  searchParams: Record<string, string | string[] | undefined>,
  keyToClear: string
) {
  const params = new URLSearchParams();

  for (const [key, value] of Object.entries(searchParams)) {
    if (key === keyToClear || value == null) {
      continue;
    }

    if (Array.isArray(value)) {
      for (const entry of value) {
        params.append(key, entry);
      }
      continue;
    }

    if (value !== "") {
      params.set(key, value);
    }
  }

  const query = params.toString();
  return query ? `/shoes?${query}` : "/shoes";
}

export function ActiveFilterChips({
  searchParams,
  brands,
  categories,
}: ActiveFilterChipsProps) {
  const search = readValue(searchParams, "search");
  const brand = readValue(searchParams, "brand");
  const category = readValue(searchParams, "category");
  const size = readValue(searchParams, "size");
  const sort = readValue(searchParams, "sort");
  const minPrice = readValue(searchParams, "minPrice");
  const maxPrice = readValue(searchParams, "maxPrice");

  const brandLabel = brands.find((item) => item.slug === brand)?.name;
  const categoryLabel = categories.find((item) => item.slug === category)?.name;

  const chips = [
    search ? { key: "search", label: `Search: ${search}` } : null,
    brand ? { key: "brand", label: `Brand: ${brandLabel ?? brand}` } : null,
    category ? { key: "category", label: `Category: ${categoryLabel ?? category}` } : null,
    size ? { key: "size", label: `Size: ${size}` } : null,
    minPrice ? { key: "minPrice", label: `Min: Tk ${minPrice}` } : null,
    maxPrice ? { key: "maxPrice", label: `Max: Tk ${maxPrice}` } : null,
    sort
      ? {
          key: "sort",
          label:
            sort === "price-asc"
              ? "Sort: Low to high"
              : sort === "price-desc"
                ? "Sort: High to low"
                : `Sort: ${sort}`,
        }
      : null,
  ].filter(Boolean) as Array<{ key: string; label: string }>;

  if (chips.length === 0) {
    return null;
  }

  return (
    <div className="flex flex-wrap gap-3">
      {chips.map((chip) => (
        <Link
          key={chip.key}
          href={buildClearHref(searchParams, chip.key)}
          className="rounded-full border border-pine/15 bg-white px-4 py-2 text-sm font-medium text-pine transition hover:border-pine/30"
        >
          {chip.label} ×
        </Link>
      ))}
    </div>
  );
}
