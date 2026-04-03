import { useCallback } from 'react'
import {
  type JsonSchema,
  resolveSchema,
  getEffectiveType,
  isMapSchema,
  isStructuredObject,
  isBareObject,
  keyToLabel,
} from '../../lib/schema-utils'
import { TextInput } from '../shared/TextInput'
import { EnumSelect } from '../shared/EnumSelect'
import { BooleanToggle } from '../shared/BooleanToggle'
import { ArrayEditor } from '../shared/ArrayEditor'
import { ObjectEditor } from '../shared/ObjectEditor'
import { KeyValueEditor } from '../shared/KeyValueEditor'
import { MapEditor } from '../shared/MapEditor'
import { ArrayObjectEditor } from '../shared/ArrayObjectEditor'
import { EnvEditor } from '../shared/EnvEditor'
import { NodeTargetingField } from '../shared/NodeTargetingField'
import { MountsEditor } from '../shared/MountsEditor'
import { CollapsibleSection } from '../shared/CollapsibleSection'
import { HelpText } from '../shared/HelpText'
import { useWizardValues, useWizardNavigate } from '../../lib/use-wizard'
import { getAtPath, getKeysAtPath, getStepForPath } from '../../lib/values-utils'

interface SchemaFieldProps {
  schema: JsonSchema
  rootSchema: JsonSchema
  value: unknown
  onChange: (value: unknown) => void
  label?: string
  required?: boolean
  depth?: number
}

/**
 * Recursively renders a form field based on JSON Schema.
 * This is the core of the auto-generated wizard.
 */
