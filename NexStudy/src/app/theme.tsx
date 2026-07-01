import { useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { loadSettings, saveSettings, STORAGE_KEYS, subscribeToStudyData, type ThemeMode } from '../lib/studyData'
import { ThemeContext } from './theme-context'

function getInitialThemeMode(): ThemeMode {
  if (typeof window === 'undefined') {
    return 'light'
  }

  return loadSettings().themeMode
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [themeMode, setThemeModeState] = useState<ThemeMode>(getInitialThemeMode)

  useEffect(() => {
    document.documentElement.dataset.theme = themeMode
    document.documentElement.style.colorScheme = themeMode
  }, [themeMode])

  useEffect(() => {
    const currentSettings = loadSettings()

    if (currentSettings.themeMode !== themeMode) {
      saveSettings({ ...currentSettings, themeMode })
    }
  }, [themeMode])

  useEffect(() => {
    return subscribeToStudyData(() => {
      const nextThemeMode = loadSettings().themeMode
      setThemeModeState((current) => (current === nextThemeMode ? current : nextThemeMode))
    }, [STORAGE_KEYS.settings])
  }, [])

  function setThemeMode(mode: ThemeMode) {
    setThemeModeState(mode)
  }

  function toggleThemeMode() {
    setThemeModeState((current) => (current === 'dark' ? 'light' : 'dark'))
  }

  return (
    <ThemeContext.Provider value={{ themeMode, setThemeMode, toggleThemeMode }}>
      {children}
    </ThemeContext.Provider>
  )
}
