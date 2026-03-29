# Autoscaling & Availability

## Horizontal Pod Autoscaler

Uses the [autoscaling/v2 API](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/horizontal-pod-autoscaler-v2/). Only applies to Deployment and StatefulSet workloads.

```yaml
autoscaling:
  hpa:
    enabled: true
    minReplicas: 2
    maxReplicas: 20
    metrics:
      - type: Resource
        resource:
          name: cpu
          target:
            type: Utilization
            averageUtilization: 75
      - type: Resource
        resource:
          name: memory
          target:
            type: Utilization
            averageUtilization: 80
      - type: Pods
        pods:
          metric:
            name: http_requests_per_second
          target:
            type: AverageValue
            averageValue: "1000"
    behavior:
      scaleDown:
        stabilizationWindowSeconds: 300
        policies:
          - type: Percent
            value: 10
            periodSeconds: 60
      scaleUp:
        stabilizationWindowSeconds: 30
        policies:
          - type: Percent
            value: 100
            periodSeconds: 15
    annotations: {}
    labels: {}
```

When `autoscaling.hpa.enabled: true`, the `replicaCount` field in the workload config is omitted (HPA controls replicas).

[HPA reference](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) |
[HPA walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)

## Vertical Pod Autoscaler

[VPA](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler) automatically adjusts CPU and memory requests based on observed usage. Applies to Deployment, StatefulSet, DaemonSet, and Rollout.

VPA can be used **alongside HPA** — set `controlledValues: RequestsOnly` so VPA manages requests while HPA manages replica count.

```yaml
autoscaling:
  vpa:
    enabled: true
    updatePolicy:
      updateMode: Auto              # Off (dry-run) | Initial | Auto
    resourcePolicy:
      containerPolicies:
        - containerName: "*"
          minAllowed:
            cpu: 100m
            memory: 50Mi
          maxAllowed:
            cpu: "1"
            memory: 500Mi
          controlledResources: ["cpu", "memory"]
          controlledValues: RequestsOnly   # use with HPA
    annotations: {}
    labels: {}
```

### Update Modes

| Mode | Behavior |
|------|----------|
| `Off` | Recommendations computed but not applied (dry-run) |
| `Initial` | Resources set only at pod creation |
| `Auto` | Pods recreated when recommendations change significantly |

### Container Policies

| Field | Description |
|-------|-------------|
| `containerName` | Container name or `"*"` for all |
| `mode` | `Auto` (default) or `Off` to exclude a container |
| `minAllowed` | Minimum CPU/memory VPA can set |
| `maxAllowed` | Maximum CPU/memory VPA can set |
| `controlledResources` | `["cpu"]`, `["memory"]`, or `["cpu", "memory"]` |
| `controlledValues` | `RequestsAndLimits` or `RequestsOnly` |

[VPA reference](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)

## KEDA

[KEDA](https://keda.sh/) provides event-driven autoscaling. When `autoscaling.keda.enabled: true`, the chart creates a **ScaledObject** (for Deployment, StatefulSet, or Rollout) or a **ScaledJob** (for Job workloads). KEDA and HPA are mutually exclusive -- enabling both is a validation error.

### ScaledObject (Deployment / StatefulSet / Rollout)

```yaml
autoscaling:
  keda:
    enabled: true
    pollingInterval: 30
    cooldownPeriod: 300
    idleReplicaCount: 0              # 0 = scale to zero when idle
    minReplicaCount: 1
    maxReplicaCount: 20
    triggers:
      - type: prometheus
        metadata:
          serverAddress: http://prometheus:9090
          query: sum(rate(http_requests_total{service="my-app"}[2m]))
          threshold: "100"
    fallback:
      failureThreshold: 3
      replicas: 5
    advanced:
      horizontalPodAutoscalerConfig:
        behavior:
          scaleDown:
            stabilizationWindowSeconds: 300
    annotations: {}
    labels: {}
```

### ScaledJob (Job)

When `workloadType: Job`, KEDA creates a ScaledJob that spawns Job pods in response to events:

```yaml
workloadType: Job
autoscaling:
  keda:
    enabled: true
    pollingInterval: 15
    maxReplicaCount: 10
    successfulJobsHistoryLimit: 5
    failedJobsHistoryLimit: 3
    scalingStrategy:
      strategy: default              # default | custom | accurate
    triggers:
      - type: aws-sqs-queue
        metadata:
          queueURL: https://sqs.us-east-1.amazonaws.com/123456789/my-queue
          queueLength: "5"
          awsRegion: us-east-1
```

### Common Trigger Examples

```yaml
# Cron schedule
triggers:
  - type: cron
    metadata:
      timezone: UTC
      start: "0 8 * * 1-5"
      end: "0 18 * * 1-5"
      desiredReplicas: "5"

# Kafka consumer lag
triggers:
  - type: kafka
    metadata:
      bootstrapServers: kafka:9092
      consumerGroup: my-group
      topic: my-topic
      lagThreshold: "50"
```

[KEDA documentation](https://keda.sh/docs/) |
[Scaler catalog](https://keda.sh/docs/scalers/) |
[ScaledObject spec](https://keda.sh/docs/concepts/scaling-deployments/) |
[ScaledJob spec](https://keda.sh/docs/concepts/scaling-jobs/)

## Pod Disruption Budget

Ensures minimum availability during voluntary disruptions. Applies to Deployment, StatefulSet, and DaemonSet.

```yaml
pdb:
  enabled: true
  minAvailable: "50%"          # number or percentage
  # or:
  # maxUnavailable: 1
  unhealthyPodEvictionPolicy: ""  # IfHealthy | AlwaysAllow
  annotations: {}
  labels: {}
```

[PDB reference](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) |
[Disruptions](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)
