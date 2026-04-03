import { useState } from 'react'
import { Plus, Trash2, ChevronDown } from 'lucide-react'
import { HelpText } from './HelpText'
import { useWizardValues, useWizardNavigate } from '../../lib/use-wizard'
import { getKeysAtPath, getStepForPath } from '../../lib/values-utils'

type EnvType = 'value' | 'secretKeyRef' | 'configMapKeyRef' | 'extSecretKeyRef' | 'extConfigMapKeyRef' | 'fieldRef' | 'resourceFieldRef' | 'configMapRef' | 'secretRef' | 'extConfigMapRef' | 'extSecretRef'

interface EnvEntry {
  value?: string
  valueFrom?: {
    secretKeyRef?: { name: string; key: string; external?: boolean }
    configMapKeyRef?: { name: string; key: string; external?: boolean }
    fieldRef?: { fieldPath: string }
    resourceFieldRef?: { resource: string; containerName?: string }
  }
  configMapRef?: { name: string; external?: boolean }
  secretRef?: { name: string; external?: boolean }
}

const TYPE_LABELS: Record<EnvType, string> = {
  value: 'Plain Value',
  secretKeyRef: 'Secret Key',
  configMapKeyRef: 'ConfigMap Key',
  extSecretKeyRef: 'Existing Secret Key',
  extConfigMapKeyRef: 'Existing ConfigMap Key',
  fieldRef: 'Field Ref',
  resourceFieldRef: 'Resource Field',
  configMapRef: 'Bulk ConfigMap',
  secretRef: 'Bulk Secret',
  extConfigMapRef: 'Bulk Existing ConfigMap',
  extSecretRef: 'Bulk Existing Secret',
}

/** Types that are individual env vars (not bulk) */
const INDIVIDUAL_TYPES: EnvType[] = ['value', 'secretKeyRef', 'configMapKeyRef', 'extSecretKeyRef', 'extConfigMapKeyRef', 'fieldRef', 'resourceFieldRef']
/** Types that are bulk (envFrom) */
const BULK_TYPES: EnvType[] = ['configMapRef', 'secretRef', 'extConfigMapRef', 'extSecretRef']

function detectType(entry: EnvEntry): EnvType {
  if (entry.valueFrom?.secretKeyRef?.external) return 'extSecretKeyRef'
  if (entry.valueFrom?.secretKeyRef) return 'secretKeyRef'
  if (entry.valueFrom?.configMapKeyRef?.external) return 'extConfigMapKeyRef'
  if (entry.valueFrom?.configMapKeyRef) return 'configMapKeyRef'
  if (entry.valueFrom?.fieldRef) return 'fieldRef'
  if (entry.valueFrom?.resourceFieldRef) return 'resourceFieldRef'
  if (entry.configMapRef?.external) return 'extConfigMapRef'
  if (entry.configMapRef) return 'configMapRef'
  if (entry.secretRef?.external) return 'extSecretRef'
  if (entry.secretRef) return 'secretRef'
  return 'value'
}

function createEntry(type: EnvType): EnvEntry {
  switch (type) {
    case 'value': return { value: '' }
    case 'secretKeyRef': return { valueFrom: { secretKeyRef: { name: '', key: '' } } }
    case 'configMapKeyRef': return { valueFrom: { configMapKeyRef: { name: '', key: '' } } }
    case 'extSecretKeyRef': return { valueFrom: { secretKeyRef: { name: '', key: '', external: true } } }
    case 'extConfigMapKeyRef': return { valueFrom: { configMapKeyRef: { name: '', key: '', external: true } } }
    case 'fieldRef': return { valueFrom: { fieldRef: { fieldPath: '' } } }
    case 'resourceFieldRef': return { valueFrom: { resourceFieldRef: { resource: '' } } }
    case 'configMapRef': return { configMapRef: { name: '' } }
    case 'secretRef': return { secretRef: { name: '' } }
    case 'extConfigMapRef': return { configMapRef: { name: '', external: true } }
    case 'extSecretRef': return { secretRef: { name: '', external: true } }
  }
}

interface EnvEditorProps {
  label: string
  value: Record<string, EnvEntry>
  onChange: (value: Record<string, EnvEntry>) => void
  helpText?: string
}

