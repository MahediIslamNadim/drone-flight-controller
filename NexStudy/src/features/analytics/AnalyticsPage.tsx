import PageHeader from '../../components/layout/PageHeader'
import Card from '../../components/ui/Card'
import SubjectProgressChart from '../../components/charts/SubjectProgressChart'
import WeeklyStudyChart from '../../components/charts/WeeklyStudyChart'
import { loadSessions, loadStudyWorkspace, loadSubjects, loadTasks, STORAGE_KEYS } from '../../lib/studyData'
import { buildStudyIntelligence } from '../../lib/studyIntelligence'
import { useStudyLiveValue } from '../../lib/useStudyLiveValue'

export default function AnalyticsPage() {
  const { subjects, sessions, tasks } = useStudyLiveValue(
    () => ({
      subjects: loadSubjects(),
      sessions: loadSessions(),
      tasks: loadTasks(),
    }),
    [STORAGE_KEYS.subjects, STORAGE_KEYS.sessions, STORAGE_KEYS.planner],
  )
  const intelligence = useStudyLiveValue(
    () => buildStudyIntelligence(loadStudyWorkspace()),
    [
      STORAGE_KEYS.subjects,
      STORAGE_KEYS.sessions,
      STORAGE_KEYS.planner,
      STORAGE_KEYS.goals,
      STORAGE_KEYS.reminders,
      STORAGE_KEYS.settings,
    ],
  )
  const totalHours = sessions.reduce((sum, session) => sum + session.duration, 0)
  const averageProgress =
    subjects.length > 0
      ? Math.round(subjects.reduce((sum, subject) => sum + subject.progress, 0) / subjects.length)
      : 0
  const completionRate =
    tasks.length > 0 ? Math.round((tasks.filter((task) => task.completed).length / tasks.length) * 100) : 0

  return (
    <div className="space-y-6">
      <PageHeader
        title="Analytics"
        subtitle="Detailed insights into your study habits"
      />
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card glass>
          <p className="text-sm text-[var(--color-text-muted)]">Tracked Hours</p>
          <p className="mt-2 text-3xl font-bold text-[var(--color-text)]">{totalHours.toFixed(1)}h</p>
        </Card>
        <Card glass>
          <p className="text-sm text-[var(--color-text-muted)]">Average Subject Progress</p>
          <p className="mt-2 text-3xl font-bold text-[var(--color-text)]">{averageProgress}%</p>
        </Card>
        <Card glass>
          <p className="text-sm text-[var(--color-text-muted)]">Task Completion</p>
          <p className="mt-2 text-3xl font-bold text-[var(--color-text)]">{completionRate}%</p>
        </Card>
      </div>
      <div className="grid grid-cols-1 xl:grid-cols-[1.2fr_0.8fr] gap-6">
        <Card glass className="space-y-4">
          <div className="flex items-center justify-between gap-4">
            <div>
              <p className="study-kicker">Performance Signals</p>
              <h3 className="mt-3 text-xl font-semibold text-[var(--color-text)]">Study intelligence layer</h3>
            </div>
            <div className="rounded-full px-4 py-2 text-sm font-semibold" style={{ background: 'rgba(31, 111, 100, 0.12)', color: 'var(--color-primary)' }}>
              Readiness {intelligence.readinessScore}
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="study-panel-soft rounded-[1.25rem] p-4">
              <p className="text-sm text-[var(--color-text-muted)]">Streak Strength</p>
              <p className="mt-2 text-2xl font-semibold text-[var(--color-text)]">{intelligence.streakDays} days</p>
              <p className="mt-1 text-sm text-[var(--color-text-muted)]">Consistency beats intensity over time.</p>
            </div>
            <div className="study-panel-soft rounded-[1.25rem] p-4">
              <p className="text-sm text-[var(--color-text-muted)]">Weekly Momentum</p>
              <p className="mt-2 text-2xl font-semibold text-[var(--color-text)]">
                {intelligence.weeklyMomentumHours >= 0 ? '+' : ''}
                {intelligence.weeklyMomentumHours.toFixed(1)}h
              </p>
              <p className="mt-1 text-sm text-[var(--color-text-muted)]">
                {intelligence.weeklyHours.toFixed(1)}h this week vs {intelligence.previousWeeklyHours.toFixed(1)}h last week.
              </p>
            </div>
            <div className="study-panel-soft rounded-[1.25rem] p-4">
              <p className="text-sm text-[var(--color-text-muted)]">Focus Trend</p>
              <p className="mt-2 text-2xl font-semibold capitalize text-[var(--color-text)]">{intelligence.focusTrend}</p>
              <p className="mt-1 text-sm text-[var(--color-text-muted)]">{intelligence.averageFocusToday}% average focus today.</p>
            </div>
          </div>
        </Card>

        <Card glass className="space-y-4">
          <div>
            <p className="study-kicker">Priority Lens</p>
            <h3 className="mt-3 text-xl font-semibold text-[var(--color-text)]">
              {intelligence.topPrioritySubject?.name ?? 'No urgent subject risk'}
            </h3>
            <p className="mt-2 text-sm leading-6 text-[var(--color-text-muted)]">
              {intelligence.topPrioritySubject?.reason ?? 'Your current data does not show a standout risk zone right now.'}
            </p>
          </div>
          <div className="space-y-3">
            {intelligence.insights.map((insight) => (
              <div
                key={insight.id}
                className="rounded-[1.2rem] border px-4 py-4"
                style={{
                  borderColor: 'var(--color-border)',
                  background: insight.tone === 'urgent' ? 'rgba(202, 115, 77, 0.1)' : 'var(--surface-panel)',
                }}
              >
                <p className="font-semibold text-[var(--color-text)]">{insight.title}</p>
                <p className="mt-1 text-sm leading-6 text-[var(--color-text-muted)]">{insight.description}</p>
              </div>
            ))}
          </div>
        </Card>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card glass>
          <h3 className="text-lg font-medium mb-4">Subject Progress</h3>
          <SubjectProgressChart />
        </Card>
        <Card glass>
          <h3 className="text-lg font-medium mb-4">Weekly Overview</h3>
          <WeeklyStudyChart />
        </Card>
      </div>
    </div>
  )
}
