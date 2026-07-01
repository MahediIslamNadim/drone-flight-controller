import { useEffect, useState } from 'react'
import { BellPlus } from 'lucide-react'
import PageHeader from '../../components/layout/PageHeader'
import Card from '../../components/ui/Card'
import Button from '../../components/ui/Button'
import Input from '../../components/ui/Input'
import Select from '../../components/ui/Select'
import Modal from '../../components/ui/Modal'
import Badge from '../../components/ui/Badge'
import {
  REMINDER_CHANNEL_OPTIONS,
  type ReminderChannel,
  type ReminderItem,
  loadReminders,
  saveReminders,
} from '../../lib/studyData'
import { getEscalatedReminders, type ReminderUrgency } from '../../lib/studyIntelligence'

interface ReminderFormState {
  title: string
  remindAt: string
  channel: ReminderChannel
}

const INITIAL_FORM: ReminderFormState = {
  title: '',
  remindAt: '',
  channel: 'App',
}

const URGENCY_META: Record<ReminderUrgency, { label: string; badge: 'danger' | 'warning' | 'info' | 'default' | 'success' }> = {
  overdue: { label: 'Overdue', badge: 'danger' },
  today: { label: 'Today', badge: 'warning' },
  tomorrow: { label: 'Tomorrow', badge: 'info' },
  upcoming: { label: 'Upcoming', badge: 'default' },
  completed: { label: 'Completed', badge: 'success' },
}

export default function RemindersPage() {
  const [reminders, setReminders] = useState<ReminderItem[]>(loadReminders)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [form, setForm] = useState<ReminderFormState>(INITIAL_FORM)
  const [error, setError] = useState('')

  useEffect(() => {
    saveReminders(reminders)
  }, [reminders])

  const escalatedReminders = getEscalatedReminders(reminders)

  function closeModal() {
    setForm(INITIAL_FORM)
    setError('')
    setIsModalOpen(false)
  }

  function addReminder() {
    if (!form.title.trim()) {
      setError('Reminder title is required.')
      return
    }

    if (!form.remindAt) {
      setError('Reminder time is required.')
      return
    }

    const nextReminder: ReminderItem = {
      id: `reminder-${Date.now()}`,
      title: form.title.trim(),
      remindAt: form.remindAt,
      channel: form.channel,
      completed: false,
    }

    setReminders((current) => [nextReminder, ...current])
    closeModal()
  }

  function toggleReminder(id: string) {
    setReminders((current) =>
      current.map((reminder) =>
        reminder.id === id ? { ...reminder, completed: !reminder.completed } : reminder,
      ),
    )
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Reminders"
        subtitle="Manage alerts for assignments, exams, and revision blocks."
        actions={
          <Button icon={<BellPlus size={18} />} type="button" onClick={() => setIsModalOpen(true)}>
            Add Reminder
          </Button>
        }
      />
      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        {(['overdue', 'today', 'tomorrow', 'upcoming'] as ReminderUrgency[]).map((urgency) => (
          <Card key={urgency} glass className="space-y-2">
            <p className="text-xs uppercase tracking-[0.18em] text-[var(--color-text-muted)]">{URGENCY_META[urgency].label}</p>
            <p className="text-2xl font-semibold text-[var(--color-text)]">
              {escalatedReminders.filter((reminder) => reminder.urgency === urgency).length}
            </p>
          </Card>
        ))}
      </div>
      <Card glass className="space-y-4">
        {escalatedReminders.map((reminder) => (
          <div
            key={reminder.id}
            className="study-panel-soft rounded-xl border p-4"
            style={{ borderColor: 'var(--color-border)' }}
          >
            <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <p className="font-medium text-[var(--color-text)]">{reminder.title}</p>
                  <Badge variant={reminder.completed ? 'success' : 'info'}>
                    {reminder.completed ? 'Done' : reminder.channel}
                  </Badge>
                  <Badge variant={URGENCY_META[reminder.urgency].badge}>
                    {URGENCY_META[reminder.urgency].label}
                  </Badge>
                </div>
                <p className="text-sm text-[var(--color-text-muted)]">{reminder.remindAt.replace('T', ' ')}</p>
              </div>
              <Button type="button" variant="secondary" onClick={() => toggleReminder(reminder.id)}>
                {reminder.completed ? 'Reopen' : 'Mark Done'}
              </Button>
            </div>
          </div>
        ))}
      </Card>

      <Modal isOpen={isModalOpen} onClose={closeModal} title="Add Reminder">
        <form
          className="space-y-4"
          onSubmit={(event) => {
            event.preventDefault()
            addReminder()
          }}
        >
          <Input
            label="Reminder Title"
            value={form.title}
            placeholder="Review Calculus formulas"
            onChange={(event) => setForm((current) => ({ ...current, title: event.target.value }))}
          />
          <Input
            label="Remind At"
            type="datetime-local"
            value={form.remindAt}
            onChange={(event) => setForm((current) => ({ ...current, remindAt: event.target.value }))}
          />
          <Select
            label="Channel"
            options={[...REMINDER_CHANNEL_OPTIONS]}
            value={form.channel}
            onChange={(event) => setForm((current) => ({ ...current, channel: event.target.value as ReminderChannel }))}
          />
          {error && <p className="text-sm text-[var(--color-accent-rose)]">{error}</p>}
          <div className="flex justify-end gap-3">
            <Button type="button" variant="secondary" onClick={closeModal}>
              Cancel
            </Button>
            <Button type="submit">Save Reminder</Button>
          </div>
        </form>
      </Modal>
    </div>
  )
}