export function EnvEditor({ label, value = {}, onChange, helpText }: EnvEditorProps) {
  const [counter, setCounter] = useState(Object.keys(value).length)
  const [stableIds] = useState(() => new Map<string, string>())

  const entries = Object.entries(value)
  for (const [key] of entries) {
    if (!stableIds.has(key)) stableIds.set(key, crypto.randomUUID())
  }
  for (const tracked of stableIds.keys()) {
    if (!(tracked in value)) stableIds.delete(tracked)
  }

  const updateEntry = (key: string, entry: EnvEntry) => {
    onChange({ ...value, [key]: entry })
  }

  const removeEntry = (key: string) => {
    const next = { ...value }
    delete next[key]
    onChange(next)
  }

  const renameEntry = (oldKey: string, newKey: string) => {
    if (newKey === oldKey || !newKey.trim()) return
    if (value[newKey]) return
    const next: Record<string, EnvEntry> = {}
    for (const [k, v] of Object.entries(value)) {
      next[k === oldKey ? newKey : k] = v
    }
    const id = stableIds.get(oldKey)
    if (id) {
      stableIds.delete(oldKey)
      stableIds.set(newKey, id)
    }
    onChange(next)
  }

  const changeType = (key: string, newType: EnvType) => {
    updateEntry(key, createEntry(newType))
  }

  const addEntry = (type: EnvType = 'value') => {
    let name: string
    let c = counter
    do {
      c++
      name = `VAR_${c}`
    } while (value[name])
    setCounter(c)
    stableIds.set(name, crypto.randomUUID())
    onChange({ ...value, [name]: createEntry(type) })
  }

  const perVarEntries = entries.filter(([, e]) => !BULK_TYPES.includes(detectType(e)))
  const bulkEntries = entries.filter(([, e]) => BULK_TYPES.includes(detectType(e)))

  return (
    <div className="space-y-4">
      {/* Per-variable env vars */}
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <label className="block text-sm font-medium text-gray-700">{label} <span className="text-gray-400">({perVarEntries.length})</span></label>
          <button type="button" onClick={() => addEntry()} className="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800">
            <Plus className="h-3 w-3" /> Add
          </button>
        </div>
        {helpText && <HelpText text={helpText} />}
        {perVarEntries.map(([key, entry]) => (
          <EnvRow
            key={stableIds.get(key) ?? key}
            name={key}
            entry={entry}
            onRename={(newName) => renameEntry(key, newName)}
            onUpdate={(e) => updateEntry(key, e)}
            onRemove={() => removeEntry(key)}
            onChangeType={(t) => changeType(key, t)}
          />
        ))}
        {perVarEntries.length === 0 && <p className="text-xs text-gray-400 italic">No environment variables</p>}
      </div>

      {/* Bulk sources (envFrom) */}
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <label className="block text-sm font-medium text-gray-700">Env Sources <span className="text-gray-400">({bulkEntries.length})</span></label>
          <button type="button" onClick={() => addEntry('configMapRef')} className="inline-flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800">
            <Plus className="h-3 w-3" /> Add
          </button>
        </div>
        <HelpText text="Inject all keys from a ConfigMap or Secret as environment variables." />
        {bulkEntries.map(([key, entry]) => (
          <BulkRow
            key={stableIds.get(key) ?? key}
            entry={entry}
            onUpdate={(e) => updateEntry(key, e)}
            onRemove={() => removeEntry(key)}
            onChangeType={(t) => changeType(key, t)}
          />
        ))}
        {bulkEntries.length === 0 && <p className="text-xs text-gray-400 italic">No env sources</p>}
      </div>
    </div>
  )
}

/* --- Per-variable row --- */

const PER_VAR_TYPES: EnvType[] = INDIVIDUAL_TYPES

function EnvRow({ name, entry, onRename, onUpdate, onRemove, onChangeType }: {
  name: string
  entry: EnvEntry
  onRename: (name: string) => void
  onUpdate: (entry: EnvEntry) => void
  onRemove: () => void
  onChangeType: (type: EnvType) => void
}) {
  const type = detectType(entry)

  return (
    <div className="rounded-md border border-gray-200 p-2 space-y-2">
      <div className="flex items-center gap-2">
        {/* Name */}
        <input
          value={name}
          onChange={e => onRename(e.target.value)}
          className="flex-1 rounded border border-gray-300 bg-gray-50 px-2 py-1.5 text-sm font-mono"
          placeholder="VAR_NAME"
        />

        {/* Type selector */}
        <div className="relative shrink-0">
          <select
            value={type}
            onChange={e => onChangeType(e.target.value as EnvType)}
            className="appearance-none rounded border border-gray-300 bg-white pl-2 pr-7 py-1.5 text-sm"
          >
            {PER_VAR_TYPES.map(t => (
              <option key={t} value={t}>{TYPE_LABELS[t]}</option>
            ))}
          </select>
          <ChevronDown className="pointer-events-none absolute right-1.5 top-2 h-3.5 w-3.5 text-gray-400" />
        </div>

        <button type="button" aria-label="Remove variable" onClick={onRemove} className="shrink-0 text-gray-400 hover:text-red-600">
          <Trash2 className="h-4 w-4" />
        </button>
      </div>

      {/* Value fields */}
      <div className="flex items-center gap-2">
        <EnvValueFields entry={entry} type={type} onUpdate={onUpdate} />
      </div>
    </div>
  )
}

