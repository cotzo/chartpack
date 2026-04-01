import { useState } from 'react'
import { Plus, Trash2, ChevronDown, ChevronRight } from 'lucide-react'
import { HelpText } from './HelpText'

interface MapEditorProps<T> {
  label: string
  value: Record<string, T>
  onChange: (value: Record<string, T>) => void
  renderItem: (key: string, item: T, onChange: (item: T) => void) => React.ReactNode
  createDefault: () => T
  helpText?: string
  keyPlaceholder?: string
}

export function MapEditor<T>({ label, value = {} as Record<string, T>, onChange, renderItem, createDefault, helpText }: MapEditorProps<T>) {
  const [expandedKeys, setExpandedKeys] = useState<Set<string>>(new Set())
  const [stableIds] = useState(() => new Map<string, string>())

  const entries = Object.entries(value)
  const [counter, setCounter] = useState(entries.length)

  // Assign stable IDs to map keys so React doesn't remount on rename
  for (const [key] of entries) {
    if (!stableIds.has(key)) stableIds.set(key, crypto.randomUUID())
  }
  for (const tracked of stableIds.keys()) {
    if (!(tracked in value)) stableIds.delete(tracked)
  }

  const addEntry = () => {
    let name: string
    let c = counter
    do {
      c++
      name = `item-${c}`
    } while (value[name])
    setCounter(c)
    stableIds.set(name, crypto.randomUUID())
    onChange({ ...value, [name]: createDefault() })
    setExpandedKeys(new Set([...expandedKeys, name]))
  }

  const removeEntry = (key: string) => {
    const next = { ...value }
    delete next[key]
    onChange(next)
    const nextExpanded = new Set(expandedKeys)
    nextExpanded.delete(key)
    setExpandedKeys(nextExpanded)
  }

  const updateEntry = (key: string, item: T) => {
    onChange({ ...value, [key]: item })
  }

  const toggleExpand = (key: string) => {
    const next = new Set(expandedKeys)
    if (next.has(key)) next.delete(key)
    else next.add(key)
    setExpandedKeys(next)
  }

  const renameEntry = (oldKey: string, newKey: string) => {
    if (newKey === oldKey || !newKey.trim()) return
    if (value[newKey]) return
    const next: Record<string, T> = {}
    for (const [k, v] of Object.entries(value)) {
      next[k === oldKey ? newKey : k] = v
    }
    // Transfer stable ID to new key
    const id = stableIds.get(oldKey)
    if (id) {
      stableIds.delete(oldKey)
      stableIds.set(newKey, id)
    }
    onChange(next)
    const nextExpanded = new Set(expandedKeys)
    if (nextExpanded.has(oldKey)) {
      nextExpanded.delete(oldKey)
      nextExpanded.add(newKey)
    }
    setExpandedKeys(nextExpanded)
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <label className="block text-sm font-medium text-gray-700">{label} <span className="text-gray-400">({entries.length})</span></label>
        <button type="button" onClick={addEntry} className="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800">
          <Plus className="h-3 w-3" /> Add
        </button>
      </div>
      {helpText && <HelpText text={helpText} />}

      {entries.map(([key, item]) => (
        <div key={stableIds.get(key) ?? key} className="border border-gray-200 rounded-lg overflow-hidden">
          <div className="flex items-center gap-2 px-3 py-2 bg-gray-50">
            <button type="button" onClick={() => toggleExpand(key)} className="text-gray-500">
              {expandedKeys.has(key) ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
            </button>
            <input
              value={key}
              onChange={e => renameEntry(key, e.target.value)}
              className="flex-1 bg-transparent text-sm font-medium text-gray-800 border-none focus:outline-none focus:ring-0"
            />
            <button type="button" aria-label="Remove entry" onClick={() => removeEntry(key)} className="text-gray-400 hover:text-red-600">
              <Trash2 className="h-4 w-4" />
            </button>
          </div>
          {expandedKeys.has(key) && (
            <div className="px-4 py-4 space-y-4 border-t border-gray-200">
              {renderItem(key, item, (updated) => updateEntry(key, updated))}
            </div>
          )}
        </div>
      ))}

      {entries.length === 0 && <p className="text-xs text-gray-400 italic">No items</p>}
    </div>
  )
}
