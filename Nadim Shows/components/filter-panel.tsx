import Link from "next/link";
import { Search } from "lucide-react";
import type { Brand, Category } from "@/lib/types";

type FilterPanelProps = {
  brands: Brand[];
  categories: Category[];
  searchParams: Record<string, string | string[] | undefined>;
};

const sizeOptions = ["36", "37", "38", "39", "40", "41", "42", "43", "44"];

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

export function FilterPanel({ brands, categories, searchParams }: FilterPanelProps) {
  const activeSearch = readValue(searchParams, "search");
  const activeBrand = readValue(searchParams, "brand");
  const activeCategory = readValue(searchParams, "category");
  const activeSize = readValue(searchParams, "size");
  const activeSort = readValue(searchParams, "sort");
  const activeMinPrice = readValue(searchParams, "minPrice");
  const activeMaxPrice = readValue(searchParams, "maxPrice");

  return (
    <aside className="surface h-fit rounded-[2rem] border border-white/70 p-5 shadow-sm">
      <div className="mb-5">
        <p className="text-sm uppercase tracking-[0.22em] text-ember">Filters</p>
        <h2 className="mt-2 font-[family-name:var(--font-heading)] text-2xl font-bold text-ink">
          Find the right pair faster
        </h2>
        <p className="mt-2 text-sm leading-6 text-ink/65">
          Browse by brand, category, size, ar budget. Pochondo hole store visit korun.
        </p>
      </div>

      <form className="space-y-5" action="/shoes">
        <label className="block">
          <span className="mb-2 block text-sm font-medium text-ink/75">Search</span>
          <div className="flex items-center gap-2 rounded-2xl border border-pine/10 bg-white px-4 py-3">
            <Search className="h-4 w-4 text-ink/45" />
            <input
              type="search"
              name="search"
              defaultValue={activeSearch}
              placeholder="Name or color"
              className="w-full border-0 bg-transparent text-sm text-ink outline-none placeholder:text-ink/35"
            />
          </div>
        </label>

        <label className="block">
          <span className="mb-2 block text-sm font-medium text-ink/75">Brand</span>
          <select
            name="brand"
            defaultValue={activeBrand}
            className="w-full rounded-2xl border border-pine/10 bg-white px-4 py-3 text-sm text-ink"
          >
            <option value="">All brands</option>
            {brands.map((brand) => (
              <option key={brand.id} value={brand.slug}>
                {brand.name}
              </option>
            ))}
          </select>
        </label>

        <label className="block">
          <span className="mb-2 block text-sm font-medium text-ink/75">Category</span>
          <select
            name="category"
            defaultValue={activeCategory}
            className="w-full rounded-2xl border border-pine/10 bg-white px-4 py-3 text-sm text-ink"
          >
            <option value="">All categories</option>
            {categories.map((category) => (
              <option key={category.id} value={category.slug}>
                {category.name}
              </option>
            ))}
          </select>
        </label>

        <div className="grid grid-cols-2 gap-3">
          <label className="block">
            <span className="mb-2 block text-sm font-medium text-ink/75">Min price</span>
            <input
              type="number"
              name="minPrice"
              defaultValue={activeMinPrice}
              placeholder="1200"
              className="w-full rounded-2xl border border-pine/10 bg-white px-4 py-3 text-sm text-ink"
            />
          </label>

          <label className="block">
            <span className="mb-2 block text-sm font-medium text-ink/75">Max price</span>
            <input
              type="number"
              name="maxPrice"
              defaultValue={activeMaxPrice}
              placeholder="4500"
              className="w-full rounded-2xl border border-pine/10 bg-white px-4 py-3 text-sm text-ink"
            />
          </label>
        </div>

        <label className="block">
          <span className="mb-2 block text-sm font-medium text-ink/75">Size</span>
          <select
            name="size"
            defaultValue={activeSize}
            className="w-full rounded-2xl border border-pine/10 bg-white px-4 py-3 text-sm text-ink"
          >
            <option value="">Any size</option>
            {sizeOptions.map((size) => (
              <option key={size} value={size}>
                {size}
              </option>
            ))}
          </select>
        </label>

        <label className="block">
          <span className="mb-2 block text-sm font-medium text-ink/75">Sort</span>
          <select
            name="sort"
            defaultValue={activeSort}
            className="w-full rounded-2xl border border-pine/10 bg-white px-4 py-3 text-sm text-ink"
          >
            <option value="">Newest first</option>
            <option value="price-asc">Price low to high</option>
            <option value="price-desc">Price high to low</option>
          </select>
        </label>

        <div className="flex flex-col gap-3">
          <button
            type="submit"
            className="rounded-full bg-pine px-5 py-3 text-sm font-semibold text-white transition hover:bg-pine/90"
          >
            Apply filters
          </button>
          <Link
            href="/shoes"
            className="rounded-full border border-pine/10 px-5 py-3 text-center text-sm font-semibold text-pine transition hover:border-pine/25"
          >
            Clear all
          </Link>
        </div>

        <div className="rounded-[1.5rem] border border-pine/10 bg-mist px-4 py-4 text-sm text-ink/70">
          Tip: Size filter use korle dokane jawar age shortlist korte easy hoy.
        </div>
      </form>
    </aside>
  );
}
