# Persistence

Persistence entries define PVC storage. For **StatefulSets**, they become [volumeClaimTemplates](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#volume-claim-templates). For all other workload types, standalone PVCs are created.

Mounting is configured per container via the `mounts` list.

```yaml
persistence:
  data:
    storageClass: standard
    accessModes:
      - ReadWriteOnce            # ReadWriteOnce | ReadWriteMany | ReadOnlyMany | ReadWriteOncePod (1.29+)
    size: 10Gi
    annotations: {}
    labels: {}

  shared:
    storageClass: efs-sc
    accessModes:
      - ReadWriteMany
    size: 50Gi

  existing:
    existingClaim: legacy-data-pvc  # use existing PVC, no new PVC created

containers:
  app:
    mounts:
      - path: /data
        persistence: data
      - path: /shared
        persistence: shared
      - path: /legacy
        persistence: existing
```

### Defaults

- `accessModes` defaults to `["ReadWriteOnce"]` if omitted
- `size` defaults to `1Gi` if omitted

### Storage Class

- Omit `storageClass` to use the cluster default
- Set `storageClass: "-"` for an empty `storageClassName` (disables dynamic provisioning)
- Set `storageClass: "fast-ssd"` to use a specific class

### Static Volume Binding

Bind to a specific pre-created PersistentVolume:

```yaml
persistence:
  data:
    volumeName: pv-data-001         # bind to specific PV by name
    size: 10Gi
  filtered:
    selector:                       # select PVs by label
      matchLabels:
        environment: production
    size: 50Gi
```

[Persistent Volumes reference](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) |
[Storage Classes reference](https://kubernetes.io/docs/concepts/storage/storage-classes/)

## Pod Volumes

For non-persistent volumes (emptyDir, hostPath, projected, etc.), define them in `podSettings.volumes` and reference via `mounts`:

```yaml
podSettings:
  volumes:
    - name: tmp
      emptyDir:
        sizeLimit: 100Mi
    - name: shared
      emptyDir: {}

containers:
  app:
    mounts:
      - path: /tmp
        volume: tmp
```

[Volume types reference](https://kubernetes.io/docs/concepts/storage/volumes/#volume-types)
