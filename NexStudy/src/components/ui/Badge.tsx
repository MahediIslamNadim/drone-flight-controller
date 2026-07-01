import type { HTMLAttributes, ReactNode } from 'react'

type BadgeVariant = 'success' | 'warning' | 'danger' | 'info' | 'default'

interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  children: ReactNode
  variant?: BadgeVariant
}

const VARIANT_STYLES: Record<BadgeVariant, { bg: string, text: string, border: string }> = {
  success: { bg: 'rgba(102, 143, 123, 0.14)', text: 'var(--color-accent-emerald)', border: 'rgba(102, 143, 123, 0.22)' },
  warning: { bg: 'rgba(216, 154, 75, 0.14)', text: 'var(--color-accent-amber)', border: 'rgba(216, 154, 75, 0.2)' },
  danger:  { bg: 'rgba(209, 110, 85, 0.14)', text: 'var(--color-accent-rose)', border: 'rgba(209, 110, 85, 0.2)' },
  info:    { bg: 'rgba(61, 107, 145, 0.12)', text: 'var(--color-primary-dark)', border: 'rgba(61, 107, 145, 0.18)' },
  default: { bg: 'rgba(95, 114, 132, 0.1)', text: 'var(--color-text-muted)', border: 'rgba(95, 114, 132, 0.14)' },
}

export default function Badge({ children, variant = 'default', className = '', ...props }: BadgeProps) {
  const styles = VARIANT_STYLES[variant]
  
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${className}`}
      style={{ background: styles.bg, border: `1px solid ${styles.border}`, color: styles.text }}
      {...props}
    >
      {children}
    </span>
  )
}
