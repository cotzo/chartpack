import { useContext } from 'react'
import { WizardContext } from './wizard-context'

export function useWizardValues(): Record<string, unknown> {
  return useContext(WizardContext).values
}

export function useWizardNavigate(): ((stepId: string) => void) | undefined {
  return useContext(WizardContext).navigateTo
}
