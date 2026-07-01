import { NavLink } from 'react-router-dom'
import {
  BarChart2,
  Bell,
  BookOpen,
  CalendarDays,
  Clock,
  FileText,
  Grid3X3,
  LayoutDashboard,
  Layers,
  Settings,
  Target,
  Timer,
  X,
} from 'lucide-react'
import { useWorkspace } from '../../app/useWorkspace'

const NAV_ITEMS = [
  { to: '/',           label: 'Dashboard',  icon: LayoutDashboard },
  { to: '/subjects',   label: 'Subjects',   icon: BookOpen },
  { to: '/tracker',    label: 'Tracker',    icon: Clock },
  { to: '/planner',    label: 'Planner',    icon: CalendarDays },
  { to: '/notes',      label: 'Notes',      icon: FileText },
  { to: '/flashcards', label: 'Flashcards', icon: Layers },
  { to: '/timetable',  label: 'Timetable',  icon: Grid3X3 },
  { to: '/timer',      label: 'Timer',      icon: Timer },
  { to: '/goals',      label: 'Goals',      icon: Target },
  { to: '/analytics',  label: 'Analytics',  icon: BarChart2 },
  { to: '/reminders',  label: 'Reminders',  icon: Bell },
  { to: '/settings',   label: 'Settings',   icon: Settings },
]

interface SidebarProps {
  mobile?: boolean
  onClose?: () => void
}

export default function Sidebar({ mobile = false, onClose }: SidebarProps) {
  const { focusModeEnabled } = useWorkspace()

  return (
    <aside
      className={`flex w-[17rem] flex-shrink-0 flex-col overflow-hidden border ${
        mobile ? 'h-full rounded-[1.75rem]' : 'mr-3 rounded-[2rem] md:mr-4'
      }`}
      style={{
        background: 'var(--surface-sidebar)',
        borderColor: 'var(--color-border)',
        boxShadow: '0 0 0 1px rgba(0, 212, 255, 0.08), 18px 0 40px rgba(0, 0, 0, 0.35)',
      }}
    >
      <div className="flex items-center gap-3 border-b px-6 py-6" style={{ borderColor: 'var(--color-border)' }}>
        <div
          className="flex h-10 w-10 items-center justify-center rounded-2xl text-sm font-bold"
          style={{
            background: 'linear-gradient(135deg, var(--color-primary-dark), var(--color-accent-teal))',
            boxShadow: 'var(--shadow-glow)',
            color: '#fff',
          }}
        >
          N
        </div>
        <div>
          <span className="text-lg font-bold gradient-text">NexStudy</span>
          <p className="mt-1 text-xs uppercase tracking-[0.2em]" style={{ color: 'var(--color-text-muted)' }}>
            {focusModeEnabled ? 'Focus mode' : 'Study cockpit'}
          </p>
        </div>
        {mobile && (
          <button
            type="button"
            onClick={onClose}
            className="ml-auto rounded-2xl border p-2 transition-colors"
            style={{
              background: 'var(--surface-search)',
              borderColor: 'var(--color-border)',
              color: 'var(--color-text-muted)',
            }}
            aria-label="Close menu"
          >
            <X size={18} />
          </button>
        )}
      </div>

      <nav className="flex-1 space-y-2 overflow-y-auto px-3 py-5">
        {NAV_ITEMS.map(({ to, label, icon: Icon }) => (
          <NavLink
            key={to}
            to={to}
            end={to === '/'}
            onClick={onClose}
            className={({ isActive }) =>
              `flex items-center gap-3 rounded-2xl px-4 py-3 text-sm font-medium transition-all duration-150 ${
                isActive
                  ? 'text-white shadow-sm'
                  : 'text-[var(--color-text-muted)] hover:-translate-y-0.5 hover:text-[var(--color-text)]'
              }`
            }
            style={({ isActive }) =>
              isActive
                ? {
                    background: 'linear-gradient(135deg, var(--color-primary-dark), var(--color-accent-teal))',
                    boxShadow: 'var(--shadow-glow)',
                    color: '#fff',
                  }
                : {
                    background: 'var(--color-surface-muted)',
                    border: '1px solid rgba(0, 212, 255, 0.08)',
                  }
            }
          >
            <Icon size={18} />
            {label}
          </NavLink>
        ))}
      </nav>

      <div className="border-t px-4 py-4 text-xs" style={{ borderColor: 'var(--color-border)', color: 'var(--color-text-muted)' }}>
        {focusModeEnabled ? 'Distraction reduced. Stay with the next best task.' : 'Daily rhythm, weekly progress, one calm workspace.'}
      </div>
    </aside>
  )
}
