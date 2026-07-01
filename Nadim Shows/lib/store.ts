import { createClient as createServerSupabaseClient } from "@/lib/supabase/server";
import { mockBrands, mockCategories, mockShoes } from "@/lib/mock-data";
import type {
  AdminDashboardStats,
  AdminShoePayload,
  Brand,
  Category,
  SaleEntry,
  SalePayload,
  Shoe,
  StockUpdatePayload,
  SupabaseShoeRow,
} from "@/lib/types";

export function isSupabaseConfigured() {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  );
}

function normalizeShoe(row: SupabaseShoeRow): Shoe {
  const brand = Array.isArray(row.brand) ? row.brand[0] : row.brand;
  const category = Array.isArray(row.category) ? row.category[0] : row.category;

  return {
    id: row.id,
    brand: brand ?? { id: "brand-unknown", name: "Unknown", slug: "unknown" },
    category: category ?? {
      id: "category-unknown",
      name: "General",
      slug: "general",
    },
    nameBn: row.name_bn,
    nameEn: row.name_en,
    price: Number(row.price ?? 0),
    imageUrls: row.image_urls?.length ? row.image_urls : mockShoes[0].imageUrls,
    colors: row.colors?.length ? row.colors : ["Classic"],
    materials: row.materials?.length ? row.materials : ["Standard"],
    styleType: row.style_type ?? undefined,
    gender: row.gender ?? undefined,
    stockStatus: row.stock_status ?? "in_stock",
    createdAt: row.created_at ?? new Date().toISOString(),
    sizes:
      row.sizes?.map((size) => ({
        id: size.id,
        size: size.size,
        stockQuantity: Number(size.stock_quantity ?? 0),
        isAvailable: Boolean(size.is_available),
      })) ?? [],
  };
}

function readStringParam(
  searchParams: Record<string, string | string[] | undefined>,
  key: string
) {
  const value = searchParams[key];

  if (Array.isArray(value)) {
    return value[0] ?? "";
  }

  return value ?? "";
}

function sortShoes(shoes: Shoe[], sortValue: string) {
  const items = [...shoes];

  if (sortValue === "price-asc") {
    return items.sort((a, b) => a.price - b.price);
  }

  if (sortValue === "price-desc") {
    return items.sort((a, b) => b.price - a.price);
  }

  return items.sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );
}

function filterShoes(
  shoes: Shoe[],
  searchParams: Record<string, string | string[] | undefined>
) {
  const search = readStringParam(searchParams, "search").toLowerCase();
  const brand = readStringParam(searchParams, "brand").toLowerCase();
  const category = readStringParam(searchParams, "category").toLowerCase();
  const size = readStringParam(searchParams, "size");
  const minPrice = Number(readStringParam(searchParams, "minPrice") || 0);
  const maxPrice = Number(readStringParam(searchParams, "maxPrice") || 0);

  return shoes.filter((shoe) => {
    const matchesSearch =
      !search ||
      shoe.nameEn.toLowerCase().includes(search) ||
      shoe.nameBn.toLowerCase().includes(search) ||
      shoe.colors.some((color) => color.toLowerCase().includes(search));

    const matchesBrand = !brand || shoe.brand.slug.toLowerCase() === brand;
    const matchesCategory = !category || shoe.category.slug.toLowerCase() === category;
    const matchesSize = !size || shoe.sizes.some((item) => item.size === size);
    const matchesMinPrice = !minPrice || shoe.price >= minPrice;
    const matchesMaxPrice = !maxPrice || shoe.price <= maxPrice;

    return (
      matchesSearch &&
      matchesBrand &&
      matchesCategory &&
      matchesSize &&
      matchesMinPrice &&
      matchesMaxPrice
    );
  });
}

export async function getBrands(): Promise<Brand[]> {
  if (!isSupabaseConfigured()) {
    return mockBrands;
  }

  try {
    const supabase = await createServerSupabaseClient();
    const { data, error } = await supabase
      .from("brands")
      .select("id, name, slug")
      .eq("is_active", true)
      .order("name");

    if (error || !data) {
      return mockBrands;
    }

    return data;
  } catch {
    return mockBrands;
  }
}

