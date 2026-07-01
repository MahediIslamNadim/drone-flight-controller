import { startTransition, useDeferredValue, useEffect, useEffectEvent, useRef, useState, type ChangeEvent } from 'react'
import {
  BarChart2,
  Bell,
  BookOpen,
  CalendarDays,
  Clock3,
  FileText,
  Grid3X3,
  Layers,
  LayoutDashboard,
  Moon,
  Search,
  Settings,
  Sparkles,
  SunMedium,
  Target,
  Timer,
} from 'lucide-react'
import { useLocation, useNavigate } from 'react-router-dom'
import { useTheme } from '../../app/useTheme'
import { useWorkspace } from '../../app/useWorkspace'
import {
  getTodayIsoDate,
  loadStudyWorkspace,
  STORAGE_KEYS,
  type StudyStorageKey,
} from '../../lib/studyData'
import { useStudyLiveValue } from '../../lib/useStudyLiveValue'

type CommandSection = 'Focus' | 'Navigate' | 'Study Data'

interface CommandItem {
  id: string
  section: CommandSection
  label: string
  description: string
  keywords: string
  Icon: typeof Search
  action: () => void
}

interface CommandPaletteProps {
  isOpen: boolean
  onClose: () => void
}

const WORKSPACE_KEYS: StudyStorageKey[] = [
  STORAGE_KEYS.subjects,
  STORAGE_KEYS.sessions,
  STORAGE_KEYS.planner,
  STORAGE_KEYS.notes,
  STORAGE_KEYS.goals,
  STORAGE_KEYS.reminders,
  STORAGE_KEYS.flashcards,
  STORAGE_KEYS.timetable,
  STORAGE_KEYS.settings,
]

const NAV_ITEMS = [
  { to: '/', label: 'Dashboard', description: 'View your study overview, summaries, and charts.', keywords: 'home overview stats', Icon: LayoutDashboard },
  { to: '/subjects', label: 'Subjects', description: 'Manage courses, goals, exams, and study progress.', keywords: 'courses exam progress', Icon: BookOpen },
  { to: '/tracker', label: 'Tracker', description: 'Log study sessions and focus scores.', keywords: 'sessions focus hours log', Icon: Clock3 },
  { to: '/planner', label: 'Planner', description: 'Organize assignments, deadlines, and revision tasks.', keywords: 'tasks due calendar', Icon: CalendarDays },
  { to: '/notes', label: 'Notes', description: 'Open class notes and revision summaries.', keywords: 'writing docs summary', Icon: FileText },
  { to: '/flashcards', label: 'Flashcards', description: 'Review decks and spaced repetition study sets.', keywords: 'cards memorization deck', Icon: Layers },
  { to: '/timetable', label: 'Timetable', description: 'See your weekly class routine.', keywords: 'schedule class week', Icon: Grid3X3 },
  { to: '/timer', label: 'Timer', description: 'Run a focused Pomodoro session.', keywords: 'pomodoro deep work countdown', Icon: Timer },
  { to: '/goals', label: 'Goals', description: 'Track long-term study targets and deadlines.', keywords: 'targets achievement milestones', Icon: Target },
  { to: '/analytics', label: 'Analytics', description: 'See trends across hours, progress, and tasks.', keywords: 'insights charts trends', Icon: BarChart2 },
  { to: '/reminders', label: 'Reminders', description: 'Check upcoming alerts and revision nudges.', keywords: 'alerts notifications remember', Icon: Bell },
  { to: '/settings', label: 'Settings', description: 'Adjust your workspace and backup tools.', keywords: 'preferences backup import export', Icon: Settings },
] as const

function formatDate(date: string) {
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(new Date(date))
}

function formatDateTime(dateTime: string) {
  const normalized = dateTime.includes('T') ? dateTime : `${dateTime}T00:00:00`

  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(new Date(normalized))
}

function matchesQuery(item: CommandItem, query: string) {
  const haystack = `${item.label} ${item.description} ${item.keywords}`.toLowerCase()
  return haystack.includes(query)
}

