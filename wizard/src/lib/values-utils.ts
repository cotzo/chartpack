/** Get nested value from an object by dot-separated path */
export function getAtPath(obj: Record<string, unknown>, path: string): unknown {
  return path.split('.').reduce<unknown>((acc, key) => {
    if (acc && typeof acc === 'object' && !Array.isArray(acc)) {
      return (acc as Record<string, unknown>)[key]
    }
    return undefined
  }, obj)
}

/** Get the keys of a map at a given dot-separated path */
export function getKeysAtPath(values: Record<string, unknown>, path: string): string[] {
  // Special: collect all port names across all containers
  if (path === 'containers.*.ports') {
    const containers = getAtPath(values, 'containers')
    if (!containers || typeof containers !== 'object') return []
    const portNames = new Set<string>()
    for (const c of Object.values(containers as Record<string, Record<string, unknown>>)) {
      if (c?.ports && typeof c.ports === 'object') {
        for (const name of Object.keys(c.ports as Record<string, unknown>)) {
          portNames.add(name)
        }
      }
    }
    return [...portNames]
  }

  const target = getAtPath(values, path)
  if (target && typeof target === 'object' && !Array.isArray(target)) {
    return Object.keys(target as Record<string, unknown>)
  }
  return []
}

/** Map from optionsFrom path to the wizard step ID that manages it */
const PATH_TO_STEP: Record<string, { stepId: string; label: string }> = {
  'config.configMaps': { stepId: 'config-configMaps', label: 'ConfigMaps' },
  'config.secrets': { stepId: 'config-secrets', label: 'Secrets' },
  'persistence': { stepId: 'persistence', label: 'Persistence' },
  'networking.oauth2Proxies': { stepId: 'networking-oauth2Proxies', label: 'OAuth2 Proxy' },
  'rbac.roles': { stepId: 'rbac', label: 'RBAC' },
  'rbac.clusterRoles': { stepId: 'rbac', label: 'RBAC' },
  'containers.*.ports': { stepId: 'containers', label: 'Containers' },
  'integrations.eso.stores': { stepId: 'integrations-eso', label: 'External Secrets (ESO)' },
}

export function getStepForPath(path: string): { stepId: string; label: string } | undefined {
  return PATH_TO_STEP[path]
}
