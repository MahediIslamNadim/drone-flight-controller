import { redirect } from "next/navigation";
import { ShieldCheck } from "lucide-react";
import { AdminLoginForm } from "@/components/admin-login-form";
import { isAdminAuthenticated, isUsingDefaultAdminPassword } from "@/lib/admin-auth";

export default async function AdminLoginPage() {
  if (await isAdminAuthenticated()) {
    redirect("/admin/dashboard");
  }

  const showDefaultPasswordHint = isUsingDefaultAdminPassword();

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-6xl items-center px-4 py-8 sm:px-6 lg:px-8">
      <div className="grid w-full gap-8 lg:grid-cols-[1.05fr_0.95fr]">
        <section className="rounded-[2.5rem] bg-gradient-to-br from-pine to-ocean p-8 text-white shadow-glow">
          <div className="inline-flex h-14 w-14 items-center justify-center rounded-2xl bg-white/12">
            <ShieldCheck className="h-7 w-7" />
          </div>
          <p className="mt-8 text-sm uppercase tracking-[0.25em] text-white/70">Admin access</p>
          <h1 className="mt-3 font-[family-name:var(--font-heading)] text-4xl font-bold">
            Simple login for daily shop updates
          </h1>
          <p className="mt-4 max-w-xl text-base leading-7 text-white/80">
            Password diye login korlei dashboard, stock, ar notun juta add flow use
            kora jabe. Eta intentionally simple rakha hoyeche.
          </p>
          <div className="mt-8 rounded-[1.75rem] border border-white/15 bg-white/10 p-5 text-sm leading-7 text-white/85">
            <p>Bangla shortcut labels ready:</p>
            <p className="mt-2">নতুন জুতা • স্টক • বিক্রি</p>
          </div>
        </section>

        <section className="surface rounded-[2.5rem] border border-white/70 p-6 shadow-sm sm:p-8">
          <p className="text-sm uppercase tracking-[0.24em] text-ember">Login</p>
          <h2 className="mt-3 font-[family-name:var(--font-heading)] text-3xl font-bold text-ink">
            /admin
          </h2>
          <p className="mt-3 text-sm leading-7 text-ink/70">
            Ekhan theke Abbu easily inventory maintain korte parben.
          </p>

          {showDefaultPasswordHint ? (
            <div className="mt-5 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
              Demo password active: <span className="font-semibold">air-dokan-admin</span>
            </div>
          ) : null}

          <div className="mt-6">
            <AdminLoginForm />
          </div>
        </section>
      </div>
    </div>
  );
}

