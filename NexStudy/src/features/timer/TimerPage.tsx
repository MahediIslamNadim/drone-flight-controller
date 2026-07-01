import { useEffect, useState } from 'react'
import { Pause, Play, RotateCcw, Settings } from 'lucide-react'
import { useWorkspace } from '../../app/useWorkspace'
import PageHeader from '../../components/layout/PageHeader'
import Card from '../../components/ui/Card'
import Button from '../../components/ui/Button'
import Input from '../../components/ui/Input'
import Modal from '../../components/ui/Modal'
import { loadSettings, saveSettings } from '../../lib/studyData'

function formatTime(seconds: number) {
  const minutes = String(Math.floor(seconds / 60)).padStart(2, '0')
  const remainingSeconds = String(seconds % 60).padStart(2, '0')
  return `${minutes}:${remainingSeconds}`
}

export default function TimerPage() {
  const [settings, setSettings] = useState(loadSettings)
  const [secondsLeft, setSecondsLeft] = useState(() => loadSettings().pomodoroMinutes * 60)
  const [isRunning, setIsRunning] = useState(false)
  const [isSettingsOpen, setIsSettingsOpen] = useState(false)
  const [error, setError] = useState('')
  const { focusModeEnabled, setFocusModeEnabled } = useWorkspace()

  useEffect(() => {
    if (!isRunning) {
      return
    }

    const intervalId = window.setInterval(() => {
      setSecondsLeft((current) => {
        if (current <= 1) {
          window.clearInterval(intervalId)
          setIsRunning(false)
          return 0
        }

        return current - 1
      })
    }, 1000)

    return () => window.clearInterval(intervalId)
  }, [isRunning])

  function resetTimer() {
    setIsRunning(false)
    setSecondsLeft(settings.pomodoroMinutes * 60)
  }

  function closeSettings() {
    setSettings(loadSettings())
    setError('')
    setIsSettingsOpen(false)
  }

  function saveTimerSettings() {
    if (settings.pomodoroMinutes < 5) {
      setError('Pomodoro minutes must be at least 5.')
      return
    }

    if (settings.shortBreakMinutes < 1) {
      setError('Short break minutes must be at least 1.')
      return
    }

    saveSettings(settings)
    setSecondsLeft(settings.pomodoroMinutes * 60)
    setIsSettingsOpen(false)
    setIsRunning(false)
    setError('')
  }

  function handleToggleTimer() {
    if (isRunning) {
      setIsRunning(false)
      return
    }

    if (secondsLeft === 0) {
      setSecondsLeft(settings.pomodoroMinutes * 60)
    }

    if (!focusModeEnabled) {
      setFocusModeEnabled(true)
    }

    setIsRunning(true)
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Pomodoro Timer"
        subtitle="Focus on your study sessions"
        actions={
          <Button
            variant="ghost"
            icon={<Settings size={18} />}
            type="button"
            onClick={() => {
              setSettings(loadSettings())
              setIsSettingsOpen(true)
            }}
          >
            Settings
          </Button>
        }
      />
      <div className="flex justify-center mt-12">
        <Card glass className="w-full max-w-md space-y-8 text-center">
          <div>
            <p className="text-sm text-[var(--color-text-muted)]">
              Focus session{focusModeEnabled ? ' • deep work mode' : ''}
            </p>
            <p className="mt-4 text-6xl font-bold text-[var(--color-text)]">{formatTime(secondsLeft)}</p>
          </div>
          <div className="flex items-center justify-center gap-3">
            <Button
              type="button"
              icon={isRunning ? <Pause size={18} /> : <Play size={18} />}
              onClick={handleToggleTimer}
            >
              {isRunning ? 'Pause' : 'Start'}
            </Button>
            <Button type="button" variant="secondary" icon={<RotateCcw size={18} />} onClick={resetTimer}>
              Reset
            </Button>
          </div>
          <p className="text-sm text-[var(--color-text-muted)]">
            Pomodoro: {settings.pomodoroMinutes} min | Break: {settings.shortBreakMinutes} min
          </p>
          <Button
            type="button"
            variant="ghost"
            onClick={() => setFocusModeEnabled(!focusModeEnabled)}
          >
            {focusModeEnabled ? 'Exit Focus Mode' : 'Enter Focus Mode'}
          </Button>
        </Card>
      </div>

      <Modal isOpen={isSettingsOpen} onClose={closeSettings} title="Timer Settings">
        <div className="space-y-4">
          <Input
            label="Pomodoro Minutes"
            type="number"
            min="5"
            value={String(settings.pomodoroMinutes)}
            onChange={(event) =>
              setSettings((current) => ({
                ...current,
                pomodoroMinutes: Number(event.target.value || 0),
              }))
            }
          />
          <Input
            label="Short Break Minutes"
            type="number"
            min="1"
            value={String(settings.shortBreakMinutes)}
            onChange={(event) =>
              setSettings((current) => ({
                ...current,
                shortBreakMinutes: Number(event.target.value || 0),
              }))
            }
          />
          {error && <p className="text-sm text-[var(--color-accent-rose)]">{error}</p>}
          <div className="flex justify-end gap-3">
            <Button type="button" variant="secondary" onClick={closeSettings}>
              Cancel
            </Button>
            <Button type="button" onClick={saveTimerSettings}>
              Save Settings
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  )
}
