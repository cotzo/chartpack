# Gateway API Routes

The `networking.gatewayApi.routes` map creates [Gateway API](https://gateway-api.sigs.k8s.io/) route resources. Each entry specifies its `kind` to determine the CRD type. Gateways are **not** created by this chart — they are pre-existing cluster infrastructure that routes attach to via `parentRefs`.

## Route Types

| `kind` | API Version | Status |
|--------|------------|--------|
| `HTTPRoute` | `gateway.networking.k8s.io/v1` | GA |
| `GRPCRoute` | `gateway.networking.k8s.io/v1` | GA |
| `TLSRoute` | `gateway.networking.k8s.io/v1` | GA |
| `TCPRoute` | `gateway.networking.k8s.io/v1alpha2` | Alpha |
| `UDPRoute` | `gateway.networking.k8s.io/v1alpha2` | Alpha |

Default: `HTTPRoute`.

## HTTPRoute

```yaml
networking:
  gatewayApi:
    routes:
      web:
        kind: HTTPRoute
        parentRefs:
          - name: my-gateway
            namespace: gateway-system
            sectionName: https          # optional — gateway listener name
        hostnames:
          - app.example.com
        rules:
          - matches:
              - path:
                  type: PathPrefix
                  value: /
            backendRefs:
              - name: http              # key from networking.services map, auto-prefixed
                port: 80
            timeouts:
              request: 30s
              backendRequest: 15s
```

### Traffic Splitting

```yaml
networking:
  gatewayApi:
    routes:
      canary:
        kind: HTTPRoute
        parentRefs:
          - name: my-gateway
        hostnames:
          - app.example.com
        rules:
          - matches:
              - path:
                  type: PathPrefix
                  value: /
            backendRefs:
              - name: http
                port: 80
                weight: 90
              - name: http-canary
                port: 80
                weight: 10
```

### Header Matching & Filters

```yaml
networking:
  gatewayApi:
    routes:
      api-v2:
        kind: HTTPRoute
        parentRefs:
          - name: my-gateway
        hostnames:
          - api.example.com
        rules:
          - matches:
              - headers:
                  - name: X-Api-Version
                    value: v2
            backendRefs:
              - name: http
                port: 80
            filters:
              - type: RequestHeaderModifier
                requestHeaderModifier:
                  set:
                    - name: X-Forwarded-Prefix
                      value: /v2
```

[HTTPRoute reference](https://gateway-api.sigs.k8s.io/api-types/httproute/)

## GRPCRoute

```yaml
networking:
  gatewayApi:
    routes:
      grpc:
        kind: GRPCRoute
        parentRefs:
          - name: my-gateway
            sectionName: grpc
        hostnames:
          - grpc.example.com
        rules:
          - matches:
              - method:
                  service: myapp.v1.ItemService
                  method: GetItem
            backendRefs:
              - name: grpc
                port: 9090
```

[GRPCRoute reference](https://gateway-api.sigs.k8s.io/api-types/grpcroute/)

## TLSRoute

For TLS passthrough — traffic is forwarded without termination.

```yaml
networking:
  gatewayApi:
    routes:
      tls:
        kind: TLSRoute
        parentRefs:
          - name: my-gateway
            sectionName: tls-passthrough
        hostnames:
          - secure.example.com
        rules:
          - backendRefs:
              - name: http
                port: 443
```

[TLSRoute reference](https://gateway-api.sigs.k8s.io/api-types/tlsroute/)

## TCPRoute (Alpha)

```yaml
networking:
  gatewayApi:
    routes:
      postgres:
        kind: TCPRoute
        parentRefs:
          - name: my-gateway
            sectionName: postgres
        rules:
          - backendRefs:
              - name: postgres
                port: 5432
```

[TCP routing guide](https://gateway-api.sigs.k8s.io/guides/tcp/)

## UDPRoute (Alpha)

```yaml
networking:
  gatewayApi:
    routes:
      dns:
        kind: UDPRoute
        parentRefs:
          - name: my-gateway
            sectionName: dns
        rules:
          - backendRefs:
              - name: dns
                port: 53
```

## Backend References

`backendRefs[].name` references a key from the `networking.services` map and is auto-prefixed with `<fullname>-`. The `port` is the service port number.

## Envoy Gateway Traffic Policies

When using [Envoy Gateway](https://gateway.envoyproxy.io/) as your Gateway implementation, you can attach a `BackendTrafficPolicy` to any route via the `policies.envoy` key:

```yaml
networking:
  gatewayApi:
    routes:
      web:
        kind: HTTPRoute
        parentRefs:
          - name: my-gateway
        hostnames:
          - app.example.com
        rules:
          - backendRefs:
              - name: http
                port: 80
        policies:
          envoy:
            loadBalancer:
              type: LeastRequest
            circuitBreaker:
              maxConnections: 2048
              maxPendingRequests: 512
            retry:
              numRetries: 3
            rateLimit:
              global:
                rules:
                  - limit:
                      requests: 100
                      unit: Second
            timeout:
              tcp:
                connectTimeout: 10s
              http:
                connectionIdleTimeout: 60s
            tcpKeepalive:
              probes: 3
              idleTime: 60s
              interval: 10s
```

Each route with `policies.envoy` generates a `BackendTrafficPolicy` resource (`gateway.envoyproxy.io/v1alpha1`) that targets that route.

### Available Policy Fields

| Field | Description |
|-------|-------------|
| `loadBalancer` | Algorithm: RoundRobin, LeastRequest, Random, ConsistentHash |
| `circuitBreaker` | Connection and request limits |
| `retry` | Retry count and conditions |
| `rateLimit` | Rate limiting rules |
| `timeout` | TCP and HTTP timeouts |
| `healthCheck` | Active health checking |
| `tcpKeepalive` | TCP keep-alive configuration |
| `faultInjection` | Delay/abort injection for testing |
| `useClientProtocol` | Preserve client protocol (HTTP/1.1 vs HTTP/2) |
| `compression` | Response compression |
| `http2` | HTTP/2 settings |
| `dns` | DNS resolution settings |

[Envoy Gateway docs](https://gateway.envoyproxy.io/) |
[BackendTrafficPolicy API](https://gateway.envoyproxy.io/docs/api/extension_types/#backendtrafficpolicy)

[Gateway API reference](https://gateway-api.sigs.k8s.io/) |
[API specification](https://gateway-api.sigs.k8s.io/reference/spec/)
