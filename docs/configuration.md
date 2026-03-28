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

## External Secrets

Integrates with [External Secrets Operator](https://external-secrets.io/) to sync secrets from external providers.

```yaml
config:
  externalSecrets:
    aws-credentials:
      refreshInterval: 1h
      secretStoreRef:
        name: aws-secrets-manager
        kind: ClusterSecretStore     # SecretStore | ClusterSecretStore
      target:
        creationPolicy: Owner
        deletionPolicy: Retain
        template:                    # optional: template the output secret
          type: Opaque
          data:
            conn: "postgresql://{{ .username }}:{{ .password }}@db:5432/mydb"
      data:
        - secretKey: access-key-id
          remoteRef:
            key: /prod/app/credentials
            property: access_key_id
      # or bulk extract:
      dataFrom:
        - extract:
            key: database/creds/my-role
```

[External Secrets Operator docs](https://external-secrets.io/)

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

## How Containers Reference Config

Containers declare their own config dependencies -- see [Containers](containers.md) for the unified `env` and `mounts` syntax. The chart auto-prefixes resource names and auto-generates pod-level volumes.
