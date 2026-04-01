export interface WizardMeta {
  order: number
  group?: string
  label: string
  icon: string
  description: string
  hiddenFor?: string[]
  renderer?: 'workloadType' | 'review'
  /** Render only the child property whose key matches this value path (lcFirst) */
  selectByValue?: string
  /** If true, render this property inside an "Advanced" collapsible section */
  advanced?: boolean
  /** If true, the collapsible section is expanded by default */
  expanded?: boolean
  /** If true, render this field as narrow (half-width) to allow side-by-side layout */
  narrow?: boolean
  /** Hide this field when a sibling boolean field is true (e.g. "headless") */
  hiddenWhen?: string
  /** Populate a dropdown with keys from the map at this dot-separated path in the wizard values */
  optionsFrom?: string
  /** Show this field only when a sibling field matches one of the listed values (e.g. { "type": ["LoadBalancer"] }) */
  visibleWhen?: Record<string, string[]>
}

export interface JsonSchema {
  $schema?: string
  $ref?: string
  type?: string | string[]
  enum?: string[]
  properties?: Record<string, JsonSchema>
  additionalProperties?: JsonSchema | boolean
  required?: string[]
  items?: JsonSchema
  description?: string
  minimum?: number
  maximum?: number
  minLength?: number
  maxLength?: number
  minProperties?: number
  oneOf?: JsonSchema[]
  allOf?: JsonSchema[]
  default?: unknown
  definitions?: Record<string, JsonSchema>
  'x-wizard'?: WizardMeta
  'x-wizard-field'?: string
}

let rootSchema: JsonSchema | null = null

export async function loadSchema(): Promise<JsonSchema> {
  if (rootSchema) return rootSchema
  const resp = await fetch(import.meta.env.BASE_URL + 'values.schema.json')
  if (!resp.ok) {
    throw new Error(`Failed to load schema: ${resp.status} ${resp.statusText}`)
  }
  try {
    rootSchema = await resp.json()
    return rootSchema!
  } catch {
    throw new Error('Failed to parse schema JSON')
  }
}

export function resolveRef(schema: JsonSchema, root: JsonSchema): JsonSchema {
  if (!schema.$ref) return schema
  const path = schema.$ref.replace('#/', '').split('/')
  let current: unknown = root
  for (const segment of path) {
    current = (current as Record<string, unknown>)[segment]
  }
  return current as JsonSchema
}

export function resolveSchema(schema: JsonSchema, root: JsonSchema): JsonSchema {
  let resolved = resolveRef(schema, root)

  // Handle allOf by merging all schemas
  if (resolved.allOf) {
    let merged: JsonSchema = {}
    for (const sub of resolved.allOf) {
      const resolvedSub = resolveSchema(sub, root)
      merged = {
        ...merged,
        ...resolvedSub,
        properties: { ...merged.properties, ...resolvedSub.properties },
        required: [...(merged.required || []), ...(resolvedSub.required || [])],
      }
    }
    // Keep description from parent if present
    if (resolved.description) merged.description = resolved.description
    resolved = merged
  }

  return resolved
}

/** Get the effective type, handling union types like ["integer", "string"] */
export function getEffectiveType(schema: JsonSchema): string {
  if (schema.enum) return 'enum'
  if (Array.isArray(schema.type)) {
    // Prefer integer over string for inputs
    if (schema.type.includes('integer')) return 'integer'
    return schema.type[0]
  }
  return schema.type || 'object'
}

/** Check if an object schema is a "map" (has additionalProperties with a schema, not just bare `true`) */
export function isMapSchema(schema: JsonSchema): boolean {
  return (
    getEffectiveType(schema) === 'object' &&
    typeof schema.additionalProperties === 'object' &&
    schema.additionalProperties !== null &&
    !schema.properties
  )
}

/** Check if an object schema has defined properties (structured form) */
export function isStructuredObject(schema: JsonSchema): boolean {
  return getEffectiveType(schema) === 'object' && !!schema.properties && Object.keys(schema.properties).length > 0
}

/** Check if an object schema is bare (no properties, no additionalProperties schema) = free-form YAML */
export function isBareObject(schema: JsonSchema): boolean {
  if (getEffectiveType(schema) !== 'object') return false
  if (schema.properties && Object.keys(schema.properties).length > 0) return false
  if (typeof schema.additionalProperties === 'object' && schema.additionalProperties !== null) return false
  return true
}

/** Convert a schema property key to a human-readable label */
export function keyToLabel(key: string): string {
  // Split camelCase and handle common abbreviations
  return key
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2')
    .replace(/^./, s => s.toUpperCase())
    .replace(/\bUrl\b/g, 'URL')
    .replace(/\bIp\b/g, 'IP')
    .replace(/\bDns\b/g, 'DNS')
    .replace(/\bTls\b/g, 'TLS')
    .replace(/\bHpa\b/g, 'HPA')
    .replace(/\bVpa\b/g, 'VPA')
    .replace(/\bPdb\b/g, 'PDB')
    .replace(/\bRbac\b/g, 'RBAC')
    .replace(/\bTtl\b/g, 'TTL')
    .replace(/\bCpu\b/g, 'CPU')
    .replace(/\bOauth2\b/g, 'OAuth2')
    .replace(/\bVm\b/g, 'VM')
}

/** Get the schema for a dot-separated path within the root schema */
export function getSchemaAtPath(path: string, root: JsonSchema): JsonSchema | null {
  const segments = path.split('.')
  let current: JsonSchema = root

  for (const segment of segments) {
    current = resolveSchema(current, root)

    if (current.properties?.[segment]) {
      current = current.properties[segment]
    } else if (typeof current.additionalProperties === 'object') {
      current = current.additionalProperties
    } else {
      return null
    }
  }

  return resolveSchema(current, root)
}

/** Walk the schema and collect all properties that have a `default` value into a nested object */
export function extractDefaults(schema: JsonSchema, root?: JsonSchema): Record<string, unknown> {
  const rootSchema = root ?? schema
  const result: Record<string, unknown> = {}
  if (!schema.properties) return result

  for (const [key, prop] of Object.entries(schema.properties)) {
    const resolved = resolveSchema(prop, rootSchema)

    if (resolved.default !== undefined) {
      result[key] = resolved.default
    } else if (resolved.type === 'object' && resolved.properties) {
      const nested = extractDefaults(resolved, rootSchema)
      if (Object.keys(nested).length > 0) {
        result[key] = nested
      }
    }
  }

  return result
}
