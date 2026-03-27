# Advanced

## Global Settings

Labels and annotations added to **every** resource the chart creates:

```yaml
global:
  labels:
    team: platform
    env: production
  annotations:
    managed-by: chartpack
```

## Pod Settings

All pod template spec settings:

```yaml
podSettings:
  imagePullSecrets:
    - name: registry-secret
  securityContext:
    fsGroup: 1000
    runAsUser: 1000
    runAsGroup: 1000
    fsGroupChangePolicy: OnRootMismatch
  annotations:
    prometheus.io/scrape: "true"
  labels:
    sidecar.istio.io/inject: "true"
  volumes:
    - name: tmp
      emptyDir:
        sizeLimit: 100Mi
  nodeSelector: {}
  tolerations: []
  affinity: {}
  topologySpreadConstraints: []
  priorityClassName: ""
  terminationGracePeriodSeconds: 30
  dnsPolicy: ClusterFirst
  dnsConfig:
    options:
      - name: ndots
        value: "2"
  hostNetwork: false
  restartPolicy: ""              # defaults to OnFailure for Job/CronJob
```

[Pod security context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod) |
[DNS config](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-dns-config)

## Extra Resources

Escape hatch for any Kubernetes manifest not natively supported by the chart. Supports Helm templating via `tpl`.

```yaml
extraResources:
  - apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: '{{ include "chartpack.fullname" . }}-netpol'
    spec:
      podSelector:
        matchLabels:
          app.kubernetes.io/name: my-app
      policyTypes:
        - Ingress
      ingress:
        - from:
            - namespaceSelector:
                matchLabels:
                  name: ingress-nginx
          ports:
            - protocol: TCP
              port: 8080
```

## Name Override

```yaml
nameOverride: ""          # overrides chart name in resource names
fullnameOverride: ""      # overrides the entire resource name prefix
```

## Checksum Annotations

The chart automatically adds SHA256 checksums of ConfigMap and Secret data as pod annotations. This forces pod rollouts when config content changes, solving the "config changed but pods didn't restart" problem.

Checksums are generated for all chart-managed ConfigMaps and Secrets, regardless of whether they are mounted or referenced by containers.