export default function CommandPalette({ isOpen, onClose }: CommandPaletteProps) {
  const [query, setQuery] = useState('')
  const [selectedIndex, setSelectedIndex] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)
  const navigate = useNavigate()
  const { pathname } = useLocation()
  const { themeMode, toggleThemeMode } = useTheme()
  const { focusModeEnabled, toggleFocusMode, openDailyBriefing } = useWorkspace()
  const workspace = useStudyLiveValue(loadStudyWorkspace, WORKSPACE_KEYS)
  const deferredQuery = useDeferredValue(query)
  const normalizedQuery = deferredQuery.trim().toLowerCase()
  const today = getTodayIsoDate()

  useEffect(() => {
    if (!isOpen) {
      return
    }

    window.requestAnimationFrame(() => {
      inputRef.current?.focus()
    })
  }, [isOpen])

  const overdueTask = [...workspace.tasks]
    .filter((task) => !task.completed && task.dueDate < today)
    .sort((a, b) => a.dueDate.localeCompare(b.dueDate))[0]
  const nextTask = [...workspace.tasks]
    .filter((task) => !task.completed)
    .sort((a, b) => a.dueDate.localeCompare(b.dueDate))[0]
  const nextReminder = [...workspace.reminders]
    .filter((reminder) => !reminder.completed)
    .sort((a, b) => a.remindAt.localeCompare(b.remindAt))[0]
  const nextExam = [...workspace.subjects]
    .filter((subject) => subject.examDate)
    .sort((a, b) => a.examDate.localeCompare(b.examDate))[0]

  const commands: CommandItem[] = [
    {
      id: 'focus-timer',
      section: 'Focus',
      label: 'Start Focus Timer',
      description: 'Jump into a Pomodoro session and keep your flow moving.',
      keywords: 'timer pomodoro start focus deep work',
      Icon: Timer,
      action: () => {
        navigate('/timer')
        onClose()
      },
    },
    {
      id: 'toggle-focus-mode',
      section: 'Focus',
      label: focusModeEnabled ? 'Exit Focus Mode' : 'Enter Focus Mode',
      description: 'Reduce visual distractions and stay inside the next best task.',
      keywords: 'focus mode distraction deep work calm workspace',
      Icon: Target,
      action: () => {
        toggleFocusMode()
        onClose()
      },
    },
    {
      id: 'daily-briefing',
      section: 'Focus',
      label: 'Open Daily Briefing',
      description: 'See the latest intelligent summary, pressure points, and next move.',
      keywords: 'briefing coach intelligence summary plan',
      Icon: Sparkles,
      action: () => {
        openDailyBriefing()
        onClose()
      },
    },
    {
      id: 'log-session',
      section: 'Focus',
      label: 'Log Study Session',
      description: 'Add a fresh session entry with duration and focus score.',
      keywords: 'tracker session log hours focus',
      Icon: Clock3,
      action: () => {
        navigate('/tracker')
        onClose()
      },
    },
    {
      id: 'toggle-theme',
      section: 'Focus',
      label: themeMode === 'dark' ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      description: 'Change the study workspace appearance instantly.',
      keywords: 'theme mode dark light appearance',
      Icon: themeMode === 'dark' ? SunMedium : Moon,
      action: () => {
        toggleThemeMode()
        onClose()
      },
    },
    ...(overdueTask
      ? [{
          id: `overdue-${overdueTask.id}`,
          section: 'Focus' as const,
          label: `Review overdue task: ${overdueTask.title}`,
          description: `${overdueTask.subject} • Was due ${formatDate(overdueTask.dueDate)}.`,
          keywords: `overdue urgent ${overdueTask.subject} ${overdueTask.title}`,
          Icon: Sparkles,
          action: () => {
            navigate('/planner')
            onClose()
          },
        }]
      : []),
    ...(nextReminder
      ? [{
          id: `next-reminder-${nextReminder.id}`,
          section: 'Focus' as const,
          label: `Check reminder: ${nextReminder.title}`,
          description: `${nextReminder.channel} alert scheduled for ${formatDateTime(nextReminder.remindAt)}.`,
          keywords: `reminder alert ${nextReminder.title}`,
          Icon: Bell,
          action: () => {
            navigate('/reminders')
            onClose()
          },
        }]
      : []),
    ...(nextExam
      ? [{
          id: `next-exam-${nextExam.id}`,
          section: 'Focus' as const,
          label: `Prepare for ${nextExam.name} exam`,
          description: `Next exam is on ${formatDate(nextExam.examDate)}.`,
          keywords: `exam subject ${nextExam.name}`,
          Icon: BookOpen,
          action: () => {
            navigate('/subjects')
            onClose()
          },
        }]
      : []),
    ...NAV_ITEMS.map((item) => ({
      id: `nav-${item.to}`,
      section: 'Navigate' as const,
      label: item.label,
      description: item.description,
      keywords: `${item.keywords} ${item.label.toLowerCase()}`,
      Icon: item.Icon,
      action: () => {
        navigate(item.to)
        onClose()
      },
    })),
    ...workspace.subjects.map((subject) => ({
      id: `subject-${subject.id}`,
      section: 'Study Data' as const,
      label: subject.name,
      description: `Subject • ${subject.progress}% progress • ${subject.studiedHours.toFixed(1)}h tracked.`,
      keywords: `${subject.name} ${subject.category} ${subject.instructor} exam ${subject.examDate}`,
      Icon: BookOpen,
      action: () => {
        navigate('/subjects')
        onClose()
      },
    })),
    ...workspace.tasks.map((task) => ({
      id: `task-${task.id}`,
      section: 'Study Data' as const,
      label: task.title,
      description: `${task.completed ? 'Completed' : 'Task'} • ${task.subject} • Due ${formatDate(task.dueDate)}.`,
      keywords: `${task.title} ${task.subject} ${task.type} ${task.priority} ${task.notes}`,
      Icon: CalendarDays,
      action: () => {
        navigate('/planner')
        onClose()
      },
    })),
    ...workspace.notes.map((note) => ({
      id: `note-${note.id}`,
      section: 'Study Data' as const,
      label: note.title,
      description: `Note • ${note.subject} • Updated ${formatDate(note.updatedAt)}.`,
      keywords: `${note.title} ${note.subject} ${note.content}`,
      Icon: FileText,
      action: () => {
        navigate('/notes')
        onClose()
      },
    })),
    ...workspace.reminders.map((reminder) => ({
      id: `reminder-${reminder.id}`,
      section: 'Study Data' as const,
      label: reminder.title,
      description: `${reminder.completed ? 'Completed reminder' : 'Reminder'} • ${formatDateTime(reminder.remindAt)}.`,
      keywords: `${reminder.title} ${reminder.channel} ${reminder.remindAt}`,
      Icon: Bell,
      action: () => {
        navigate('/reminders')
        onClose()
      },
    })),
  ]

  const visibleCommands = commands
    .filter((item) => (normalizedQuery ? matchesQuery(item, normalizedQuery) : true))
    .filter((item) => (normalizedQuery ? true : item.section !== 'Study Data' || item.id === `task-${nextTask?.id}`))
    .slice(0, normalizedQuery ? 18 : 10)
  const activeIndex = visibleCommands.length === 0 ? 0 : Math.min(selectedIndex, visibleCommands.length - 1)

  const handleKeyDown = useEffectEvent((event: KeyboardEvent) => {
    if (!isOpen) {
      return
    }

    if (event.key === 'ArrowDown') {
      event.preventDefault()
      setSelectedIndex((current) => (visibleCommands.length === 0 ? 0 : (current + 1) % visibleCommands.length))
    }

    if (event.key === 'ArrowUp') {
      event.preventDefault()
      setSelectedIndex((current) =>
        visibleCommands.length === 0 ? 0 : (current - 1 + visibleCommands.length) % visibleCommands.length,
      )
    }

    if (event.key === 'Enter' && visibleCommands[activeIndex]) {
      event.preventDefault()
      visibleCommands[activeIndex].action()
    }
  })

  useEffect(() => {
    if (!isOpen) {
      return undefined
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => {
      window.removeEventListener('keydown', handleKeyDown)
    }
  }, [isOpen])

  function handleQueryChange(event: ChangeEvent<HTMLInputElement>) {
    const nextValue = event.target.value
    startTransition(() => {
      setQuery(nextValue)
      setSelectedIndex(0)
    })
  }

  if (!isOpen) {
    return null
  }

  return (
    <div className="fixed inset-0 z-[60] flex items-start justify-center p-4 pt-[8vh] md:p-6 md:pt-[10vh]">
      <button
        type="button"
        className="absolute inset-0 backdrop-blur-sm"
        style={{ background: 'var(--color-overlay)' }}
        onClick={onClose}
        aria-label="Close command palette overlay"
      />

      <div
        className="relative z-10 flex w-full max-w-3xl flex-col overflow-hidden rounded-[2rem] border"
        style={{
          background: 'var(--surface-modal)',
          borderColor: 'var(--color-border)',
          boxShadow: '0 32px 90px rgba(38, 28, 16, 0.22)',
        }}
      >
        <div className="border-b px-5 py-4 md:px-6" style={{ borderColor: 'var(--color-border)' }}>
          <div className="flex items-center gap-3 rounded-[1.35rem] border px-4 py-3" style={{ borderColor: 'var(--color-border)', background: 'var(--surface-search)' }}>
            <Search size={18} className="text-[var(--color-text-muted)]" />
            <input
              ref={inputRef}
              value={query}
              onChange={handleQueryChange}
              placeholder="Search pages, tasks, notes, reminders, or actions..."
              className="w-full bg-transparent text-sm outline-none placeholder:text-[var(--color-text-muted)]"
              style={{ color: 'var(--color-text)' }}
            />
            <kbd className="hidden rounded-full border px-2 py-1 text-[0.7rem] text-[var(--color-text-muted)] sm:inline-flex" style={{ borderColor: 'var(--color-border)' }}>
              Esc
            </kbd>
          </div>
          <div className="mt-3 flex flex-wrap items-center gap-2 text-xs text-[var(--color-text-muted)]">
            <span className="command-chip">⌘/Ctrl + K</span>
            <span className="command-chip">↑↓ move</span>
            <span className="command-chip">Enter open</span>
            <span className="command-chip">{pathname === '/' ? 'Dashboard context' : 'Current page aware'}</span>
          </div>
        </div>

        <div className="max-h-[65vh] overflow-y-auto p-3 md:p-4">
          {visibleCommands.length === 0 ? (
            <div className="rounded-[1.5rem] border px-5 py-8 text-center" style={{ borderColor: 'var(--color-border)', background: 'var(--surface-panel)' }}>
              <p className="text-base font-medium text-[var(--color-text)]">No matching study command found.</p>
              <p className="mt-2 text-sm text-[var(--color-text-muted)]">
                Try a subject name, task title, note, timer, or reminder keyword.
              </p>
            </div>
          ) : (
            ['Focus', 'Navigate', 'Study Data'].map((section) => {
              const sectionItems = visibleCommands.filter((item) => item.section === section)

              if (sectionItems.length === 0) {
                return null
              }

              return (
                <div key={section} className="mb-4 last:mb-0">
                  <p className="px-2 pb-2 text-[0.7rem] font-semibold uppercase tracking-[0.22em] text-[var(--color-text-muted)]">
                    {section}
                  </p>
                  <div className="space-y-2">
                    {sectionItems.map((item) => {
                      const itemIndex = visibleCommands.findIndex((command) => command.id === item.id)
                      const isActive = itemIndex === activeIndex

                      return (
                        <button
                          key={item.id}
                          type="button"
                          onClick={item.action}
                          className={`command-row w-full text-left ${isActive ? 'is-active' : ''}`}
                        >
                          <span className="study-icon-chip info h-11 w-11 rounded-[1rem]">
                            <item.Icon size={18} />
                          </span>
                          <span className="min-w-0 flex-1">
                            <span className="block truncate text-sm font-semibold text-[var(--color-text)]">{item.label}</span>
                            <span className="mt-1 block truncate text-sm text-[var(--color-text-muted)]">{item.description}</span>
                          </span>
                        </button>
                      )
                    })}
                  </div>
                </div>
              )
            })
          )}
        </div>
      </div>
    </div>
  )
}