export function SchemaField({ schema, rootSchema, value, onChange, label, required, depth = 0 }: SchemaFieldProps) {
  const resolved = resolveSchema(schema, rootSchema)
  const wizardField = schema['x-wizard-field'] || resolved['x-wizard-field']
  const wizard = schema['x-wizard'] || resolved['x-wizard']
  const type = getEffectiveType(resolved)
  const desc = schema.description || resolved.description
  const allValues = useWizardValues()
  const navigateTo = useWizardNavigate()

  // --- Node targeting field (oneOf: string[] | {values, enforcement}) ---
  if (wizardField === 'nodeTargeting') {
    return (
      <NodeTargetingField
        label={label || ''}
        value={value as Record<string, unknown> | string[] | undefined}
        onChange={onChange}
        helpText={desc}
      />
    )
  }

  // --- Mounts editor ---
  if (wizardField === 'mounts') {
    return (
      <MountsEditor
        label={label || ''}
        value={(value ?? []) as never[]}
        onChange={v => onChange(v.length > 0 ? v : undefined)}
        helpText={desc}
      />
    )
  }

  // --- Enum (string with enum values) ---
  if (type === 'enum' || resolved.enum) {
    const schemaDefault = resolved.default as string | undefined
    const enumValue = (value as string) ?? schemaDefault ?? ''
    return (
      <EnumSelect
        label={label || ''}
        value={enumValue}
        onChange={v => onChange(v === schemaDefault ? undefined : v)}
        options={resolved.enum || []}
        required={required}
        helpText={desc}
        placeholder={enumValue ? undefined : 'Select...'}
      />
    )
  }

  // --- Boolean ---
  if (type === 'boolean') {
    return (
      <BooleanToggle
        label={label || ''}
        value={(value as boolean) ?? false}
        onChange={onChange}
        helpText={desc}
      />
    )
  }

  // --- Integer ---
  if (type === 'integer') {
    return (
      <TextInput
        label={label || ''}
        value={value != null ? String(value) : (resolved.default != null ? String(resolved.default) : '')}
        onChange={v => onChange(v ? parseInt(v, 10) : undefined)}
        type="number"
        min={resolved.minimum}
        max={resolved.maximum}
        required={required}
        helpText={desc}
      />
    )
  }

  // --- String ---
  // --- String with optionsFrom (dynamic dropdown from other values) ---
  if (type === 'string' && wizard?.optionsFrom) {
    const options = getKeysAtPath(allValues, wizard.optionsFrom)
    const stepInfo = getStepForPath(wizard.optionsFrom)
    if (options.length > 0) {
      return (
        <EnumSelect
          label={label || ''}
          value={(value as string) ?? ''}
          onChange={v => onChange(v || undefined)}
          options={options}
          required={required}
          helpText={desc}
          placeholder="Select..."
        />
      )
    }
    return (
      <div className="space-y-1">
        <label className="block text-sm font-medium text-gray-700">
          {label}{required && <span className="text-red-500 ml-0.5">*</span>}
        </label>
        <div className="rounded-md border border-amber-300 bg-amber-50 px-3 py-2 text-xs text-amber-700">
          No {wizard.optionsFrom.split('.').pop()} defined.{' '}
          {stepInfo && navigateTo ? (
            <button type="button" onClick={() => navigateTo(stepInfo.stepId)} className="underline font-medium hover:text-amber-900">
              Go to {stepInfo.label}
            </button>
          ) : (
            <span>Create one first.</span>
          )}
        </div>
        {desc && <HelpText text={desc} />}
      </div>
    )
  }

  // --- String ---
  if (type === 'string') {
    return (
      <TextInput
        label={label || ''}
        value={(value as string) ?? (resolved.default as string) ?? ''}
        onChange={v => onChange(v || undefined)}
        required={required}
        helpText={desc}
      />
    )
  }

  // --- Array of strings with optionsFrom (dropdown per item) ---
  if (type === 'array' && resolved.items?.type === 'string' && resolved.items?.['x-wizard']?.optionsFrom) {
    const itemOptions = getKeysAtPath(allValues, resolved.items['x-wizard'].optionsFrom)
    const stepInfo = getStepForPath(resolved.items['x-wizard'].optionsFrom)
    return (
      <ArrayEditor
        label={label || ''}
        value={(value as string[]) ?? []}
        onChange={onChange}
        helpText={desc}
        options={itemOptions}
        uniqueItems={!!resolved.uniqueItems}
        optionsStepInfo={navigateTo && stepInfo ? { stepId: stepInfo.stepId, label: stepInfo.label, navigate: navigateTo } : undefined}
      />
    )
  }

  // --- Array of strings ---
  if (type === 'array' && resolved.items?.type === 'string') {
    return (
      <ArrayEditor
        label={label || ''}
        value={(value as string[]) ?? []}
        onChange={onChange}
        helpText={desc}
      />
    )
  }

  // --- Array of structured objects ---
  if (type === 'array' && resolved.items) {
    const itemSchema = resolveSchema(resolved.items, rootSchema)
    if (itemSchema.properties && Object.keys(itemSchema.properties).length > 0) {
      return (
        <ArrayObjectEditor
          label={label || ''}
          value={(value as Record<string, unknown>[]) ?? []}
          onChange={v => onChange(v.length > 0 ? v : undefined)}
          createDefault={() => createDefaultFromSchema(itemSchema, rootSchema) as Record<string, unknown>}
          helpText={desc}
          itemLabel={(item, idx) => {
            // Use first string value as label if available
            const first = Object.values(item).find(v => typeof v === 'string' && v)
            return first ? String(first) : `#${idx + 1}`
          }}
          renderItem={(item, onItemChange) => (
            <SchemaObjectFields
              schema={itemSchema}
              rootSchema={rootSchema}
              value={item}
              onChange={v => onItemChange((v ?? {}) as Record<string, unknown>)}
              depth={depth + 1}
            />
          )}
        />
      )
    }
  }

  // --- Array (fallback: free-form YAML) ---
  if (type === 'array') {
    return (
      <ObjectEditor
        label={label || ''}
        value={value != null ? ({ _arr: value } as Record<string, unknown>) : {}}
        onChange={v => {
          const arr = (v as Record<string, unknown>)._arr
          onChange(arr !== undefined ? arr : Object.keys(v).length > 0 ? v : undefined)
        }}
        helpText={desc}
      />
    )
  }

  // --- Env map (custom editor) ---
  if (wizardField === 'env') {
    const mapValue = (value ?? {}) as Record<string, Record<string, unknown>>
    return (
      <EnvEditor
        label={label || ''}
        value={mapValue}
        onChange={v => onChange(Object.keys(v).length > 0 ? v : undefined)}
        helpText={desc}
      />
    )
  }

  // --- Map: object with additionalProperties and no properties ---
  if (isMapSchema(resolved)) {
    const itemSchema = resolved.additionalProperties as JsonSchema
    const resolvedItem = resolveSchema(itemSchema, rootSchema)
    const mapValue = (value ?? {}) as Record<string, unknown>

    // If the map values are simple strings, use KeyValueEditor style
    if (getEffectiveType(resolvedItem) === 'string' && !resolvedItem.enum) {
      return (
        <KeyValueEditor
          label={label || ''}
          value={(mapValue as Record<string, string>) ?? {}}
          onChange={v => onChange(Object.keys(v).length > 0 ? v : undefined)}
          helpText={desc}
        />
      )
    }

    return (
      <MapEditor
        label={label || ''}
        value={mapValue}
        onChange={v => onChange(Object.keys(v).length > 0 ? v : undefined)}
        keyPlaceholder="Name"
        helpText={desc}
        createDefault={() => createDefaultFromSchema(resolvedItem, rootSchema)}
        renderItem={(_key, item, onItemChange) => (
          <SchemaObjectFields
            schema={resolvedItem}
            rootSchema={rootSchema}
            value={(item ?? {}) as Record<string, unknown>}
            onChange={onItemChange}
            depth={depth + 1}
          />
        )}
      />
    )
  }

  // --- Structured object with properties ---
  if (isStructuredObject(resolved)) {
    if (depth > 0) {
      return (
        <CollapsibleSection title={label || ''} defaultOpen={!!(schema['x-wizard']?.expanded ?? resolved['x-wizard']?.expanded)}>
          {desc && <HelpText text={desc} />}
          <SchemaObjectFields
            schema={resolved}
            rootSchema={rootSchema}
            value={(value ?? {}) as Record<string, unknown>}
            onChange={onChange}
            depth={depth}
          />
        </CollapsibleSection>
      )
    }
    return (
      <SchemaObjectFields
        schema={resolved}
        rootSchema={rootSchema}
        value={(value ?? {}) as Record<string, unknown>}
        onChange={onChange}
        depth={depth}
      />
    )
  }

  // --- Bare object (free-form YAML) ---
  if (isBareObject(resolved)) {
    return (
      <ObjectEditor
        label={label || ''}
        value={(value ?? {}) as Record<string, unknown>}
        onChange={v => onChange(Object.keys(v).length > 0 ? v : undefined)}
        helpText={desc}
      />
    )
  }

  // Fallback: free-form
  return (
    <ObjectEditor
      label={label || '(unknown)'}
      value={(value ?? {}) as Record<string, unknown>}
      onChange={onChange}
      helpText={desc}
    />
  )
}

