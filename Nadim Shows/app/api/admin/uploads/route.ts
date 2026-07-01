import { NextResponse } from "next/server";
import { isAdminAuthenticated } from "@/lib/admin-auth";
import { mockShoes } from "@/lib/mock-data";
import { createAdminClient } from "@/lib/supabase/admin";

export const runtime = "nodejs";

const bucketName = process.env.SUPABASE_SHOE_IMAGES_BUCKET ?? "shoe-images";

function sanitizeFileName(fileName: string) {
  return fileName
    .toLowerCase()
    .replace(/[^a-z0-9.-]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

function isSupabaseConfigured() {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
      (process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY)
  );
}

export async function POST(request: Request) {
  if (!(await isAdminAuthenticated())) {
    return NextResponse.json({ error: "Unauthorized." }, { status: 401 });
  }

  const formData = await request.formData();
  const files = formData
    .getAll("files")
    .filter((entry): entry is File => entry instanceof File && entry.size > 0)
    .slice(0, 3);

  if (files.length === 0) {
    return NextResponse.json({ error: "No image files received." }, { status: 400 });
  }

  if (!isSupabaseConfigured()) {
    return NextResponse.json({
      mode: "mock",
      urls: files.map((_, index) => mockShoes[index % mockShoes.length]?.imageUrls[0]).filter(Boolean),
    });
  }

  try {
    const supabase = createAdminClient();
    const uploadedUrls: string[] = [];

    for (const file of files) {
      const arrayBuffer = await file.arrayBuffer();
      const filePath = `uploads/${Date.now()}-${crypto.randomUUID()}-${sanitizeFileName(file.name)}`;

      const { error: uploadError } = await supabase.storage
        .from(bucketName)
        .upload(filePath, Buffer.from(arrayBuffer), {
          contentType: file.type || "application/octet-stream",
          upsert: false,
        });

      if (uploadError) {
        throw new Error(uploadError.message);
      }

      const { data: publicData } = supabase.storage.from(bucketName).getPublicUrl(filePath);

      if (!publicData.publicUrl) {
        throw new Error("Could not resolve a public URL for the uploaded image.");
      }

      uploadedUrls.push(publicData.publicUrl);
    }

    return NextResponse.json({
      mode: "supabase",
      urls: uploadedUrls,
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unexpected error while uploading images.";

    return NextResponse.json({ error: message }, { status: 500 });
  }
}
