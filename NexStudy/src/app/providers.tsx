import type { ReactNode } from 'react'
import { ThemeProvider } from './theme'
import { WorkspaceProvider } from './workspace'

interface AppProvidersProps {
  children: ReactNode
}

/**
 * AppProviders wraps the app with global context providers.
 * Add theme, auth, or data providers here as features grow.
 */
export function AppProviders({ children }: AppProvidersProps) {
  return (
    <ThemeProvider>
      <WorkspaceProvider>{children}</WorkspaceProvider>
    </ThemeProvider>
  )
}