export async function getCategories(): Promise<Category[]> {
  if (!isSupabaseConfigured()) {
    return mockCategories;
  }

  try {
    const supabase = await createServerSupabaseClient();
    const { data, error } = await supabase
      .from("categories")
      .select("id, name, slug")
      .eq("is_active", true)
      .order("name");

    if (error || !data) {
      return mockCategories;
    }

    return data;
  } catch {
    return mockCategories;
  }
}

export async function getShoes(
  searchParams: Record<string, string | string[] | undefined> = {}
): Promise<Shoe[]> {
  const sortValue = readStringParam(searchParams, "sort");

  if (!isSupabaseConfigured()) {
    return sortShoes(filterShoes(mockShoes, searchParams), sortValue);
  }

  try {
    const supabase = await createServerSupabaseClient();
    const { data, error } = await supabase
      .from("shoes")
      .select(
        `
          id,
          name_bn,
          name_en,
          price,
          image_urls,
          colors,
          materials,
          style_type,
          gender,
          stock_status,
          created_at,
          brand:brands(id, name, slug),
          category:categories(id, name, slug),
          sizes:shoe_sizes(id, size, stock_quantity, is_available)
        `
      )
      .eq("is_active", true)
      .order("created_at", { ascending: false });

    if (error || !data) {
      return sortShoes(filterShoes(mockShoes, searchParams), sortValue);
    }

    const normalized = data.map((row) => normalizeShoe(row as unknown as SupabaseShoeRow));
    return sortShoes(filterShoes(normalized, searchParams), sortValue);
  } catch {
    return sortShoes(filterShoes(mockShoes, searchParams), sortValue);
  }
}

export async function getFeaturedShoes() {
  const shoes = await getShoes();
  return shoes.slice(0, 3);
}

export async function getShoeById(id: string) {
  const shoes = await getShoes();
  return shoes.find((shoe) => shoe.id === id) ?? null;
}

export async function getRelatedShoes(currentShoe: Shoe) {
  const shoes = await getShoes();

  return shoes
    .filter(
      (shoe) =>
        shoe.id !== currentShoe.id &&
        (shoe.category.slug === currentShoe.category.slug ||
          shoe.brand.slug === currentShoe.brand.slug)
    )
    .slice(0, 3);
}

export async function getAdminDashboardStats(): Promise<AdminDashboardStats> {
  const shoes = await getShoes();
  const lowStockItems = shoes.filter((shoe) =>
    shoe.sizes.some((size) => size.isAvailable && size.stockQuantity > 0 && size.stockQuantity < 3)
  );

  return {
    totalShoes: shoes.length,
    todaysSales: 7,
    todaysRevenue: 18630,
    lowStockItems: lowStockItems.slice(0, 5),
    weeklySales: [
      { day: "Sat", total: 3 },
      { day: "Sun", total: 5 },
      { day: "Mon", total: 4 },
      { day: "Tue", total: 6 },
      { day: "Wed", total: 2 },
      { day: "Thu", total: 7 },
      { day: "Fri", total: 4 },
    ],
  };
}

export async function createShoeRecord(payload: AdminShoePayload) {
  if (!isSupabaseConfigured()) {
    return {
      ok: true,
      mode: "mock" as const,
      shoeId: `mock-${payload.nameEn.toLowerCase().replace(/\s+/g, "-")}`,
      message: "Saved in mock mode. Connect Supabase credentials to persist real data.",
    };
  }

  const supabase = await createServerSupabaseClient();

  const [{ data: brandData, error: brandError }, { data: categoryData, error: categoryError }] =
    await Promise.all([
      supabase.from("brands").select("id").eq("slug", payload.brandSlug).maybeSingle(),
      supabase.from("categories").select("id").eq("slug", payload.categorySlug).maybeSingle(),
    ]);

  if (brandError || !brandData?.id) {
    throw new Error("Brand not found. Please check the selected brand.");
  }

  if (categoryError || !categoryData?.id) {
    throw new Error("Category not found. Please check the selected category.");
  }

  const fallbackImage = mockShoes[0]?.imageUrls[0] ?? "";
  const imageUrls = payload.imageUrls.length
    ? payload.imageUrls
    : fallbackImage
      ? [fallbackImage]
      : [];

  const { data: insertedShoe, error: shoeError } = await supabase
    .from("shoes")
    .insert({
      brand_id: brandData.id,
      category_id: categoryData.id,
      name_bn: payload.nameBn,
      name_en: payload.nameEn,
      price: payload.price,
      image_urls: imageUrls,
      colors: payload.colors,
      materials: payload.materials,
      style_type: payload.styleType || null,
      gender: payload.gender || null,
      stock_status: payload.sizes.some((size) => size.stockQuantity > 0)
        ? "in_stock"
        : "out_of_stock",
    })
    .select("id")
    .single();

  if (shoeError || !insertedShoe?.id) {
    throw new Error("Could not save the shoe record.");
  }

  const sizeRows = payload.sizes.map((size) => ({
    shoe_id: insertedShoe.id,
    size: size.size,
    stock_quantity: size.stockQuantity,
    is_available: size.stockQuantity > 0,
  }));

  if (sizeRows.length > 0) {
    const { error: sizeError } = await supabase.from("shoe_sizes").insert(sizeRows);

    if (sizeError) {
      throw new Error("Shoe saved, but size information could not be stored.");
    }
  }

  return {
    ok: true,
    mode: "supabase" as const,
    shoeId: insertedShoe.id,
    message: "Shoe saved successfully.",
  };
}

