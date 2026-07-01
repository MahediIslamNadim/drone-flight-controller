import {
  getOffsetIsoDate,
  getTodayIsoDate,
  type PlannerTask,
  type ReminderItem,
  type StudySession,
  type StudyWorkspaceData,
  type Subject,
} from './studyData'

type Trend = 'rising' | 'steady' | 'falling'
type InsightTone = 'urgent' | 'focus' | 'steady'
export type ReminderUrgency = 'overdue' | 'today' | 'tomorrow' | 'upcoming' | 'completed'

export interface StudyInsightItem {
  id: string
  title: string
  description: string
  route: string
  actionLabel: string
  tone: InsightTone
}

export interface StudyPrioritySubject {
  name: string
  reason: string
  progress: number
}

export interface StudyIntelligence {
  readinessScore: number
  streakDays: number
  todayHours: number
  dailyGoalHours: number
  completionRate: number
  overdueTaskCount: number
  dueSoonTaskCount: number
  pendingReminderCount: number
  averageFocusToday: number
  focusTrend: Trend
  weeklyHours: number
  previousWeeklyHours: number
  weeklyMomentumHours: number
  topPrioritySubject: StudyPrioritySubject | null
  insights: StudyInsightItem[]
}

export interface EscalatedReminder extends ReminderItem {
  urgency: ReminderUrgency
}

function sumSessionDuration(sessions: StudySession[]) {
  return sessions.reduce((sum, session) => sum + session.duration, 0)
}

function getAverageFocus(sessions: StudySession[]) {
  if (sessions.length === 0) {
    return 0
  }

  return Math.round(sessions.reduce((sum, session) => sum + session.focusScore, 0) / sessions.length)
}

function getSessionsForDates(sessions: StudySession[], dates: Set<string>) {
  return sessions.filter((session) => dates.has(session.date))
}

function getFocusTrend(sessions: StudySession[]) {
  const recentDates = new Set(Array.from({ length: 3 }, (_, index) => getOffsetIsoDate(index - 2)))
  const previousDates = new Set(Array.from({ length: 3 }, (_, index) => getOffsetIsoDate(index - 5)))
  const recentAverage = getAverageFocus(getSessionsForDates(sessions, recentDates))
  const previousAverage = getAverageFocus(getSessionsForDates(sessions, previousDates))

  if (recentAverage - previousAverage >= 5) {
    return 'rising' as const
  }

  if (previousAverage - recentAverage >= 5) {
    return 'falling' as const
  }

  return 'steady' as const
}

function getStreakDays(sessions: StudySession[]) {
  const uniqueDates = new Set(sessions.map((session) => session.date))
  let streak = 0

  for (let offset = 0; offset < 365; offset += 1) {
    const date = getOffsetIsoDate(-offset)

    if (!uniqueDates.has(date)) {
      break
    }

    streak += 1
  }

  return streak
}

function getWeeklyHours(sessions: StudySession[], offsetStart: number, offsetEnd: number) {
  const dates = new Set(
    Array.from({ length: offsetEnd - offsetStart + 1 }, (_, index) => getOffsetIsoDate(offsetStart + index)),
  )
  return Number(sumSessionDuration(getSessionsForDates(sessions, dates)).toFixed(1))
}

function getTaskCountWithinDays(tasks: PlannerTask[], dayCount: number) {
  const today = getTodayIsoDate()
  const threshold = getOffsetIsoDate(dayCount)
  return tasks.filter((task) => !task.completed && task.dueDate >= today && task.dueDate <= threshold).length
}

export function getReminderUrgency(reminder: ReminderItem): ReminderUrgency {
  if (reminder.completed) {
    return 'completed'
  }

  const today = getTodayIsoDate()
  const reminderDate = reminder.remindAt.slice(0, 10)

  if (reminder.remindAt < `${today}T23:59` && reminderDate < today) {
    return 'overdue'
  }

  if (reminderDate === today) {
    return 'today'
  }

  if (reminderDate === getOffsetIsoDate(1)) {
    return 'tomorrow'
  }

  return 'upcoming'
}

