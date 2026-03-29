# Network Policies

NetworkPolicies are defined in the `networking.networkPolicies` map. Each entry is named `<fullname>-<key>`. Uses built-in `networking.k8s.io/v1` -- no external operators required (but requires a CNI that supports NetworkPolicy, e.g. Calico, Cilium).

The `podSelector` defaults to the chart's selectorLabels if not specified, targeting the app's own pods.

## Deny All

Block all traffic to the app's pods:

```yaml
networking:
  networkPolicies:
    deny-all:
      policyTypes:
        - Ingress
        - Egress
```

## Allow Ingress from Specific Namespace

```yaml
networking:
  networkPolicies:
    allow-ingress:
      policyTypes:
        - Ingress
      ingress:
        - from:
            - namespaceSelector:
                matchLabels:
                  name: ingress-nginx
          ports:
            - protocol: TCP
              port: 80
```

## Allow DNS Egress

Most apps need DNS. Combine with a deny-all policy:

```yaml
networking:
  networkPolicies:
    allow-dns:
      policyTypes:
        - Egress
      egress:
        - to:
            - namespaceSelector: {}
          ports:
            - protocol: UDP
              port: 53
```

## Allow from Specific Pods

```yaml
networking:
  networkPolicies:
    allow-from-frontend:
      policyTypes:
        - Ingress
      ingress:
        - from:
            - podSelector:
                matchLabels:
                  tier: frontend
          ports:
            - protocol: TCP
              port: 8080
```

## IP Block Rules

```yaml
networking:
  networkPolicies:
    allow-office:
      policyTypes:
        - Ingress
      ingress:
        - from:
            - ipBlock:
                cidr: 203.0.113.0/24
                except:
                  - 203.0.113.50/32
          ports:
            - protocol: TCP
              port: 443
```

## Custom Pod Selector

Override the default selector to target different pods:

```yaml
networking:
  networkPolicies:
    namespace-deny-all:
      podSelector: {}              # empty = all pods in namespace
      policyTypes:
        - Ingress
```

## Zero-Trust Pattern

Combine deny-all with explicit allow policies:

```yaml
networking:
  networkPolicies:
    deny-all:
      policyTypes:
        - Ingress
        - Egress
    allow-dns:
      policyTypes:
        - Egress
      egress:
        - to:
            - namespaceSelector: {}
          ports:
            - protocol: UDP
              port: 53
    allow-ingress:
      policyTypes:
        - Ingress
      ingress:
        - from:
            - namespaceSelector:
                matchLabels:
                  name: ingress-nginx
          ports:
            - protocol: TCP
              port: 80
    allow-db-egress:
      policyTypes:
        - Egress
      egress:
        - to:
            - podSelector:
                matchLabels:
                  app: postgres
          ports:
            - protocol: TCP
              port: 5432
```

[NetworkPolicy reference](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
