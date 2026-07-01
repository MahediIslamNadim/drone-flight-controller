import type { ReactNode } from 'react'

interface PageHeaderProps {
  title: string
  subtitle?: string
  actions?: ReactNode
}

export default function PageHeader({ title, subtitle, actions }: PageHeaderProps) {
  return (
    <div className="study-hero cockpit-panel mb-6 flex flex-col gap-5 rounded-[2rem] px-5 py-5 md:px-6 md:py-6 lg:flex-row lg:items-end lg:justify-between">
      <div className="max-w-3xl">
        <p className="study-kicker cockpit-display">Cockpit Interface</p>
        <h2 className="mt-3 text-3xl font-bold md:text-[2.15rem]" style={{ color: 'var(--color-text)' }}>{title}</h2>
        {subtitle && (
          <p className="mt-2 max-w-2xl text-sm leading-7 md:text-[0.95rem]" style={{ color: 'var(--color-text-muted)' }}>{subtitle}</p>
        )}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-3">{actions}</div>}
    </div>
  )
}
