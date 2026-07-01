export type Brand = {
  id: string;
  name: string;
  slug: string;
};

export type Category = {
  id: string;
  name: string;
  slug: string;
};

export type ShoeSize = {
  id: string;
  size: string;
  stockQuantity: number;
  isAvailable: boolean;
};

export type Shoe = {
  id: string;
  brand: Brand;
  category: Category;
  nameBn: string;
  nameEn: string;
  price: number;
  imageUrls: string[];
  colors: string[];
  materials: string[];
  styleType?: string;
  gender?: string;
  stockStatus: string;
  createdAt: string;
  sizes: ShoeSize[];
};

export type AdminDashboardStats = {
  totalShoes: number;
  todaysSales: number;
  todaysRevenue: number;
  lowStockItems: Shoe[];
  weeklySales: {
    day: string;
    total: number;
  }[];
};

export type AdminShoePayload = {
  brandSlug: string;
  categorySlug: string;
  nameBn: string;
  nameEn: string;
  price: number;
  colors: string[];
  materials: string[];
  styleType: string;
  gender: string;
  imageUrls: string[];
  sizes: Array<{
    size: string;
    stockQuantity: number;
  }>;
};

export type StockUpdatePayload = {
  shoeId: string;
  sizes: Array<{
    id: string;
    size: string;
    stockQuantity: number;
  }>;
};

export type SaleEntry = {
  id: string;
  shoeId: string;
  shoeName: string;
  size: string;
  quantity: number;
  amount: number;
  soldAt: string;
};

export type SalePayload = {
  shoeId: string;
  sizeId: string;
  quantity: number;
};

export type SupabaseShoeRow = {
  id: string;
  brand: Brand | Brand[] | null;
  category: Category | Category[] | null;
  name_bn: string;
  name_en: string;
  price: number;
  image_urls: string[] | null;
  colors: string[] | null;
  materials: string[] | null;
  style_type: string | null;
  gender: string | null;
  stock_status: string | null;
  created_at: string | null;
  sizes:
    | {
        id: string;
        size: string;
        stock_quantity: number;
        is_available: boolean;
      }[]
    | null;
};
