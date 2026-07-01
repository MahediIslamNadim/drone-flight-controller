import { useEffect, useState } from 'react'
import { BookOpen, CalendarDays, Plus, Target, Trash2 } from 'lucide-react'
import PageHeader from '../../components/layout/PageHeader'
import Card from '../../components/ui/Card'
import Button from '../../components/ui/Button'
import Input from '../../components/ui/Input'
import Select from '../../components/ui/Select'
import Textarea from '../../components/ui/Textarea'
import Modal from '../../components/ui/Modal'
import Badge from '../../components/ui/Badge'
import { removeSubjectDependencies } from '../../lib/studyData'

type SubjectCategory = 'Science' | 'Math' | 'Language' | 'Business' | 'Arts' | 'Other'

interface Subject {
  id: string
  name: string
  category: SubjectCategory
  instructor: string
  weeklyGoal: number
  studiedHours: number
  progress: number
  examDate: string
  notes: string
}

interface SubjectFormState {
  name: string
  category: SubjectCategory
  instructor: string
  weeklyGoal: string
  studiedHours: string
  progress: string
  examDate: string
  notes: string
}

const STORAGE_KEY = 'nexstudy-subjects'

const CATEGORY_OPTIONS = [
  { value: 'Science', label: 'Science' },
  { value: 'Math', label: 'Math' },
  { value: 'Language', label: 'Language' },
  { value: 'Business', label: 'Business' },
  { value: 'Arts', label: 'Arts' },
  { value: 'Other', label: 'Other' },
] as const

const INITIAL_FORM: SubjectFormState = {
  name: '',
  category: 'Science',
  instructor: '',
  weeklyGoal: '',
  studiedHours: '',
  progress: '',
  examDate: '',
  notes: '',
}

const STARTER_SUBJECTS: Subject[] = [
  {
    id: 'sub-physics',
    name: 'Physics',
    category: 'Science',
    instructor: 'Dr. Rahman',
    weeklyGoal: 8,
    studiedHours: 5.5,
    progress: 72,
    examDate: '2026-05-24',
    notes: 'Focus on motion, force, and problem-solving drills.',
  },
  {
    id: 'sub-calculus',
    name: 'Calculus',
    category: 'Math',
    instructor: 'Prof. Karim',
    weeklyGoal: 6,
    studiedHours: 4,
    progress: 61,
    examDate: '2026-05-27',
    notes: 'Practice integration shortcuts and past questions.',
  },
  {
    id: 'sub-english',
    name: 'English Literature',
    category: 'Language',
    instructor: 'Ms. Farzana',
    weeklyGoal: 4,
    studiedHours: 3,
    progress: 84,
    examDate: '2026-06-02',
    notes: 'Revise themes, quotes, and comparison answers.',
  },
]

function getProgressVariant(progress: number) {
  if (progress >= 80) return 'success'
  if (progress >= 60) return 'info'
  if (progress >= 40) return 'warning'
  return 'danger'
}

