import { NextResponse } from "next/server";
import { isAdminAuthenticated } from "@/lib/admin-auth";
import { updateStockRecord } from "@/lib/store";
import type { StockUpdatePayload } from "@/lib/types";

function validatePayload(payload: Partial<StockUpdatePayload>) {
  return Boolean(
    payload.shoeId &&
      Array.isArray(payload.sizes) &&
      payload.sizes.every(
        (size) =>
          typeof size.id === "string" &&
          typeof size.size === "string" &&
          typeof size.stockQuantity === "number" &&
          size.stockQuantity >= 0
      )
  );
}

export async function POST(request: Request) {
  if (!(await isAdminAuthenticated())) {
    return NextResponse.json({ error: "Unauthorized." }, { status: 401 });
  }

  const payload = (await request.json()) as Partial<StockUpdatePayload>;

  if (!validatePayload(payload)) {
    return NextResponse.json({ error: "Invalid stock payload." }, { status: 400 });
  }

  try {
    const result = await updateStockRecord(payload as StockUpdatePayload);
    return NextResponse.json(result);
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "Unexpected error while updating stock.";

    return NextResponse.json({ error: message }, { status: 500 });
  }
}
