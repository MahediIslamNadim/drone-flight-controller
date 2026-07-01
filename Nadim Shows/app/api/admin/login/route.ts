import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import {
  ADMIN_SESSION_COOKIE,
  getAdminPassword,
  shouldUseSecureCookies,
} from "@/lib/admin-auth";

export async function POST(request: Request) {
  const body = (await request.json()) as {
    password?: string;
  };

  if (!body.password || body.password !== getAdminPassword()) {
    return NextResponse.json({ error: "Incorrect password." }, { status: 401 });
  }

  const cookieStore = await cookies();
  cookieStore.set(ADMIN_SESSION_COOKIE, "authenticated", {
    httpOnly: true,
    sameSite: "lax",
    secure: shouldUseSecureCookies(request.url),
    path: "/",
    maxAge: 60 * 60 * 12,
  });

  return NextResponse.json({ ok: true });
}
