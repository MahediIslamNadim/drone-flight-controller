"use client";

import Image from "next/image";
import { useMemo, useState } from "react";
import { LoaderCircle, Search } from "lucide-react";
import type { SaleEntry, Shoe } from "@/lib/types";

type AdminSalesEntryProps = {
  initialShoes: Shoe[];
  initialSales: SaleEntry[];
};

export function AdminSalesEntry({
  initialShoes,
  initialSales,
}: AdminSalesEntryProps) {
  const [shoes, setShoes] = useState(initialShoes);
  const [sales, setSales] = useState(initialSales);
  const [search, setSearch] = useState("");
  const [selectedShoeId, setSelectedShoeId] = useState(initialShoes[0]?.id ?? "");
  const [selectedSizeId, setSelectedSizeId] = useState(initialShoes[0]?.sizes[0]?.id ?? "");
  const [quantity, setQuantity] = useState(1);
  const [isSaving, setIsSaving] = useState(false);
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
        shoe.nameBn.toLowerCase().includes(query)
    );
  }, [search, shoes]);

  const selectedShoe =
    filteredShoes.find((shoe) => shoe.id === selectedShoeId) ??
    shoes.find((shoe) => shoe.id === selectedShoeId) ??
    filteredShoes[0] ??
    shoes[0];

  const sizeOptions = selectedShoe?.sizes.filter((size) => size.stockQuantity > 0) ?? [];
  const selectedSize =
    sizeOptions.find((size) => size.id === selectedSizeId) ?? sizeOptions[0] ?? null;

  async function submitSale() {
    if (!selectedShoe || !selectedSize) {
      setError("Available shoe and size select korun.");
      return;
    }

    setIsSaving(true);
    setMessage("");
    setError("");

    try {
      const response = await fetch("/api/admin/sales/add", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          shoeId: selectedShoe.id,
          sizeId: selectedSize.id,
          quantity,
        }),
      });

      const result = (await response.json()) as {
        message?: string;
        error?: string;
        sale?: SaleEntry;
        updatedSize?: {
          id: string;
          size: string;
          stockQuantity: number;
          isAvailable: boolean;
        };
      };

      if (!response.ok || !result.sale || !result.updatedSize) {
        setError(result.error ?? "Sale save failed.");
        return;
      }

      setSales((current) => [result.sale as SaleEntry, ...current].slice(0, 8));
      setShoes((current) =>
        current.map((shoe) =>
          shoe.id === selectedShoe.id
            ? {
                ...shoe,
                sizes: shoe.sizes.map((size) =>
                  size.id === result.updatedSize?.id
                    ? {
                        ...size,
                        stockQuantity: result.updatedSize.stockQuantity,
                        isAvailable: result.updatedSize.isAvailable,
                      }
                    : size
                ),
              }
            : shoe
        )
      );
      setMessage(result.message ?? "Sale recorded.");
      setQuantity(1);
    } catch {
      setError("Network error while saving sale.");
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <div className="space-y-6">
      <div className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
        <label className="flex items-center gap-3 rounded-2xl border border-pine/10 bg-mist px-4 py-4">
          <Search className="h-5 w-5 text-pine" />
          <input
            type="search"
            value={search}
            onChange={(event) => {
              setSearch(event.target.value);
              const query = event.target.value.trim().toLowerCase();
              const nextMatch = shoes.find(
                (shoe) =>
                  shoe.nameEn.toLowerCase().includes(query) ||
                  shoe.nameBn.toLowerCase().includes(query)
              );
              if (nextMatch) {
                setSelectedShoeId(nextMatch.id);
                setSelectedSizeId(nextMatch.sizes.find((size) => size.stockQuantity > 0)?.id ?? "");
              }
            }}
            placeholder="Shoe name diye khujun"
            className="w-full bg-transparent text-base text-ink outline-none placeholder:text-ink/40"
          />
        </label>
      </div>

      {selectedShoe ? (
        <div className="grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
          <div className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
            <div className="flex gap-4">
              <Image
                src={selectedShoe.imageUrls[0]}
                alt={selectedShoe.nameEn}
                width={96}
                height={96}
                className="rounded-[1.5rem] object-cover"
              />
              <div>
                <p className="font-[family-name:var(--font-heading)] text-3xl font-bold text-ink">
                  {selectedShoe.nameEn}
                </p>
                <p className="text-sm text-ink/65">{selectedShoe.nameBn}</p>
                <p className="mt-2 text-sm font-semibold text-pine">
                  Tk {Math.round(selectedShoe.price).toLocaleString("en-US")}
                </p>
              </div>
            </div>

            <div className="mt-5 grid gap-4 sm:grid-cols-2">
              <label className="block">
                <span className="mb-2 block text-sm font-medium text-ink/75">Select shoe</span>
                <select
                  value={selectedShoe.id}
                  onChange={(event) => {
                    const nextShoe = shoes.find((shoe) => shoe.id === event.target.value);
                    setSelectedShoeId(event.target.value);
                    setSelectedSizeId(
                      nextShoe?.sizes.find((size) => size.stockQuantity > 0)?.id ?? ""
                    );
                  }}
                  className="w-full rounded-2xl border border-pine/10 bg-mist px-4 py-3 text-base text-ink"
                >
                  {filteredShoes.map((shoe) => (
                    <option key={shoe.id} value={shoe.id}>
                      {shoe.nameEn}
                    </option>
                  ))}
                </select>
              </label>

              <label className="block">
                <span className="mb-2 block text-sm font-medium text-ink/75">Select size</span>
                <select
                  value={selectedSize?.id ?? ""}
                  onChange={(event) => setSelectedSizeId(event.target.value)}
                  className="w-full rounded-2xl border border-pine/10 bg-mist px-4 py-3 text-base text-ink"
                >
                  {sizeOptions.map((size) => (
                    <option key={size.id} value={size.id}>
                      {size.size} ({size.stockQuantity} left)
                    </option>
                  ))}
                </select>
              </label>
            </div>

            <label className="mt-4 block">
              <span className="mb-2 block text-sm font-medium text-ink/75">Quantity sold</span>
              <input
                type="number"
                min="1"
                max={selectedSize?.stockQuantity ?? 1}
                value={quantity}
                onChange={(event) => setQuantity(Number(event.target.value))}
                className="w-full rounded-2xl border border-pine/10 bg-mist px-4 py-3 text-base text-ink"
              />
            </label>

            {error ? (
              <p className="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
                {error}
              </p>
            ) : null}

            {message ? (
              <p className="mt-4 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
                {message}
              </p>
            ) : null}

            <button
              type="button"
              onClick={() => void submitSale()}
              disabled={isSaving || !selectedSize}
              className="mt-5 inline-flex w-full items-center justify-center gap-2 rounded-full bg-pine px-6 py-4 text-base font-semibold text-white transition hover:bg-pine/90 disabled:cursor-not-allowed disabled:opacity-70"
            >
              {isSaving ? <LoaderCircle className="h-5 w-5 animate-spin" /> : null}
              Save sale
            </button>
          </div>

          <div className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
            <p className="text-sm uppercase tracking-[0.22em] text-ember">Today&apos;s sales</p>
            <h2 className="mt-2 font-[family-name:var(--font-heading)] text-3xl font-bold text-ink">
              Quick summary
            </h2>
            <div className="mt-5 space-y-3">
              {sales.map((sale) => (
                <div key={sale.id} className="rounded-[1.5rem] bg-mist px-4 py-4">
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <p className="font-semibold text-ink">{sale.shoeName}</p>
                      <p className="text-sm text-ink/60">
                        Size {sale.size} • Qty {sale.quantity}
                      </p>
                    </div>
                    <p className="font-semibold text-pine">
                      Tk {Math.round(sale.amount).toLocaleString("en-US")}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : (
        <div className="rounded-[2rem] border border-dashed border-pine/20 bg-white/70 px-6 py-12 text-center">
          <p className="font-semibold text-ink">Kon shoe paowa jai ni.</p>
        </div>
      )}
    </div>
  );
}

