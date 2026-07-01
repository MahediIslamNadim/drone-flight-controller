import { useEffect, useState } from 'react'
import { Plus } from 'lucide-react'
import PageHeader from '../../components/layout/PageHeader'
import Card from '../../components/ui/Card'
import Button from '../../components/ui/Button'
import Input from '../../components/ui/Input'
import Select from '../../components/ui/Select'
import Modal from '../../components/ui/Modal'
import {
  WEEKDAY_OPTIONS,
  type TimetableClass,
  loadSubjects,
  loadTimetable,
  saveTimetable,
} from '../../lib/studyData'

interface ClassFormState {
  title: string
  subject: string
  day: TimetableClass['day']
  time: string
  room: string
}

function createClassFormState(): ClassFormState {
  return {
    title: '',
    subject: loadSubjects()[0]?.name ?? '',
    day: 'Sunday',
    time: '',
    room: '',
  }
}

export default function TimetablePage() {
  const [classes, setClasses] = useState<TimetableClass[]>(loadTimetable)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [form, setForm] = useState<ClassFormState>(createClassFormState)
  const [error, setError] = useState('')
  const subjects = loadSubjects()
  const hasSubjects = subjects.length > 0

  useEffect(() => {
    saveTimetable(classes)
  }, [classes])

  function closeModal() {
    setError('')
    setForm(createClassFormState())
    setIsModalOpen(false)
  }

  function addClass() {
    if (!form.title.trim()) {
      setError('Class title is required.')
      return
    }

    if (!form.subject) {
      setError('Add a subject first before creating timetable entries.')
      return
    }

    if (!form.time.trim()) {
      setError('Class time is required.')
      return
    }

    const nextClass: TimetableClass = {
      id: `class-${Date.now()}`,
      title: form.title.trim(),
      subject: form.subject,
      day: form.day,
      time: form.time.trim(),
      room: form.room.trim(),
    }

    setClasses((current) => [...current, nextClass])
    closeModal()
  }

  const subjectOptions = subjects.map((subject) => ({
    value: subject.name,
    label: subject.name,
  }))

  return (
    <div className="space-y-6">
      <PageHeader
        title="Timetable"
        subtitle="Your weekly class and study schedule"
        actions={
          <Button icon={<Plus size={18} />} type="button" onClick={() => setIsModalOpen(true)} disabled={!hasSubjects}>
            Add Class
          </Button>
        }
      />
      {!hasSubjects && (
        <Card glass className="text-sm text-[var(--color-text-muted)]">
          Add a subject first from the Subjects page to build a timetable that stays connected to your courses.
        </Card>
      )}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
        {[...WEEKDAY_OPTIONS].map((day) => (
          <Card key={day.value} glass className="space-y-4">
            <h3 className="text-lg font-semibold text-[var(--color-text)]">{day.label}</h3>
            {classes
              .filter((item) => item.day === day.value)
              .map((item) => (
                <div
                  key={item.id}
                  className="study-panel-soft rounded-xl border p-3"
                  style={{ borderColor: 'var(--color-border)' }}
                >
                  <p className="font-medium text-[var(--color-text)]">{item.title}</p>
                  <p className="mt-1 text-sm text-[var(--color-text-muted)]">{item.subject}</p>
                  <p className="mt-1 text-sm text-[var(--color-text-muted)]">{item.time}</p>
                  <p className="mt-1 text-sm text-[var(--color-text-muted)]">{item.room}</p>
                </div>
              ))}
          </Card>
        ))}
      </div>

      <Modal isOpen={isModalOpen} onClose={closeModal} title="Add Timetable Class">
        <form
          className="space-y-4"
          onSubmit={(event) => {
            event.preventDefault()
            addClass()
          }}
        >
          <Input
            label="Class Title"
            value={form.title}
            placeholder="Physics Lecture"
            onChange={(event) => setForm((current) => ({ ...current, title: event.target.value }))}
          />
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <Select
              label="Subject"
              options={subjectOptions}
              value={form.subject}
              onChange={(event) => setForm((current) => ({ ...current, subject: event.target.value }))}
            />
            <Select
              label="Day"
              options={[...WEEKDAY_OPTIONS]}
              value={form.day}
              onChange={(event) => setForm((current) => ({ ...current, day: event.target.value as TimetableClass['day'] }))}
            />
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <Input
              label="Time"
              value={form.time}
              placeholder="10:00 - 11:30"
              onChange={(event) => setForm((current) => ({ ...current, time: event.target.value }))}
            />
            <Input
              label="Room"
              value={form.room}
              placeholder="Room 204"
              onChange={(event) => setForm((current) => ({ ...current, room: event.target.value }))}
            />
          </div>
          {error && <p className="text-sm text-[var(--color-accent-rose)]">{error}</p>}
          <div className="flex justify-end gap-3">
            <Button type="button" variant="secondary" onClick={closeModal}>
              Cancel
            </Button>
            <Button type="submit">Save Class</Button>
          </div>
        </form>
      </Modal>
    </div>
  )
}