export async function updateShoeRecord(shoeId: string, payload: AdminShoePayload) {
  if (!isSupabaseConfigured()) {
    return {
      ok: true,
      mode: "mock" as const,
      shoeId,
      message: "Updated in mock mode. Connect Supabase credentials to persist real data.",
    };
  }

  const supabase = await createServerSupabaseClient();

  const [{ data: brandData, error: brandError }, { data: categoryData, error: categoryError }] =
    await Promise.all([
      supabase.from("brands").select("id").eq("slug", payload.brandSlug).maybeSingle(),
      supabase.from("categories").select("id").eq("slug", payload.categorySlug).maybeSingle(),
    ]);

  if (brandError || !brandData?.id) {
    throw new Error("Brand not found. Please check the selected brand.");
  }

  if (categoryError || !categoryData?.id) {
    throw new Error("Category not found. Please check the selected category.");
  }

  const fallbackImage = mockShoes[0]?.imageUrls[0] ?? "";
  const imageUrls = payload.imageUrls.length
    ? payload.imageUrls
    : fallbackImage
      ? [fallbackImage]
      : [];

  const { error: shoeError } = await supabase
    .from("shoes")
    .update({
      brand_id: brandData.id,
      category_id: categoryData.id,
      name_bn: payload.nameBn,
      name_en: payload.nameEn,
      price: payload.price,
      image_urls: imageUrls,
      colors: payload.colors,
      materials: payload.materials,
      style_type: payload.styleType || null,
      gender: payload.gender || null,
      stock_status: payload.sizes.some((size) => size.stockQuantity > 0)
        ? "in_stock"
        : "out_of_stock",
    })
    .eq("id", shoeId);

  if (shoeError) {
    throw new Error("Could not update the shoe record.");
  }

  const { error: deleteSizesError } = await supabase
    .from("shoe_sizes")
    .delete()
    .eq("shoe_id", shoeId);

  if (deleteSizesError) {
    throw new Error("Shoe updated, but previous size rows could not be cleared.");
  }

  const sizeRows = payload.sizes.map((size) => ({
    shoe_id: shoeId,
    size: size.size,
    stock_quantity: size.stockQuantity,
    is_available: size.stockQuantity > 0,
  }));

  if (sizeRows.length > 0) {
    const { error: sizeError } = await supabase.from("shoe_sizes").insert(sizeRows);

    if (sizeError) {
      throw new Error("Shoe updated, but size information could not be stored.");
    }
  }

  return {
    ok: true,
    mode: "supabase" as const,
    shoeId,
    message: "Shoe updated successfully.",
  };
}

export async function getLowStockShoes() {
  const shoes = await getShoes();

  return shoes.filter((shoe) =>
    shoe.sizes.some((size) => size.isAvailable && size.stockQuantity >= 0 && size.stockQuantity < 3)
  );
}

