import "server-only";

import { cookies } from "next/headers";

export const ADMIN_SESSION_COOKIE = "air_dokan_admin";
const DEFAULT_ADMIN_PASSWORD = "air-dokan-admin";

export function getAdminPassword() {
  return process.env.ADMIN_PASSWORD || DEFAULT_ADMIN_PASSWORD;
}

export function isUsingDefaultAdminPassword() {
  return !process.env.ADMIN_PASSWORD;
}

export function shouldUseSecureCookies(requestUrl?: string) {
  if (requestUrl) {
    try {
      const url = new URL(requestUrl);
      const isLocalHost =
        url.hostname === "localhost" ||
        url.hostname === "127.0.0.1" ||
        url.hostname === "::1";

      if (isLocalHost) {
        return false;
      }

      return url.protocol === "https:";
    } catch {
      return process.env.NODE_ENV === "production";
    }
  }

  const appUrl = process.env.NEXT_PUBLIC_APP_URL;

  if (appUrl) {
    try {
      return new URL(appUrl).protocol === "https:";
    } catch {
      return process.env.NODE_ENV === "production";
    }
  }

  return false;
}

export async function isAdminAuthenticated() {
  const cookieStore = await cookies();
  return cookieStore.get(ADMIN_SESSION_COOKIE)?.value === "authenticated";
}
