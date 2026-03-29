# Hooks

Hook Jobs run at Helm lifecycle events — DB migrations, schema setup, cache warming, etc. Each hook is a named Job under the `hooks` map.

Hooks **share the main workload's pod settings** (ServiceAccount, tolerations, nodeSelector, volumes, security context) but define their own containers. This means hooks automatically get the same Secrets and ConfigMaps mounted.

## Basic Usage

```yaml
hooks:
  db-migrate:
    events:
      - pre-install
      - pre-upgrade
    containers:
      migrate:
        image:
          repository: my-app
          tag: "1.0.0"
        command: ["./migrate", "--up"]
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
    backoffLimit: 3
    activeDeadlineSeconds: 300
```

## Hook Events

| Event | When it runs |
|-------|-------------|
| `pre-install` | Before any resources are created |
| `post-install` | After all resources are created |
| `pre-upgrade` | Before any resources are updated |
| `post-upgrade` | After all resources are updated |
| `pre-delete` | Before any resources are deleted |
| `post-delete` | After all resources are deleted |
| `pre-rollback` | Before a rollback |
| `post-rollback` | After a rollback |

## Execution Order

Use `weight` to control the order when multiple hooks run at the same event. Lower values run first:

```yaml
hooks:
  schema-create:
    events: [pre-install]
    weight: "-10"
    containers:
      run:
        image: { repository: my-app }
        command: ["./schema", "create"]

  db-migrate:
    events: [pre-install, pre-upgrade]
    weight: "-5"
    containers:
      run:
        image: { repository: my-app }
        command: ["./migrate", "--up"]

  seed-data:
    events: [post-install]
    weight: "0"
    containers:
      run:
        image: { repository: my-app }
        command: ["./seed"]
```

## Delete Policies

Controls when Helm deletes the hook resource:

| Policy | Behavior |
|--------|----------|
| `before-hook-creation` (default) | Delete previous hook before creating new one |
| `hook-succeeded` | Delete after hook succeeds |
| `hook-failed` | Delete after hook fails |

```yaml
hooks:
  db-migrate:
    events: [pre-upgrade]
    deletePolicy: hook-succeeded
    containers:
      migrate:
        image: { repository: my-app }
        command: ["./migrate"]
```

## Shared Configuration

Hooks share the main workload's pod settings. A hook container can mount the same ConfigMaps and Secrets:

```yaml
config:
  configMaps:
    app-config:
      data:
        db-host: "postgres:5432"
  secrets:
    db-creds:
      stringData:
        password: "s3cret"

hooks:
  db-migrate:
    events: [pre-upgrade]
    containers:
      migrate:
        image: { repository: my-app }
        command: ["./migrate"]
        mounts:
          - path: /config
            configMap: app-config
          - path: /secrets
            secret: db-creds
        env:
          DB_PASSWORD:
            valueFrom:
              secretKeyRef:
                name: db-creds
                key: password
```

## Job Options

| Field | Description |
|-------|-------------|
| `backoffLimit` | Number of retries before marking as failed |
| `activeDeadlineSeconds` | Maximum runtime |
| `ttlSecondsAfterFinished` | Auto-cleanup after completion |
| `completions` | Number of successful completions needed |
| `parallelism` | Max parallel pods |

## GitOps Compatibility

### Flux

Flux's Helm Controller runs `helm install/upgrade` natively, so **Helm hooks work out of the box**. No additional configuration needed.

### Argo CD

Argo CD does **not** execute Helm hooks via `helm.sh/hook`. Instead, it uses its own annotation system. Chartpack **automatically renders both annotation styles** on every hook Job, so hooks work with Argo CD without any changes:

| Helm annotation | Argo CD annotation (auto-generated) |
|----------------|-------------------------------------|
| `helm.sh/hook: pre-install` | `argocd.argoproj.io/hook: PreSync` |
| `helm.sh/hook: pre-upgrade` | `argocd.argoproj.io/hook: PreSync` |
| `helm.sh/hook: post-install` | `argocd.argoproj.io/hook: PostSync` |
| `helm.sh/hook: post-upgrade` | `argocd.argoproj.io/hook: PostSync` |
| `helm.sh/hook: pre-delete` | `argocd.argoproj.io/hook: SyncFail` |
| `helm.sh/hook-delete-policy: before-hook-creation` | `argocd.argoproj.io/hook-delete-policy: BeforeHookCreation` |
| `helm.sh/hook-delete-policy: hook-succeeded` | `argocd.argoproj.io/hook-delete-policy: HookSucceeded` |
| `helm.sh/hook-delete-policy: hook-failed` | `argocd.argoproj.io/hook-delete-policy: HookFailed` |

**How Argo CD runs hooks:**
1. During a Sync, Argo CD checks for `argocd.argoproj.io/hook` annotations
2. `PreSync` hooks run **before** the main resources are applied
3. `PostSync` hooks run **after** all resources are healthy
4. `SyncFail` hooks run if the sync fails
5. The hook Job must complete successfully for the sync to proceed

Both annotation sets are safe on the same resource — Helm ignores Argo annotations and vice versa.

**Note:** `post-delete`, `pre-rollback`, and `post-rollback` events have no Argo CD equivalent. These hooks will only run when using Helm directly or Flux.

[Helm hooks reference](https://helm.sh/docs/topics/charts_hooks/) |
[Argo CD resource hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/)
