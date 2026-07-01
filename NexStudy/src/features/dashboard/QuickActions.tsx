import { ArrowRight, BookOpen, GaugeCircle, Plus, Timer } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import Card from '../../components/ui/Card'
import Button from '../../components/ui/Button'
import { loadStudyWorkspace, STORAGE_KEYS } from '../../lib/studyData'
import { buildStudyIntelligence } from '../../lib/studyIntelligence'
import { useStudyLiveValue } from '../../lib/useStudyLiveValue'

export default function QuickActions() {
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
  const primaryAction = intelligence.insights[0]
  const energy = intelligence.focusTrend === 'rising' ? 'Nominal' : intelligence.focusTrend === 'falling' ? 'Caution' : 'Stable'

  return (
    <Card glass className="cockpit-panel rounded-[1.8rem]">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="cockpit-kicker">Flight Timer</p>
          <h3 className="mt-3 text-xl font-semibold text-[var(--color-text)]">Focus propulsion controls</h3>
        </div>
        <span className="indicator-pulse inline-flex h-3 w-3 rounded-full bg-[var(--color-primary)] shadow-[0_0_18px_rgba(0,212,255,0.8)]" />
      </div>

      <div className="mt-5 grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div className="hud-pill rounded-[1.2rem] p-4">
          <p className="text-xs uppercase tracking-[0.22em] text-[var(--color-text-muted)]">Pomodoro</p>
          <p className="cockpit-display mt-3 text-2xl font-semibold text-[var(--color-primary)]">
            {workspace.settings.pomodoroMinutes}m
          </p>
        </div>
        <div className="hud-pill rounded-[1.2rem] p-4">
          <p className="text-xs uppercase tracking-[0.22em] text-[var(--color-text-muted)]">Engine Status</p>
          <p className="cockpit-display mt-3 break-words text-2xl font-semibold text-[var(--color-accent-emerald)]">
            {energy}
          </p>
        </div>
      </div>

      {primaryAction && (
        <button
          type="button"
          onClick={() => navigate(primaryAction.route)}
          className="mt-4 w-full rounded-[1.45rem] border px-4 py-4 text-left transition-all hover:-translate-y-0.5"
          style={{
            borderColor: 'var(--color-border)',
            background: 'linear-gradient(135deg, rgba(0, 212, 255, 0.08), rgba(255, 149, 0, 0.08))',
            boxShadow: '0 0 26px rgba(0, 212, 255, 0.12)',
          }}
        >
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-xs uppercase tracking-[0.22em] text-[var(--color-text-muted)]">Mission Control</p>
              <p className="mt-2 font-semibold text-[var(--color-text)]">{primaryAction.title}</p>
              <p className="mt-1 text-sm leading-6 text-[var(--color-text-muted)]">{primaryAction.description}</p>
            </div>
            <ArrowRight size={18} className="mt-1 shrink-0 text-[var(--color-primary)]" />
          </div>
        </button>
      )}

      <div className="mt-5 flex flex-col gap-3">
        <Button variant="secondary" icon={<Timer size={16} />} className="w-full justify-between" onClick={() => navigate('/timer')}>
          Engage Focus Timer
          <ArrowRight size={14} />
        </Button>
        <Button variant="secondary" icon={<BookOpen size={16} />} className="w-full justify-between" onClick={() => navigate('/tracker')}>
          Log Flight Session
          <ArrowRight size={14} />
        </Button>
        <Button variant="secondary" icon={<Plus size={16} />} className="w-full justify-between" onClick={() => navigate('/planner')}>
          Arm New Mission
          <ArrowRight size={14} />
        </Button>
      </div>

      <div className="mt-5 rounded-[1.4rem] border p-4" style={{ borderColor: 'var(--color-border)', background: 'rgba(0, 212, 255, 0.04)' }}>
        <div className="flex items-center gap-3">
          <div className="study-icon-chip sky">
            <GaugeCircle size={18} />
          </div>
          <div>
            <p className="text-sm text-[var(--color-text)]">Focus mode</p>
            <p className="mt-1 text-xs text-[var(--color-text-muted)]">
              {workspace.settings.focusModeEnabled ? 'Cockpit noise reduced for deep work.' : 'Standby. Enable focus mode for a cleaner HUD.'}
            </p>
          </div>
        </div>
      </div>
    </Card>
  )
}
