interface CircularGaugeProps {
  label: string
  value: number
  max?: number
  suffix?: string
  tone?: 'cyan' | 'amber' | 'green'
  size?: 'sm' | 'md'
}

const TONE_STYLES = {
  cyan: {
    glow: 'rgba(0, 212, 255, 0.24)',
    track: 'rgba(0, 212, 255, 0.12)',
    color: 'var(--color-primary)',
  },
  amber: {
    glow: 'rgba(255, 149, 0, 0.24)',
    track: 'rgba(255, 149, 0, 0.12)',
    color: 'var(--color-accent-amber)',
  },
  green: {
    glow: 'rgba(0, 255, 136, 0.24)',
    track: 'rgba(0, 255, 136, 0.12)',
    color: 'var(--color-accent-emerald)',
  },
} as const

const SIZE_STYLES = {
  sm: { outer: 'h-28 w-28', inner: 'h-[4.9rem] w-[4.9rem]' },
  md: { outer: 'h-36 w-36', inner: 'h-[6.2rem] w-[6.2rem]' },
} as const

export default function CircularGauge({
  label,
  value,
  max = 100,
  suffix = '',
  tone = 'cyan',
  size = 'md',
}: CircularGaugeProps) {
  const normalized = Math.max(0, Math.min(value / Math.max(max, 1), 1))
  const angle = normalized * 360
  const toneStyle = TONE_STYLES[tone]
  const sizeStyle = SIZE_STYLES[size]

  return (
    <div className="flex flex-col items-center gap-3">
      <div
        className={`relative flex items-center justify-center rounded-full border ${sizeStyle.outer}`}
        style={{
          borderColor: 'var(--color-border)',
          background: `conic-gradient(${toneStyle.color} ${angle}deg, ${toneStyle.track} ${angle}deg 360deg)`,
          boxShadow: `0 0 24px ${toneStyle.glow}`,
        }}
      >
        <div
          className={`flex flex-col items-center justify-center rounded-full border px-2 text-center ${sizeStyle.inner}`}
          style={{
            borderColor: 'rgba(0, 212, 255, 0.12)',
            background: 'linear-gradient(180deg, rgba(10, 14, 39, 0.94), rgba(8, 11, 26, 0.98))',
          }}
        >
          <span className="cockpit-display text-xl font-semibold" style={{ color: toneStyle.color }}>
            {Math.round(value)}
            {suffix}
          </span>
          <span className="mt-1 text-center text-[0.64rem] uppercase tracking-[0.18em] text-[var(--color-text-muted)]">
            {label}
          </span>
        </div>
      </div>
    </div>
  )
}
