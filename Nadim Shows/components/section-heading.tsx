type SectionHeadingProps = {
  eyebrow: string;
  title: string;
  description: string;
};

export function SectionHeading({ eyebrow, title, description }: SectionHeadingProps) {
  return (
    <div className="max-w-3xl space-y-3">
      <p className="text-sm uppercase tracking-[0.28em] text-ember">{eyebrow}</p>
      <h2 className="font-[family-name:var(--font-heading)] text-3xl font-bold leading-tight text-ink sm:text-4xl">
        {title}
      </h2>
      <p className="text-base leading-7 text-ink/72">{description}</p>
    </div>
  );
}

