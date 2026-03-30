# Scheduling

## Node Targeting

High-level node targeting rendered as [nodeAffinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity) `In` expressions. Label keys come from `infraSettings.nodeLabels`.

Each targeting property supports two forms:

- **Array shorthand** — soft enforcement (default): `os: [linux]`
- **Object form** — explicit enforcement: `os: { values: [linux], enforcement: hard }`

```yaml
nodeTargeting:
  restrictions:
    type: differentNodes
    enforcement: soft
  os: [linux]                               # shorthand → soft
  arch:
    values: [amd64, arm64]
    enforcement: hard                       # explicit → hard
  regions: [us-east-1, eu-west-1]           # shorthand → soft
  zones: [us-east-1a, us-east-1b]
  racks: [rack-a, rack-b]
  nodeTypes: [m5.xlarge, c5.2xlarge]
  nodePools: [general-purpose]
```

### Restrictions

Controls how replicas are placed across nodes.

```yaml
nodeTargeting:
  restrictions:
    type: differentNodes        # differentNodes | sameNode | none
    enforcement: soft           # soft | hard
```

**Type:**

| Value | Behavior |
|-------|----------|
| `differentNodes` (default) | Spread replicas across different nodes (podAntiAffinity) |
| `sameNode` | Colocate replicas on the same node (podAffinity) |
| `none` | No placement preference |

**Enforcement:**

| Value | Behavior |
|-------|----------|
| `soft` (default) | Best-effort (`preferredDuringSchedulingIgnoredDuringExecution`). Pods still schedule if preference can't be met. |
| `hard` | Strict (`requiredDuringSchedulingIgnoredDuringExecution`). Pods stay unschedulable if constraint can't be satisfied. |

Use `soft` for most workloads. Use `hard` when colocation or separation is a strict requirement (e.g., HA guarantees).

### Node Affinity

The targeting fields (`os`, `arch`, `regions`, `zones`, `racks`, `nodeTypes`, `nodePools`) generate nodeAffinity `In` expressions. The `enforcement` field controls whether expressions are required or preferred.

> **Warning:** `hard` enforcement can leave pods in `Pending` state indefinitely if no nodes match the criteria. Use `soft` (the default) unless you have a strict scheduling requirement.

**Enforcement:**

| Value | Behavior |
|-------|----------|
| `soft` (default) | Best-effort (`preferredDuringSchedulingIgnoredDuringExecution` weight 100). Pods still schedule on non-matching nodes. |
| `hard` | Strict (`requiredDuringSchedulingIgnoredDuringExecution`). Pods stay unschedulable if no nodes match. |

For example, with `arch.enforcement: hard` and `regions` using the default `soft`:

```yaml
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
      - matchExpressions:
          - key: kubernetes.io/arch
            operator: In
            values: [amd64, arm64]
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      preference:
        matchExpressions:
          - key: topology.kubernetes.io/region
            operator: In
            values: [us-east-1, eu-west-1]
```

When multiple properties share the same enforcement level, their expressions are combined into a single `nodeSelectorTerm` (hard) or a single `preference` entry (soft).

### Label Key Mapping

Label keys are resolved from `infraSettings.nodeLabels`. Override them for non-standard clusters:

```yaml
infraSettings:
  nodeLabels:
    topologyRegion: custom.io/region              # used by nodeTargeting.regions
    topologyZone: custom.io/zone                  # used by nodeTargeting.zones
    topologyRack: custom.io/rack                  # used by nodeTargeting.racks
    os: kubernetes.io/os                          # used by nodeTargeting.os
    arch: kubernetes.io/arch                      # used by nodeTargeting.arch
    nodeType: node.kubernetes.io/instance-type    # used by nodeTargeting.nodeTypes
    nodePool: cloud.google.com/gke-nodepool       # used by nodeTargeting.nodePools
```