/** Dropdown if options exist, warning with link otherwise */
function RefSelect({ value, onChange, optionsPath, placeholder }: {
  value: string
  onChange: (v: string) => void
  optionsPath: string
  placeholder: string
}) {
  const allValues = useWizardValues()
  const navigateTo = useWizardNavigate()
  const options = getKeysAtPath(allValues, optionsPath)
  const stepInfo = getStepForPath(optionsPath)

  if (options.length > 0) {
    return (
      <div className="relative flex-1">
        <select
          value={value}
          onChange={e => onChange(e.target.value)}
          className="block w-full appearance-none rounded border border-gray-300 bg-white pl-2 pr-7 py-1.5 text-sm"
        >
          <option value="">Select...</option>
          {options.map(o => <option key={o} value={o}>{o}</option>)}
        </select>
        <ChevronDown className="pointer-events-none absolute right-1.5 top-2 h-3.5 w-3.5 text-gray-400" />
      </div>
    )
  }

  return (
    <div className="flex-1 rounded border border-amber-300 bg-amber-50 px-2 py-1.5 text-xs text-amber-700">
      No {placeholder}s defined.{' '}
      {stepInfo && navigateTo ? (
        <button type="button" onClick={() => navigateTo(stepInfo.stepId)} className="underline font-medium hover:text-amber-900">
          Go to {stepInfo.label}
        </button>
      ) : (
        <span>Create one first.</span>
      )}
    </div>
  )
}

