import { Bell, Menu, Moon, Search, Sparkles, SunMedium, Target } from 'lucide-react'
import { useLocation, useNavigate } from 'react-router-dom'
import { useTheme } from '../../app/useTheme'
import { useWorkspace } from '../../app/useWorkspace'
import { getTodayIsoDate, loadReminders, loadTasks, STORAGE_KEYS } from '../../lib/studyData'
import { getEscalatedReminders } from '../../lib/studyIntelligence'
import { useStudyLiveValue } from '../../lib/useStudyLiveValue'

const ROUTE_TITLES: Record<string, string> = {
  '/': 'Dashboard',
  '/subjects': 'Subjects',
  '/tracker': 'Study Tracker',
  '/planner': 'Planner',
  '/notes': 'Notes',
  '/flashcards': 'Flashcards',
  '/timetable': 'Timetable',
  '/timer': 'Study Timer',
  '/goals': 'Goals',
  '/analytics': 'Analytics',
  '/reminders': 'Reminders',
  '/settings': 'Settings',
}

interface NavbarProps {
  onMenuOpen?: () => void
  onSearchOpen?: () => void
}

export default function Navbar({ onMenuOpen, onSearchOpen }: NavbarProps) {
  const { pathname } = useLocation()
  const navigate = useNavigate()
  const { themeMode, toggleThemeMode } = useTheme()
  const { focusModeEnabled, toggleFocusMode, openDailyBriefing } = useWorkspace()
  const title = ROUTE_TITLES[pathname] ?? 'NexStudy'
  const todayLabel = new Intl.DateTimeFormat('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  }).format(new Date())
  const { pendingReminders, escalatedReminders, overdueTasks } = useStudyLiveValue(
    () => {
      const today = getTodayIsoDate()

      return {
        pendingReminders: loadReminders().filter((reminder) => !reminder.completed).length,
        escalatedReminders: getEscalatedReminders(loadReminders()).filter((reminder) => reminder.urgency === 'overdue' || reminder.urgency === 'today').length,
        overdueTasks: loadTasks().filter((task) => !task.completed && task.dueDate < today).length,
      }
    },
    [STORAGE_KEYS.reminders, STORAGE_KEYS.planner],
  )
  const alertCount = escalatedReminders + overdueTasks

  return (
    <header
      className="flex flex-shrink-0 items-center justify-between border-b px-4 py-4 md:px-6"
      style={{
        background: 'var(--surface-header)',
        borderColor: 'var(--color-border)',
        backdropFilter: 'blur(18px)',
        WebkitBackdropFilter: 'blur(18px)',
      }}
    >
      <div className="flex items-start gap-3">
        <button
          type="button"
          onClick={onMenuOpen}
          className="rounded-2xl border p-2.5 transition-colors md:hidden"
          style={{
            background: 'var(--surface-search)',
            borderColor: 'var(--color-border)',
            color: 'var(--color-text-muted)',
          }}
          aria-label="Open menu"
        >
          <Menu size={18} />
        </button>

        <div>
          <p className="study-kicker">{todayLabel}</p>
          <h1 className="mt-2 text-xl font-semibold" style={{ color: 'var(--color-text)' }}>
            {title}
          </h1>
        </div>
      </div>

      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={onSearchOpen}
          className="hidden items-center gap-2 rounded-2xl px-4 py-2 text-sm transition-colors md:flex"
          style={{
            background: 'var(--surface-search)',
            border: '1px solid var(--color-border)',
            boxShadow: 'inset 0 1px 0 var(--color-inset-highlight)',
            color: 'var(--color-text-muted)',
          }}
          aria-label="Open command palette"
        >
          <Search size={15} />
          <span>Search...</span>
          <kbd className="ml-4 text-xs opacity-50">Ctrl+K</kbd>
        </button>

        <button
          type="button"
          onClick={onSearchOpen}
          className="rounded-2xl border p-2.5 transition-colors md:hidden"
          style={{
            background: 'var(--surface-search)',
            borderColor: 'var(--color-border)',
            color: 'var(--color-text-muted)',
          }}
          aria-label="Open search"
        >
          <Search size={18} />
        </button>

        <button
          type="button"
          onClick={toggleFocusMode}
          className="rounded-2xl border p-2.5 transition-colors"
          style={{
            background: focusModeEnabled ? 'linear-gradient(135deg, rgba(0, 212, 255, 0.14), rgba(255, 149, 0, 0.1))' : 'var(--surface-search)',
            borderColor: 'var(--color-border)',
            color: focusModeEnabled ? 'var(--color-primary)' : 'var(--color-text-muted)',
          }}
          aria-label={focusModeEnabled ? 'Disable focus mode' : 'Enable focus mode'}
          title={focusModeEnabled ? 'Focus mode is on' : 'Turn on focus mode'}
        >
          <Target size={18} />
        </button>

        <button
          type="button"
          onClick={toggleThemeMode}
          className="rounded-2xl border p-2.5 transition-colors"
          style={{
            background: 'var(--surface-search)',
            borderColor: 'var(--color-border)',
            color: 'var(--color-text-muted)',
          }}
          aria-label={themeMode === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
          title={themeMode === 'dark' ? 'Light mode' : 'Dark mode'}
        >
          {themeMode === 'dark' ? <SunMedium size={18} /> : <Moon size={18} />}
        </button>

        <button
          type="button"
          onClick={openDailyBriefing}
          className="focus-hide-when-mode hidden rounded-2xl border p-2.5 transition-colors sm:flex"
          style={{
            background: 'var(--surface-search)',
            borderColor: 'var(--color-border)',
            color: 'var(--color-text-muted)',
          }}
          aria-label="Open daily briefing"
          title="Open daily briefing"
        >
          <Sparkles size={18} />
        </button>

        <button
          type="button"
          onClick={() => navigate('/reminders')}
          className="relative rounded-2xl border p-2.5 transition-colors"
          style={{
            background: 'var(--surface-search)',
            borderColor: 'var(--color-border)',
            color: 'var(--color-text-muted)',
          }}
          aria-label="Open reminders"
          title={alertCount > 0 ? `${alertCount} urgent alerts` : pendingReminders > 0 ? `${pendingReminders} pending reminders` : 'No active alerts'}
        >
          <Bell size={18} />
          {alertCount > 0 && (
            <span
              className="absolute -right-1.5 -top-1.5 flex min-h-5 min-w-5 items-center justify-center rounded-full px-1 text-[0.65rem] font-semibold text-white"
              style={{
                background: 'var(--color-accent-rose)',
                boxShadow: '0 0 0 4px rgba(255, 149, 0, 0.14)',
              }}
            >
              {alertCount > 9 ? '9+' : alertCount}
            </span>
          )}
        </button>

        <div
          className="focus-hide-when-mode hidden h-10 w-10 cursor-pointer items-center justify-center rounded-2xl text-sm font-bold sm:flex"
          style={{
            background: 'linear-gradient(135deg, var(--color-primary-dark), var(--color-accent-teal))',
            boxShadow: 'var(--shadow-glow)',
            color: '#fff',
          }}
        >
          U
        </div>
      </div>
    </header>
  )
}