function formatExamDate(date: string) {
  if (!date) return 'No date set'

  return new Intl.DateTimeFormat('en-US', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(new Date(date))
}

function getDaysUntil(date: string) {
  if (!date) return null

  const target = new Date(`${date}T00:00:00`)
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const diff = target.getTime() - today.getTime()
  return Math.ceil(diff / (1000 * 60 * 60 * 24))
}

function getInitialSubjects() {
  const storedSubjects = window.localStorage.getItem(STORAGE_KEY)

  if (!storedSubjects) {
    return STARTER_SUBJECTS
  }

  try {
    const parsed = JSON.parse(storedSubjects) as Subject[]
    return Array.isArray(parsed) ? parsed : STARTER_SUBJECTS
  } catch {
    window.localStorage.removeItem(STORAGE_KEY)
    return STARTER_SUBJECTS
  }
}

export default function SubjectsPage() {
  const [subjects, setSubjects] = useState<Subject[]>(getInitialSubjects)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [form, setForm] = useState<SubjectFormState>(INITIAL_FORM)
  const [error, setError] = useState('')

  useEffect(() => {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(subjects))
  }, [subjects])

  const totalWeeklyGoal = subjects.reduce((sum, subject) => sum + subject.weeklyGoal, 0)
  const totalStudiedHours = subjects.reduce((sum, subject) => sum + subject.studiedHours, 0)
  const averageProgress =
    subjects.length > 0
      ? Math.round(subjects.reduce((sum, subject) => sum + subject.progress, 0) / subjects.length)
      : 0
  const nextExam = [...subjects]
    .filter((subject) => subject.examDate)
    .sort((a, b) => a.examDate.localeCompare(b.examDate))[0]
  const lowestProgressSubject = [...subjects].sort((a, b) => a.progress - b.progress)[0]

  function resetForm() {
    setForm(INITIAL_FORM)
    setError('')
  }

  function closeModal() {
    setIsModalOpen(false)
    resetForm()
  }

  function handleCreateSubject() {
    const normalizedName = form.name.trim()
    const weeklyGoal = Number(form.weeklyGoal)
    const studiedHours = Number(form.studiedHours)
    const progress = Number(form.progress)

    if (!normalizedName) {
      setError('Subject name is required.')
      return
    }

    if (subjects.some((subject) => subject.name.trim().toLowerCase() === normalizedName.toLowerCase())) {
      setError('A subject with this name already exists.')
      return
    }

    if (!form.instructor.trim()) {
      setError('Instructor name is required.')
      return
    }

    if (Number.isNaN(weeklyGoal) || weeklyGoal <= 0) {
      setError('Weekly goal must be greater than 0.')
      return
    }

    if (Number.isNaN(studiedHours) || studiedHours < 0) {
      setError('Studied hours cannot be negative.')
      return
    }

    if (Number.isNaN(progress) || progress < 0 || progress > 100) {
      setError('Progress must be between 0 and 100.')
      return
    }

    const nextSubject: Subject = {
      id: `subject-${Date.now()}`,
      name: normalizedName,
      category: form.category,
      instructor: form.instructor.trim(),
      weeklyGoal,
      studiedHours,
      progress,
      examDate: form.examDate,
      notes: form.notes.trim(),
    }

    setSubjects((current) => [nextSubject, ...current])
    closeModal()
  }

  function deleteSubject(id: string) {
    const subjectToDelete = subjects.find((subject) => subject.id === id)

    if (!subjectToDelete) {
      return
    }

    removeSubjectDependencies(subjectToDelete.name)
    setSubjects((current) => current.filter((subject) => subject.id !== id))
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Subjects"
        subtitle="Manage your subjects, weekly study goals, and exam targets in one place."
        actions={
          <Button
            icon={<Plus size={18} />}
            type="button"
            onClick={() => setIsModalOpen(true)}
          >
            Add Subject
          </Button>
        }
      />

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card glass>
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-sm text-[var(--color-text-muted)]">Active Subjects</p>
              <p className="mt-2 text-3xl font-bold text-[var(--color-text)]">{subjects.length}</p>
            </div>
            <div
              className="study-icon-chip sky"
            >
              <BookOpen size={20} />
            </div>
          </div>
        </Card>

        <Card glass>
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-sm text-[var(--color-text-muted)]">Weekly Study Goal</p>
              <p className="mt-2 text-3xl font-bold text-[var(--color-text)]">{totalWeeklyGoal}h</p>
              <p className="mt-1 text-sm text-[var(--color-text-muted)]">{totalStudiedHours}h logged so far</p>
            </div>
            <div
              className="study-icon-chip info"
            >
              <Target size={20} />
            </div>
          </div>
        </Card>

        <Card glass>
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-sm text-[var(--color-text-muted)]">Next Exam</p>
              <p className="mt-2 text-lg font-bold text-[var(--color-text)]">
                {nextExam ? nextExam.name : 'No exam planned'}
              </p>
              <p className="mt-1 text-sm text-[var(--color-text-muted)]">
                {nextExam ? formatExamDate(nextExam.examDate) : 'Add a subject deadline to see it here.'}
              </p>
            </div>
            <div
              className="study-icon-chip warm"
            >
              <CalendarDays size={20} />
            </div>
          </div>
        </Card>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[1.7fr_1fr] gap-6">
        <Card glass className="space-y-5">
          <div className="flex items-center justify-between gap-4">
            <div>
              <h3 className="text-lg font-semibold text-[var(--color-text)]">Subject Overview</h3>
              <p className="mt-1 text-sm text-[var(--color-text-muted)]">
                Track progress, study pace, and the next deadline for each subject.
              </p>
            </div>
            <Badge variant={getProgressVariant(averageProgress)}>
              Avg progress {averageProgress}%
            </Badge>
          </div>

          <div className="space-y-4">
            {subjects.map((subject) => {
              const daysUntilExam = getDaysUntil(subject.examDate)
              const remainingHours = Math.max(subject.weeklyGoal - subject.studiedHours, 0)

              return (
                <div
                  key={subject.id}
                  className="study-panel-soft rounded-xl border p-4"
                  style={{ borderColor: 'var(--color-border)' }}
                >
                  <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
                    <div className="space-y-2">
                      <div className="flex flex-wrap items-center gap-2">
                        <h4 className="text-lg font-semibold text-[var(--color-text)]">{subject.name}</h4>
                        <Badge variant="default">{subject.category}</Badge>
                        <Badge variant={getProgressVariant(subject.progress)}>{subject.progress}% done</Badge>
                      </div>

                      <p className="text-sm text-[var(--color-text-muted)]">
                        Instructor: {subject.instructor}
                      </p>

                      <p className="text-sm text-[var(--color-text-muted)]">
                        {subject.studiedHours}h logged of {subject.weeklyGoal}h weekly goal
                        {remainingHours > 0 ? ` | ${remainingHours}h left this week` : ' | Weekly target reached'}
                      </p>

                      <div className="h-2 overflow-hidden rounded-full bg-[var(--color-surface-alt)]">
                        <div
                          className="h-full rounded-full"
                          style={{
                            width: `${subject.progress}%`,
                            background: 'linear-gradient(90deg, var(--color-primary), var(--color-accent-teal))',
                          }}
                        />
                      </div>

                      <p className="text-sm text-[var(--color-text-muted)]">
                        Exam: {formatExamDate(subject.examDate)}
                        {daysUntilExam !== null ? ` | ${daysUntilExam} day${daysUntilExam === 1 ? '' : 's'} left` : ''}
                      </p>

                      {subject.notes && (
                        <p className="text-sm leading-6 text-[var(--color-text-muted)]">{subject.notes}</p>
                      )}
                    </div>

                    <Button
                      type="button"
                      variant="ghost"
                      icon={<Trash2 size={16} />}
                      className="self-start"
                      onClick={() => deleteSubject(subject.id)}
                    >
                      Remove
                    </Button>
                  </div>
                </div>
              )
            })}
          </div>
        </Card>

        <Card glass className="space-y-5">
          <div>
            <h3 className="text-lg font-semibold text-[var(--color-text)]">Study Snapshot</h3>
            <p className="mt-1 text-sm text-[var(--color-text-muted)]">
              A quick view of pace and what needs attention first.
            </p>
          </div>

          <div className="space-y-4">
            {[...subjects]
              .sort((a, b) => a.progress - b.progress)
              .slice(0, 3)
              .map((subject) => (
                <div
                  key={subject.id}
                  className="rounded-xl border p-4"
                  style={{ borderColor: 'var(--color-border)' }}
                >
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <p className="font-medium text-[var(--color-text)]">{subject.name}</p>
                      <p className="mt-1 text-sm text-[var(--color-text-muted)]">
                        {subject.studiedHours}h / {subject.weeklyGoal}h this week
                      </p>
                    </div>
                    <Badge variant={getProgressVariant(subject.progress)}>{subject.progress}%</Badge>
                  </div>
                </div>
              ))}
          </div>

          <div
            className="rounded-xl border p-4"
            style={{
              borderColor: 'var(--color-border)',
              background: 'linear-gradient(135deg, rgba(31, 111, 100, 0.08), rgba(186, 133, 47, 0.1))',
            }}
          >
            <p className="text-sm text-[var(--color-text-muted)]">Recommendation</p>
            <p className="mt-2 text-sm leading-6 text-[var(--color-text)]">
              Focus next on <span className="font-semibold">{lowestProgressSubject?.name ?? 'your weakest subject'}</span>{' '}
              to lift the overall average above {averageProgress}%.
            </p>
          </div>
        </Card>
      </div>

      <Modal isOpen={isModalOpen} onClose={closeModal} title="Add New Subject">
        <form
          className="space-y-4"
          onSubmit={(event) => {
            event.preventDefault()
            handleCreateSubject()
          }}
        >
          <Input
            label="Subject Name"
            placeholder="e.g. Organic Chemistry"
            value={form.name}
            onChange={(event) => setForm((current) => ({ ...current, name: event.target.value }))}
          />

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <Select
              label="Category"
              options={[...CATEGORY_OPTIONS]}
              value={form.category}
              onChange={(event) =>
                setForm((current) => ({
                  ...current,
                  category: event.target.value as SubjectCategory,
                }))
              }
            />
            <Input
              label="Instructor"
              placeholder="Teacher or course mentor"
              value={form.instructor}
              onChange={(event) => setForm((current) => ({ ...current, instructor: event.target.value }))}
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <Input
              label="Weekly Goal"
              type="number"
              min="1"
              step="0.5"
              placeholder="6"
              value={form.weeklyGoal}
              onChange={(event) => setForm((current) => ({ ...current, weeklyGoal: event.target.value }))}
            />
            <Input
              label="Studied Hours"
              type="number"
              min="0"
              step="0.5"
              placeholder="2.5"
              value={form.studiedHours}
              onChange={(event) => setForm((current) => ({ ...current, studiedHours: event.target.value }))}
            />
            <Input
              label="Progress %"
              type="number"
              min="0"
              max="100"
              placeholder="55"
              value={form.progress}
              onChange={(event) => setForm((current) => ({ ...current, progress: event.target.value }))}
            />
          </div>

          <Input
            label="Exam Date"
            type="date"
            value={form.examDate}
            onChange={(event) => setForm((current) => ({ ...current, examDate: event.target.value }))}
          />

          <Textarea
            label="Study Notes"
            placeholder="What should you revise next for this subject?"
            value={form.notes}
            onChange={(event) => setForm((current) => ({ ...current, notes: event.target.value }))}
          />

          {error && <p className="text-sm text-[var(--color-accent-rose)]">{error}</p>}

          <div className="flex justify-end gap-3 pt-2">
            <Button type="button" variant="secondary" onClick={closeModal}>
              Cancel
            </Button>
            <Button type="submit">Save Subject</Button>
          </div>
        </form>
      </Modal>
    </div>
  )
}
