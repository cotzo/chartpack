import { useState } from 'react'
import { ChevronDown, Plus, X } from 'lucide-react'
import { HelpText } from './HelpText'

interface ArrayEditorProps {
  label: string
  value: string[]
  onChange: (value: string[]) => void
  placeholder?: string
  helpText?: string
  /** When provided, render dropdowns instead of text inputs */
  options?: string[]
  /** When true, filter out already-selected values from dropdowns and hide Add when exhausted */
  uniqueItems?: boolean
  /** Link to the step that manages the options */
  optionsStepInfo?: { stepId: string; label: string; navigate: (stepId: string) => void }
}

export function ArrayEditor({ label, value = [], onChange, placeholder = 'Value', helpText, options, uniqueItems, optionsStepInfo }: ArrayEditorProps) {
  const [stableIds] = useState(() => new Map<number, string>())

  // Ensure each index has a stable ID
  while (stableIds.size < value.length) {
    stableIds.set(stableIds.size, crypto.randomUUID())
  }

  const addItem = () => {
    stableIds.set(value.length, crypto.randomUUID())
    onChange([...value, ''])
  }

  const removeItem = (idx: number) => {
    const newIds = new Map<number, string>()
    for (let i = 0; i < value.length; i++) {
      if (i < idx) newIds.set(i, stableIds.get(i)!)
      else if (i > idx) newIds.set(i - 1, stableIds.get(i)!)
    }
    stableIds.clear()
    for (const [k, v] of newIds) stableIds.set(k, v)

    const next = [...value]
    next.splice(idx, 1)
    onChange(next)
  }

  const updateItem = (idx: number, val: string) => {
    const next = [...value]
    next[idx] = val
    onChange(next)
  }

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <label className="block text-sm font-medium text-gray-700">{label} <span className="text-gray-400">({value.length})</span></label>
        <button type="button" onClick={addItem} className="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800" hidden={options != null && (options.length === 0 || (uniqueItems && options.length <= value.length))}>
          <Plus className="h-3 w-3" /> Add
        </button>
      </div>
      {helpText && <HelpText text={helpText} />}
      {value.map((item, idx) => (
        <div key={stableIds.get(idx) ?? idx} className="flex items-center gap-2">
          {options ? (
            <div className="relative flex-1">
              <select
                value={item}
                onChange={e => updateItem(idx, e.target.value)}
                className="block w-full appearance-none rounded-md border border-gray-300 bg-white px-3 py-1.5 pr-9 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 cursor-pointer"
              >
                <option value="">Select...</option>
                {options.filter(opt => !uniqueItems || opt === item || !value.includes(opt)).map(opt => (
                  <option key={opt} value={opt}>{opt}</option>
                ))}
              </select>
              <ChevronDown className="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            </div>
          ) : (
            <input
              value={item}
              onChange={e => updateItem(idx, e.target.value)}
              placeholder={placeholder}
              className="flex-1 rounded-md border border-gray-300 bg-white px-2 py-1.5 text-sm"
            />
          )}
          <button type="button" aria-label="Remove item" onClick={() => removeItem(idx)} className="text-gray-400 hover:text-red-600">
            <X className="h-4 w-4" />
          </button>
        </div>
      ))}
      {value.length === 0 && options?.length === 0 && optionsStepInfo && (
        <div className="rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-xs text-amber-700">
          No stores defined.{' '}
          <button type="button" onClick={() => optionsStepInfo.navigate(optionsStepInfo.stepId)} className="underline font-medium hover:text-amber-900">
            Go to {optionsStepInfo.label}
          </button>
        </div>
      )}
      {value.length === 0 && !(options?.length === 0 && optionsStepInfo) && <p className="text-xs text-gray-400 italic">No items</p>}
    </div>
  )
}