export function getEscalatedReminders(reminders: ReminderItem[]) {
  const urgencyOrder: Record<ReminderUrgency, number> = {
    overdue: 0,
    today: 1,
    tomorrow: 2,
    upcoming: 3,
    completed: 4,
  }

  return reminders
    .map<EscalatedReminder>((reminder) => ({
      ...reminder,
      urgency: getReminderUrgency(reminder),
    }))
    .sort((a, b) => {
      const urgencyDiff = urgencyOrder[a.urgency] - urgencyOrder[b.urgency]

      if (urgencyDiff !== 0) {
        return urgencyDiff
      }

      return a.remindAt.localeCompare(b.remindAt)
    })
}

function getTopPrioritySubject(subjects: Subject[], tasks: PlannerTask[]) {
  if (subjects.length === 0) {
    return null
  }

  const today = getTodayIsoDate()

  return [...subjects]
    .map((subject) => {
      const subjectTasks = tasks.filter((task) => task.subject === subject.name && !task.completed)
      const overdueTasks = subjectTasks.filter((task) => task.dueDate < today).length
      const dueSoonTasks = subjectTasks.filter((task) => task.dueDate >= today && task.dueDate <= getOffsetIsoDate(3)).length
      const examPressure = subject.examDate && subject.examDate >= today && subject.examDate <= getOffsetIsoDate(7) ? 1 : 0
      const remainingHours = Math.max(subject.weeklyGoal - subject.studiedHours, 0)
      const score = overdueTasks * 40 + dueSoonTasks * 18 + examPressure * 26 + remainingHours * 3 + Math.max(70 - subject.progress, 0)

      let reason = 'Needs attention to keep momentum high.'

      if (overdueTasks > 0) {
        reason = `${overdueTasks} overdue task${overdueTasks === 1 ? '' : 's'} need clearing.`
      } else if (examPressure > 0) {
        reason = 'Upcoming exam is close, so revision pressure is higher.'
      } else if (remainingHours > 0) {
        reason = `${remainingHours.toFixed(1)}h still needed to reach the weekly target.`
      } else if (subject.progress < 70) {
        reason = 'Progress is still below the strong zone.'
      }

      return {
        name: subject.name,
        progress: subject.progress,
        score,
        reason,
      }
    })
    .sort((a, b) => b.score - a.score)[0] ?? null
}

function createInsights({
  subjects,
  tasks,
  reminders,
  sessions,
  todayHours,
  dailyGoalHours,
  overdueTaskCount,
  dueSoonTaskCount,
  topPrioritySubject,
}: {
  subjects: Subject[]
  tasks: PlannerTask[]
  reminders: ReminderItem[]
  sessions: StudySession[]
  todayHours: number
  dailyGoalHours: number
  overdueTaskCount: number
  dueSoonTaskCount: number
  topPrioritySubject: StudyPrioritySubject | null
}) {
  const insights: StudyInsightItem[] = []

  if (subjects.length === 0) {
    insights.push({
      id: 'add-subject',
      title: 'Create your first subject',
      description: 'A subject unlocks planner, notes, flashcards, and better analytics.',
      route: '/subjects',
      actionLabel: 'Add Subject',
      tone: 'focus',
    })
  }

  if (overdueTaskCount > 0) {
    insights.push({
      id: 'clear-overdue',
      title: `Clear ${overdueTaskCount} overdue task${overdueTaskCount === 1 ? '' : 's'}`,
      description: 'Your planner has missed deadlines that are dragging down the daily plan.',
      route: '/planner',
      actionLabel: 'Open Planner',
      tone: 'urgent',
    })
  }

  if (todayHours < dailyGoalHours) {
    const remaining = Number(Math.max(dailyGoalHours - todayHours, 0).toFixed(1))
    insights.push({
      id: 'hit-daily-goal',
      title: `Finish ${remaining}h to hit today’s goal`,
      description: 'A focused timer sprint is the fastest way to close the gap.',
      route: '/timer',
      actionLabel: 'Start Timer',
      tone: 'focus',
    })
  }

  if (topPrioritySubject) {
    insights.push({
      id: 'priority-subject',
      title: `Prioritize ${topPrioritySubject.name}`,
      description: topPrioritySubject.reason,
      route: '/subjects',
      actionLabel: 'Review Subject',
      tone: 'focus',
    })
  }

  const pendingReminders = reminders.filter((reminder) => !reminder.completed).length

  if (pendingReminders > 0) {
    insights.push({
      id: 'pending-reminders',
      title: `${pendingReminders} active reminder${pendingReminders === 1 ? '' : 's'} waiting`,
      description: 'Use reminders to stay ahead of classes, revisions, and submissions.',
      route: '/reminders',
      actionLabel: 'View Reminders',
      tone: 'steady',
    })
  }

  if (sessions.length === 0 && tasks.length > 0) {
    insights.push({
      id: 'log-first-session',
      title: 'Log your first study session',
      description: 'Tracking sessions unlocks stronger focus analytics and streaks.',
      route: '/tracker',
      actionLabel: 'Open Tracker',
      tone: 'steady',
    })
  }

  if (dueSoonTaskCount > 0 && overdueTaskCount === 0) {
    insights.push({
      id: 'due-soon',
      title: `${dueSoonTaskCount} task${dueSoonTaskCount === 1 ? '' : 's'} due soon`,
      description: 'Your next few days are getting busy, so it is a good time to pre-plan them now.',
      route: '/planner',
      actionLabel: 'Plan Ahead',
      tone: 'steady',
    })
  }

  if (insights.length === 0) {
    insights.push({
      id: 'steady-progress',
      title: 'You are in a stable study zone',
      description: 'No urgent blockers detected. This is a good moment for deep work or revision.',
      route: '/analytics',
      actionLabel: 'View Analytics',
      tone: 'steady',
    })
  }

  return insights.slice(0, 4)
}

