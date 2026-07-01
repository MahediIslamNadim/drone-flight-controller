import PageHeader from '../../components/layout/PageHeader'
import StudyCoachPanel from './StudyCoachPanel'
import TodaySummary from './TodaySummary'
import QuickActions from './QuickActions'
import UpcomingItems from './UpcomingItems'
import { loadStudyWorkspace, STORAGE_KEYS } from '../../lib/studyData'
import { buildStudyIntelligence } from '../../lib/studyIntelligence'
import { useStudyLiveValue } from '../../lib/useStudyLiveValue'

export default function DashboardPage() {
  const intelligence = useStudyLiveValue(
    () => {
      const workspace = loadStudyWorkspace()
      return buildStudyIntelligence(workspace)
    },
    [
      STORAGE_KEYS.subjects,
      STORAGE_KEYS.sessions,
      STORAGE_KEYS.planner,
      STORAGE_KEYS.notes,
      STORAGE_KEYS.goals,
      STORAGE_KEYS.reminders,
      STORAGE_KEYS.settings,
    ],
  )

  return (
    <div className="space-y-6">
      <PageHeader
        title="Study Cockpit"
        subtitle="A panoramic command center for missions, timers, subject modules, and focus telemetry."
      />

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <div className="hud-pill rounded-[1.35rem] px-4 py-4">
          <p className="text-xs uppercase tracking-[0.24em] text-[var(--color-text-muted)]">HUD Goal</p>
          <p className="cockpit-display mt-2 text-2xl font-semibold text-[var(--color-primary)]">
            {intelligence.todayHours.toFixed(1)}h
          </p>
        </div>
        <div className="hud-pill rounded-[1.35rem] px-4 py-4">
          <p className="text-xs uppercase tracking-[0.24em] text-[var(--color-text-muted)]">XP Points</p>
          <p className="cockpit-display mt-2 text-2xl font-semibold text-[var(--color-accent-emerald)]">
            {Math.round(intelligence.weeklyHours * 100 + intelligence.streakDays * 24)}
          </p>
        </div>
        <div className="hud-pill rounded-[1.35rem] px-4 py-4">
          <p className="text-xs uppercase tracking-[0.24em] text-[var(--color-text-muted)]">Focus Streak</p>
          <p className="cockpit-display mt-2 text-2xl font-semibold text-[var(--color-accent-amber)]">
            {intelligence.streakDays}d
          </p>
        </div>
        <div className="hud-pill rounded-[1.35rem] px-4 py-4">
          <p className="text-xs uppercase tracking-[0.24em] text-[var(--color-text-muted)]">Threat Level</p>
          <p className="cockpit-display mt-2 text-2xl font-semibold text-[var(--color-text)]">
            {intelligence.overdueTaskCount + intelligence.dueSoonTaskCount}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-5 xl:grid-cols-[17rem_minmax(0,1fr)_18rem]">
        <div className="order-2 space-y-5 xl:order-1">
          <QuickActions />
          <UpcomingItems />
        </div>

        <div className="order-1 xl:order-2">
          <StudyCoachPanel />
        </div>

        <div className="order-3">
          <TodaySummary />
        </div>
      </div>
    </div>
  )
}
