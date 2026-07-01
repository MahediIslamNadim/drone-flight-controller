import { NextResponse } from "next/server";
import { isAdminAuthenticated } from "@/lib/admin-auth";
import { recordSale } from "@/lib/store";
import type { SalePayload } from "@/lib/types";

function validatePayload(payload: Partial<SalePayload>) {
  return Boolean(
    typeof payload.shoeId === "string" &&
      typeof payload.sizeId === "string" &&
      typeof payload.quantity === "number" &&
      payload.quantity > 0
  );
}

export async function POST(request: Request) {
  if (!(await isAdminAuthenticated())) {
    return NextResponse.json({ error: "Unauthorized." }, { status: 401 });
  }

  const payload = (await request.json()) as Partial<SalePayload>;

  if (!validatePayload(payload)) {
    return NextResponse.json({ error: "Invalid sale payload." }, { status: 400 });
  }

  try {
    const result = await recordSale(payload as SalePayload);
    return NextResponse.json(result);
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unexpected error while saving sale.";

    return NextResponse.json({ error: message }, { status: 500 });
  }
}