export function buildStudyIntelligence(workspace: StudyWorkspaceData): StudyIntelligence {
  const today = getTodayIsoDate()
  const todaySessions = workspace.sessions.filter((session) => session.date === today)
  const todayHours = Number(sumSessionDuration(todaySessions).toFixed(1))
  const dailyGoalHours = workspace.settings.dailyStudyGoal
  const completedTaskCount = workspace.tasks.filter((task) => task.completed).length
  const completionRate =
    workspace.tasks.length > 0 ? Math.round((completedTaskCount / workspace.tasks.length) * 100) : 0
  const overdueTaskCount = workspace.tasks.filter((task) => !task.completed && task.dueDate < today).length
  const dueSoonTaskCount = getTaskCountWithinDays(workspace.tasks, 3)
  const pendingReminderCount = workspace.reminders.filter((reminder) => !reminder.completed).length
  const averageFocusToday = getAverageFocus(todaySessions)
  const focusTrend = getFocusTrend(workspace.sessions)
  const streakDays = getStreakDays(workspace.sessions)
  const weeklyHours = getWeeklyHours(workspace.sessions, -6, 0)
  const previousWeeklyHours = getWeeklyHours(workspace.sessions, -13, -7)
  const weeklyMomentumHours = Number((weeklyHours - previousWeeklyHours).toFixed(1))
  const topPrioritySubject = getTopPrioritySubject(workspace.subjects, workspace.tasks)

  const readinessScore = Math.max(
    0,
    Math.min(
      100,
      Math.round(
        58 +
          Math.min(todayHours / Math.max(dailyGoalHours, 1), 1) * 18 +
          Math.min(streakDays, 7) * 2 +
          (focusTrend === 'rising' ? 8 : focusTrend === 'falling' ? -8 : 2) +
          completionRate * 0.12 -
          overdueTaskCount * 9 -
          Math.max(pendingReminderCount - 3, 0) * 2,
      ),
    ),
  )

  return {
    readinessScore,
    streakDays,
    todayHours,
    dailyGoalHours,
    completionRate,
    overdueTaskCount,
    dueSoonTaskCount,
    pendingReminderCount,
    averageFocusToday,
    focusTrend,
    weeklyHours,
    previousWeeklyHours,
    weeklyMomentumHours,
    topPrioritySubject,
    insights: createInsights({
      subjects: workspace.subjects,
      tasks: workspace.tasks,
      reminders: workspace.reminders,
      sessions: workspace.sessions,
      todayHours,
      dailyGoalHours,
      overdueTaskCount,
      dueSoonTaskCount,
      topPrioritySubject,
    }),
  }
}