function EnvValueFields({ entry, type, onUpdate }: {
  entry: EnvEntry
  type: EnvType
  onUpdate: (entry: EnvEntry) => void
}) {
  switch (type) {
    case 'value':
      return (
        <input
          value={entry.value ?? ''}
          onChange={e => onUpdate({ value: e.target.value })}
          placeholder="value"
          className="flex-1 rounded border border-gray-300 bg-white px-2 py-1.5 text-sm"
        />
      )
    case 'secretKeyRef':
      return (
        <>
          <RefSelect
            value={entry.valueFrom?.secretKeyRef?.name ?? ''}
            onChange={v => onUpdate({ valueFrom: { secretKeyRef: { name: v, key: entry.valueFrom?.secretKeyRef?.key ?? '' } } })}
            optionsPath="config.secrets"
            placeholder="secret name"
          />
          <input
            value={entry.valueFrom?.secretKeyRef?.key ?? ''}
            onChange={e => onUpdate({ valueFrom: { secretKeyRef: { name: entry.valueFrom?.secretKeyRef?.name ?? '', key: e.target.value } } })}
            placeholder="key"
            className="flex-1 rounded border border-gray-300 bg-white px-2 py-1.5 text-sm"
          />
        </>
      )
    case 'configMapKeyRef':
      return (
        <>
          <RefSelect
            value={entry.valueFrom?.configMapKeyRef?.name ?? ''}
            onChange={v => onUpdate({ valueFrom: { configMapKeyRef: { name: v, key: entry.valueFrom?.configMapKeyRef?.key ?? '' } } })}
            optionsPath="config.configMaps"
            placeholder="configmap name"
          />
          <input
            value={entry.valueFrom?.configMapKeyRef?.key ?? ''}
            onChange={e => onUpdate({ valueFrom: { configMapKeyRef: { name: entry.valueFrom?.configMapKeyRef?.name ?? '', key: e.target.value } } })}
            placeholder="key"
            className="flex-1 rounded border border-gray-300 bg-white px-2 py-1.5 text-sm"
          />
        </>
      )
    case 'extSecretKeyRef':
      return (
        <>
          <input
            value={entry.valueFrom?.secretKeyRef?.name ?? ''}
            onChange={e => onUpdate({ valueFrom: { secretKeyRef: { name: e.target.value, key: entry.valueFrom?.secretKeyRef?.key ?? '', external: true } } })}
            placeholder="secret name"
            className="flex-1 rounded border border-gray-300 bg-white px-2 py-1.5 text-sm"
          />
          <input
            value={entry.valueFrom?.secretKeyRef?.key ?? ''}
            onChange={e => onUpdate({ valueFrom: { secretKeyRef: { name: entry.valueFrom?.secretKeyRef?.name ?? '', key: e.target.value, external: true } } })}
            placeholder="key"
            className="flex-1 rounded border border-gray-300 bg-white px-2 py-1.5 text-sm"
          />
        </>
      )
    case 'extConfigMapKeyRef':
      return (
        <>
          <input
            value={entry.valueFrom?.configMapKeyRef?.name ?? ''}
            onChange={e => onUpdate({ valueFrom: { configMapKeyRef: { name: e.target.value, key: entry.valueFrom?.configMapKeyRef?.key ?? '', external: true } } })}
            placeholder="configmap name"
            className="flex-1 rounded border border-gray-300 bg-white px-2 py-1.5 text-sm"
          />
          <input
            value={entry.valueFrom?.configMapKeyRef?.key ?? ''}
            onChange={e => onUpdate({ valueFrom: { configMapKeyRef: { name: entry.valueFrom?.configMapKeyRef?.name ?? '', key: e.target.value, external: true } } })}
            placeholder="key"
            className="flex-1 rounded border border-gray-300 bg-white px-2 py-1.5 text-sm"
          />
        </>
      )
    case 'fieldRef':
      return (
        <input
          value={entry.valueFrom?.fieldRef?.fieldPath ?? ''}
          onChange={e => onUpdate({ valueFrom: { fieldRef: { fieldPath: e.target.value } } })}
          placeholder="e.g. metadata.name, status.podIP"
          className="flex-1 rounded border border-gray-300 bg-white px-2 py-1.5 text-sm"
        />
      )
    case 'resourceFieldRef':
      return (
        <>
          <input
            value={entry.valueFrom?.resourceFieldRef?.resource ?? ''}
            onChange={e => onUpdate({ valueFrom: { resourceFieldRef: { resource: e.target.value, containerName: entry.valueFrom?.resourceFieldRef?.containerName } } })}
            placeholder="resource (e.g. limits.cpu)"
            className="flex-1 rounded border border-gray-300 bg-white px-2 py-1.5 text-sm"
          />
          <input
            value={entry.valueFrom?.resourceFieldRef?.containerName ?? ''}
            onChange={e => onUpdate({ valueFrom: { resourceFieldRef: { resource: entry.valueFrom?.resourceFieldRef?.resource ?? '', containerName: e.target.value || undefined } } })}
            placeholder="container (optional)"
            className="flex-1 rounded border border-gray-300 bg-white px-2 py-1.5 text-sm"
          />
        </>
      )
    case 'configMapRef':
      return (
        <RefSelect
          value={entry.configMapRef?.name ?? ''}
          onChange={v => onUpdate({ configMapRef: { name: v } })}
          optionsPath="config.configMaps"
          placeholder="configmap name"
        />
      )
    case 'secretRef':
      return (
        <RefSelect
          value={entry.secretRef?.name ?? ''}
          onChange={v => onUpdate({ secretRef: { name: v } })}
          optionsPath="config.secrets"
          placeholder="secret name"
        />
      )
    case 'extConfigMapRef':
      return (
        <input
          value={entry.configMapRef?.name ?? ''}
          onChange={e => onUpdate({ configMapRef: { name: e.target.value, external: true } })}
          placeholder="configmap name"
          className="flex-1 rounded border border-gray-300 bg-white px-2 py-1.5 text-sm"
        />
      )
    case 'extSecretRef':
      return (
        <input
          value={entry.secretRef?.name ?? ''}
          onChange={e => onUpdate({ secretRef: { name: e.target.value, external: true } })}
          placeholder="secret name"
          className="flex-1 rounded border border-gray-300 bg-white px-2 py-1.5 text-sm"
        />
      )
    default:
      return null
  }
}

/* --- Bulk row (envFrom) --- */

function BulkRow({ entry, onUpdate, onRemove, onChangeType }: {
  entry: EnvEntry
  onUpdate: (entry: EnvEntry) => void
  onRemove: () => void
  onChangeType: (type: EnvType) => void
}) {
  const type = detectType(entry)

  return (
    <div className="flex items-center gap-2 rounded-md border border-dashed border-gray-300 bg-gray-50 p-2">
      <div className="relative shrink-0">
        <select
          value={type}
          onChange={e => onChangeType(e.target.value as EnvType)}
          className="appearance-none rounded border border-gray-300 bg-white pl-2 pr-7 py-1.5 text-sm"
        >
          {BULK_TYPES.map(t => <option key={t} value={t}>{TYPE_LABELS[t]}</option>)}
        </select>
        <ChevronDown className="pointer-events-none absolute right-1.5 top-2 h-3.5 w-3.5 text-gray-400" />
      </div>

      <EnvValueFields entry={entry} type={type} onUpdate={onUpdate} />

      <button type="button" aria-label="Remove source" onClick={onRemove} className="shrink-0 text-gray-400 hover:text-red-600">
        <Trash2 className="h-4 w-4" />
      </button>
    </div>
  )
}

