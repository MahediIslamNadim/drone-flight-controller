import "server-only";

import { isUsingDefaultAdminPassword } from "@/lib/admin-auth";

const defaultBucketName = process.env.SUPABASE_SHOE_IMAGES_BUCKET ?? "shoe-images";

export type AdminDiagnostics = {
  mode: "mock" | "supabase";
  bucketName: string;
  checks: Array<{
    label: string;
    ok: boolean;
    detail: string;
  }>;
};

export function getAdminDiagnostics(): AdminDiagnostics {
  const hasSupabaseUrl = Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL);
  const hasAnonKey = Boolean(process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
  const hasServiceRole = Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY);
  const hasAdminPassword = Boolean(process.env.ADMIN_PASSWORD);
  const hasStoreAddress = Boolean(process.env.NEXT_PUBLIC_STORE_ADDRESS);
  const hasStorePhone = Boolean(process.env.NEXT_PUBLIC_STORE_PHONE);
  const hasStoreHours = Boolean(process.env.NEXT_PUBLIC_STORE_HOURS);

  const mode = hasSupabaseUrl && hasAnonKey ? "supabase" : "mock";

  return {
    mode,
    bucketName: defaultBucketName,
    checks: [
      {
        label: "Supabase URL",
        ok: hasSupabaseUrl,
        detail: hasSupabaseUrl
          ? "NEXT_PUBLIC_SUPABASE_URL is configured."
          : "Missing NEXT_PUBLIC_SUPABASE_URL.",
      },
      {
        label: "Supabase anon key",
        ok: hasAnonKey,
        detail: hasAnonKey
          ? "NEXT_PUBLIC_SUPABASE_ANON_KEY is configured."
          : "Missing NEXT_PUBLIC_SUPABASE_ANON_KEY.",
      },
      {
        label: "Service role key",
        ok: hasServiceRole,
        detail: hasServiceRole
          ? "SUPABASE_SERVICE_ROLE_KEY is configured for admin uploads."
          : "Missing SUPABASE_SERVICE_ROLE_KEY. Uploads may fall back or fail.",
      },
      {
        label: "Admin password",
        ok: hasAdminPassword,
        detail: isUsingDefaultAdminPassword()
          ? "Using the default admin password. Set ADMIN_PASSWORD before launch."
          : "Custom ADMIN_PASSWORD is configured.",
      },
      {
        label: "Storage bucket",
        ok: true,
        detail: `Uploads expect the public bucket named "${defaultBucketName}".`,
      },
      {
        label: "Store address",
        ok: hasStoreAddress,
        detail: hasStoreAddress
          ? "NEXT_PUBLIC_STORE_ADDRESS is configured."
          : "Using fallback store address.",
      },
      {
        label: "Store phone",
        ok: hasStorePhone,
        detail: hasStorePhone
          ? "NEXT_PUBLIC_STORE_PHONE is configured."
          : "Using fallback store phone.",
      },
      {
        label: "Store hours",
        ok: hasStoreHours,
        detail: hasStoreHours
          ? "NEXT_PUBLIC_STORE_HOURS is configured."
          : "Using fallback store hours.",
      },
    ],
  };
}

