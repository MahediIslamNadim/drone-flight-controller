import { useEffect, useState } from 'react'
import { Plus } from 'lucide-react'
import PageHeader from '../../components/layout/PageHeader'
import Card from '../../components/ui/Card'
import Button from '../../components/ui/Button'
import Input from '../../components/ui/Input'
import Modal from '../../components/ui/Modal'
import Badge from '../../components/ui/Badge'
import { getGoalStatus, type GoalItem, loadGoals, saveGoals } from '../../lib/studyData'

interface GoalFormState {
  title: string
  targetHours: string
  progressHours: string
  deadline: string
}

const INITIAL_FORM: GoalFormState = {
  title: '',
  targetHours: '',
  progressHours: '',
  deadline: '',
}

function getGoalVariant(status: GoalItem['status']) {
  if (status === 'Done') return 'success'
  if (status === 'On Track') return 'info'
  return 'warning'
}

export default function GoalsPage() {
  const [goals, setGoals] = useState<GoalItem[]>(loadGoals)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [form, setForm] = useState<GoalFormState>(INITIAL_FORM)
  const [error, setError] = useState('')

  useEffect(() => {
    saveGoals(goals)
  }, [goals])

  function closeModal() {
    setForm(INITIAL_FORM)
    setError('')
    setIsModalOpen(false)
  }

  function addGoal() {
    const targetHours = Number(form.targetHours)
    const progressHours = Number(form.progressHours)

    if (!form.title.trim()) {
      setError('Goal title is required.')
      return
    }

    if (Number.isNaN(targetHours) || targetHours <= 0) {
      setError('Target hours must be greater than 0.')
      return
    }

    if (Number.isNaN(progressHours) || progressHours < 0) {
      setError('Progress hours cannot be negative.')
      return
    }

    if (!form.deadline) {
      setError('Deadline is required.')
      return
    }

    const nextGoal: GoalItem = {
      id: `goal-${Date.now()}`,
      title: form.title.trim(),
      targetHours,
      progressHours,
      deadline: form.deadline,
      status: getGoalStatus(progressHours, targetHours),
    }

    setGoals((current) => [nextGoal, ...current])
    closeModal()
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Goals"
        subtitle="Set measurable academic goals and keep progress visible."
        actions={
          <Button icon={<Plus size={18} />} type="button" onClick={() => setIsModalOpen(true)}>
            New Goal
          </Button>
        }
      />
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {goals.map((goal) => {
          const status = getGoalStatus(goal.progressHours, goal.targetHours)
          const percent = Math.min(100, Math.round((goal.progressHours / goal.targetHours) * 100))

          return (
            <Card key={goal.id} hover glass className="space-y-4">
              <div className="flex items-center justify-between gap-3">
                <h3 className="text-lg font-semibold text-[var(--color-text)]">{goal.title}</h3>
                <Badge variant={getGoalVariant(status)}>{status}</Badge>
              </div>
              <p className="text-sm text-[var(--color-text-muted)]">
                {goal.progressHours}h of {goal.targetHours}h
              </p>
              <div className="h-2 overflow-hidden rounded-full bg-[var(--color-surface-alt)]">
                <div
                  className="h-full rounded-full"
                  style={{
                    width: `${percent}%`,
                    background: 'linear-gradient(90deg, var(--color-primary), var(--color-accent-teal))',
                  }}
                />
              </div>
              <p className="text-sm text-[var(--color-text-muted)]">Deadline {goal.deadline}</p>
            </Card>
          )
        })}
      </div>

      <Modal isOpen={isModalOpen} onClose={closeModal} title="Add Goal">
        <form
          className="space-y-4"
          onSubmit={(event) => {
            event.preventDefault()
            addGoal()
          }}
        >
          <Input
            label="Goal Title"
            value={form.title}
            placeholder="Reach 30 study hours this month"
            onChange={(event) => setForm((current) => ({ ...current, title: event.target.value }))}
          />
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <Input
              label="Target Hours"
              type="number"
              min="1"
              value={form.targetHours}
              onChange={(event) => setForm((current) => ({ ...current, targetHours: event.target.value }))}
            />
            <Input
              label="Current Progress"
              type="number"
              min="0"
              value={form.progressHours}
              onChange={(event) => setForm((current) => ({ ...current, progressHours: event.target.value }))}
            />
          </div>
          <Input
            label="Deadline"
            type="date"
            value={form.deadline}
            onChange={(event) => setForm((current) => ({ ...current, deadline: event.target.value }))}
          />
          {error && <p className="text-sm text-[var(--color-accent-rose)]">{error}</p>}
          <div className="flex justify-end gap-3">
            <Button type="button" variant="secondary" onClick={closeModal}>
              Cancel
            </Button>
            <Button type="submit">Save Goal</Button>
          </div>
        </form>
      </Modal>
    </div>
  )
}
