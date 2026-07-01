"use client";

import { useState } from "react";
import { AlertTriangle, CheckCircle2, LoaderCircle, PlayCircle } from "lucide-react";

type LiveCheck = {
  label: string;
  ok: boolean;
  detail: string;
};

type LiveResult = {
  mode: string;
  checks: LiveCheck[];
};

export function AdminLiveVerifier() {
  const [result, setResult] = useState<LiveResult | null>(null);
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  async function runCheck() {
    setIsLoading(true);
    setError("");

    try {
      const response = await fetch("/api/admin/debug/live", {
        method: "GET",
      });

      const payload = (await response.json()) as LiveResult & { error?: string };

      if (!response.ok && payload.error) {
        setError(payload.error);
      }

      setResult(payload);
    } catch {
      setError("Could not reach the live verifier route.");
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <section className="rounded-[2rem] border border-white/70 bg-white/85 p-5 shadow-sm">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <p className="text-sm uppercase tracking-[0.22em] text-ember">Live Test</p>
          <h2 className="mt-2 font-[family-name:var(--font-heading)] text-3xl font-bold text-ink">
            Verify database and storage access
          </h2>
          <p className="mt-2 text-sm leading-7 text-ink/68">
            Button press kore actual Supabase tables ar storage bucket reachable kina check korun.
          </p>
        </div>

        <button
          type="button"
          onClick={() => void runCheck()}
          disabled={isLoading}
          className="inline-flex items-center justify-center gap-2 rounded-full bg-pine px-5 py-3 text-sm font-semibold text-white transition hover:bg-pine/90 disabled:cursor-not-allowed disabled:opacity-70"
        >
          {isLoading ? (
            <LoaderCircle className="h-4 w-4 animate-spin" />
          ) : (
            <PlayCircle className="h-4 w-4" />
          )}
          Run live check
        </button>
      </div>

      {error ? (
        <p className="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </p>
      ) : null}

      {result ? (
        <div className="mt-5 space-y-3">
          <div className="rounded-[1.5rem] bg-mist px-4 py-3 text-sm text-ink/75">
            Current mode: <span className="font-semibold text-pine">{result.mode}</span>
          </div>

          {result.checks.map((check) => (
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
      ) : null}
    </section>
  );
}