export async function updateStockRecord(payload: StockUpdatePayload) {
  if (!isSupabaseConfigured()) {
    return {
      ok: true,
      mode: "mock" as const,
      shoeId: payload.shoeId,
      sizes: payload.sizes.map((size) => ({
        ...size,
        isAvailable: size.stockQuantity > 0,
      })),
      message: "Stock updated in mock mode.",
    };
  }

  const supabase = await createServerSupabaseClient();

  const updates = payload.sizes.map((size) =>
    supabase
      .from("shoe_sizes")
      .update({
        stock_quantity: size.stockQuantity,
        is_available: size.stockQuantity > 0,
      })
      .eq("id", size.id)
  );

  const results = await Promise.all(updates);
  const failed = results.find((result) => result.error);

  if (failed?.error) {
    throw new Error("Could not update stock quantities.");
  }

  const inStock = payload.sizes.some((size) => size.stockQuantity > 0);
  const { error: shoeError } = await supabase
    .from("shoes")
    .update({
      stock_status: inStock ? "in_stock" : "out_of_stock",
    })
    .eq("id", payload.shoeId);

  if (shoeError) {
    throw new Error("Stock updated, but main shoe status could not be synced.");
  }

  return {
    ok: true,
    mode: "supabase" as const,
    shoeId: payload.shoeId,
    sizes: payload.sizes.map((size) => ({
      ...size,
      isAvailable: size.stockQuantity > 0,
    })),
    message: "Stock updated successfully.",
  };
}

export async function recordSale(payload: SalePayload) {
  const shoes = await getShoes();
  const shoe = shoes.find((item) => item.id === payload.shoeId);

  if (!shoe) {
    throw new Error("Shoe not found.");
  }

  const selectedSize = shoe.sizes.find((size) => size.id === payload.sizeId);

  if (!selectedSize) {
    throw new Error("Selected size not found.");
  }

  if (payload.quantity < 1) {
    throw new Error("Quantity must be at least 1.");
  }

  if (selectedSize.stockQuantity < payload.quantity) {
    throw new Error("Not enough stock for this sale.");
  }

  const amount = payload.quantity * shoe.price;
  const remainingStock = selectedSize.stockQuantity - payload.quantity;

  if (!isSupabaseConfigured()) {
    return {
      ok: true,
      mode: "mock" as const,
      sale: {
        id: `sale-${Date.now()}`,
        shoeId: shoe.id,
        shoeName: shoe.nameEn,
        size: selectedSize.size,
        quantity: payload.quantity,
        amount,
        soldAt: new Date().toISOString(),
      } satisfies SaleEntry,
      updatedSize: {
        id: selectedSize.id,
        size: selectedSize.size,
        stockQuantity: remainingStock,
        isAvailable: remainingStock > 0,
      },
      message: "Sale saved in mock mode.",
    };
  }

  const supabase = await createServerSupabaseClient();

  const { error: sizeUpdateError } = await supabase
    .from("shoe_sizes")
    .update({
      stock_quantity: remainingStock,
      is_available: remainingStock > 0,
    })
    .eq("id", selectedSize.id);

  if (sizeUpdateError) {
    throw new Error("Could not update stock for the sale.");
  }

  const { data: saleRecord, error: saleError } = await supabase
    .from("sales")
    .insert({
      shoe_id: shoe.id,
      shoe_size_id: selectedSize.id,
      quantity: payload.quantity,
      unit_price: shoe.price,
      total_price: amount,
    })
    .select("id, sold_at")
    .single();

  if (saleError || !saleRecord?.id) {
    throw new Error("Stock updated, but sale record could not be stored.");
  }

  const refreshedSizes = shoe.sizes.map((size) =>
    size.id === selectedSize.id
      ? {
          ...size,
          stockQuantity: remainingStock,
          isAvailable: remainingStock > 0,
        }
      : size
  );
  const inStock = refreshedSizes.some((size) => size.stockQuantity > 0);

  const { error: shoeError } = await supabase
    .from("shoes")
    .update({
      stock_status: inStock ? "in_stock" : "out_of_stock",
    })
    .eq("id", shoe.id);

  if (shoeError) {
    throw new Error("Sale saved, but shoe stock status could not be updated.");
  }

  return {
    ok: true,
    mode: "supabase" as const,
    sale: {
      id: saleRecord.id,
      shoeId: shoe.id,
      shoeName: shoe.nameEn,
      size: selectedSize.size,
      quantity: payload.quantity,
      amount,
      soldAt: saleRecord.sold_at as string,
    } satisfies SaleEntry,
    updatedSize: {
      id: selectedSize.id,
      size: selectedSize.size,
      stockQuantity: remainingStock,
      isAvailable: remainingStock > 0,
    },
    message: "Sale recorded successfully.",
  };
}
