import { useState } from 'react'
import { Plus, Trash2, ChevronDown, ChevronRight } from 'lucide-react'
import { HelpText } from './HelpText'

type SourceType = 'configMap' | 'secret' | 'persistence' | 'volume'

interface MountEntry {
  path: string
  configMap?: string
  secret?: string
  persistence?: string
  volume?: string
  external?: boolean
  readOnly?: boolean
  subPath?: string
  items?: unknown[]
  defaultMode?: number
}

const SOURCE_LABELS: Record<SourceType, string> = {
  configMap: 'ConfigMap',
  secret: 'Secret',
  persistence: 'Persistence',
  volume: 'Volume',
}

function detectSource(entry: MountEntry): SourceType {
  if ('configMap' in entry) return 'configMap'
  if ('secret' in entry) return 'secret'
  if ('persistence' in entry) return 'persistence'
  if ('volume' in entry) return 'volume'
  return 'configMap'
}

function getSourceValue(entry: MountEntry, type: SourceType): string {
  return (entry[type] as string) ?? ''
}

function setSource(entry: MountEntry, type: SourceType, value: string): MountEntry {
  const next: MountEntry = { path: entry.path, readOnly: entry.readOnly, subPath: entry.subPath, items: entry.items, defaultMode: entry.defaultMode, external: entry.external }
  next[type] = value
  // Clean undefined fields
  if (!next.readOnly) delete next.readOnly
  if (!next.subPath) delete next.subPath
  if (!next.items || (Array.isArray(next.items) && next.items.length === 0)) delete next.items
  if (next.defaultMode === undefined) delete next.defaultMode
  if (!next.external) delete next.external
  return next
}

interface MountsEditorProps {
  label: string
  value: MountEntry[]
  onChange: (value: MountEntry[]) => void
  helpText?: string
}

export function MountsEditor({ label, value = [], onChange, helpText }: MountsEditorProps) {
  const [expandedIdx, setExpandedIdx] = useState<Set<number>>(new Set())

  const addMount = () => {
    onChange([...value, { path: '' }])
    setExpandedIdx(new Set([...expandedIdx, value.length]))
  }

  const removeMount = (idx: number) => {
    onChange(value.filter((_, i) => i !== idx))
    const next = new Set<number>()
    for (const i of expandedIdx) {
      if (i < idx) next.add(i)
      else if (i > idx) next.add(i - 1)
    }
    setExpandedIdx(next)
  }

  const updateMount = (idx: number, entry: MountEntry) => {
    const next = [...value]
    next[idx] = entry
    onChange(next)
  }

  const toggleExpand = (idx: number) => {
    const next = new Set(expandedIdx)
    if (next.has(idx)) next.delete(idx)
    else next.add(idx)
    setExpandedIdx(next)
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <label className="block text-sm font-medium text-gray-700">{label} <span className="text-gray-400">({value.length})</span></label>
        <button type="button" onClick={addMount} className="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800">
          <Plus className="h-3 w-3" /> Add
        </button>
      </div>
      {helpText && <HelpText text={helpText} />}

      {value.map((entry, idx) => {
        const sourceType = detectSource(entry)
        const sourceValue = getSourceValue(entry, sourceType)
        const isExpanded = expandedIdx.has(idx)
        const summary = entry.path || '(no path)'

        return (
          <div key={idx} className="border border-gray-200 rounded-lg overflow-hidden">
            {/* Header row */}
            <div className="flex items-center gap-2 px-3 py-2 bg-gray-50">
              <button type="button" onClick={() => toggleExpand(idx)} className="text-gray-500">
                {isExpanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
              </button>
              <span className="flex-1 text-sm font-medium text-gray-800 truncate">{summary}</span>
              <span className="text-xs text-gray-400">{SOURCE_LABELS[sourceType]}{sourceValue ? `: ${sourceValue}` : ''}</span>
              <button type="button" aria-label="Remove mount" onClick={() => removeMount(idx)} className="text-gray-400 hover:text-red-600">
                <Trash2 className="h-4 w-4" />
              </button>
            </div>

            {isExpanded && (
              <div className="px-4 py-4 space-y-3 border-t border-gray-200">
                {/* Path */}
                <div className="space-y-1">
                  <label className="block text-xs font-medium text-gray-600">Mount Path <span className="text-red-500">*</span></label>
                  <input
                    value={entry.path}
                    onChange={e => updateMount(idx, { ...entry, path: e.target.value })}
                    placeholder="/mnt/data"
                    className="block w-full rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm"
                  />
                </div>

                {/* Source type + name */}
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1">
                    <label className="block text-xs font-medium text-gray-600">Source Type</label>
                    <div className="relative">
                      <select
                        value={sourceType}
                        onChange={e => {
                          const newType = e.target.value as SourceType
                          updateMount(idx, setSource(entry, newType, sourceValue))
                        }}
                        className="block w-full appearance-none rounded-md border border-gray-300 bg-white pl-3 pr-8 py-1.5 text-sm"
                      >
                        {(Object.keys(SOURCE_LABELS) as SourceType[]).map(t => (
                          <option key={t} value={t}>{SOURCE_LABELS[t]}</option>
                        ))}
                      </select>
                      <ChevronDown className="pointer-events-none absolute right-2 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-gray-400" />
                    </div>
                  </div>
                  <div className="space-y-1">
                    <label className="block text-xs font-medium text-gray-600">Source Name</label>
                    <input
                      value={sourceValue}
                      onChange={e => updateMount(idx, setSource(entry, sourceType, e.target.value))}
                      placeholder={sourceType === 'volume' ? 'volume-name' : 'resource-key'}
                      className="block w-full rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm"
                    />
                  </div>
                </div>

                {/* Sub-path */}
                <div className="space-y-1">
                  <label className="block text-xs font-medium text-gray-600">Sub Path</label>
                  <input
                    value={entry.subPath ?? ''}
                    onChange={e => updateMount(idx, { ...entry, subPath: e.target.value || undefined })}
                    placeholder="Optional sub-path within the volume"
                    className="block w-full rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm"
                  />
                </div>

                {/* Options */}
                <div className="grid grid-cols-2 gap-3">
                  <div className="flex items-center justify-between">
                    <div>
                      <span className="text-sm font-medium text-gray-700">Read Only</span>
                      <p className="text-xs text-gray-500">Mount as read-only</p>
                    </div>
                    <button
                      type="button"
                      role="switch"
                      aria-checked={!!entry.readOnly}
                      onClick={() => updateMount(idx, { ...entry, readOnly: !entry.readOnly || undefined })}
                      className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors ${entry.readOnly ? 'bg-blue-600' : 'bg-gray-200'}`}
                    >
                      <span className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition-transform ${entry.readOnly ? 'translate-x-5' : 'translate-x-0'}`} />
                    </button>
                  </div>
                  {(sourceType === 'configMap' || sourceType === 'secret') && (
                    <div className="flex items-center justify-between">
                      <div>
                        <span className="text-sm font-medium text-gray-700">External</span>
                        <p className="text-xs text-gray-500">Not prefixed with release name</p>
                      </div>
                      <button
                        type="button"
                        role="switch"
                        aria-checked={!!entry.external}
                        onClick={() => updateMount(idx, { ...entry, external: !entry.external || undefined })}
                        className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors ${entry.external ? 'bg-blue-600' : 'bg-gray-200'}`}
                      >
                        <span className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition-transform ${entry.external ? 'translate-x-5' : 'translate-x-0'}`} />
                      </button>
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>
        )
      })}

      {value.length === 0 && <p className="text-xs text-gray-400 italic">No mounts</p>}
    </div>
  )
}
