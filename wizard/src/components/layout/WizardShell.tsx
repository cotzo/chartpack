import { useState, useEffect, useCallback, useMemo } from 'react'
import { ChevronLeft, ChevronRight, Download, Upload } from 'lucide-react'
import { StepNavigation } from './StepNavigation'
import { type StepConfig, buildStepConfig, getVisibleSteps, groupSteps } from '../../lib/step-config'
import { type JsonSchema, loadSchema } from '../../lib/schema-utils'
import { GenericStep } from '../schema/GenericStep'
import { StepWorkloadType } from '../wizard/StepWorkloadType'
import { StepReview } from '../wizard/StepReview'
import { ImportModal } from '../shared/ImportModal'
import { generateYaml, parseYaml } from '../../lib/yaml-generator'
import { ValuesProvider } from '../../lib/values-context'

export function WizardShell() {
  const [schema, setSchema] = useState<JsonSchema | null>(null)
  const [values, setValues] = useState<Record<string, unknown>>({ workloadType: 'Deployment' })
  const [currentStep, setCurrentStep] = useState('workloadType')
  const [completedSteps, setCompletedSteps] = useState<Set<string>>(new Set())
  const [showImport, setShowImport] = useState(false)
  const [sidebarOpen, setSidebarOpen] = useState(true)

  useEffect(() => {
    loadSchema().then(setSchema)
  }, [])

  const allSteps: StepConfig[] = useMemo(
    () => (schema ? buildStepConfig(schema) : []),
    [schema],
  )

  const workloadType = (values.workloadType as string) || 'Deployment'
  const visibleSteps = getVisibleSteps(allSteps, workloadType)
  let currentIndex = visibleSteps.findIndex(s => s.id === currentStep)

  // Re-anchor if the current step is no longer visible (workload type change, import)
  if (currentIndex === -1 && visibleSteps.length > 0) {
    currentIndex = 0
    // Defer the state update to avoid setting state during render
    queueMicrotask(() => setCurrentStep(visibleSteps[0].id))
  }

  const currentStepConfig = visibleSteps[currentIndex]

  const getValue = useCallback((path: string) => {
    return path.split('.').reduce<unknown>((acc, key) => {
      if (acc && typeof acc === 'object' && !Array.isArray(acc)) {
        return (acc as Record<string, unknown>)[key]
      }
      return undefined
    }, values)
  }, [values])

  const setValue = useCallback((path: string, value: unknown) => {
    setValues(prev => {
      const keys = path.split('.')
      const result = structuredClone(prev)
      let current: Record<string, unknown> = result
      for (let i = 0; i < keys.length - 1; i++) {
        if (!current[keys[i]] || typeof current[keys[i]] !== 'object') {
          current[keys[i]] = {}
        }
        current = current[keys[i]] as Record<string, unknown>
      }
      current[keys[keys.length - 1]] = value
      return result
    })
  }, [])

  const markComplete = useCallback((stepId: string) => {
    setCompletedSteps(prev => new Set([...prev, stepId]))
  }, [])

  const goNext = () => {
    if (currentIndex < visibleSteps.length - 1) {
      markComplete(currentStep)
      setCurrentStep(visibleSteps[currentIndex + 1].id)
    }
  }

  const goPrev = () => {
    if (currentIndex > 0) {
      setCurrentStep(visibleSteps[currentIndex - 1].id)
    }
  }

  const handleImport = (yamlStr: string): string | void => {
    try {
      const parsed = parseYaml(yamlStr)
      setValues(parsed)
      setShowImport(false)
    } catch (e) {
      return (e as Error).message || 'Invalid YAML'
    }
  }

  const handleDownload = () => {
    const yamlStr = generateYaml(values)
    const blob = new Blob([yamlStr], { type: 'text/yaml' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'values.yaml'
    a.click()
    URL.revokeObjectURL(url)
  }

  const renderStep = () => {
    if (!currentStepConfig) return null

    // Special renderers for steps that need custom UI
    if (currentStepConfig.renderer === 'workloadType') {
      return <StepWorkloadType values={values} getValue={getValue} setValue={setValue} />
    }
    if (currentStepConfig.renderer === 'review') {
      return <StepReview values={values} schema={schema} />
    }

    // Generic schema-driven step for everything else
    if (!schema) return <p className="text-sm text-gray-500">Loading schema...</p>

    return (
      <GenericStep
        step={currentStepConfig}
        schema={schema}
        values={values}
        onChange={setValues}
      />
    )
  }

  const navGroups = useMemo(() => groupSteps(visibleSteps), [visibleSteps])

  return (
    <ValuesProvider values={values} navigateTo={setCurrentStep}>
    <div className="flex h-screen bg-gray-50">
      {sidebarOpen && (
        <StepNavigation
          groups={navGroups}
          currentStep={currentStep}
          onStepClick={setCurrentStep}
          completedSteps={completedSteps}
        />
      )}

      <div className="flex-1 flex flex-col min-w-0">
        {/* Top bar */}
        <header className="flex items-center justify-between border-b border-gray-200 bg-white px-6 py-3">
          <div className="flex items-center gap-3">
            <button type="button" onClick={() => setSidebarOpen(!sidebarOpen)} className="text-gray-500 hover:text-gray-700 lg:hidden">
              {sidebarOpen ? <ChevronLeft className="h-5 w-5" /> : <ChevronRight className="h-5 w-5" />}
            </button>
            <h2 className="text-lg font-semibold text-gray-900">
              {currentStepConfig?.label}
            </h2>
            <span className="text-sm text-gray-400">
              Step {currentIndex + 1} of {visibleSteps.length}
            </span>
          </div>
          <div className="flex items-center gap-2">
            <button type="button" onClick={() => setShowImport(true)} className="inline-flex items-center gap-1.5 rounded-md border border-gray-300 px-3 py-1.5 text-sm text-gray-700 hover:bg-gray-50">
              <Upload className="h-4 w-4" /> Import
            </button>
            <button type="button" onClick={handleDownload} className="inline-flex items-center gap-1.5 rounded-md bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700">
              <Download className="h-4 w-4" /> Download YAML
            </button>
          </div>
        </header>

        {/* Step content */}
        <main className="flex-1 overflow-y-auto px-6 py-6">
          <div className="max-w-3xl mx-auto">
            {renderStep()}
          </div>
        </main>

        {/* Bottom nav */}
        <footer className="border-t border-gray-200 bg-white px-6 py-3">
          <div className="flex items-center justify-between max-w-3xl mx-auto">
            <button
              type="button"
              onClick={goPrev}
              disabled={currentIndex === 0}
              className="inline-flex items-center gap-1.5 rounded-md border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed"
            >
              <ChevronLeft className="h-4 w-4" /> Previous
            </button>
            <button
              type="button"
              onClick={goNext}
              disabled={currentIndex === visibleSteps.length - 1}
              className="inline-flex items-center gap-1.5 rounded-md bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-40 disabled:cursor-not-allowed"
            >
              Next <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </footer>
      </div>

      {showImport && <ImportModal onImport={handleImport} onClose={() => setShowImport(false)} />}
    </div>
    </ValuesProvider>
  )
}
