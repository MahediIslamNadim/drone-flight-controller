import { lazy } from 'react'

export const DashboardPage = lazy(() => import('../features/dashboard/DashboardPage'))
export const SubjectsPage = lazy(() => import('../features/subjects/SubjectsPage'))
export const TrackerPage = lazy(() => import('../features/tracker/TrackerPage'))
export const PlannerPage = lazy(() => import('../features/planner/PlannerPage'))
export const NotesPage = lazy(() => import('../features/notes/NotesPage'))
export const FlashcardsPage = lazy(() => import('../features/flashcards/FlashcardsPage'))
export const TimetablePage = lazy(() => import('../features/timetable/TimetablePage'))
export const TimerPage = lazy(() => import('../features/timer/TimerPage'))
export const GoalsPage = lazy(() => import('../features/goals/GoalsPage'))
export const AnalyticsPage = lazy(() => import('../features/analytics/AnalyticsPage'))
export const RemindersPage = lazy(() => import('../features/reminders/RemindersPage'))
export const SettingsPage = lazy(() => import('../features/settings/SettingsPage'))
