<p align="center">
  <img src="docs/images/banner.jpeg" alt="ChartPack" width="800">
</p>


<p align="center">
  <a href="https://artifacthub.io/packages/search?repo=chartpack"><img src="https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/chartpack" alt="Artifact Hub"></a>
  <a href="https://github.com/cotzo/chartpack/actions/workflows/lint.yaml"><img src="https://github.com/cotzo/chartpack/actions/workflows/lint.yaml/badge.svg" alt="Lint & Test"></a>
  <a href="https://github.com/cotzo/chartpack/actions/workflows/integration.yaml"><img src="https://github.com/cotzo/chartpack/actions/workflows/integration.yaml/badge.svg" alt="Integration Tests"></a>
  <img src="https://img.shields.io/badge/kubernetes-%3E%3D1.28-blue?logo=kubernetes&logoColor=white" alt="Kubernetes >= 1.28">
  <img src="https://img.shields.io/badge/helm-v3-blue?logo=helm&logoColor=white" alt="Helm v3">
  <img src="https://img.shields.io/badge/license-Apache%202.0-green" alt="License">
</p>

<p align="center">
  <a href="https://cotzo.github.io/chartpack/wizard/"><img src="https://img.shields.io/badge/%F0%9F%A7%99%20Values%20Generator-Open%20Wizard-blueviolet?style=for-the-badge" alt="Values Generator"></a>
</p>

# Chartpack

A single, opinionated Helm chart for deploying any Kubernetes application workload.
Instead of maintaining separate charts per application, define your entire deployment through values.

## Quick Start

```bash
helm install my-app ./chartpack -f values.yaml
```

```yaml
containers:
  app:
    image:
      repository: nginx
      tag: "1.27"
    ports:
      http:
        port: 80

networking:
  services:
    http:
      ports:
        http:
          port: 80
```

This produces a Deployment with 1 replica, a ClusterIP Service, and a ServiceAccount.

## Key Features

**Any workload type** -- Deployment, StatefulSet, DaemonSet, CronJob, Job, or Argo Rollout -- all from a single chart with `workloadType`.

**Full networking stack** -- Services, Ingresses, Gateway API routes, Istio VirtualServices, Envoy Gateway policies, NetworkPolicies, and cert-manager Certificates. OAuth2 proxy autowiring for ingresses and routes.

**Observability built in** -- Prometheus/VictoriaMetrics monitors, alerting rules (PrometheusRule/VMRule), and Grafana dashboards.

**Event-driven autoscaling** -- HPA v2, VPA, and KEDA (ScaledObject + ScaledJob) with any trigger.

**Secrets management** -- ConfigMaps, Secrets with push/pull via ESO, and auto-generated passwords (ArgoCD-safe). Stakater Reloader annotations auto-generated per resource.

**Lifecycle hooks** -- Pre-install/pre-upgrade Jobs for DB migrations, schema setup, etc. Auto-generates both Helm and Argo CD hook annotations. Hooks share the main workload's pod settings (SA, volumes, secrets).

**Argo CD native** -- Auto sync waves for ordered deployment, sync options, and dual hook annotations. Works with Argo CD, Flux, and Helm CLI without configuration changes.

**Schema validation** -- Catches misconfigurations at install time: missing mounts, port mismatches, conflicting settings.

## Documentation

### Core

| Guide | Description |
|-------|-------------|
| [Workloads](docs/workloads.md) | Deployment, StatefulSet, DaemonSet, CronJob, Job, Argo Rollout |
| [Containers](docs/containers.md) | Container spec, env, mounts, health checks, init/sidecar containers |
| [Configuration](docs/configuration.md) | ConfigMaps, Secrets (push/pull via ESO), auto-generated secrets |
| [Persistence](docs/persistence.md) | PVCs, StatefulSet volume claim templates, static PV binding |
| [RBAC](docs/rbac.md) | ServiceAccount, Roles, ClusterRoles, Bindings |
| [Scheduling](docs/scheduling.md) | Node affinity, tolerations, topology spread, priority classes |

### Networking

| Guide | Description |
|-------|-------------|
| [Services & Ingresses](docs/networking.md) | ClusterIP, NodePort, LoadBalancer, headless services, Ingress |
| [Gateway API](docs/routes.md) | HTTPRoute, GRPCRoute, TLSRoute, TCPRoute, UDPRoute, Envoy policies |
| [Istio](docs/istio.md) | VirtualService, DestinationRule, PeerAuthentication, AuthorizationPolicy |
| [Certificates](docs/certificates.md) | cert-manager TLS certificates with auto-named secrets |
| [Network Policies](docs/network-policies.md) | Ingress/egress rules, deny-all, namespace/pod/IP selectors |
| [OAuth2 Proxy](docs/oauth2-proxy.md) | Sidecar and deployment mode, ingress/route autowiring |

