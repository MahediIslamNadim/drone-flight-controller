import { NextResponse } from "next/server";
import { createShoeRecord } from "@/lib/store";
import { isAdminAuthenticated } from "@/lib/admin-auth";
import type { AdminShoePayload } from "@/lib/types";

function validatePayload(payload: Partial<AdminShoePayload>) {
  return Boolean(
    payload.brandSlug &&
      payload.categorySlug &&
      payload.nameBn &&
      payload.nameEn &&
      typeof payload.price === "number" &&
      payload.price > 0 &&
      Array.isArray(payload.colors) &&
      payload.colors.length > 0 &&
      Array.isArray(payload.materials) &&
      payload.materials.length > 0 &&
      Array.isArray(payload.imageUrls) &&
      Array.isArray(payload.sizes)
  );
}

export async function POST(request: Request) {
  if (!(await isAdminAuthenticated())) {
    return NextResponse.json({ error: "Unauthorized." }, { status: 401 });
  }

  const payload = (await request.json()) as Partial<AdminShoePayload>;

  if (!validatePayload(payload)) {
    return NextResponse.json(
      { error: "Please fill all required shoe fields before saving." },
      { status: 400 }
    );
  }

  try {
    const result = await createShoeRecord(payload as AdminShoePayload);
    return NextResponse.json(result);
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unexpected error while saving shoe.";

    return NextResponse.json({ error: message }, { status: 500 });
  }
}
