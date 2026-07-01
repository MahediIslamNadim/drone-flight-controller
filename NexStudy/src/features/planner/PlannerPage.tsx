import { useEffect, useState } from 'react'
import { CheckCircle2, Plus } from 'lucide-react'
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
  PRIORITY_OPTIONS,
  TASK_TYPE_OPTIONS,
  type PlannerTask,
  type Priority,
  type TaskType,
  loadSubjects,
  loadTasks,
  saveTasks,
} from '../../lib/studyData'

interface TaskFormState {
  title: string
  subject: string
  type: TaskType
  dueDate: string
  priority: Priority
  notes: string
}

function createInitialForm() {
  const firstSubject = loadSubjects()[0]?.name ?? ''

  return {
    title: '',
    subject: firstSubject,
    type: 'Assignment' as TaskType,
    dueDate: '',
    priority: 'Medium' as Priority,
    notes: '',
  }
}

function getPriorityVariant(priority: Priority) {
  if (priority === 'High') return 'danger'
  if (priority === 'Medium') return 'warning'
  return 'info'
}

function formatDueDate(date: string) {
  return new Intl.DateTimeFormat('en-US', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(new Date(date))
}

export default function PlannerPage() {
  const [tasks, setTasks] = useState<PlannerTask[]>(loadTasks)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [form, setForm] = useState<TaskFormState>(createInitialForm)
  const [error, setError] = useState('')
  const subjects = loadSubjects()
  const hasSubjects = subjects.length > 0

  useEffect(() => {
    saveTasks(tasks)
  }, [tasks])

  const openTasks = tasks.filter((task) => !task.completed)
  const completedTasks = tasks.filter((task) => task.completed)
  const nextDeadline = [...openTasks].sort((a, b) => a.dueDate.localeCompare(b.dueDate))[0]

  function closeModal() {
    setIsModalOpen(false)
    setError('')
    setForm(createInitialForm())
  }

  function addTask() {
    if (!form.title.trim()) {
      setError('Task title is required.')
      return
    }

    if (!form.subject) {
      setError('Select a subject first.')
      return
    }

    if (!form.dueDate) {
      setError('Due date is required.')
      return
    }

    const nextTask: PlannerTask = {
      id: `task-${Date.now()}`,
      title: form.title.trim(),
      subject: form.subject,
      type: form.type,
      dueDate: form.dueDate,
      priority: form.priority,
      completed: false,
      completedAt: undefined,
      notes: form.notes.trim(),
    }

    setTasks((current) => [nextTask, ...current])
    closeModal()
  }

  function toggleTask(id: string) {
    setTasks((current) =>
      current.map((task) =>
        task.id === id
          ? {
              ...task,
              completed: !task.completed,
              completedAt: task.completed ? undefined : getTodayIsoDate(),
            }
          : task,
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
        title="Planner"
        subtitle="Organize assignments, exams, and revision tasks with clear priority."
        actions={
          <Button icon={<Plus size={18} />} type="button" onClick={() => setIsModalOpen(true)} disabled={!hasSubjects}>
            Add Task
          </Button>
        }
      />
      {!hasSubjects && (
        <Card glass className="text-sm text-[var(--color-text-muted)]">
          Add a subject first from the Subjects page before creating planned tasks.
        </Card>
      )}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card glass>
          <p className="text-sm text-[var(--color-text-muted)]">Open Tasks</p>
          <p className="mt-2 text-3xl font-bold text-[var(--color-text)]">{openTasks.length}</p>
        </Card>
        <Card glass>
          <p className="text-sm text-[var(--color-text-muted)]">Completed</p>
          <p className="mt-2 text-3xl font-bold text-[var(--color-text)]">{completedTasks.length}</p>
        </Card>
        <Card glass>
          <p className="text-sm text-[var(--color-text-muted)]">Next Deadline</p>
          <p className="mt-2 text-lg font-bold text-[var(--color-text)]">
            {nextDeadline ? nextDeadline.title : 'No pending tasks'}
          </p>
          <p className="mt-1 text-sm text-[var(--color-text-muted)]">
            {nextDeadline ? formatDueDate(nextDeadline.dueDate) : 'You are all caught up.'}
          </p>
        </Card>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[1.6fr_1fr] gap-6">
        <Card glass className="space-y-4">
          <h3 className="text-lg font-semibold text-[var(--color-text)]">Upcoming Work</h3>
          {openTasks.length === 0 && (
            <p className="text-sm text-[var(--color-text-muted)]">No open tasks. Add one to plan your week.</p>
          )}
          {openTasks
            .sort((a, b) => a.dueDate.localeCompare(b.dueDate))
            .map((task) => (
              <div
                key={task.id}
                className="study-panel-soft rounded-xl border p-4"
                style={{ borderColor: 'var(--color-border)' }}
              >
                <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                  <div className="space-y-2">
                    <div className="flex flex-wrap items-center gap-2">
                      <h4 className="font-semibold text-[var(--color-text)]">{task.title}</h4>
                      <Badge variant={getPriorityVariant(task.priority)}>{task.priority}</Badge>
                      <Badge variant="default">{task.type}</Badge>
                    </div>
                    <p className="text-sm text-[var(--color-text-muted)]">{task.subject}</p>
                    <p className="text-sm text-[var(--color-text-muted)]">Due {formatDueDate(task.dueDate)}</p>
                    {task.notes && <p className="text-sm text-[var(--color-text-muted)]">{task.notes}</p>}
                  </div>
                  <Button type="button" variant="secondary" onClick={() => toggleTask(task.id)}>
                    Mark Done
                  </Button>
                </div>
              </div>
            ))}
        </Card>

        <Card glass className="space-y-4">
          <h3 className="text-lg font-semibold text-[var(--color-text)]">Completed Tasks</h3>
          {completedTasks.length === 0 && (
            <p className="text-sm text-[var(--color-text-muted)]">Finished tasks will appear here.</p>
          )}
          {[...completedTasks]
            .sort((a, b) => (b.completedAt ?? '').localeCompare(a.completedAt ?? ''))
            .map((task) => (
            <div key={task.id} className="rounded-xl border p-4" style={{ borderColor: 'var(--color-border)' }}>
              <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                <div className="flex items-start gap-3">
                  <CheckCircle2 size={18} className="mt-0.5 text-[var(--color-accent-emerald)]" />
                  <div>
                    <p className="font-medium text-[var(--color-text)]">{task.title}</p>
                    <p className="mt-1 text-sm text-[var(--color-text-muted)]">
                      {task.subject} | {task.type}
                      {task.completedAt ? ` | Done ${formatDueDate(task.completedAt)}` : ''}
                    </p>
                  </div>
                </div>
                <Button type="button" variant="secondary" onClick={() => toggleTask(task.id)}>
                  Reopen
                </Button>
              </div>
            </div>
          ))}
        </Card>
      </div>

      <Modal isOpen={isModalOpen} onClose={closeModal} title="Add Planner Task">
        <form
          className="space-y-4"
          onSubmit={(event) => {
            event.preventDefault()
            addTask()
          }}
        >
          <Input
            label="Task Title"
            value={form.title}
            placeholder="Prepare Calculus revision sheet"
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
              label="Task Type"
              options={[...TASK_TYPE_OPTIONS]}
              value={form.type}
              onChange={(event) => setForm((current) => ({ ...current, type: event.target.value as TaskType }))}
            />
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <Input
              label="Due Date"
              type="date"
              value={form.dueDate}
              onChange={(event) => setForm((current) => ({ ...current, dueDate: event.target.value }))}
            />
            <Select
              label="Priority"
              options={[...PRIORITY_OPTIONS]}
              value={form.priority}
              onChange={(event) => setForm((current) => ({ ...current, priority: event.target.value as Priority }))}
            />
          </div>
          <Textarea
            label="Notes"
            value={form.notes}
            placeholder="Add extra details or checklist"
            onChange={(event) => setForm((current) => ({ ...current, notes: event.target.value }))}
          />
          {error && <p className="text-sm text-[var(--color-accent-rose)]">{error}</p>}
          <div className="flex justify-end gap-3">
            <Button type="button" variant="secondary" onClick={closeModal}>
              Cancel
            </Button>
            <Button type="submit">Save Task</Button>
          </div>
        </form>
      </Modal>
    </div>
  )
}
