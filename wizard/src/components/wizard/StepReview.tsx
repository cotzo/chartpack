import { useState, useMemo } from 'react'
import { Copy, Download, Check, AlertTriangle, CheckCircle2 } from 'lucide-react'
import Ajv from 'ajv/dist/2020'
import { generateYaml } from '../../lib/yaml-generator'
import type { JsonSchema } from '../../lib/schema-utils'
import { getAtPath } from '../../lib/values-utils'

interface StepReviewProps {
  values: Record<string, unknown>
  schema: JsonSchema | null
}

interface ValidationError {
  path: string
  message: string
}

function validateValues(values: Record<string, unknown>, schema: JsonSchema | null): ValidationError[] {
  if (!schema) return []

  const ajv = new Ajv({ allErrors: true, strict: false })
  const validate = ajv.compile(schema)
  validate(values)

  if (!validate.errors) return []

  return validate.errors.map(err => ({
    path: err.instancePath || '/',
    message: `${err.instancePath || '/'}: ${err.message}${err.params ? ` (${formatParams(err.params)})` : ''}`,
  }))
}

function formatParams(params: Record<string, unknown>): string {
  const parts: string[] = []
  for (const [k, v] of Object.entries(params)) {
    if (k === 'type') parts.push(`expected ${v}`)
    else if (k === 'allowedValues') parts.push(`allowed: ${(v as string[]).join(', ')}`)
    else if (k === 'missingProperty') parts.push(`missing: ${v}`)
    else if (k === 'additionalProperty') parts.push(`unknown: ${v}`)
    else if (k === 'limit') parts.push(`${k}: ${v}`)
  }
  return parts.join(', ')
}

function validateCrossReferences(values: Record<string, unknown>): ValidationError[] {
  const errors: ValidationError[] = []

  const mapKeys = (path: string): Set<string> => {
    const obj = getAtPath(values, path)
    return new Set(obj && typeof obj === 'object' && !Array.isArray(obj) ? Object.keys(obj as Record<string, unknown>) : [])
  }

  const configMaps = mapKeys('config.configMaps')
  const secrets = mapKeys('config.secrets')
  const persistenceKeys = mapKeys('persistence')
  const oauth2Proxies = mapKeys('networking.oauth2Proxies')
  const roles = mapKeys('rbac.roles')
  const clusterRoles = mapKeys('rbac.clusterRoles')

  const checkRef = (ref: string | undefined, target: Set<string>, targetLabel: string, context: string) => {
    if (ref && !target.has(ref)) {
      errors.push({ path: context, message: `${context}: references ${targetLabel} "${ref}" which is not defined` })
    }
  }

  // Container env and mount references
  const checkContainers = (containers: Record<string, unknown> | undefined, prefix: string) => {
    if (!containers || typeof containers !== 'object') return
    for (const [cName, cSpec] of Object.entries(containers as Record<string, Record<string, unknown>>)) {
      if (!cSpec || typeof cSpec !== 'object') continue
      const ctx = `${prefix}.${cName}`

      // Env references
      const env = cSpec.env as Record<string, Record<string, unknown>> | undefined
      if (env && typeof env === 'object') {
        for (const [envName, envVal] of Object.entries(env)) {
          if (!envVal || typeof envVal !== 'object') continue
          const eCtx = `${ctx}.env.${envName}`
          const vf = envVal.valueFrom as Record<string, Record<string, string>> | undefined
          if (vf?.configMapKeyRef?.name && !envVal.external) checkRef(vf.configMapKeyRef.name, configMaps, 'configMap', eCtx)
          if (vf?.secretKeyRef?.name && !envVal.external) checkRef(vf.secretKeyRef.name, secrets, 'secret', eCtx)
          const cmRef = envVal.configMapRef as Record<string, string> | undefined
          if (cmRef?.name && !envVal.external) checkRef(cmRef.name, configMaps, 'configMap', eCtx)
          const sRef = envVal.secretRef as Record<string, string> | undefined
          if (sRef?.name && !envVal.external) checkRef(sRef.name, secrets, 'secret', eCtx)
        }
      }

      // Mount references
      const mounts = cSpec.mounts as Record<string, unknown>[] | undefined
      if (Array.isArray(mounts)) {
        mounts.forEach((m, i) => {
          if (!m || typeof m !== 'object') return
          const mount = m as Record<string, unknown>
          const mCtx = `${ctx}.mounts[${i}]`
          if (mount.configMap && !mount.external) checkRef(mount.configMap as string, configMaps, 'configMap', mCtx)
          if (mount.secret && !mount.external) checkRef(mount.secret as string, secrets, 'secret', mCtx)
          if (mount.persistence) checkRef(mount.persistence as string, persistenceKeys, 'persistence', mCtx)
        })
      }
    }
  }

  checkContainers(getAtPath(values, 'containers') as Record<string, unknown>, 'containers')
  checkContainers(getAtPath(values, 'initContainers') as Record<string, unknown>, 'initContainers')

  // Ingress oauth2Proxy references
  const ingresses = getAtPath(values, 'networking.ingresses') as Record<string, Record<string, unknown>> | undefined
  if (ingresses && typeof ingresses === 'object') {
    for (const [name, ing] of Object.entries(ingresses)) {
      if (ing?.oauth2Proxy) checkRef(ing.oauth2Proxy as string, oauth2Proxies, 'oauth2Proxy', `networking.ingresses.${name}`)
    }
  }

  // Route oauth2Proxy references
  const routes = getAtPath(values, 'networking.gatewayApi.routes') as Record<string, Record<string, unknown>> | undefined
  if (routes && typeof routes === 'object') {
    for (const [name, route] of Object.entries(routes)) {
      if (route?.oauth2Proxy) checkRef(route.oauth2Proxy as string, oauth2Proxies, 'oauth2Proxy', `networking.gatewayApi.routes.${name}`)
    }
  }

  // RoleBinding references
  const roleBindings = getAtPath(values, 'rbac.roleBindings') as Record<string, Record<string, unknown>> | undefined
  if (roleBindings && typeof roleBindings === 'object') {
    for (const [name, rb] of Object.entries(roleBindings)) {
      const ref = rb?.roleRef as Record<string, string> | undefined
      if (ref?.name) {
        const kind = ref.kind || 'Role'
        if (kind === 'Role') checkRef(ref.name, roles, 'role', `rbac.roleBindings.${name}`)
        else checkRef(ref.name, clusterRoles, 'clusterRole', `rbac.roleBindings.${name}`)
      }
    }
  }

  // ClusterRoleBinding references
  const crbindings = getAtPath(values, 'rbac.clusterRoleBindings') as Record<string, Record<string, unknown>> | undefined
  if (crbindings && typeof crbindings === 'object') {
    for (const [name, crb] of Object.entries(crbindings)) {
      const ref = crb?.roleRef as Record<string, string> | undefined
      if (ref?.name) checkRef(ref.name, clusterRoles, 'clusterRole', `rbac.clusterRoleBindings.${name}`)
    }
  }

  return errors
}