| nodeTargeting field | infraSettings.nodeLabels key | Default label |
|--------------------|-----------------------------|---------------|
| `os` | `os` | `kubernetes.io/os` |
| `arch` | `arch` | `kubernetes.io/arch` |
| `regions` | `topologyRegion` | `topology.kubernetes.io/region` |
| `zones` | `topologyZone` | `topology.kubernetes.io/zone` |
| `racks` | `topologyRack` | `topology.kubernetes.io/rack` |
| `nodeTypes` | `nodeType` | `node.kubernetes.io/instance-type` |
| `nodePools` | `nodePool` | `node.cluster.x-k8s.io/node-pool` |

> **Cloud-specific nodePool labels:** The default `nodePool` label is Cluster API standard. Override it for your cloud:
> GKE: `cloud.google.com/gke-nodepool`, EKS: `eks.amazonaws.com/nodegroup`, AKS: `kubernetes.azure.com/agentpool`.

These expressions are **merged** with any existing `podSettings.affinity.nodeAffinity`. Hard-enforced expressions merge into `requiredDuringSchedulingIgnoredDuringExecution`; soft-enforced ones merge into `preferredDuringSchedulingIgnoredDuringExecution`.

## Pod Settings

All pod-level scheduling lives under `podSettings`:

### Node Selector

Simple key-value node selection (AND logic):

```yaml
podSettings:
  nodeSelector:
    node.kubernetes.io/instance-type: m5.xlarge
    topology.kubernetes.io/zone: us-east-1a
```

[nodeSelector reference](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector)

### Affinity

Full affinity rules. `nodeTargeting` expressions are merged into nodeAffinity based on their enforcement level.

```yaml
podSettings:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchExpressions:
                - key: app.kubernetes.io/name
                  operator: In
                  values: [my-app]
            topologyKey: kubernetes.io/hostname
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: topology.kubernetes.io/zone
                operator: In
                values: [us-east-1a, us-east-1b]
```

[Affinity reference](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)

### Tolerations

```yaml
podSettings:
  tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "app"
      effect: "NoSchedule"
    - key: "node.kubernetes.io/not-ready"
      operator: "Exists"
      effect: "NoExecute"
      tolerationSeconds: 300
```

[Tolerations reference](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)

### Topology Spread Constraints

Defined as a map under `podSettings.topologySpreadConstraints`. The `labelSelector` **defaults to the chart's selectorLabels** if not specified — no need to repeat your app labels.

```yaml
podSettings:
  topologySpreadConstraints:
    zone-spread:
      maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
    node-spread:
      maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
```

#### Available Fields

| Field | Default | Description |
|-------|---------|-------------|
| `maxSkew` | `1` | Max difference in pod count between topology domains |
| `topologyKey` | **required** | Node label key or `infraSettings.nodeLabels` friendly name |
| `whenUnsatisfiable` | `DoNotSchedule` | `DoNotSchedule` or `ScheduleAnyway` |
| `labelSelector` | chart selectorLabels | Override to target different pods |
| `matchLabelKeys` | | Pod label keys for per-revision spreading |
| `minDomains` | | Minimum topology domains (K8s 1.30+) |
| `nodeAffinityPolicy` | | `Honor` or `Ignore` node affinity |
| `nodeTaintsPolicy` | | `Honor` or `Ignore` node taints |

#### Using infraSettings friendly names

`topologyKey` can reference an `infraSettings.nodeLabels` key instead of a raw label:

```yaml
podSettings:
  topologySpreadConstraints:
    zone-spread:
      topologyKey: topologyZone      # resolves to topology.kubernetes.io/zone
    pool-spread:
      topologyKey: nodePool          # resolves to cloud-specific label
```

#### Custom Label Selector

```yaml
podSettings:
  topologySpreadConstraints:
    custom:
      topologyKey: topology.kubernetes.io/zone
      labelSelector:
        matchLabels:
          custom: label
```

[Topology spread reference](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)

### Priority

```yaml
podSettings:
  priorityClassName: high-priority
```

[Priority and preemption reference](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)
