import { NextResponse } from "next/server";
import { isAdminAuthenticated } from "@/lib/admin-auth";
import { updateShoeRecord } from "@/lib/store";
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

type RouteProps = {
  params: Promise<{
    id: string;
  }>;
};

export async function PUT(request: Request, { params }: RouteProps) {
  if (!(await isAdminAuthenticated())) {
    return NextResponse.json({ error: "Unauthorized." }, { status: 401 });
  }

  const { id } = await params;
  const payload = (await request.json()) as Partial<AdminShoePayload>;

  if (!validatePayload(payload)) {
    return NextResponse.json(
      { error: "Please fill all required shoe fields before updating." },
      { status: 400 }
    );
  }

  try {
    const result = await updateShoeRecord(id, payload as AdminShoePayload);
    return NextResponse.json(result);
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unexpected error while updating shoe.";

    return NextResponse.json({ error: message }, { status: 500 });
  }
}
