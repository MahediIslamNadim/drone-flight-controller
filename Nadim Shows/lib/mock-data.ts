import type { Brand, Category, Shoe } from "@/lib/types";

export const mockBrands: Brand[] = [
  { id: "brand-bata", name: "Bata", slug: "bata" },
  { id: "brand-apex", name: "Apex", slug: "apex" },
  { id: "brand-power", name: "Power", slug: "power" },
  { id: "brand-nike", name: "Nike", slug: "nike" },
];

export const mockCategories: Category[] = [
  { id: "cat-formal", name: "Formal", slug: "formal" },
  { id: "cat-casual", name: "Casual", slug: "casual" },
  { id: "cat-sports", name: "Sports", slug: "sports" },
  { id: "cat-sandal", name: "Sandal", slug: "sandal" },
];

export const mockShoes: Shoe[] = [
  {
    id: "shoe-bata-premium-oxford",
    brand: mockBrands[0],
    category: mockCategories[0],
    nameBn: "বাটা প্রিমিয়াম অক্সফোর্ড",
    nameEn: "Bata Premium Oxford",
    price: 3290,
    imageUrls: [
      "https://images.unsplash.com/photo-1614252369475-531eba835eb1?auto=format&fit=crop&w=1200&q=80",
      "https://images.unsplash.com/photo-1614252235316-8c857d38b5f4?auto=format&fit=crop&w=1200&q=80",
      "https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=1200&q=80",
    ],
    colors: ["Black", "Brown"],
    materials: ["Leather", "Rubber Sole"],
    styleType: "Formal",
    gender: "Men",
    stockStatus: "in_stock",
    createdAt: "2026-05-21T09:00:00.000Z",
    sizes: [
      { id: "size-1", size: "39", stockQuantity: 2, isAvailable: true },
      { id: "size-2", size: "40", stockQuantity: 4, isAvailable: true },
      { id: "size-3", size: "41", stockQuantity: 3, isAvailable: true },
      { id: "size-4", size: "42", stockQuantity: 0, isAvailable: false },
    ],
  },
  {
    id: "shoe-apex-city-loafer",
    brand: mockBrands[1],
    category: mockCategories[1],
    nameBn: "এপেক্স সিটি লোফার",
    nameEn: "Apex City Loafer",
    price: 2490,
    imageUrls: [
      "https://images.unsplash.com/photo-1600185365926-3a2ce3cdb9eb?auto=format&fit=crop&w=1200&q=80",
      "https://images.unsplash.com/photo-1600185365483-26d7a4cc7519?auto=format&fit=crop&w=1200&q=80",
      "https://images.unsplash.com/photo-1514989940723-e8e51635b782?auto=format&fit=crop&w=1200&q=80",
    ],
    colors: ["Tan", "Cream"],
    materials: ["Synthetic Leather"],
    styleType: "Casual",
    gender: "Men",
    stockStatus: "in_stock",
    createdAt: "2026-05-19T09:00:00.000Z",
    sizes: [
      { id: "size-5", size: "40", stockQuantity: 6, isAvailable: true },
      { id: "size-6", size: "41", stockQuantity: 3, isAvailable: true },
      { id: "size-7", size: "42", stockQuantity: 2, isAvailable: true },
      { id: "size-8", size: "43", stockQuantity: 1, isAvailable: true },
    ],
  },
  {
    id: "shoe-power-run-x",
    brand: mockBrands[2],
    category: mockCategories[2],
    nameBn: "পাওয়ার রান এক্স",
    nameEn: "Power Run X",
    price: 4190,
    imageUrls: [
      "https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=1200&q=80",
      "https://images.unsplash.com/photo-1600185365483-26d7a4cc7519?auto=format&fit=crop&w=1200&q=80",
      "https://images.unsplash.com/photo-1460353581641-37baddab0fa2?auto=format&fit=crop&w=1200&q=80",
    ],
    colors: ["Red", "White", "Black"],
    materials: ["Mesh", "Foam", "Rubber"],
    styleType: "Running",
    gender: "Unisex",
    stockStatus: "in_stock",
    createdAt: "2026-05-20T09:00:00.000Z",
    sizes: [
      { id: "size-9", size: "38", stockQuantity: 5, isAvailable: true },
      { id: "size-10", size: "39", stockQuantity: 4, isAvailable: true },
      { id: "size-11", size: "40", stockQuantity: 2, isAvailable: true },
      { id: "size-12", size: "41", stockQuantity: 0, isAvailable: false },
    ],
  },
  {
    id: "shoe-nike-breeze-slide",
    brand: mockBrands[3],
    category: mockCategories[3],
    nameBn: "নাইক ব্রিজ স্লাইড",
    nameEn: "Nike Breeze Slide",
    price: 1990,
    imageUrls: [
      "https://images.unsplash.com/photo-1605733160314-4fc7dac4bb16?auto=format&fit=crop&w=1200&q=80",
      "https://images.unsplash.com/photo-1600269452121-4f2416e55c28?auto=format&fit=crop&w=1200&q=80",
      "https://images.unsplash.com/photo-1525966222134-fcfa99b8ae77?auto=format&fit=crop&w=1200&q=80",
    ],
    colors: ["Slate", "White"],
    materials: ["EVA", "Rubber"],
    styleType: "Slide",
    gender: "Unisex",
    stockStatus: "in_stock",
    createdAt: "2026-05-18T09:00:00.000Z",
    sizes: [
      { id: "size-13", size: "38", stockQuantity: 2, isAvailable: true },
      { id: "size-14", size: "39", stockQuantity: 2, isAvailable: true },
      { id: "size-15", size: "40", stockQuantity: 3, isAvailable: true },
      { id: "size-16", size: "41", stockQuantity: 3, isAvailable: true },
    ],
  },
];

