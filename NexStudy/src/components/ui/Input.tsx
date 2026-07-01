import type { InputHTMLAttributes } from 'react'

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string
  error?: string
}

export default function Input({ label, error, className = '', ...props }: InputProps) {
  return (
    <div className="flex flex-col gap-1.5 w-full">
      {label && <label className="text-sm font-medium" style={{ color: 'var(--color-text)' }}>{label}</label>}
      <input
        className={`w-full rounded-[1rem] px-4 py-3 text-sm transition-colors focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)] ${className}`}
        style={{
          background: 'var(--color-surface-strong)',
          border: `1px solid ${error ? 'var(--color-accent-rose)' : 'var(--color-border)'}`,
          boxShadow: 'inset 0 1px 0 var(--color-inset-highlight)',
          color: 'var(--color-text)',
        }}
        {...props}
      />
      {error && <span className="text-xs" style={{ color: 'var(--color-accent-rose)' }}>{error}</span>}
    </div>
  )
}
