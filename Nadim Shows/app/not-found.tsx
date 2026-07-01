import Link from "next/link";

export default function NotFound() {
  return (
    <div className="mx-auto flex min-h-[60vh] max-w-3xl flex-col items-center justify-center px-4 text-center">
      <p className="text-sm uppercase tracking-[0.25em] text-ember">404</p>
      <h1 className="mt-4 font-[family-name:var(--font-heading)] text-4xl font-bold text-ink">
        This shoe page could not be found
      </h1>
      <p className="mt-3 max-w-xl text-ink/70">
        The catalog route exists, but this specific item is not available yet. Once Supabase inventory is added, this will resolve automatically.
      </p>
      <Link
        href="/shoes"
        className="mt-6 inline-flex rounded-full bg-pine px-6 py-3 font-semibold text-white"
      >
        Back to catalog
      </Link>
    </div>
  );
}

