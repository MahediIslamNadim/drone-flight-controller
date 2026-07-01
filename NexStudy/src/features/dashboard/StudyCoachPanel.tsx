import { ArrowRight, BrainCircuit, Radar, Sparkles } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import Card from '../../components/ui/Card'
import Button from '../../components/ui/Button'
import CircularGauge from '../../components/ui/CircularGauge'
import DailyStudyChart from '../../components/charts/DailyStudyChart'
import { loadStudyWorkspace, STORAGE_KEYS } from '../../lib/studyData'
import { buildStudyIntelligence } from '../../lib/studyIntelligence'
import { useStudyLiveValue } from '../../lib/useStudyLiveValue'

export default function StudyCoachPanel() {
  const navigate = useNavigate()
  const { workspace, intelligence } = useStudyLiveValue(
    () => {
      const workspace = loadStudyWorkspace()

      return {
        workspace,
        intelligence: buildStudyIntelligence(workspace),
      }
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

  const openTasks = workspace.tasks
    .filter((task) => !task.completed)
    .sort((a, b) => a.dueDate.localeCompare(b.dueDate))
    .slice(0, 3)

  const subjectModules = [...workspace.subjects]
    .sort((a, b) => a.progress - b.progress)
    .slice(0, 4)

  return (
    <Card glass className="cockpit-panel cockpit-canopy rounded-[2.2rem] p-0">
      <div className="grid gap-0 xl:grid-cols-[minmax(0,1.2fr)_20rem]">
        <div className="p-5 md:p-6">
          <div className="flex flex-col gap-5 lg:flex-row lg:items-start lg:justify-between">
            <div className="max-w-2xl min-w-0">
              <p className="cockpit-kicker">Mission Control</p>
              <h3 className="mt-3 text-xl font-semibold leading-tight text-[var(--color-text)] sm:text-2xl md:text-[2.3rem]">
                Pilot your learning like a high-altitude command mission.
              </h3>
              <p className="mt-3 max-w-xl text-sm leading-7 text-[var(--color-text-muted)]">
                The cockpit is tracking study velocity, subject pressure, reminders, and mission completion to keep you on course.
              </p>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-2">
              <div className="hud-pill rounded-[1.2rem] px-4 py-3">
                <p className="text-xs uppercase tracking-[0.24em] text-[var(--color-text-muted)]">Today's Goal</p>
                <p className="cockpit-display mt-2 text-xl font-semibold text-[var(--color-primary)]">
                  {intelligence.todayHours.toFixed(1)}h
                </p>
              </div>
              <div className="hud-pill rounded-[1.2rem] px-4 py-3">
                <p className="text-xs uppercase tracking-[0.24em] text-[var(--color-text-muted)]">XP</p>
                <p className="cockpit-display mt-2 text-xl font-semibold text-[var(--color-accent-emerald)]">
                  {Math.round(intelligence.weeklyHours * 100 + intelligence.streakDays * 24)}
                </p>
              </div>
              <div className="hud-pill rounded-[1.2rem] px-4 py-3">
                <p className="text-xs uppercase tracking-[0.24em] text-[var(--color-text-muted)]">Streak</p>
                <p className="cockpit-display mt-2 text-xl font-semibold text-[var(--color-accent-amber)]">
                  {intelligence.streakDays}d
                </p>
              </div>
              <div className="hud-pill rounded-[1.2rem] px-4 py-3">
                <p className="text-xs uppercase tracking-[0.24em] text-[var(--color-text-muted)]">Readiness</p>
                <p className="cockpit-display mt-2 text-xl font-semibold text-[var(--color-text)]">
                  {intelligence.readinessScore}
                </p>
              </div>
            </div>
          </div>

          <div className="mt-6 grid gap-5 xl:grid-cols-[minmax(0,1.05fr)_18rem]">
            <div
              className="rounded-[1.8rem] border p-4 md:p-5"
              style={{
                borderColor: 'var(--color-border)',
                background: 'linear-gradient(180deg, rgba(0, 212, 255, 0.06), rgba(8, 11, 26, 0.92))',
              }}
            >
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="cockpit-kicker">Windshield View</p>
                  <h4 className="mt-3 text-lg font-semibold text-[var(--color-text)]">Flight path over the last 7 days</h4>
                </div>
                <div className="study-icon-chip info indicator-pulse">
                  <Radar size={18} />
                </div>
              </div>
              <div
                className="mt-5 rounded-[1.4rem] border p-3"
                style={{ borderColor: 'var(--color-border)', background: 'rgba(0, 212, 255, 0.04)' }}
              >
                <DailyStudyChart />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 xl:grid-cols-1">
              <CircularGauge label="Focus" value={intelligence.averageFocusToday} suffix="%" tone="cyan" />
              <CircularGauge label="Energy" value={intelligence.readinessScore} suffix="%" tone="green" />
              <CircularGauge label="Progress" value={intelligence.completionRate} suffix="%" tone="amber" />
            </div>
          </div>

          <div className="mt-6 grid gap-5 lg:grid-cols-2">
            <div
              className="rounded-[1.65rem] border p-5"
              style={{ borderColor: 'var(--color-border)', background: 'var(--surface-panel)' }}
            >
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="cockpit-kicker">Navigation Map</p>
                  <h4 className="mt-3 text-lg font-semibold text-[var(--color-text)]">Subject roadmap</h4>
                </div>
                <span className="indicator-blink h-2.5 w-2.5 rounded-full bg-[var(--color-primary)] shadow-[0_0_12px_rgba(0,212,255,0.65)]" />
              </div>

              <div className="mt-5 space-y-4">
                {subjectModules.length === 0 && (
                  <p className="text-sm text-[var(--color-text-muted)]">Add subjects to unlock navigation modules.</p>
                )}
                {subjectModules.map((subject) => (
                  <div key={subject.id} className="rounded-[1.25rem] border p-4" style={{ borderColor: 'var(--color-border)' }}>
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <p className="font-semibold text-[var(--color-text)]">{subject.name}</p>
                        <p className="mt-1 text-xs uppercase tracking-[0.2em] text-[var(--color-text-muted)]">
                          {subject.category} module
                        </p>
                      </div>
                      <span className="cockpit-display shrink-0 text-sm font-semibold text-[var(--color-primary)]">
                        {subject.progress}%
                      </span>
                    </div>
                    <div className="mt-3 h-2 overflow-hidden rounded-full bg-[rgba(0,212,255,0.06)]">
                      <div
                        className="h-full rounded-full"
                        style={{
                          width: `${subject.progress}%`,
                          background: 'linear-gradient(90deg, var(--color-primary), var(--color-accent-emerald))',
                          boxShadow: '0 0 12px rgba(0, 212, 255, 0.28)',
                        }}
                      />
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div
              className="rounded-[1.65rem] border p-5"
              style={{ borderColor: 'var(--color-border)', background: 'var(--surface-panel)' }}
            >
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="cockpit-kicker">Mission Queue</p>
                  <h4 className="mt-3 text-lg font-semibold text-[var(--color-text)]">Today's study plan</h4>
                </div>
                <div className="study-icon-chip warm">
                  <Sparkles size={18} />
                </div>
              </div>

              <div className="mt-5 space-y-3">
                {openTasks.length === 0 && (
                  <p className="text-sm text-[var(--color-text-muted)]">No open missions. You're clear for deep work.</p>
                )}

                {openTasks.map((task) => (
                  <div
                    key={task.id}
                    className="rounded-[1.25rem] border p-4"
                    style={{
                      borderColor: task.priority === 'High' ? 'rgba(255, 149, 0, 0.28)' : 'var(--color-border)',
                      background: task.priority === 'High' ? 'rgba(255, 149, 0, 0.08)' : 'rgba(0, 212, 255, 0.04)',
                    }}
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <p className="font-semibold text-[var(--color-text)]">{task.title}</p>
                        <p className="mt-1 text-sm text-[var(--color-text-muted)]">{task.subject} | due {task.dueDate}</p>
                      </div>
                      <span className="cockpit-display shrink-0 text-[0.68rem] uppercase tracking-[0.24em] text-[var(--color-accent-amber)]">
                        {task.priority}
                      </span>
                    </div>
                  </div>
                ))}
              </div>

              <div className="mt-5 space-y-3">
                {intelligence.insights.map((insight) => (
                  <button
                    key={insight.id}
                    type="button"
                    onClick={() => navigate(insight.route)}
                    className="w-full rounded-[1.25rem] border px-4 py-4 text-left transition-all hover:-translate-y-0.5"
                    style={{
                      borderColor: 'var(--color-border)',
                      background:
                        insight.tone === 'urgent'
                          ? 'linear-gradient(135deg, rgba(255, 149, 0, 0.12), rgba(10, 14, 39, 0.92))'
                          : 'rgba(0, 212, 255, 0.05)',
                    }}
                  >
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex items-start gap-3">
                        <div className={`study-icon-chip ${insight.tone === 'urgent' ? 'warm' : 'info'} h-10 w-10 rounded-[1rem]`}>
                          <BrainCircuit size={16} />
                        </div>
                        <div>
                          <p className="font-semibold text-[var(--color-text)]">{insight.title}</p>
                          <p className="mt-1 text-sm leading-6 text-[var(--color-text-muted)]">{insight.description}</p>
                        </div>
                      </div>
                      <ArrowRight size={18} className="shrink-0 text-[var(--color-primary)]" />
                    </div>
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>

        <div className="border-t p-5 xl:border-l xl:border-t-0 md:p-6" style={{ borderColor: 'var(--color-border)' }}>
          <div className="space-y-4">
            <div className="rounded-[1.5rem] border p-4" style={{ borderColor: 'var(--color-border)', background: 'rgba(0, 212, 255, 0.05)' }}>
              <p className="cockpit-kicker">HUD Overlay</p>
              <p className="mt-3 text-sm leading-6 text-[var(--color-text-muted)]">
                Today's best route is to push {Math.max(intelligence.dailyGoalHours - intelligence.todayHours, 0).toFixed(1)}h more and stabilize the {intelligence.focusTrend} focus trend.
              </p>
            </div>

            <div className="rounded-[1.5rem] border p-4" style={{ borderColor: 'var(--color-border)', background: 'rgba(255, 149, 0, 0.07)' }}>
              <p className="cockpit-kicker">Threat Level</p>
              <p className="cockpit-display mt-3 text-3xl font-semibold text-[var(--color-accent-amber)]">
                {intelligence.overdueTaskCount + intelligence.dueSoonTaskCount}
              </p>
              <p className="mt-2 text-sm text-[var(--color-text-muted)]">
                tasks or exams need immediate awareness.
              </p>
            </div>

            <Button type="button" className="w-full justify-between" onClick={() => navigate('/analytics')}>
              Open Full Telemetry
              <ArrowRight size={16} />
            </Button>
          </div>
        </div>
      </div>
    </Card>
  )
}
