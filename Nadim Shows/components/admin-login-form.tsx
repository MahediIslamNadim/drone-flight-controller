"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { LockKeyhole, LoaderCircle } from "lucide-react";

export function AdminLoginForm() {
  const router = useRouter();
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsLoading(true);
    setError("");

    try {
      const response = await fetch("/api/admin/login", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ password }),
      });

      const result = (await response.json()) as { error?: string };

      if (!response.ok) {
        setError(result.error ?? "Login failed.");
        return;
      }

      router.push("/admin/dashboard");
      router.refresh();
    } catch {
      setError("Network error. Please try again.");
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5">
      <label className="block">
        <span className="mb-2 block text-sm font-medium text-ink/75">Admin password</span>
        <div className="flex items-center gap-3 rounded-2xl border border-pine/10 bg-white px-4 py-4">
          <LockKeyhole className="h-5 w-5 text-pine" />
          <input
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            placeholder="Password likhun"
            className="w-full bg-transparent text-base text-ink outline-none placeholder:text-ink/35"
            autoComplete="current-password"
            required
          />
        </div>
      </label>

      {error ? (
        <p className="rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </p>
      ) : null}

      <button
        type="submit"
        disabled={isLoading}
        className="inline-flex w-full items-center justify-center gap-2 rounded-full bg-pine px-6 py-4 text-base font-semibold text-white transition hover:bg-pine/90 disabled:cursor-not-allowed disabled:opacity-70"
      >
        {isLoading ? <LoaderCircle className="h-5 w-5 animate-spin" /> : null}
        Login
      </button>
    </form>
  );
}

