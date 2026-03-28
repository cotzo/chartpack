# OAuth2 Proxy

Automatic [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/) integration. Define proxies in the `networking.oauth2Proxies` map with their provider settings, then reference them on any ingress or Gateway API route. The chart handles all the wiring.

## How It Works

```
User → Ingress/Route → oauth2-proxy → Your App
```

1. Define a proxy with provider credentials in `networking.oauth2Proxies`
2. Set `oauth2Proxy: <name>` on an ingress or route
3. The chart automatically:
   - Creates the proxy infrastructure (sidecar or deployment)
   - Rewires the ingress/route backend to pass through the proxy
   - Configures the proxy to forward authenticated traffic to your app
   - Auto-derives the upstream URL from your service configuration

## Modes

### Sidecar (default)

The proxy runs as a [native sidecar](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/) in the app pod using `restartPolicy: Always` (K8s 1.33+). No separate Deployment or Service needed.

```yaml
networking:
  oauth2Proxies:
    corporate:
      # mode: sidecar          # default
      provider: oidc
      issuerUrl: https://auth.corp.example.com
      emailDomains:
        - corp.example.com
      env:
        CLIENT_ID:
          valueFrom:
            secretKeyRef:
              name: oauth2-secret
              key: client-id
              external: true
        CLIENT_SECRET:
          valueFrom:
            secretKeyRef:
              name: oauth2-secret
              key: client-secret
              external: true
        COOKIE_SECRET:
          valueFrom:
            secretKeyRef:
              name: oauth2-secret
              key: cookie-secret
              external: true

  ingresses:
    public:
      oauth2Proxy: corporate
      className: nginx
      hosts:
        - host: app.example.com
          paths:
            - path: /
              pathType: Prefix
```

**What happens:**
- oauth2-proxy injected as init container with `restartPolicy: Always`
- Upstream auto-derived as `http://localhost:<app-container-port>`
- Ingress backend port changed to proxy port (4180)

### Deployment

The proxy runs as a separate Deployment + Service. Useful when you want independent scaling or share a proxy across multiple pods.

```yaml
networking:
  oauth2Proxies:
    corporate:
      mode: deployment
      replicas: 2
      provider: oidc
      issuerUrl: https://auth.corp.example.com
      emailDomains:
        - corp.example.com
      env:
        CLIENT_ID: ...
        CLIENT_SECRET: ...
        COOKIE_SECRET: ...
```

**What happens:**
- Deployment `<fullname>-oauth2-corporate` created
- Service `<fullname>-oauth2-corporate` created
- Upstream auto-derived from the original ingress/route backend service
- Ingress/route backend rewired to the proxy service

## Multiple Proxies

Different ingresses/routes can use different proxies:

```yaml
networking:
  oauth2Proxies:
    corporate:
      provider: oidc
      issuerUrl: https://auth.corp.example.com
      emailDomains: [corp.example.com]
      env: ...

    github:
      provider: github
      emailDomains: ["*"]
      env: ...

  ingresses:
    app:
      oauth2Proxy: corporate    # OIDC for the main app
      hosts:
        - host: app.example.com
          paths:
            - path: /

    admin:
      oauth2Proxy: github       # GitHub auth for admin
      hosts:
        - host: admin.example.com
          paths:
            - path: /

    api:
      # no oauth2Proxy — direct access
      hosts:
        - host: api.example.com
          paths:
            - path: /
```

## Works with Gateway API Routes

```yaml
networking:
  gatewayApi:
    routes:
      web:
        oauth2Proxy: corporate
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
```

## Upstream Auto-Detection

The proxy's `--upstream` argument is auto-derived:

| Mode | Upstream | How derived |
|------|----------|-------------|
| Sidecar | `http://localhost:<port>` | First service's first port → matching container port |
| Deployment | `http://<service>:<port>` | First non-headless service referenced by the ingress/route |

Override with an explicit `upstream` if auto-detection doesn't match your setup:

```yaml
networking:
  oauth2Proxies:
    custom:
      upstream: http://my-custom-backend:3000
      provider: oidc
      ...
```

## All Options

```yaml
networking:
  oauth2Proxies:
    example:
      mode: sidecar              # sidecar | deployment (default: sidecar)
      image:
        repository: quay.io/oauth2-proxy/oauth2-proxy
        tag: v7.15.1
        pullPolicy: IfNotPresent
      replicas: 1                # deployment mode only
      port: 4180
      provider: oidc             # oidc | google | github | azure | gitlab | etc.
      issuerUrl: ""              # OIDC issuer URL
      emailDomains:              # allowed email domains
        - "*"
      upstream: ""               # auto-derived if not set
      extraArgs:                 # key-value → --key=value
        cookie-secure: "true"
        skip-auth-regex: "^/health"
      args: []                   # additional raw args
      env: {}                    # same unified env map as containers
      resources: {}
      securityContext: {}
      annotations: {}
      labels: {}
```

## Credentials

oauth2-proxy requires three secrets: `CLIENT_ID`, `CLIENT_SECRET`, and `COOKIE_SECRET`. These must be provided as env vars using the [unified env map](containers.md#unified-environment-variables). Typically from external secrets:

```yaml
env:
  CLIENT_ID:
    valueFrom:
      secretKeyRef:
        name: my-oauth2-secret
        key: client-id
        external: true
  CLIENT_SECRET:
    valueFrom:
      secretKeyRef:
        name: my-oauth2-secret
        key: client-secret
        external: true
  COOKIE_SECRET:
    valueFrom:
      secretKeyRef:
        name: my-oauth2-secret
        key: cookie-secret
        external: true
```

Or generate the cookie secret automatically using the chart's [secret generation](configuration.md#auto-generated-secrets) feature.

## Validation

The chart validates that `oauth2Proxy` references on ingresses and routes point to existing keys in the `networking.oauth2Proxies` map.

[oauth2-proxy documentation](https://oauth2-proxy.github.io/oauth2-proxy/) |
[oauth2-proxy providers](https://oauth2-proxy.github.io/oauth2-proxy/configuration/providers/)
