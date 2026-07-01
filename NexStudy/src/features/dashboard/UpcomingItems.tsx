import { BellRing, CalendarClock, Radar, Siren, Target } from 'lucide-react'
import Card from '../../components/ui/Card'
import { loadReminders, loadSubjects, loadTasks, STORAGE_KEYS } from '../../lib/studyData'
import { useStudyLiveValue } from '../../lib/useStudyLiveValue'

interface UpcomingItem {
  id: string
  title: string
  when: string
  sortAt: string
  source: 'task' | 'exam' | 'reminder'
  tone: 'warning' | 'default'
}

const SOURCE_META = {
  task: { label: 'Mission', Icon: Target },
  exam: { label: 'Alert', Icon: Siren },
  reminder: { label: 'Signal', Icon: BellRing },
} as const

export default function UpcomingItems() {
  const items = useStudyLiveValue(
    () => {
      const tasks = loadTasks()
        .filter((task) => !task.completed)
        .map<UpcomingItem>((task) => ({
          id: task.id,
          title: task.title,
          when: `Due ${task.dueDate}`,
          sortAt: `${task.dueDate}T23:59:59`,
          source: 'task',
          tone: task.priority === 'High' ? 'warning' : 'default',
        }))

      const exams = loadSubjects()
        .filter((subject) => subject.examDate)
        .map<UpcomingItem>((subject) => ({
          id: `${subject.id}-exam`,
          title: `${subject.name} Exam`,
          when: subject.examDate,
          sortAt: `${subject.examDate}T23:59:59`,
          source: 'exam',
          tone: 'warning',
        }))

      const reminders = loadReminders()
        .filter((reminder) => !reminder.completed)
        .map<UpcomingItem>((reminder) => ({
          id: reminder.id,
          title: reminder.title,
          when: reminder.remindAt.replace('T', ' '),
          sortAt: reminder.remindAt,
          source: 'reminder',
          tone: 'default',
        }))

      return [...tasks, ...exams, ...reminders]
        .sort((a, b) => a.sortAt.localeCompare(b.sortAt))
        .slice(0, 5)
    },
    [STORAGE_KEYS.planner, STORAGE_KEYS.subjects, STORAGE_KEYS.reminders],
  )

  return (
    <Card glass className="cockpit-panel rounded-[1.8rem]">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="cockpit-kicker">Signal Panel</p>
          <h3 className="mt-3 text-xl font-semibold text-[var(--color-text)]">Incoming notifications</h3>
        </div>
        <div className="study-icon-chip info indicator-pulse">
          <Radar size={18} />
        </div>
      </div>

      <div className="mt-5 space-y-3">
        {items.length === 0 && (
          <div className="rounded-[1.35rem] border px-4 py-5 text-sm text-[var(--color-text-muted)]" style={{ borderColor: 'var(--color-border)', background: 'var(--surface-panel)' }}>
            All channels are quiet. No urgent reminders or deadlines detected.
          </div>
        )}

        {items.map((item) => {
          const meta = SOURCE_META[item.source]

          return (
            <div
              key={item.id}
              className="rounded-[1.35rem] border p-4"
              style={{
                borderColor: item.tone === 'warning' ? 'rgba(255, 149, 0, 0.28)' : 'var(--color-border)',
                background: item.tone === 'warning' ? 'linear-gradient(135deg, rgba(255, 149, 0, 0.08), rgba(10, 14, 39, 0.92))' : 'var(--surface-panel)',
              }}
            >
              <div className="flex items-start gap-3">
                <div className={`study-icon-chip ${item.tone === 'warning' ? 'warm' : 'info'} h-10 w-10 rounded-[1rem]`}>
                  <meta.Icon size={16} />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex flex-col items-start gap-2 sm:flex-row sm:items-center sm:justify-between">
                    <p className="max-w-full text-pretty font-semibold text-[var(--color-text)]">{item.title}</p>
                    <span className="cockpit-display shrink-0 text-[0.68rem] uppercase tracking-[0.24em] text-[var(--color-text-muted)]">
                      {meta.label}
                    </span>
                  </div>
                  <p className={`mt-2 flex items-center gap-2 text-sm ${item.tone === 'warning' ? 'text-[var(--color-accent-amber)]' : 'text-[var(--color-text-muted)]'}`}>
                    <CalendarClock size={14} />
                    {item.when}
                  </p>
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </Card>
  )
}
