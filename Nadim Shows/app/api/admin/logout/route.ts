import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { ADMIN_SESSION_COOKIE } from "@/lib/admin-auth";

export async function POST() {
  const cookieStore = await cookies();
  cookieStore.delete(ADMIN_SESSION_COOKIE);

  return NextResponse.redirect(new URL("/admin", process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000"));
}

