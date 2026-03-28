# Workload Types

The `workloadType` field selects which Kubernetes workload controller to create. Only one is active per release.

```yaml
workloadType: Deployment  # Deployment | StatefulSet | DaemonSet | CronJob | Job | Rollout
```

## Deployment

Standard stateless workload. Supports replicas, rolling updates, and HPA.

```yaml
workloadType: Deployment
workloads:
  deployment:
    replicaCount: 3
    strategy:
      type: RollingUpdate
      rollingUpdate:
        maxSurge: "25%"
        maxUnavailable: 0
    revisionHistoryLimit: 5
```

[Kubernetes Deployment reference](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

## StatefulSet

For stateful applications requiring stable network identities and persistent storage.

A headless service is **auto-generated** from all service ports. Persistence entries become [volumeClaimTemplates](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#volume-claim-templates).

```yaml
workloadType: StatefulSet
workloads:
  statefulSet:
    replicaCount: 3
    podManagementPolicy: OrderedReady  # or Parallel
    publishNotReadyAddresses: true
    updateStrategy:
      type: RollingUpdate
      rollingUpdate:
        partition: 0
    persistentVolumeClaimRetentionPolicy:
      whenDeleted: Retain
      whenScaled: Retain
```

[Kubernetes StatefulSet reference](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

## DaemonSet

Runs one pod per node. No replica count -- one pod per matched node.

```yaml
workloadType: DaemonSet
workloads:
  daemonSet:
    updateStrategy:
      type: RollingUpdate
      rollingUpdate:
        maxUnavailable: 1
```

[Kubernetes DaemonSet reference](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)

## CronJob

Scheduled batch workload. Services, HPA, and PDB are automatically skipped.

```yaml
workloadType: CronJob
workloads:
  cronJob:
    schedule: "0 2 * * *"
    timeZone: "UTC"
    concurrencyPolicy: Forbid    # Allow | Forbid | Replace
    successfulJobsHistoryLimit: 3
    failedJobsHistoryLimit: 1
    startingDeadlineSeconds: 300
  job:
    backoffLimit: 3
    activeDeadlineSeconds: 3600
    ttlSecondsAfterFinished: 86400
```

[Kubernetes CronJob reference](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)

## Job

One-off batch workload.

```yaml
workloadType: Job
workloads:
  job:
    backoffLimit: 3
    completions: 1
    parallelism: 1
    completionMode: NonIndexed   # or Indexed
    ttlSecondsAfterFinished: 3600
```

[Kubernetes Job reference](https://kubernetes.io/docs/concepts/workloads/controllers/job/)

## Rollout

[Argo Rollouts](https://argoproj.github.io/rollouts/) workload for progressive delivery with canary or blue-green strategies. Requires the Argo Rollouts controller installed in the cluster.

```yaml
workloadType: Rollout
workloads:
  rollout:
    replicaCount: 3
    strategy:
      canary:
        steps:
          - setWeight: 20
          - pause: { duration: 30s }
          - setWeight: 50
          - pause: { duration: 30s }
    revisionHistoryLimit: 5
    minReadySeconds: 30
    # restartAt: "2026-03-01T03:00:00Z"   # optional scheduled restart
    # analysis:                             # optional background analysis
    #   templates:
    #     - templateName: success-rate
```

### Blue-Green Strategy

```yaml
workloads:
  rollout:
    replicaCount: 3
    strategy:
      blueGreen:
        activeService: stable
        previewService: canary
        autoPromotionEnabled: true
        autoPromotionSeconds: 60

networking:
  services:
    stable:
      ports:
        http:
          port: 80
    canary:
      ports:
        http:
          port: 80
```

HPA, PDB, and KEDA all work with Rollouts -- the chart automatically sets `scaleTargetRef` to the Rollout resource.

[Argo Rollouts documentation](https://argoproj.github.io/rollouts/) |
[Canary strategy](https://argoproj.github.io/rollouts/features/canary/) |
[Blue-green strategy](https://argoproj.github.io/rollouts/features/bluegreen/)
