import { createContext } from 'react'

export interface WizardContextType {
  values: Record<string, unknown>
  navigateTo?: (stepId: string) => void
}

export const WizardContext = createContext<WizardContextType>({ values: {} })
