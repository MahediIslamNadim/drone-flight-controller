import { useEffect } from 'react'
import type { ReactNode } from 'react'
import { useState } from 'react'
import { loadSettings, saveSettings, STORAGE_KEYS, subscribeToStudyData, getTodayIsoDate } from '../lib/studyData'
import { WorkspaceContext } from './workspace-context'

const DAILY_BRIEFING_STORAGE_KEY = 'nexstudy-daily-briefing-last-seen'

function canUseStorage() {
  return typeof window !== 'undefined' && typeof window.localStorage !== 'undefined'
}

function getInitialWorkspaceState() {
  const settings = loadSettings()
  const lastSeenBriefingDate = canUseStorage()
    ? window.localStorage.getItem(DAILY_BRIEFING_STORAGE_KEY)
    : null
  const shouldOpenBriefing = settings.dailyBriefingEnabled && lastSeenBriefingDate !== getTodayIsoDate()

  return {
    focusModeEnabled: settings.focusModeEnabled,
    dailyBriefingEnabled: settings.dailyBriefingEnabled,
    isDailyBriefingOpen: shouldOpenBriefing,
  }
}

function markBriefingSeen() {
  if (!canUseStorage()) {
    return
  }

  window.localStorage.setItem(DAILY_BRIEFING_STORAGE_KEY, getTodayIsoDate())
}

export function WorkspaceProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState(getInitialWorkspaceState)

  useEffect(() => {
    return subscribeToStudyData(() => {
      const settings = loadSettings()
      const lastSeenBriefingDate = canUseStorage()
        ? window.localStorage.getItem(DAILY_BRIEFING_STORAGE_KEY)
        : null
      const shouldOpenBriefing = settings.dailyBriefingEnabled && lastSeenBriefingDate !== getTodayIsoDate()

      setState((current) => ({
        focusModeEnabled: settings.focusModeEnabled,
        dailyBriefingEnabled: settings.dailyBriefingEnabled,
        isDailyBriefingOpen:
          current.isDailyBriefingOpen || shouldOpenBriefing,
      }))
    }, [STORAGE_KEYS.settings])
  }, [])

  function updateSettings(partial: Partial<ReturnType<typeof loadSettings>>) {
    saveSettings({ ...loadSettings(), ...partial })
  }

  function setFocusModeEnabled(enabled: boolean) {
    updateSettings({ focusModeEnabled: enabled })
    setState((current) => ({ ...current, focusModeEnabled: enabled }))
  }

  function toggleFocusMode() {
    setFocusModeEnabled(!state.focusModeEnabled)
  }

  function setDailyBriefingEnabled(enabled: boolean) {
    updateSettings({ dailyBriefingEnabled: enabled })

    if (!enabled) {
      markBriefingSeen()
    }

    setState((current) => ({
      ...current,
      dailyBriefingEnabled: enabled,
      isDailyBriefingOpen: enabled ? current.isDailyBriefingOpen : false,
    }))
  }

  function openDailyBriefing() {
    setState((current) => ({ ...current, isDailyBriefingOpen: true }))
  }

  function closeDailyBriefing() {
    markBriefingSeen()
    setState((current) => ({ ...current, isDailyBriefingOpen: false }))
  }

  return (
    <WorkspaceContext.Provider
      value={{
        focusModeEnabled: state.focusModeEnabled,
        dailyBriefingEnabled: state.dailyBriefingEnabled,
        isDailyBriefingOpen: state.isDailyBriefingOpen,
        setFocusModeEnabled,
        toggleFocusMode,
        setDailyBriefingEnabled,
        openDailyBriefing,
        closeDailyBriefing,
      }}
    >
      {children}
    </WorkspaceContext.Provider>
  )
}
