import { useEffect, useEffectEvent, useState } from 'react'
import { Outlet } from 'react-router-dom'
import { useWorkspace } from '../../app/useWorkspace'
import Sidebar from './Sidebar'
import Navbar from './Navbar'
import CommandPalette from './CommandPalette'
import DailyBriefingModal from './DailyBriefingModal'

export default function MainLayout() {
  const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(false)
  const [isCommandPaletteOpen, setIsCommandPaletteOpen] = useState(false)
  const [commandPaletteSession, setCommandPaletteSession] = useState(0)
  const { closeDailyBriefing, focusModeEnabled, isDailyBriefingOpen } = useWorkspace()

  function openCommandPalette() {
    setCommandPaletteSession((current) => current + 1)
    setIsCommandPaletteOpen(true)
    setIsMobileSidebarOpen(false)
  }

  const handleGlobalKeyDown = useEffectEvent((event: KeyboardEvent) => {
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
      event.preventDefault()
      if (isCommandPaletteOpen) {
        setIsCommandPaletteOpen(false)
      } else {
        openCommandPalette()
      }
      return
    }

    if (event.key === 'Escape') {
      setIsMobileSidebarOpen(false)
      setIsCommandPaletteOpen(false)
      closeDailyBriefing()
    }
  })

  useEffect(() => {
    const originalOverflow = document.body.style.overflow
    const originalFocusMode = document.body.dataset.focusMode
    const shouldLockScroll = isMobileSidebarOpen || isCommandPaletteOpen || isDailyBriefingOpen

    if (shouldLockScroll) {
      document.body.style.overflow = 'hidden'
    }

    document.body.dataset.focusMode = focusModeEnabled ? 'true' : 'false'
    window.addEventListener('keydown', handleGlobalKeyDown)

    return () => {
      document.body.style.overflow = originalOverflow
      if (originalFocusMode) {
        document.body.dataset.focusMode = originalFocusMode
      } else {
        delete document.body.dataset.focusMode
      }
      window.removeEventListener('keydown', handleGlobalKeyDown)
    }
  }, [focusModeEnabled, isCommandPaletteOpen, isDailyBriefingOpen, isMobileSidebarOpen])

  return (
    <div
      className="study-shell flex min-h-screen overflow-hidden p-3 md:p-4"
      style={{ background: 'var(--color-bg)' }}
      data-focus-mode={focusModeEnabled ? 'true' : 'false'}
    >
      <div className="hidden md:block">
        <Sidebar />
      </div>

      {isMobileSidebarOpen && (
        <div className="fixed inset-0 z-50 md:hidden">
          <button
            type="button"
            className="absolute inset-0"
            style={{ background: 'var(--color-overlay)' }}
            onClick={() => setIsMobileSidebarOpen(false)}
            aria-label="Close menu overlay"
          />
          <div className="relative z-10 h-full max-w-[19rem] p-3">
            <Sidebar mobile onClose={() => setIsMobileSidebarOpen(false)} />
          </div>
        </div>
      )}

      <div
        className="flex min-w-0 flex-1 flex-col overflow-hidden rounded-[2rem] border"
        style={{
          borderColor: 'var(--color-border)',
          background: 'var(--surface-shell)',
          boxShadow: 'var(--shadow-soft)',
        }}
      >
        <Navbar
          onMenuOpen={() => setIsMobileSidebarOpen(true)}
          onSearchOpen={openCommandPalette}
        />
        <main className="flex-1 overflow-y-auto px-4 pb-6 pt-4 md:px-6 md:pb-8 md:pt-5">
          <Outlet />
        </main>
      </div>

      <CommandPalette
        key={commandPaletteSession}
        isOpen={isCommandPaletteOpen}
        onClose={() => setIsCommandPaletteOpen(false)}
      />
      <DailyBriefingModal />
    </div>
  )
}
