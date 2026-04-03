# Configuration

All configuration resources live under the `config:` key.

## ConfigMaps

Pure data definitions. Mounting and env injection is configured per container.

```yaml
config:
  configMaps:
    app-config:
      data:
        config.yaml: |
          server:
            port: 8080
        log-level: info
      annotations: {}
      labels: {}
```

Checksum annotations are automatically added to the pod template, triggering rollouts when ConfigMap data changes.

[ConfigMap reference](https://kubernetes.io/docs/concepts/configuration/configmap/)

## Secrets

```yaml
config:
  secrets:
    app-credentials:
      type: Opaque                   # defaults to Opaque
      stringData:
        api-key: "my-key"

    tls-certs:
      type: kubernetes.io/tls
      data:                          # base64-encoded
        tls.crt: LS0tLS1CRUdJTi...
        tls.key: LS0tLS1CRUdJTi...

    docker-registry:
      type: kubernetes.io/dockerconfigjson
      data:
        .dockerconfigjson: eyJhdXRocyI6e319
```

Checksum annotations are automatically added for `stringData`-based secrets.

[Secret reference](https://kubernetes.io/docs/concepts/configuration/secret/) |
[Secret types](https://kubernetes.io/docs/concepts/configuration/secret/#secret-types)

## External Secrets (Push & Pull)

The recommended way to integrate with [External Secrets Operator](https://external-secrets.io/). Define your secret stores once in `infraSettings`, then add `push` or `pull` to any secret.

### 1. Define stores

```yaml
integrations:
  eso:
    enabled: true
    stores:
      vault:
        name: vault-backend
        kind: SecretStore
      aws:
        name: aws-secrets-manager
        kind: ClusterSecretStore
```

### 2. Push a secret to external stores

Creates the Kubernetes Secret **and** a PushSecret that syncs it to the external store(s).

```yaml
config:
  secrets:
    db-creds:
      stringData:
        password: supersecret
      push:
        stores: [vault]              # can push to multiple stores
        updatePolicy: Replace        # Replace | IfNotExists
        deletionPolicy: None         # Delete | None
        refreshInterval: 1h
        data:
          - match:
              secretKey: password
              remoteRef:
                remoteKey: /prod/db/password
```

### 3. Pull a secret from an external store

Creates an ExternalSecret that populates the Kubernetes Secret from the external store.

```yaml
config:
  secrets:
    cloud-creds:
      pull:
        store: aws
        refreshInterval: 1h
        data:
          - secretKey: access-key
            remoteRef:
              key: /prod/aws/access-key
        # or bulk extract:
        dataFrom:
          - extract:
              key: database/creds/my-role
        target:
          template:                  # optional: template the output secret
            type: Opaque
            data:
              conn: "postgresql://{{ .username }}:{{ .password }}@db:5432/mydb"
```

Pull always uses `creationPolicy: Merge` (pulled keys are merged into the secret) and `deletionPolicy: Retain` (the secret survives if the ExternalSecret is removed).

| Field | Default | Description |
|-------|---------|-------------|
| `push.stores` | - | Array of named store keys to push to (required) |
| `push.updatePolicy` | `Replace` | `Replace` overwrites; `IfNotExists` only creates |
| `push.deletionPolicy` | `None` | `Delete` removes remote secret on PushSecret deletion |
| `push.refreshInterval` | - | How often to sync (e.g. `1h`, `5m`) |
| `pull.store` | - | Named store key to pull from (required) |
| `pull.refreshInterval` | - | How often to sync (e.g. `1h`, `5m`) |
| `pull.data` | - | Individual key mappings (secretKey + remoteRef) |
| `pull.dataFrom` | - | Bulk extraction (e.g. `extract`, `find`) |
| `pull.target.template` | - | Template for the generated Secret |

## Auto-Generated Secrets

Generate random secrets using [ESO Password generators](https://external-secrets.io/latest/api/generator/password/). This is ArgoCD-safe -- no `helm lookup` needed. Values are generated once and persisted by ESO.

Add a `generate` map to any secret entry:

```yaml
config:
  secrets:
    app-credentials:
      generate:
        api-key:
          length: 32
          symbols: 0             # no special characters
        webhook-secret:
          length: 64
          encoding: hex          # output as hex string
        session-key:
          length: 48
          noUpper: true
          allowRepeat: true
      # generateRefreshInterval: "0"   # "0" = generate once, never rotate
      #                                # "1h" = rotate every hour
```

For each key, the chart creates:
1. A `Password` generator CRD (`generators.external-secrets.io/v1alpha1`)
2. An `ExternalSecret` that references all generators and outputs to `<fullname>-<secret-name>`

The ExternalSecret uses `creationPolicy: Merge`, so generated keys are merged with any `stringData`/`data` keys on the same secret.

### Generator Options

| Field | Default | Description |
|-------|---------|-------------|
| `length` | 32 | Password length |
| `digits` | 25% of length | Number of digit characters |
| `symbols` | 25% of length | Number of symbol characters |
| `symbolCharacters` | `~!@#$%^&*()...` | Available symbol characters |
| `noUpper` | false | Disable uppercase letters |
| `allowRepeat` | false | Allow repeated characters |
| `encoding` | raw | Output encoding: `raw`, `base64`, `base64url`, `base32`, `hex` |

[Password generator docs](https://external-secrets.io/latest/api/generator/password/)

## Stakater Reloader Integration

The chart automatically adds [Stakater Reloader](https://github.com/stakater/Reloader) annotations to workloads, listing all chart-managed ConfigMaps and Secrets. When Reloader is installed in the cluster, it watches these resources and triggers a rolling restart when their contents change.

This works alongside the built-in checksum annotations — checksums handle `helm upgrade` rollouts, while Reloader handles out-of-band changes (e.g., External Secrets rotation, manual edits).

**All ConfigMaps and Secrets are included by default.** To exclude a specific resource, set `reloaderEnabled: false`:

```yaml
config:
  configMaps:
    app-config:
      data:
        key: value
      # included in reloader annotations by default

    static-config:
      reloaderEnabled: false           # excluded — changes won't trigger restart
      data:
        key: value

  secrets:
    db-creds:
      stringData:
        password: s3cret
      # included by default

    static-certs:
      reloaderEnabled: false           # excluded
      type: kubernetes.io/tls
      data:
        tls.crt: LS0t...
```

This renders on the workload (Deployment, StatefulSet, etc.):

```yaml
metadata:
  annotations:
    configmap.reloader.stakater.com/reload: "my-app-app-config"
    secret.reloader.stakater.com/reload: "my-app-db-creds"
```

If Reloader is not installed, these annotations are harmless and have no effect.

[Stakater Reloader docs](https://github.com/stakater/Reloader)

## How Containers Reference Config

Containers declare their own config dependencies -- see [Containers](containers.md) for the unified `env` and `mounts` syntax. The chart auto-prefixes resource names and auto-generates pod-level volumes.
