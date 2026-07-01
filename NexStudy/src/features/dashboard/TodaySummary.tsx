import Card from '../../components/ui/Card'
import CircularGauge from '../../components/ui/CircularGauge'
import {
  getTodayIsoDate,
  loadSessions,
  loadTasks,
  loadStudyWorkspace,
  STORAGE_KEYS,
} from '../../lib/studyData'
import { buildStudyIntelligence } from '../../lib/studyIntelligence'
import { useStudyLiveValue } from '../../lib/useStudyLiveValue'

export default function TodaySummary() {
  const today = getTodayIsoDate()
  const { sessions, completedTasks, intelligence } = useStudyLiveValue(
    () => ({
      sessions: loadSessions().filter((session) => session.date === today),
      completedTasks: loadTasks().filter((task) => task.completed && task.completedAt === today),
      intelligence: buildStudyIntelligence(loadStudyWorkspace()),
    }),
    [STORAGE_KEYS.sessions, STORAGE_KEYS.planner, STORAGE_KEYS.goals, STORAGE_KEYS.settings],
  )
  const hoursStudied = sessions.reduce((sum, session) => sum + session.duration, 0)
  const averageFocus =
    sessions.length > 0
      ? Math.round(sessions.reduce((sum, session) => sum + session.focusScore, 0) / sessions.length)
      : 0
  const xp = Math.round(
    intelligence.weeklyHours * 120 +
      completedTasks.length * 55 +
      intelligence.streakDays * 28 +
      intelligence.readinessScore * 3,
  )
  const level = Math.max(1, Math.floor(xp / 650) + 1)
  const levelProgress = (xp % 650) / 6.5

  return (
    <Card glass className="cockpit-panel rounded-[1.8rem]">
      <div className="flex items-center justify-between gap-4">
        <div>
          <p className="cockpit-kicker">Altitude Meter</p>
          <h3 className="mt-3 text-xl font-semibold text-[var(--color-text)]">XP and mission climb</h3>
        </div>
        <div className="hud-pill rounded-full px-3 py-2">
          <span className="cockpit-display text-xs font-semibold text-[var(--color-primary)]">LVL {level}</span>
        </div>
      </div>

      <div className="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div className="space-y-4 rounded-[1.6rem] border p-4" style={{ borderColor: 'var(--color-border)', background: 'var(--surface-panel)' }}>
          <div className="flex items-center justify-between gap-3">
            <p className="text-sm uppercase tracking-[0.22em] text-[var(--color-text-muted)]">XP Buffer</p>
            <span className="indicator-blink h-2.5 w-2.5 rounded-full bg-[var(--color-accent-amber)] shadow-[0_0_12px_rgba(255,149,0,0.65)]" />
          </div>
          <p className="cockpit-display text-3xl font-semibold text-[var(--color-primary)]">{xp}</p>
          <div className="h-2 overflow-hidden rounded-full bg-[rgba(0,212,255,0.08)]">
            <div
              className="h-full rounded-full"
              style={{
                width: `${Math.max(levelProgress, 8)}%`,
                background: 'linear-gradient(90deg, var(--color-primary), var(--color-accent-emerald))',
                boxShadow: '0 0 18px rgba(0, 212, 255, 0.35)',
              }}
            />
          </div>
          <p className="text-sm text-[var(--color-text-muted)]">Next level at {(level + 1) * 650} XP</p>
        </div>

        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div className="hud-pill rounded-[1.3rem] p-4">
            <p className="text-xs uppercase tracking-[0.2em] text-[var(--color-text-muted)]">Today's Goal</p>
            <p className="cockpit-display mt-3 text-2xl font-semibold text-[var(--color-text)]">
              {hoursStudied.toFixed(1)}h
            </p>
            <p className="mt-1 text-xs text-[var(--color-text-muted)]">of {intelligence.dailyGoalHours}h</p>
          </div>
          <div className="hud-pill rounded-[1.3rem] p-4">
            <p className="text-xs uppercase tracking-[0.2em] text-[var(--color-text-muted)]">Streak</p>
            <p className="cockpit-display mt-3 text-2xl font-semibold text-[var(--color-accent-emerald)]">
              {intelligence.streakDays}
            </p>
            <p className="mt-1 text-xs text-[var(--color-text-muted)]">focus days</p>
          </div>
          <div className="hud-pill rounded-[1.3rem] p-4">
            <p className="text-xs uppercase tracking-[0.2em] text-[var(--color-text-muted)]">Tasks</p>
            <p className="cockpit-display mt-3 text-2xl font-semibold text-[var(--color-accent-amber)]">
              {completedTasks.length}
            </p>
            <p className="mt-1 text-xs text-[var(--color-text-muted)]">done today</p>
          </div>
          <div className="hud-pill rounded-[1.3rem] p-4">
            <p className="text-xs uppercase tracking-[0.2em] text-[var(--color-text-muted)]">Readiness</p>
            <p className="cockpit-display mt-3 text-2xl font-semibold text-[var(--color-primary)]">
              {intelligence.readinessScore}
            </p>
            <p className="mt-1 text-xs text-[var(--color-text-muted)]">mission score</p>
          </div>
        </div>
      </div>

      <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <CircularGauge label="Focus" value={averageFocus} suffix="%" tone="cyan" size="sm" />
        <CircularGauge
          label="Goal"
          value={Math.min((hoursStudied / Math.max(intelligence.dailyGoalHours, 1)) * 100, 100)}
          suffix="%"
          tone="amber"
          size="sm"
        />
        <CircularGauge label="XP Sync" value={Math.min(intelligence.completionRate, 100)} suffix="%" tone="green" size="sm" />
      </div>
    </Card>
  )
}
