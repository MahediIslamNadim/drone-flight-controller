import { useRef, useState, type ChangeEvent } from 'react'
import { Database, Download, RotateCcw, Save, Upload } from 'lucide-react'
import { useTheme } from '../../app/useTheme'
import PageHeader from '../../components/layout/PageHeader'
import Card from '../../components/ui/Card'
import Button from '../../components/ui/Button'
import Input from '../../components/ui/Input'
import Select from '../../components/ui/Select'
import {
  REMINDER_CHANNEL_OPTIONS,
  STORAGE_KEYS,
  THEME_MODE_OPTIONS,
  createStudyWorkspaceBackup,
  importStudyWorkspaceBackup,
  loadSettings,
  loadStudyWorkspace,
  resetStudyWorkspace,
  type ReminderChannel,
  type ThemeMode,
  saveSettings,
} from '../../lib/studyData'
import { useStudyLiveValue } from '../../lib/useStudyLiveValue'

export default function SettingsPage() {
  const [settings, setSettings] = useState(loadSettings)
  const [savedMessage, setSavedMessage] = useState('')
  const [errorMessage, setErrorMessage] = useState('')
  const [isResetArmed, setIsResetArmed] = useState(false)
  const { themeMode, setThemeMode } = useTheme()
  const importInputRef = useRef<HTMLInputElement>(null)
  const workspace = useStudyLiveValue(loadStudyWorkspace, [
    STORAGE_KEYS.subjects,
    STORAGE_KEYS.sessions,
    STORAGE_KEYS.planner,
    STORAGE_KEYS.notes,
    STORAGE_KEYS.goals,
    STORAGE_KEYS.reminders,
    STORAGE_KEYS.flashcards,
    STORAGE_KEYS.timetable,
    STORAGE_KEYS.settings,
  ])

  function handleSave() {
    if (settings.dailyStudyGoal < 1) {
      setErrorMessage('Daily goal must be at least 1 hour.')
      setSavedMessage('')
      setIsResetArmed(false)
      return
    }

    if (settings.pomodoroMinutes < 5) {
      setErrorMessage('Pomodoro minutes must be at least 5.')
      setSavedMessage('')
      setIsResetArmed(false)
      return
    }

    if (settings.shortBreakMinutes < 1) {
      setErrorMessage('Short break minutes must be at least 1.')
      setSavedMessage('')
      setIsResetArmed(false)
      return
    }

    saveSettings({ ...settings, themeMode })
    setErrorMessage('')
    setSavedMessage('Settings saved successfully.')
    setIsResetArmed(false)
  }

  function clearNotices() {
    setSavedMessage('')
    setErrorMessage('')
    setIsResetArmed(false)
  }

  function handleExportBackup() {
    const backup = createStudyWorkspaceBackup()
    const exportUrl = URL.createObjectURL(
      new Blob([JSON.stringify(backup, null, 2)], { type: 'application/json' }),
    )
    const link = document.createElement('a')
    link.href = exportUrl
    link.download = `nexstudy-backup-${backup.exportedAt.slice(0, 10)}.json`
    link.click()
    URL.revokeObjectURL(exportUrl)
    setErrorMessage('')
    setSavedMessage('Workspace backup exported successfully.')
    setIsResetArmed(false)
  }

  async function handleImportBackup(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]

    if (!file) {
      return
    }

    try {
      const rawText = await file.text()
      importStudyWorkspaceBackup(JSON.parse(rawText))
      setSettings(loadSettings())
      setErrorMessage('')
      setSavedMessage(`Imported backup from ${file.name}.`)
      setIsResetArmed(false)
    } catch (error) {
      setSavedMessage('')
      setErrorMessage(error instanceof Error ? error.message : 'Unable to import this backup file.')
    } finally {
      event.target.value = ''
    }
  }

  function handleResetWorkspace() {
    if (!isResetArmed) {
      setSavedMessage('')
      setErrorMessage('Press Start Fresh again to clear your local study workspace.')
      setIsResetArmed(true)
      return
    }

    resetStudyWorkspace()
    setSettings(loadSettings())
    setErrorMessage('')
    setSavedMessage('Workspace reset complete. You now have a fresh study setup.')
    setIsResetArmed(false)
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Settings"
        subtitle="Configure your NexStudy experience"
        actions={<Button icon={<Save size={18} />} type="button" onClick={handleSave}>Save Changes</Button>}
      />
      <div className="max-w-2xl space-y-6">
        <Card glass className="space-y-4">
          <h3 className="text-lg font-medium text-[var(--color-text)]">Profile Settings</h3>
          <Input
            label="Full Name"
            value={settings.fullName}
            onChange={(event) => {
              clearNotices()
              setSettings((current) => ({ ...current, fullName: event.target.value }))
            }}
          />
          <Input
            label="Email"
            type="email"
            value={settings.email}
            onChange={(event) => {
              clearNotices()
              setSettings((current) => ({ ...current, email: event.target.value }))
            }}
          />
        </Card>
        <Card glass className="space-y-4">
          <h3 className="text-lg font-medium text-[var(--color-text)]">Preferences</h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <Input
              label="Daily Goal (hours)"
              type="number"
              min="1"
              value={String(settings.dailyStudyGoal)}
              onChange={(event) => {
                clearNotices()
                setSettings((current) => ({ ...current, dailyStudyGoal: Number(event.target.value || 0) }))
              }}
            />
            <Select
              label="Reminder Channel"
              options={[...REMINDER_CHANNEL_OPTIONS]}
              value={settings.reminderChannel}
              onChange={(event) => {
                clearNotices()
                setSettings((current) => ({ ...current, reminderChannel: event.target.value as ReminderChannel }))
              }}
            />
            <Select
              label="Appearance"
              options={[...THEME_MODE_OPTIONS]}
              value={themeMode}
              onChange={(event) => {
                const nextThemeMode = event.target.value as ThemeMode
                clearNotices()
                setThemeMode(nextThemeMode)
                setSettings((current) => ({ ...current, themeMode: nextThemeMode }))
              }}
            />
            <Input
              label="Pomodoro Minutes"
              type="number"
              min="5"
              value={String(settings.pomodoroMinutes)}
              onChange={(event) => {
                clearNotices()
                setSettings((current) => ({ ...current, pomodoroMinutes: Number(event.target.value || 0) }))
              }}
            />
            <Input
              label="Short Break Minutes"
              type="number"
              min="1"
              value={String(settings.shortBreakMinutes)}
              onChange={(event) => {
                clearNotices()
                setSettings((current) => ({ ...current, shortBreakMinutes: Number(event.target.value || 0) }))
              }}
            />
          </div>
          <label className="flex items-center gap-3 text-sm text-[var(--color-text)]">
            <input
              type="checkbox"
              checked={settings.notificationsEnabled}
              onChange={(event) => {
                clearNotices()
                setSettings((current) => ({ ...current, notificationsEnabled: event.target.checked }))
              }}
            />
            Enable reminders and session notifications
          </label>
          <label className="flex items-center gap-3 text-sm text-[var(--color-text)]">
            <input
              type="checkbox"
              checked={settings.focusModeEnabled}
              onChange={(event) => {
                clearNotices()
                setSettings((current) => ({ ...current, focusModeEnabled: event.target.checked }))
              }}
            />
            Keep focus mode available across the workspace
          </label>
          <label className="flex items-center gap-3 text-sm text-[var(--color-text)]">
            <input
              type="checkbox"
              checked={settings.dailyBriefingEnabled}
              onChange={(event) => {
                clearNotices()
                setSettings((current) => ({ ...current, dailyBriefingEnabled: event.target.checked }))
              }}
            />
            Show one smart daily briefing each day
          </label>
          {errorMessage && <p className="text-sm text-[var(--color-accent-rose)]">{errorMessage}</p>}
          {savedMessage && <p className="text-sm text-[var(--color-accent-emerald)]">{savedMessage}</p>}
        </Card>
        <Card glass className="space-y-5">
          <div className="flex items-start justify-between gap-4">
            <div>
              <h3 className="text-lg font-medium text-[var(--color-text)]">Workspace Tools</h3>
              <p className="mt-1 text-sm text-[var(--color-text-muted)]">
                Export your study setup, restore it on another device, or start fresh without touching the codebase.
              </p>
            </div>
            <div className="study-icon-chip warm">
              <Database size={20} />
            </div>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="rounded-xl border p-4" style={{ borderColor: 'var(--color-border)' }}>
              <p className="text-xs uppercase tracking-[0.18em] text-[var(--color-text-muted)]">Subjects</p>
              <p className="mt-2 text-2xl font-semibold text-[var(--color-text)]">{workspace.subjects.length}</p>
            </div>
            <div className="rounded-xl border p-4" style={{ borderColor: 'var(--color-border)' }}>
              <p className="text-xs uppercase tracking-[0.18em] text-[var(--color-text-muted)]">Sessions</p>
              <p className="mt-2 text-2xl font-semibold text-[var(--color-text)]">{workspace.sessions.length}</p>
            </div>
            <div className="rounded-xl border p-4" style={{ borderColor: 'var(--color-border)' }}>
              <p className="text-xs uppercase tracking-[0.18em] text-[var(--color-text-muted)]">Tasks</p>
              <p className="mt-2 text-2xl font-semibold text-[var(--color-text)]">{workspace.tasks.length}</p>
            </div>
            <div className="rounded-xl border p-4" style={{ borderColor: 'var(--color-border)' }}>
              <p className="text-xs uppercase tracking-[0.18em] text-[var(--color-text-muted)]">Notes</p>
              <p className="mt-2 text-2xl font-semibold text-[var(--color-text)]">{workspace.notes.length}</p>
            </div>
          </div>

          <div className="flex flex-col gap-3 md:flex-row">
            <Button type="button" variant="secondary" icon={<Download size={16} />} onClick={handleExportBackup}>
              Export Backup
            </Button>
            <Button
              type="button"
              variant="secondary"
              icon={<Upload size={16} />}
              onClick={() => importInputRef.current?.click()}
            >
              Import Backup
            </Button>
            <Button
              type="button"
              variant="danger"
              icon={<RotateCcw size={16} />}
              onClick={handleResetWorkspace}
            >
              {isResetArmed ? 'Confirm Start Fresh' : 'Start Fresh'}
            </Button>
          </div>

          <input
            ref={importInputRef}
            type="file"
            accept="application/json"
            className="hidden"
            onChange={handleImportBackup}
          />
        </Card>
      </div>
    </div>
  )
}
