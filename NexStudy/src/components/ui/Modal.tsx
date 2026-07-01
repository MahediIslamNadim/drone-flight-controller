import { useEffect } from 'react'
import type { ReactNode } from 'react'
import { X } from 'lucide-react'

interface ModalProps {
  isOpen: boolean
  onClose: () => void
  title: string
  children: ReactNode
}

export default function Modal({ isOpen, onClose, title, children }: ModalProps) {
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = 'unset'
    }
    return () => { document.body.style.overflow = 'unset' }
  }, [isOpen])

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div 
        className="absolute inset-0 backdrop-blur-sm transition-opacity"
        style={{ background: 'var(--color-overlay)' }}
        onClick={onClose}
      />
      
      <div 
        className="relative flex w-full max-w-lg flex-col overflow-hidden rounded-[1.8rem] shadow-2xl"
        style={{
          background: 'var(--surface-modal)',
          border: '1px solid var(--color-border)',
          boxShadow: '0 30px 70px rgba(82, 59, 28, 0.16)',
        }}
      >
        <div className="flex items-center justify-between border-b px-6 py-4" style={{ borderColor: 'var(--color-border)' }}>
          <h3 className="text-lg font-semibold">{title}</h3>
          <button 
            onClick={onClose}
            className="rounded-xl p-2 transition-colors"
            style={{ background: 'var(--surface-ghost)', color: 'var(--color-text-muted)' }}
          >
            <X size={20} />
          </button>
        </div>
        
        <div className="p-6 overflow-y-auto max-h-[80vh]">
          {children}
        </div>
      </div>
    </div>
  )
}
