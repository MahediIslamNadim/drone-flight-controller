import { useEffect, useState } from 'react'
import { Clock3, Flame, Plus, TimerReset } from 'lucide-react'
import PageHeader from '../../components/layout/PageHeader'
import Card from '../../components/ui/Card'
import Button from '../../components/ui/Button'
import Input from '../../components/ui/Input'
import Select from '../../components/ui/Select'
import Textarea from '../../components/ui/Textarea'
import Modal from '../../components/ui/Modal'
import Badge from '../../components/ui/Badge'
import {
  getTodayIsoDate,
  loadSessions,
  loadSubjects,
  saveSessions,
  saveSubjects,
  type StudySession,
  type Subject,
} from '../../lib/studyData'

type SubjectSummary = Pick<Subject, 'id' | 'name' | 'studiedHours'>

interface SessionFormState {
  subject: string
  duration: string
  focusScore: string
  date: string
  notes: string
}

function createInitialForm(subjects: SubjectSummary[]): SessionFormState {
  return {
    subject: subjects[0]?.name ?? '',
    duration: '',
    focusScore: '',
    date: getTodayIsoDate(),
    notes: '',
  }
}

function getStoredSubjects(): SubjectSummary[] {
  return loadSubjects().map(({ id, name, studiedHours }) => ({
    id,
    name,
    studiedHours,
  }))
}

function getStoredSessions(): StudySession[] {
  return loadSessions()
}

function getFocusVariant(score: number) {
  if (score >= 85) return 'success'
  if (score >= 70) return 'info'
  if (score >= 50) return 'warning'
  return 'danger'
}

