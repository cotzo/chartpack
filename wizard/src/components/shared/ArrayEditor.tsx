import { Plus, X } from 'lucide-react'
import { HelpText } from './HelpText'

interface ArrayEditorProps {
  label: string
  value: string[]
  onChange: (value: string[]) => void
  placeholder?: string
  helpText?: string
}

export function ArrayEditor({ label, value = [], onChange, placeholder = 'Value', helpText }: ArrayEditorProps) {
  const addItem = () => onChange([...value, ''])

  const removeItem = (idx: number) => {
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
        <button type="button" onClick={addItem} className="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800">
          <Plus className="h-3 w-3" /> Add
        </button>
      </div>
      {helpText && <HelpText text={helpText} />}
      {value.map((item, idx) => (
        <div key={idx} className="flex items-center gap-2">
          <input
            value={item}
            onChange={e => updateItem(idx, e.target.value)}
            placeholder={placeholder}
            className="flex-1 rounded-md border border-gray-300 bg-white px-2 py-1.5 text-sm"
          />
          <button type="button" aria-label="Remove item" onClick={() => removeItem(idx)} className="text-gray-400 hover:text-red-600">
            <X className="h-4 w-4" />
          </button>
        </div>
      ))}
      {value.length === 0 && <p className="text-xs text-gray-400 italic">No items</p>}
    </div>
  )
}
