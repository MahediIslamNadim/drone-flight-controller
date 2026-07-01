import { AdminSetupChecklist } from "@/components/admin-setup-checklist";
import { AdminLiveVerifier } from "@/components/admin-live-verifier";
import { getAdminDiagnostics } from "@/lib/admin-diagnostics";

export default function AdminSetupPage() {
  const diagnostics = getAdminDiagnostics();

  return (
    <div className="space-y-6">
      <section className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
        <p className="text-sm uppercase tracking-[0.22em] text-ember">Setup</p>
        <h1 className="mt-2 font-[family-name:var(--font-heading)] text-4xl font-bold text-ink">
          Launch checklist
        </h1>
        <p className="mt-3 max-w-2xl text-sm leading-7 text-ink/68">
          Ei page diye quickly bujha jabe app mock mode-e ache naki real Supabase-ready,
          ar kon env/config launch-er age fill kora bhalo.
        </p>
      </section>

      <AdminSetupChecklist diagnostics={diagnostics} />
      <AdminLiveVerifier />
    </div>
  );
}