function formatSessionDate(date: string) {
  return new Intl.DateTimeFormat('en-US', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(new Date(date))
}

export default function TrackerPage() {
  const [subjects, setSubjects] = useState<SubjectSummary[]>(getStoredSubjects)
  const [sessions, setSessions] = useState<StudySession[]>(getStoredSessions)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [error, setError] = useState('')
  const [form, setForm] = useState<SessionFormState>(() => createInitialForm(getStoredSubjects()))

  useEffect(() => {
    saveSessions(sessions)
  }, [sessions])

  const totalHours = sessions.reduce((sum, session) => sum + session.duration, 0)
  const averageFocus =
    sessions.length > 0
      ? Math.round(sessions.reduce((sum, session) => sum + session.focusScore, 0) / sessions.length)
      : 0
  const totalToday = sessions
    .filter((session) => session.date === getTodayIsoDate())
    .reduce((sum, session) => sum + session.duration, 0)

  function closeModal() {
    setIsModalOpen(false)
    setError('')
    setForm(createInitialForm(subjects))
  }

  function handleAddSession() {
    const duration = Number(form.duration)
    const focusScore = Number(form.focusScore)

    if (!form.subject) {
      setError('Select a subject first.')
      return
    }

    if (Number.isNaN(duration) || duration <= 0) {
      setError('Duration must be greater than 0.')
      return
    }

    if (Number.isNaN(focusScore) || focusScore < 0 || focusScore > 100) {
      setError('Focus score must be between 0 and 100.')
      return
    }

    const nextSession: StudySession = {
      id: `session-${Date.now()}`,
      subject: form.subject,
      duration,
      focusScore,
      date: form.date,
      notes: form.notes.trim(),
    }

    setSessions((current) => [nextSession, ...current])

    const nextSubjects = subjects.map((subject) =>
      subject.name === form.subject
        ? { ...subject, studiedHours: Number((subject.studiedHours + duration).toFixed(1)) }
        : subject,
    )

    setSubjects(nextSubjects)
    saveSubjects(
      loadSubjects().map((subject) =>
        subject.name === form.subject
          ? { ...subject, studiedHours: Number((subject.studiedHours + duration).toFixed(1)) }
          : subject,
      ),
    )

    closeModal()
  }

  function deleteSession(id: string) {
    const sessionToDelete = sessions.find((session) => session.id === id)

    if (!sessionToDelete) {
      return
    }

    setSessions((current) => current.filter((session) => session.id !== id))

    const nextSubjects = subjects.map((subject) =>
      subject.name === sessionToDelete.subject
        ? {
            ...subject,
            studiedHours: Number(Math.max(subject.studiedHours - sessionToDelete.duration, 0).toFixed(1)),
          }
        : subject,
    )

    setSubjects(nextSubjects)
    saveSubjects(
      loadSubjects().map((subject) =>
        subject.name === sessionToDelete.subject
          ? {
              ...subject,
              studiedHours: Number(Math.max(subject.studiedHours - sessionToDelete.duration, 0).toFixed(1)),
            }
          : subject,
      ),
    )
  }

  const subjectOptions = subjects.map((subject) => ({
    value: subject.name,
    label: subject.name,
  }))

  return (
    <div className="space-y-6">
      <PageHeader
        title="Study Tracker"
        subtitle="Log study sessions, compare focus levels, and keep your weekly effort visible."
        actions={
          <Button
            icon={<Plus size={18} />}
            type="button"
            onClick={() => setIsModalOpen(true)}
            disabled={subjects.length === 0}
          >
            Log Session
          </Button>
        }
      />

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card glass>
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-sm text-[var(--color-text-muted)]">Sessions Logged</p>
              <p className="mt-2 text-3xl font-bold text-[var(--color-text)]">{sessions.length}</p>
            </div>
            <div
              className="study-icon-chip sky"
            >
              <Clock3 size={20} />
            </div>
          </div>
        </Card>

        <Card glass>
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-sm text-[var(--color-text-muted)]">Hours Logged</p>
              <p className="mt-2 text-3xl font-bold text-[var(--color-text)]">{totalHours.toFixed(1)}h</p>
              <p className="mt-1 text-sm text-[var(--color-text-muted)]">{totalToday.toFixed(1)}h recorded today</p>
            </div>
            <div
              className="study-icon-chip info"
            >
              <TimerReset size={20} />
            </div>
          </div>
        </Card>

        <Card glass>
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-sm text-[var(--color-text-muted)]">Average Focus</p>
              <p className="mt-2 text-3xl font-bold text-[var(--color-text)]">{averageFocus}%</p>
              <p className="mt-1 text-sm text-[var(--color-text-muted)]">Based on your recent study sessions</p>
            </div>
            <div
              className="study-icon-chip rose"
            >
              <Flame size={20} />
            </div>
          </div>
        </Card>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[1.6fr_1fr] gap-6">
        <Card glass className="space-y-5">
          <div>
            <h3 className="text-lg font-semibold text-[var(--color-text)]">Recent Sessions</h3>
            <p className="mt-1 text-sm text-[var(--color-text-muted)]">
              Your latest study activity stays here so you can spot consistency fast.
            </p>
          </div>

          <div className="space-y-4">
            {sessions.map((session) => (
              <div
                key={session.id}
                className="study-panel-soft rounded-xl border p-4"
                style={{ borderColor: 'var(--color-border)' }}
              >
                <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
                  <div className="space-y-2">
                    <div className="flex flex-wrap items-center gap-2">
                      <h4 className="text-lg font-semibold text-[var(--color-text)]">{session.subject}</h4>
                      <Badge variant="default">{session.duration}h</Badge>
                      <Badge variant={getFocusVariant(session.focusScore)}>Focus {session.focusScore}%</Badge>
                    </div>
                    <p className="text-sm text-[var(--color-text-muted)]">
                      {formatSessionDate(session.date)}
                    </p>
                    {session.notes && (
                      <p className="text-sm leading-6 text-[var(--color-text-muted)]">{session.notes}</p>
                    )}
                  </div>

                  <Button
                    type="button"
                    variant="ghost"
                    className="self-start"
                    onClick={() => deleteSession(session.id)}
                  >
                    Remove
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </Card>

        <Card glass className="space-y-5">
          <div>
            <h3 className="text-lg font-semibold text-[var(--color-text)]">Subject Pace</h3>
            <p className="mt-1 text-sm text-[var(--color-text-muted)]">
              Session logs update your subject hours so the tracker and subjects stay aligned.
            </p>
          </div>

          <div className="space-y-4">
            {subjects.map((subject) => (
              <div
                key={subject.id}
                className="rounded-xl border p-4"
                style={{ borderColor: 'var(--color-border)' }}
              >
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="font-medium text-[var(--color-text)]">{subject.name}</p>
                    <p className="mt-1 text-sm text-[var(--color-text-muted)]">
                      {subject.studiedHours.toFixed(1)}h total tracked
                    </p>
                  </div>
                  <Badge variant="info">{subject.studiedHours.toFixed(1)}h</Badge>
                </div>
              </div>
            ))}
          </div>

          {subjects.length === 0 && (
            <div
              className="rounded-xl border p-4 text-sm text-[var(--color-text-muted)]"
              style={{ borderColor: 'var(--color-border)' }}
            >
              Add a subject first from the Subjects page, then you can log sessions here.
            </div>
          )}
        </Card>
      </div>

      <Modal isOpen={isModalOpen} onClose={closeModal} title="Log Study Session">
        <form
          className="space-y-4"
          onSubmit={(event) => {
            event.preventDefault()
            handleAddSession()
          }}
        >
          <Select
            label="Subject"
            options={subjectOptions}
            value={form.subject}
            onChange={(event) => setForm((current) => ({ ...current, subject: event.target.value }))}
          />

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <Input
              label="Duration (hours)"
              type="number"
              min="0.5"
              step="0.25"
              placeholder="1.5"
              value={form.duration}
              onChange={(event) => setForm((current) => ({ ...current, duration: event.target.value }))}
            />
            <Input
              label="Focus Score"
              type="number"
              min="0"
              max="100"
              placeholder="82"
              value={form.focusScore}
              onChange={(event) => setForm((current) => ({ ...current, focusScore: event.target.value }))}
            />
            <Input
              label="Date"
              type="date"
              value={form.date}
              onChange={(event) => setForm((current) => ({ ...current, date: event.target.value }))}
            />
          </div>

          <Textarea
            label="Session Notes"
            placeholder="What did you cover in this session?"
            value={form.notes}
            onChange={(event) => setForm((current) => ({ ...current, notes: event.target.value }))}
          />

          {error && <p className="text-sm text-[var(--color-accent-rose)]">{error}</p>}

          <div className="flex justify-end gap-3 pt-2">
            <Button type="button" variant="secondary" onClick={closeModal}>
              Cancel
            </Button>
            <Button type="submit">Save Session</Button>
          </div>
        </form>
      </Modal>
    </div>
  )
}
