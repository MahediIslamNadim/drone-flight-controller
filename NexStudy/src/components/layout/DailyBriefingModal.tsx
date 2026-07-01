import { ArrowRight, BrainCircuit, Sparkles, Target, TrendingUp } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { useWorkspace } from '../../app/useWorkspace'
import { buildStudyIntelligence } from '../../lib/studyIntelligence'
import { loadStudyWorkspace, STORAGE_KEYS } from '../../lib/studyData'
import { useStudyLiveValue } from '../../lib/useStudyLiveValue'
import Button from '../ui/Button'
import Modal from '../ui/Modal'

function getMomentumLabel(momentum: number) {
  if (momentum > 0.4) return 'Up'
  if (momentum < -0.4) return 'Down'
  return 'Stable'
}

export default function DailyBriefingModal() {
  const navigate = useNavigate()
  const { isDailyBriefingOpen, closeDailyBriefing, setFocusModeEnabled } = useWorkspace()
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

  return (
    <Modal isOpen={isDailyBriefingOpen} onClose={closeDailyBriefing} title="Daily Briefing">
      <div className="space-y-5">
        <div
          className="rounded-[1.5rem] border p-5"
          style={{
            borderColor: 'var(--color-border)',
            background: 'linear-gradient(135deg, rgba(31, 111, 100, 0.14), rgba(115, 150, 171, 0.1))',
          }}
        >
          <p className="study-kicker">Morning Sync</p>
          <div className="mt-4 flex flex-wrap items-end justify-between gap-4">
            <div>
              <h3 className="text-2xl font-semibold text-[var(--color-text)]">Readiness score {intelligence.readinessScore}</h3>
              <p className="mt-2 max-w-xl text-sm leading-6 text-[var(--color-text-muted)]">
                You have {intelligence.todayHours.toFixed(1)}h logged today, {intelligence.overdueTaskCount} overdue tasks, and a {intelligence.focusTrend} focus trend.
              </p>
            </div>
            <div className="study-icon-chip info h-14 w-14 rounded-[1.2rem]">
              <BrainCircuit size={22} />
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          <div className="study-panel-soft rounded-[1.25rem] p-4">
            <div className="flex items-center gap-3">
              <div className="study-icon-chip warm">
                <Sparkles size={18} />
              </div>
              <div>
                <p className="text-sm text-[var(--color-text-muted)]">Streak</p>
                <p className="mt-1 text-xl font-semibold text-[var(--color-text)]">{intelligence.streakDays} days</p>
              </div>
            </div>
          </div>
          <div className="study-panel-soft rounded-[1.25rem] p-4">
            <div className="flex items-center gap-3">
              <div className="study-icon-chip info">
                <Target size={18} />
              </div>
              <div>
                <p className="text-sm text-[var(--color-text-muted)]">Goal Gap</p>
                <p className="mt-1 text-xl font-semibold text-[var(--color-text)]">
                  {Math.max(intelligence.dailyGoalHours - intelligence.todayHours, 0).toFixed(1)}h
                </p>
              </div>
            </div>
          </div>
          <div className="study-panel-soft rounded-[1.25rem] p-4">
            <div className="flex items-center gap-3">
              <div className="study-icon-chip sky">
                <TrendingUp size={18} />
              </div>
              <div>
                <p className="text-sm text-[var(--color-text-muted)]">Momentum</p>
                <p className="mt-1 text-xl font-semibold text-[var(--color-text)]">{getMomentumLabel(intelligence.weeklyMomentumHours)}</p>
              </div>
            </div>
          </div>
        </div>

        <div className="space-y-3">
          {intelligence.insights.map((insight) => (
            <div
              key={insight.id}
              className="rounded-[1.25rem] border p-4"
              style={{
                borderColor: 'var(--color-border)',
                background: insight.tone === 'urgent' ? 'rgba(202, 115, 77, 0.12)' : 'var(--surface-panel)',
              }}
            >
              <p className="font-semibold text-[var(--color-text)]">{insight.title}</p>
              <p className="mt-1 text-sm leading-6 text-[var(--color-text-muted)]">{insight.description}</p>
            </div>
          ))}
        </div>

        <div className="flex flex-col justify-end gap-3 sm:flex-row">
          <Button type="button" variant="secondary" onClick={closeDailyBriefing}>
            Dismiss
          </Button>
          <Button
            type="button"
            variant="secondary"
            onClick={() => {
              setFocusModeEnabled(true)
              closeDailyBriefing()
              navigate('/timer')
            }}
          >
            Enter Focus Mode
          </Button>
          <Button
            type="button"
            onClick={() => {
              closeDailyBriefing()
              navigate(intelligence.insights[0]?.route ?? '/analytics')
            }}
            icon={<ArrowRight size={16} />}
          >
            {intelligence.insights[0]?.actionLabel ?? 'Open Analytics'}
          </Button>
        </div>
      </div>
    </Modal>
  )
}
