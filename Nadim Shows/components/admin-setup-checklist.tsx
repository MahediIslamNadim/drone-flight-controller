import { AlertTriangle, CheckCircle2, Database, KeyRound } from "lucide-react";
import type { AdminDiagnostics } from "@/lib/admin-diagnostics";

export function AdminSetupChecklist({
  diagnostics,
}: {
  diagnostics: AdminDiagnostics;
}) {
  const readyCount = diagnostics.checks.filter((check) => check.ok).length;

  return (
    <section className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-sm uppercase tracking-[0.22em] text-ember">Setup Status</p>
          <h2 className="mt-2 font-[family-name:var(--font-heading)] text-3xl font-bold text-ink">
            Admin diagnostics
          </h2>
          <p className="mt-2 text-sm leading-7 text-ink/68">
            Real upload, save, ar launch readiness quickly check korar jonne.
          </p>
        </div>
        <div className="rounded-[1.5rem] bg-mist px-4 py-3 text-right">
          <p className="text-xs uppercase tracking-[0.2em] text-ink/45">Mode</p>
          <p className="mt-1 font-semibold text-pine">{diagnostics.mode}</p>
        </div>
      </div>

      <div className="mt-5 grid gap-4 md:grid-cols-2">
        <div className="rounded-[1.75rem] bg-mist px-4 py-4">
          <div className="flex items-center gap-2">
            <Database className="h-5 w-5 text-pine" />
            <p className="font-semibold text-ink">Bucket</p>
          </div>
          <p className="mt-2 text-sm text-ink/70">{diagnostics.bucketName}</p>
        </div>
        <div className="rounded-[1.75rem] bg-mist px-4 py-4">
          <div className="flex items-center gap-2">
            <KeyRound className="h-5 w-5 text-pine" />
            <p className="font-semibold text-ink">Checks passed</p>
          </div>
          <p className="mt-2 text-sm text-ink/70">
            {readyCount} / {diagnostics.checks.length}
          </p>
        </div>
      </div>

      <div className="mt-5 grid gap-3">
        {diagnostics.checks.map((check) => (
          <div
            key={check.label}
            className={`rounded-[1.5rem] border px-4 py-4 ${
              check.ok
                ? "border-emerald-200 bg-emerald-50"
                : "border-amber-200 bg-amber-50"
            }`}
          >
            <div className="flex items-start gap-3">
              {check.ok ? (
                <CheckCircle2 className="mt-0.5 h-5 w-5 text-emerald-700" />
              ) : (
                <AlertTriangle className="mt-0.5 h-5 w-5 text-amber-700" />
              )}
              <div>
                <p className="font-semibold text-ink">{check.label}</p>
                <p className="mt-1 text-sm text-ink/70">{check.detail}</p>
              </div>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

