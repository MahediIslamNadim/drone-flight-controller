import { createContext } from 'react'
import type { ThemeMode } from '../lib/studyData'

export interface ThemeContextValue {
  themeMode: ThemeMode
  setThemeMode: (mode: ThemeMode) => void
  toggleThemeMode: () => void
}

export const ThemeContext = createContext<ThemeContextValue | undefined>(undefined)
