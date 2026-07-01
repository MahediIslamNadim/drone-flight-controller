import { createContext } from 'react'

interface WorkspaceContextValue {
  focusModeEnabled: boolean
  dailyBriefingEnabled: boolean
  isDailyBriefingOpen: boolean
  setFocusModeEnabled: (enabled: boolean) => void
  toggleFocusMode: () => void
  setDailyBriefingEnabled: (enabled: boolean) => void
  openDailyBriefing: () => void
  closeDailyBriefing: () => void
}

export const WorkspaceContext = createContext<WorkspaceContextValue | null>(null)
