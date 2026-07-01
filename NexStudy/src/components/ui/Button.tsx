import type { ButtonHTMLAttributes, ReactNode } from 'react'

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger'
type Size    = 'sm' | 'md' | 'lg'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  size?: Size
  icon?: ReactNode
  children: ReactNode
}

const VARIANT_STYLES: Record<Variant, string> = {
  primary:   'text-white',
  secondary: '',
  ghost:     '',
  danger:    'text-white',
}

const SIZE_STYLES: Record<Size, string> = {
  sm: 'px-3.5 py-2 text-xs',
  md: 'px-[1.125rem] py-2.5 text-sm',
  lg: 'px-6 py-3 text-base',
}

export default function Button({
  variant = 'primary',
  size = 'md',
  icon,
  children,
  className = '',
  style,
  ...props
}: ButtonProps) {
  const variantStyle =
    variant === 'primary'
      ? {
          background: 'linear-gradient(135deg, var(--color-primary-dark), var(--color-accent-teal))',
          color: '#fff',
          border: '1px solid rgba(33, 63, 93, 0.24)',
          boxShadow: 'var(--shadow-glow)',
        }
      : variant === 'secondary'
        ? {
            background: 'var(--color-surface-strong)',
            color: 'var(--color-text)',
            border: '1px solid var(--color-border)',
            boxShadow: 'inset 0 1px 0 var(--color-inset-highlight)',
          }
        : variant === 'ghost'
          ? {
              background: 'var(--surface-ghost)',
              border: '1px solid rgba(95, 114, 132, 0.12)',
              color: 'var(--color-text-muted)',
            }
          : {
              background: 'linear-gradient(135deg, var(--color-accent-rose), #b85f49)',
              color: '#fff',
              border: '1px solid rgba(209, 110, 85, 0.22)',
              boxShadow: '0 16px 32px rgba(209, 110, 85, 0.22)',
            }

  return (
    <button
      className={`inline-flex items-center justify-center gap-2 rounded-[1rem] font-medium transition-all duration-150
        hover:-translate-y-0.5 hover:opacity-95 active:scale-[0.98] disabled:opacity-40 disabled:cursor-not-allowed
        ${SIZE_STYLES[size]} ${VARIANT_STYLES[variant]} ${className}`}
      style={{ ...variantStyle, ...style }}
      {...props}
    >
      {icon && <span className="flex-shrink-0">{icon}</span>}
      {children}
    </button>
  )
}
