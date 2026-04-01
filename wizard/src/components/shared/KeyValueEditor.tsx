import { Plus, X } from 'lucide-react'
import { HelpText } from './HelpText'

interface KeyValueEditorProps {
  label: string
  value: Record<string, string>
  onChange: (value: Record<string, string>) => void
  keyPlaceholder?: string
  valuePlaceholder?: string
  helpText?: string
}

export function KeyValueEditor({ label, value = {}, onChange, keyPlaceholder = 'Key', valuePlaceholder = 'Value', helpText }: KeyValueEditorProps) {
  const entries = Object.entries(value)

  const addEntry = () => {
    onChange({ ...value, '': '' })
  }

  const removeEntry = (key: string) => {
    const next = { ...value }
    delete next[key]
    onChange(next)
  }

  const updateKey = (oldKey: string, newKey: string) => {
    const next: Record<string, string> = {}
    for (const [k, v] of Object.entries(value)) {
      next[k === oldKey ? newKey : k] = v
    }
    onChange(next)
  }

  const updateValue = (key: string, newVal: string) => {
    onChange({ ...value, [key]: newVal })
  }

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <label className="block text-sm font-medium text-gray-700">{label} <span className="text-gray-400">({entries.length})</span></label>
        <button type="button" onClick={addEntry} className="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800">
          <Plus className="h-3 w-3" /> Add
        </button>
      </div>
      {helpText && <HelpText text={helpText} />}
      {entries.map(([key, val], idx) => (
        <div key={idx} className="flex items-center gap-2">
          <input
            value={key}
            onChange={e => updateKey(key, e.target.value)}
            placeholder={keyPlaceholder}
            className="flex-1 rounded-md border border-gray-300 bg-white px-2 py-1.5 text-sm"
          />
          <input
            value={val}
            onChange={e => updateValue(key, e.target.value)}
            placeholder={valuePlaceholder}
            className="flex-1 rounded-md border border-gray-300 bg-white px-2 py-1.5 text-sm"
          />
          <button type="button" onClick={() => removeEntry(key)} className="text-gray-400 hover:text-red-600">
            <X className="h-4 w-4" />
          </button>
        </div>
      ))}
      {entries.length === 0 && <p className="text-xs text-gray-400 italic">No entries</p>}
    </div>
  )
}