/**
 * Renders all properties of a structured object schema as form fields.
 */
export function SchemaObjectFields({
  schema,
  rootSchema,
  value,
  onChange,
  depth = 0,
}: {
  schema: JsonSchema
  rootSchema: JsonSchema
  value: Record<string, unknown>
  onChange: (value: unknown) => void
  depth?: number
}) {
  const allValues = useWizardValues()
  const resolved = resolveSchema(schema, rootSchema)
  const properties = resolved.properties || {}
  const requiredFields = new Set(resolved.required || [])

  const handleFieldChange = useCallback(
    (key: string, fieldValue: unknown) => {
      const next = { ...value }
      if (fieldValue === undefined || fieldValue === '' || fieldValue === null) {
        delete next[key]
      } else {
        next[key] = fieldValue
      }
      onChange(Object.keys(next).length > 0 ? next : undefined)
    },
    [value, onChange]
  )

  const normalFields: [string, JsonSchema][] = []
  const advancedFields: [string, JsonSchema][] = []

  for (const [key, propSchema] of Object.entries(properties)) {
    const wizard = propSchema['x-wizard']
    if (wizard?.hiddenWhen && value?.[wizard.hiddenWhen]) continue
    if (wizard?.visibleWhen) {
      const hidden = Object.entries(wizard.visibleWhen).some(
        ([field, allowed]) => {
          const current = value?.[field] ?? properties[field]?.default
          return !(allowed as string[]).includes(current as string)
        }
      )
      if (hidden) continue
    }
    if (wizard?.visibleIf && !getAtPath(allValues, wizard.visibleIf)) continue

    if (propSchema['x-wizard']?.advanced) {
      advancedFields.push([key, propSchema])
    } else {
      normalFields.push([key, propSchema])
    }
  }

  const renderField = ([key, propSchema]: [string, JsonSchema]) => (
    <SchemaField
      key={key}
      schema={propSchema}
      rootSchema={rootSchema}
      value={value?.[key]}
      onChange={v => handleFieldChange(key, v)}
      label={keyToLabel(key)}
      required={requiredFields.has(key)}
      depth={depth + 1}
    />
  )

  const isNarrow = (f: [string, JsonSchema]) => !!f[1]['x-wizard']?.narrow

  /** Group consecutive narrow fields into rows of 2, leaving wide fields standalone */
  const renderRows = (fields: [string, JsonSchema][]) => {
    const rows: React.ReactNode[] = []
    let i = 0
    while (i < fields.length) {
      if (isNarrow(fields[i]) && i + 1 < fields.length && isNarrow(fields[i + 1])) {
        rows.push(
          <div key={fields[i][0]} className="py-4 first:pt-0 last:pb-0 grid grid-cols-2 gap-4">
            {renderField(fields[i])}
            {renderField(fields[i + 1])}
          </div>
        )
        i += 2
      } else {
        rows.push(
          <div key={fields[i][0]} className="py-4 first:pt-0 last:pb-0">
            {renderField(fields[i])}
          </div>
        )
        i++
      }
    }
    return rows
  }

  return (
    <div className="divide-y divide-gray-300">
      {renderRows(normalFields)}
      {advancedFields.length > 0 && (
        <div className="pt-4">
          <CollapsibleSection title="Advanced">
            <div className="divide-y divide-gray-300">
              {renderRows(advancedFields)}
            </div>
          </CollapsibleSection>
        </div>
      )}
    </div>
  )
}

/** Create a default value for a schema (used when adding new map entries) */
function createDefaultFromSchema(schema: JsonSchema, root: JsonSchema): unknown {
  const resolved = resolveSchema(schema, root)

  if (resolved.default !== undefined) return structuredClone(resolved.default)

  const type = getEffectiveType(resolved)

  if (type === 'object' && resolved.properties) {
    const result: Record<string, unknown> = {}
    const requiredFields = resolved.required || []
    for (const field of requiredFields) {
      const fieldSchema = resolved.properties[field]
      if (fieldSchema) {
        result[field] = createDefaultFromSchema(fieldSchema, root)
      }
    }
    return result
  }
  if (type === 'string') return ''
  if (type === 'integer') return undefined
  if (type === 'boolean') return false
  if (type === 'array') return []
  if (type === 'object') return {}
  return undefined
}
