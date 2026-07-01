import { redirect } from "next/navigation";
import { AdminShell } from "@/components/admin-shell";
import { isAdminAuthenticated } from "@/lib/admin-auth";

export default async function AdminProtectedLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  if (!(await isAdminAuthenticated())) {
    redirect("/admin");
  }

  return <AdminShell>{children}</AdminShell>;
}

