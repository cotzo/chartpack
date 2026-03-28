# Containers

All containers -- main, sidecar, and init -- share the same schema. Defined as maps where the key becomes the container name.

## Container Spec

```yaml
containers:
  app:
    image:
      repository: my-app
      tag: "1.0.0"
      pullPolicy: IfNotPresent   # Always | IfNotPresent | Never
    command: ["/app/server"]
    args: ["--config", "/etc/config/config.yaml"]
    workingDir: /app
    ports:
      http:
        port: 8080
      grpc:
        port: 9090
        protocol: TCP            # defaults to TCP
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
        nvidia.com/gpu: "1"      # GPU and extended resources work
      limits:
        cpu: 500m
        memory: 256Mi
        nvidia.com/gpu: "1"
    securityContext:
      runAsNonRoot: true
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: [ALL]
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "sleep 15"]
```

[Container resource reference](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) |
[Security context reference](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)

## Unified Environment Variables

A single `env` map handles all env var types. The map key is the env var name for individual vars, or a unique identifier for bulk entries. Entries with `value`/`valueFrom` become K8s `env` entries. Entries with `configMapRef`/`secretRef` become `envFrom`.

Chart-managed resource names (from `configMaps`/`secrets` maps) are auto-prefixed with `<fullname>-`. Add `external: true` to skip prefixing for resources not managed by this chart.

Using a map (instead of a list) enables deep-merging across multiple values files.

```yaml
containers:
  app:
    env:
      # Literal value — key becomes the env var name
      APP_ENV:
        value: "production"

      # Empty string values are supported
      EMPTY_VAR:
        value: ""

      # From pod field
      POD_NAME:
        valueFrom:
          fieldRef:
            fieldPath: metadata.name

      # From resource field
      CPU_LIMIT:
        valueFrom:
          resourceFieldRef:
            resource: limits.cpu

      # From chart-managed configMap key (auto-prefixed)
      LOG_LEVEL:
        valueFrom:
          configMapKeyRef:
            name: app-config       # references configMaps.app-config
            key: log-level

      # From chart-managed secret key (auto-prefixed)
      DB_PASSWORD:
        valueFrom:
          secretKeyRef:
            name: db-creds         # references secrets.db-creds
            key: password

      # From external secret (NOT auto-prefixed)
      EXTERNAL_KEY:
        valueFrom:
          secretKeyRef:
            name: some-external-secret
            key: api-key
            external: true

      # Bulk inject all keys from chart-managed configMap (→ envFrom)
      # Key is just an identifier, not an env var name
      bulk-env-config:
        configMapRef:
          name: env-config

      # Bulk inject from chart-managed secret (→ envFrom)
      bulk-env-secrets:
        secretRef:
          name: env-secrets

      # Bulk inject from external configMap
      bulk-external:
        configMapRef:
          name: shared-external-config
          external: true
```

[Environment variables reference](https://kubernetes.io/docs/tasks/inject-data-application/define-environment-variable-container/) |
[envFrom reference](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#configure-all-key-value-pairs-in-a-configmap-as-container-environment-variables)

## Unified Mounts

A single `mounts` list declares all volume mounts. Each entry has `path` and one source field. Pod-level volumes are auto-generated from mount references.

```yaml
containers:
  app:
    mounts:
      # Chart-managed configMap (auto-prefixed, volume auto-created)
      - path: /etc/config
        configMap: app-config
        readOnly: true

      # Chart-managed secret
      - path: /etc/secrets
        secret: app-credentials
        readOnly: true

      # Secret with subPath (single file)
      - path: /etc/ssl/certs/ca.crt
        secret: tls-certs
        subPath: ca.crt
        readOnly: true

      # Chart-managed persistence (PVC or VCT)
      - path: /data
        persistence: data

      # Existing pod volume (from podSettings.volumes)
      - path: /tmp
        volume: tmp

      # External configMap (not chart-managed)
      - path: /etc/external
        configMap: external-config
        external: true
```

Additional mount options: `items`, `defaultMode`.

[Volumes reference](https://kubernetes.io/docs/concepts/storage/volumes/) |
[Projected volumes reference](https://kubernetes.io/docs/concepts/storage/projected-volumes/)

## Health Checks

Grouped under `healthChecks`:

```yaml
containers:
  app:
    healthChecks:
      liveness:
        httpGet:
          path: /healthz
          port: http
        initialDelaySeconds: 15
        periodSeconds: 20
      readiness:
        httpGet:
          path: /ready
          port: http
        initialDelaySeconds: 5
        periodSeconds: 10
      startup:
        httpGet:
          path: /healthz
          port: http
        failureThreshold: 30
        periodSeconds: 10
```

[Probes reference](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)

## In-Place Resource Resize (K8s 1.35+)

Update CPU/memory without restarting pods using `resizePolicy`:

```yaml
containers:
  app:
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 256Mi
    resizePolicy:
      - resourceName: cpu
        restartPolicy: NotRequired       # resize without restart
      - resourceName: memory
        restartPolicy: RestartContainer   # restart required for memory
```

[In-place resource resize reference](https://kubernetes.io/docs/concepts/workloads/pods/#resizing-a-container)

## AppArmor Profiles (K8s 1.31+)

Configure via `securityContext` (passthrough):

```yaml
containers:
  app:
    securityContext:
      appArmorProfile:
        type: RuntimeDefault   # RuntimeDefault | Localhost | Unconfined
```

[AppArmor reference](https://kubernetes.io/docs/tutorials/security/apparmor/)

## Init Containers

Same schema as containers. Processed in **alphabetical key order** -- prefix keys with numbers to control ordering.

```yaml
initContainers:
  01-wait-for-db:
    image:
      repository: busybox
      tag: "1.36"
    command: ["sh", "-c"]
    args: ["until nc -z db:5432; do sleep 2; done"]

  02-migrate:
    image:
      repository: my-app
      tag: "1.0.0"
    command: ["/app/migrate", "--up"]
    mounts:
      - path: /etc/config
        configMap: app-config
        readOnly: true
```

[Init containers reference](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)

## Native Sidecar Containers (K8s 1.33+)

Init containers with `restartPolicy: Always` run as native sidecars -- they start before main containers, stay running throughout the pod lifecycle, and support probes.

```yaml
initContainers:
  01-log-collector:
    image:
      repository: fluent/fluent-bit
      tag: "3.0"
    restartPolicy: Always
    healthChecks:
      liveness:
        httpGet:
          path: /api/v1/health
          port: 2020
    resources:
      requests:
        cpu: 25m
        memory: 32Mi
```

[Sidecar containers reference](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)
