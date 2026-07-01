"use client";

import { useMemo, useState } from "react";
import { LoaderCircle, Search } from "lucide-react";
import type { Shoe } from "@/lib/types";

type AdminStockManagerProps = {
  initialShoes: Shoe[];
};

export function AdminStockManager({ initialShoes }: AdminStockManagerProps) {
  const [shoes, setShoes] = useState(initialShoes);
  const [search, setSearch] = useState("");
  const [savingId, setSavingId] = useState<string | null>(null);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  const filteredShoes = useMemo(() => {
    const query = search.trim().toLowerCase();

    if (!query) {
      return shoes;
    }

    return shoes.filter(
      (shoe) =>
        shoe.nameEn.toLowerCase().includes(query) ||
        shoe.nameBn.toLowerCase().includes(query) ||
        shoe.brand.name.toLowerCase().includes(query)
    );
  }, [search, shoes]);

  async function saveStock(shoeId: string) {
    const selectedShoe = shoes.find((shoe) => shoe.id === shoeId);

    if (!selectedShoe) {
      return;
    }

    setSavingId(shoeId);
    setMessage("");
    setError("");

    try {
      const response = await fetch("/api/admin/stock/update", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          shoeId,
          sizes: selectedShoe.sizes.map((size) => ({
            id: size.id,
            size: size.size,
            stockQuantity: size.stockQuantity,
          })),
        }),
      });

      const result = (await response.json()) as {
        message?: string;
        error?: string;
      };

      if (!response.ok) {
        setError(result.error ?? "Stock update failed.");
        return;
      }

      setMessage(result.message ?? "Stock updated.");
    } catch {
      setError("Network error while saving stock.");
    } finally {
      setSavingId(null);
    }
  }

  return (
    <div className="space-y-5">
      <div className="rounded-[2rem] border border-white/70 bg-white/85 p-4 shadow-sm">
        <label className="flex items-center gap-3 rounded-2xl border border-pine/10 bg-mist px-4 py-4">
          <Search className="h-5 w-5 text-pine" />
          <input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Name, brand, ba Bangla naam diye khujun"
            className="w-full bg-transparent text-base text-ink outline-none placeholder:text-ink/40"
          />
        </label>
      </div>

      {error ? (
        <p className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </p>
      ) : null}

      {message ? (
        <p className="rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
          {message}
        </p>
      ) : null}

      <div className="grid gap-4">
        {filteredShoes.map((shoe) => (
          <div
            key={shoe.id}
            className="rounded-[1.75rem] border border-white/70 bg-white/85 p-5 shadow-sm"
          >
            <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <p className="font-[family-name:var(--font-heading)] text-2xl font-bold text-ink">
                  {shoe.nameEn}
                </p>
                <p className="text-sm text-ink/60">
                  {shoe.brand.name} • {shoe.category.name}
                </p>
              </div>
              <button
                type="button"
                onClick={() => void saveStock(shoe.id)}
                disabled={savingId === shoe.id}
                className="inline-flex items-center justify-center gap-2 rounded-full bg-pine px-5 py-3 text-sm font-semibold text-white transition hover:bg-pine/90 disabled:cursor-not-allowed disabled:opacity-70"
              >
                {savingId === shoe.id ? <LoaderCircle className="h-4 w-4 animate-spin" /> : null}
                Save stock
              </button>
            </div>

            <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
              {shoe.sizes.map((size) => {
                const tone =
                  size.stockQuantity === 0
                    ? "bg-red-50 text-red-700"
                    : size.stockQuantity < 3
                      ? "bg-amber-50 text-amber-700"
                      : "bg-emerald-50 text-emerald-700";

                return (
                  <div key={size.id} className="rounded-[1.5rem] border border-pine/10 bg-mist p-4">
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <p className="font-[family-name:var(--font-heading)] text-2xl font-bold text-ink">
                          {size.size}
                        </p>
                        <p className="text-sm text-ink/55">Size</p>
                      </div>
                      <span className={`rounded-full px-3 py-1 text-xs font-semibold ${tone}`}>
                        {size.stockQuantity === 0
                          ? "Out"
                          : size.stockQuantity < 3
                            ? "Low"
                            : "Good"}
                      </span>
                    </div>

                    <label className="mt-4 block">
                      <span className="mb-2 block text-sm font-medium text-ink/70">Quantity</span>
                      <input
                        type="number"
                        min="0"
                        value={size.stockQuantity}
                        onChange={(event) =>
                          setShoes((current) =>
                            current.map((item) =>
                              item.id === shoe.id
                                ? {
                                    ...item,
                                    sizes: item.sizes.map((entry) =>
                                      entry.id === size.id
                                        ? {
                                            ...entry,
                                            stockQuantity: Number(event.target.value),
                                            isAvailable: Number(event.target.value) > 0,
                                          }
                                        : entry
                                    ),
                                  }
                                : item
                            )
                          )
                        }
                        className="w-full rounded-2xl border border-pine/10 bg-white px-4 py-3 text-base text-ink"
                      />
                    </label>
                  </div>
                );
              })}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