### Autoscaling & Availability

| Guide | Description |
|-------|-------------|
| [Autoscaling](docs/autoscaling.md) | HPA v2, VPA, KEDA (ScaledObject, ScaledJob), Pod Disruption Budgets |

### Observability

| Guide | Description |
|-------|-------------|
| [Monitoring](docs/monitoring.md) | ServiceMonitor, PodMonitor, VMServiceScrape, VMPodScrape |
| [Alerting](docs/alerting.md) | PrometheusRule, VMRule (alerting + recording rules) |
| [Dashboards](docs/dashboards.md) | GrafanaDashboard (inline JSON, grafana.com, URL, ConfigMap, Jsonnet) |

### GitOps & Deployment

| Guide | Description |
|-------|-------------|
| [Argo CD](docs/argocd.md) | Sync waves, sync options, hook annotations |
| [Hooks](docs/hooks.md) | Pre-install/pre-upgrade Jobs, Argo CD + Flux compatible |

### Advanced

| Guide | Description |
|-------|-------------|
| [Resource Quotas](docs/resource-quotas.md) | LimitRange, ResourceQuota |
| [Extra Resources](docs/advanced.md) | Escape hatch for arbitrary resources, global settings, pod settings |

## Requirements

- Kubernetes >= 1.28
- Helm >= 3.x

The core chart (Deployment, Service, Ingress, ConfigMap, Secret, HPA, PDB, RBAC) has **zero external dependencies**. Optional features require their respective operators:

| Feature | Operator | Values key | Version |
|---------|----------|------------|---------|
| Argo Rollouts | [Argo Rollouts](https://argoproj.github.io/rollouts/) | `workloadType: Rollout` | v1.6+ |
| VPA | [Vertical Pod Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler) | `autoscaling.vpa.enabled` | v1.0+ |
| KEDA autoscaling | [KEDA](https://keda.sh/) | `autoscaling.keda.enabled` | v2.12+ |
| Gateway API | [Gateway API CRDs](https://gateway-api.sigs.k8s.io/) | `networking.gatewayApi.routes` | v1.2+ |
| Envoy policies | [Envoy Gateway](https://gateway.envoyproxy.io/) | `networking.gatewayApi.routes.*.policies.envoy` | v1.0+ |
| Istio mesh | [Istio](https://istio.io/) | `networking.istio.*` | v1.20+ |
| TLS certificates | [cert-manager](https://cert-manager.io/) | `config.certificates` | v1.12+ |
| External Secrets | [ESO](https://external-secrets.io/) | `config.secrets.*.pull` / `config.secrets.*.push` / `config.secrets.*.generate` | v0.9+ |
| Prometheus | [Prometheus Operator](https://prometheus-operator.dev/) | `monitors` / `alerting` (operator: prometheus) | v0.70+ |
| VictoriaMetrics | [VictoriaMetrics Operator](https://docs.victoriametrics.com/operator/) | `monitors` / `alerting` (operator: victoriametrics) | v0.44+ |
| Grafana dashboards | [Grafana Operator](https://grafana-operator.github.io/grafana-operator/) | `dashboards.grafana` | v5.22+ |

## Examples

Tested configurations in [`ci/`](ci/):

| File | Scenario |
|------|----------|
| [`minimal-values.yaml`](ci/minimal-values.yaml) | Simplest deployment |
| [`deployment-values.yaml`](ci/deployment-values.yaml) | Deployment with ingress, HPA, monitoring |
| [`statefulset-values.yaml`](ci/statefulset-values.yaml) | StatefulSet with persistence |
| [`daemonset-values.yaml`](ci/daemonset-values.yaml) | DaemonSet with pod monitoring |
| [`cronjob-values.yaml`](ci/cronjob-values.yaml) | Scheduled batch job |
| [`job-values.yaml`](ci/job-values.yaml) | One-shot job |
| [`rollout-values.yaml`](ci/rollout-values.yaml) | Argo Rollout with canary strategy |
| [`keda-values.yaml`](ci/keda-values.yaml) | KEDA ScaledObject |
| [`scaledjob-values.yaml`](ci/scaledjob-values.yaml) | KEDA ScaledJob |
| [`full-values.yaml`](ci/full-values.yaml) | Every feature exercised |

## Values Reference

See the fully commented [`values.yaml`](values.yaml) for all available options.

## License

Apache License 2.0 -- see [LICENSE](LICENSE).
