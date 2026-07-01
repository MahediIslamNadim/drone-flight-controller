import { NextResponse } from "next/server";
import { isAdminAuthenticated } from "@/lib/admin-auth";
import { createAdminClient } from "@/lib/supabase/admin";

const bucketName = process.env.SUPABASE_SHOE_IMAGES_BUCKET ?? "shoe-images";

export async function GET() {
  if (!(await isAdminAuthenticated())) {
    return NextResponse.json({ error: "Unauthorized." }, { status: 401 });
  }

  const hasSupabaseUrl = Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL);
  const hasAnonKey = Boolean(process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);

  if (!hasSupabaseUrl || !hasAnonKey) {
    return NextResponse.json({
      mode: "mock",
      checks: [
        {
          label: "Supabase connection",
          ok: false,
          detail: "Missing Supabase URL or anon key, so live verification cannot run.",
        },
      ],
    });
  }

  try {
    const supabase = createAdminClient();

    const [{ count: brandCount, error: brandError }, { count: categoryCount, error: categoryError }] =
      await Promise.all([
        supabase.from("brands").select("id", { count: "exact", head: true }),
        supabase.from("categories").select("id", { count: "exact", head: true }),
      ]);

    const { count: shoeCount, error: shoeError } = await supabase
      .from("shoes")
      .select("id", { count: "exact", head: true });

    const { data: storageItems, error: storageError } = await supabase.storage
      .from(bucketName)
      .list("", { limit: 1 });

    return NextResponse.json({
      mode: "supabase",
      checks: [
        {
          label: "Brands table",
          ok: !brandError,
          detail: brandError
            ? brandError.message
            : `Reachable. Current rows: ${brandCount ?? 0}.`,
        },
        {
          label: "Categories table",
          ok: !categoryError,
          detail: categoryError
            ? categoryError.message
            : `Reachable. Current rows: ${categoryCount ?? 0}.`,
        },
        {
          label: "Shoes table",
          ok: !shoeError,
          detail: shoeError
            ? shoeError.message
            : `Reachable. Current rows: ${shoeCount ?? 0}.`,
        },
        {
          label: "Storage bucket",
          ok: !storageError,
          detail: storageError
            ? storageError.message
            : `Bucket "${bucketName}" reachable. Sample objects found: ${storageItems?.length ?? 0}.`,
        },
      ],
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unexpected error while running live checks.";

    return NextResponse.json(
      {
        mode: "supabase",
        checks: [
          {
            label: "Live verification",
            ok: false,
            detail: message,
          },
        ],
      },
      { status: 500 }
    );
  }
}

