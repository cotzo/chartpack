import { useState } from 'react'
import { Plus, X } from 'lucide-react'
import { HelpText } from './HelpText'

interface NodeTargetingValue {
  values?: string[]
  enforcement?: 'soft' | 'hard'
}

interface NodeTargetingFieldProps {
  label: string
  value: NodeTargetingValue | string[] | undefined
  onChange: (value: NodeTargetingValue | undefined) => void
  helpText?: string
  placeholder?: string
}

function normalize(value: NodeTargetingValue | string[] | undefined): NodeTargetingValue {
  if (!value) return { values: [], enforcement: 'soft' }
  if (Array.isArray(value)) return { values: value, enforcement: 'soft' }
  return { values: value.values ?? [], enforcement: value.enforcement ?? 'soft' }
}

export function NodeTargetingField({ label, value, onChange, helpText, placeholder = 'e.g. linux' }: NodeTargetingFieldProps) {
  const [newItem, setNewItem] = useState('')
  const norm = normalize(value)
  const items = norm.values ?? []

  const emit = (values: string[], enforcement: 'soft' | 'hard') => {
    if (values.length === 0) {
      onChange(undefined)
    } else {
      onChange({ values, enforcement })
    }
  }

  const addItem = () => {
    const trimmed = newItem.trim()
    if (!trimmed || items.includes(trimmed)) return
    emit([...items, trimmed], norm.enforcement ?? 'soft')
    setNewItem('')
  }

  const removeItem = (idx: number) => {
    const next = items.filter((_, i) => i !== idx)
    emit(next, norm.enforcement ?? 'soft')
  }

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <label className="block text-sm font-medium text-gray-700">{label}</label>
        {items.length > 0 && (
          <select
            value={norm.enforcement}
            onChange={e => emit(items, e.target.value as 'soft' | 'hard')}
            className="rounded border border-gray-300 bg-white px-2 py-0.5 text-xs text-gray-600"
          >
            <option value="soft">Soft (preferred)</option>
            <option value="hard">Hard (required)</option>
          </select>
        )}
      </div>
      {helpText && <HelpText text={helpText} />}

      {items.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {items.map((item, idx) => (
            <span key={idx} className="inline-flex items-center gap-1 rounded-full bg-blue-50 px-2.5 py-1 text-sm text-blue-700">
              {item}
              <button type="button" aria-label="Remove value" onClick={() => removeItem(idx)} className="text-blue-400 hover:text-blue-700">
                <X className="h-3 w-3" />
              </button>
            </span>
          ))}
        </div>
      )}

      <div className="flex items-center gap-2">
        <input
          value={newItem}
          onChange={e => setNewItem(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && (e.preventDefault(), addItem())}
          placeholder={placeholder}
          className="flex-1 rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm"
        />
        <button
          type="button"
          onClick={addItem}
          className="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800"
        >
          <Plus className="h-3 w-3" /> Add
        </button>
      </div>
    </div>
  )
}
