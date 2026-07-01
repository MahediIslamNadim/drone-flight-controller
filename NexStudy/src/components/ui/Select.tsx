import type { SelectHTMLAttributes } from 'react'

interface SelectOption {
  value: string | number
  label: string
}

interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> {
  label?: string
  options: SelectOption[]
  error?: string
}

export default function Select({ label, options, error, className = '', ...props }: SelectProps) {
  return (
    <div className="flex flex-col gap-1.5 w-full">
      {label && <label className="text-sm font-medium" style={{ color: 'var(--color-text)' }}>{label}</label>}
      <select
        className={`w-full appearance-none rounded-[1rem] px-4 py-3 text-sm transition-colors focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)] ${className}`}
        style={{
          background: 'var(--color-surface-strong)',
          border: `1px solid ${error ? 'var(--color-accent-rose)' : 'var(--color-border)'}`,
          boxShadow: 'inset 0 1px 0 var(--color-inset-highlight)',
          color: 'var(--color-text)',
        }}
        {...props}
      >
        {options.map((opt) => (
          <option key={opt.value} value={opt.value}>{opt.label}</option>
        ))}
      </select>
      {error && <span className="text-xs" style={{ color: 'var(--color-accent-rose)' }}>{error}</span>}
    </div>
  )
}
