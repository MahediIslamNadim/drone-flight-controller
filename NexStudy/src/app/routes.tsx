import { Suspense } from 'react'
import type { ReactNode } from 'react'
import { createBrowserRouter } from 'react-router-dom'
import MainLayout from '../components/layout/MainLayout'
import {
  AnalyticsPage,
  DashboardPage,
  FlashcardsPage,
  GoalsPage,
  NotesPage,
  PlannerPage,
  RemindersPage,
  SettingsPage,
  SubjectsPage,
  TimetablePage,
  TimerPage,
  TrackerPage,
} from './LazyPages'

function renderPage(node: ReactNode) {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-[240px] text-sm text-[var(--color-text-muted)]">
          Loading...
        </div>
      }
    >
      {node}
    </Suspense>
  )
}

export const router = createBrowserRouter([
  {
    path: '/',
    element: <MainLayout />,
    children: [
      { index: true, element: renderPage(<DashboardPage />) },
      { path: 'subjects', element: renderPage(<SubjectsPage />) },
      { path: 'tracker', element: renderPage(<TrackerPage />) },
      { path: 'planner', element: renderPage(<PlannerPage />) },
      { path: 'notes', element: renderPage(<NotesPage />) },
      { path: 'flashcards', element: renderPage(<FlashcardsPage />) },
      { path: 'timetable', element: renderPage(<TimetablePage />) },
      { path: 'timer', element: renderPage(<TimerPage />) },
      { path: 'goals', element: renderPage(<GoalsPage />) },
      { path: 'analytics', element: renderPage(<AnalyticsPage />) },
      { path: 'reminders', element: renderPage(<RemindersPage />) },
      { path: 'settings', element: renderPage(<SettingsPage />) },
    ],
  },
])
