# Networking

## Services

Services are defined in the `networking.services` map. Each entry is named `<fullname>-<key>`. Not created for CronJob/Job workloads.

Ports are also a map -- the key is the port name. `containerPort` defaults to the port key name, referencing the container's ports map by name.

```yaml
networking:
  services:
    http:
      type: ClusterIP              # ClusterIP | NodePort | LoadBalancer | ExternalName
      ports:
        http:
          port: 80
          containerPort: http      # defaults to port key name

    grpc:
      type: ClusterIP
      ports:
        grpc:
          port: 9090

    external:
      type: NodePort
      ports:
        http:
          port: 80
          containerPort: http
          nodePort: 30080
      externalTrafficPolicy: Local
```

### Headless Services

Set `headless: true` for `clusterIP: None`:

```yaml
networking:
  services:
    discovery:
      headless: true
      publishNotReadyAddresses: true
      ports:
        http:
          port: 8080
```

### StatefulSet Auto-Headless

When `workloadType: StatefulSet`, a headless service named `<fullname>-headless` is automatically created from all service ports. Override the name with `statefulSet.serviceName`.

### Additional Service Options

```yaml
networking:
  services:
    example:
      ports:
        http:
          port: 80
      clusterIP: ""
      loadBalancerIP: ""
      loadBalancerSourceRanges: []
      externalTrafficPolicy: ""    # Cluster | Local
      trafficDistribution: ""     # PreferSameNode | PreferSameZone (K8s 1.35+)
      sessionAffinity: ""
      ipFamilyPolicy: ""
      ipFamilies: []
      publishNotReadyAddresses: false
      selectorLabels: {}           # extra labels merged with default selector
      annotations: {}
      labels: {}
```

[Service reference](https://kubernetes.io/docs/concepts/services-networking/service/) |
[Headless services](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services)

## Ingresses

Ingresses are defined in the `networking.ingresses` map. Each entry is named `<fullname>-<key>`. Path backends default to the first service's name and port.

```yaml
networking:
  ingresses:
    public:
      className: nginx
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-prod
      hosts:
        - host: app.example.com
          paths:
            - path: /
              pathType: Prefix       # Prefix | Exact | ImplementationSpecific
            - path: /api
              pathType: Prefix
              serviceName: my-app-api  # override backend service
              servicePort: 8080        # override backend port
      tls:
        - secretName: app-tls
          hosts:
            - app.example.com

    internal:
      className: nginx-internal
      annotations:
        nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8"
      hosts:
        - host: app.internal.example.com
          paths:
            - path: /
              pathType: Prefix
```

[Ingress reference](https://kubernetes.io/docs/concepts/services-networking/ingress/) |
[Ingress controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/)

## Gateway API Routes

For Gateway API based routing (HTTPRoute, GRPCRoute, TLSRoute, TCPRoute, UDPRoute) and Envoy Gateway traffic policies, see [Gateway API Routes](routes.md).
