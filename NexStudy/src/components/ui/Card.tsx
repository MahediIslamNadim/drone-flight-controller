import type { ReactNode, HTMLAttributes } from 'react'

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode
  hover?: boolean
  glass?: boolean
}

export default function Card({ children, hover = false, glass = false, className = '', style, ...props }: CardProps) {
  return (
    <div
      className={`relative overflow-hidden rounded-[1.6rem] p-5 ${hover ? 'card-hover cursor-pointer' : ''} ${glass ? 'glass' : ''} ${className}`}
      style={{
        background: glass ? undefined : 'var(--surface-card-solid)',
        border: '1px solid var(--color-border)',
        boxShadow: glass ? undefined : 'var(--shadow-soft)',
        ...style,
      }}
      {...props}
    >
      {children}
    </div>
  )
}