export function StepReview({ values, schema }: StepReviewProps) {
  const [copied, setCopied] = useState(false)

  const yamlOutput = useMemo(() => generateYaml(values), [values])
  const schemaErrors = useMemo(() => validateValues(values, schema), [values, schema])
  const refErrors = useMemo(() => validateCrossReferences(values), [values])
  const errors = useMemo(() => [...schemaErrors, ...refErrors], [schemaErrors, refErrors])

  const handleCopy = async () => {
    await navigator.clipboard.writeText(yamlOutput)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const handleDownload = () => {
    const blob = new Blob([yamlOutput], { type: 'text/yaml' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'values.yaml'
    a.click()
    URL.revokeObjectURL(url)
  }

  const lineCount = yamlOutput.split('\n').length

  return (
    <div className="space-y-4">
      {/* Validation result */}
      {errors.length > 0 ? (
        <div className="rounded-lg border border-amber-200 bg-amber-50 p-4">
          <div className="flex items-center gap-2 mb-2">
            <AlertTriangle className="h-5 w-5 text-amber-600" />
            <h3 className="text-sm font-semibold text-amber-800">
              Validation: {errors.length} {errors.length === 1 ? 'issue' : 'issues'} found
            </h3>
          </div>
          <ul className="space-y-1">
            {errors.map((err, i) => (
              <li key={i} className="text-xs text-amber-700 font-mono">
                {err.message}
              </li>
            ))}
          </ul>
        </div>
      ) : (
        <div className="rounded-lg border border-green-200 bg-green-50 p-4">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="h-5 w-5 text-green-600" />
            <h3 className="text-sm font-semibold text-green-800">Validation passed</h3>
          </div>
          <p className="text-xs text-green-600 mt-1">All values conform to the schema.</p>
        </div>
      )}

      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-600">
            Review your generated values.yaml. Copy or download when ready.
          </p>
          <p className="text-xs text-gray-400 mt-1">{lineCount} lines</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={handleCopy}
            className="inline-flex items-center gap-1.5 rounded-md border border-gray-300 px-3 py-1.5 text-sm text-gray-700 hover:bg-gray-50"
          >
            {copied ? <Check className="h-4 w-4 text-green-600" /> : <Copy className="h-4 w-4" />}
            {copied ? 'Copied!' : 'Copy'}
          </button>
          <button
            type="button"
            onClick={handleDownload}
            className="inline-flex items-center gap-1.5 rounded-md bg-blue-600 px-3 py-1.5 text-sm text-white hover:bg-blue-700"
          >
            <Download className="h-4 w-4" /> Download
          </button>
        </div>
      </div>

      <div className="relative rounded-lg border border-gray-200 bg-gray-900 overflow-hidden">
        <div className="flex">
          {/* Line numbers */}
          <div className="select-none px-3 py-4 text-right text-xs leading-relaxed text-gray-500 bg-gray-950 border-r border-gray-700">
            {yamlOutput.split('\n').map((_, i) => (
              <div key={i}>{i + 1}</div>
            ))}
          </div>
          {/* Code */}
          <pre className="flex-1 overflow-x-auto px-4 py-4 text-xs leading-relaxed text-gray-100">
            <code>{yamlOutput}</code>
          </pre>
        </div>
      </div>
    </div>
  )
}
