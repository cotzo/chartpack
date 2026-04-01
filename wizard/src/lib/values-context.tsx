import { WizardContext } from './wizard-context'

export function ValuesProvider({ values, navigateTo, children }: {
  values: Record<string, unknown>
  navigateTo?: (stepId: string) => void
  children: React.ReactNode
}) {
  return <WizardContext.Provider value={{ values, navigateTo }}>{children}</WizardContext.Provider>
}
