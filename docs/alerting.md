# Alerting Rules

The `alerting` map creates alerting and recording rule resources. Each entry specifies its `operator` to select the CRD type:

| `operator` | API Version | Kind |
|------------|------------|------|
| `prometheus` (default) | `monitoring.coreos.com/v1` | `PrometheusRule` |
| `victoriametrics` | `operator.victoriametrics.com/v1beta1` | `VMRule` |

Rule groups use standard PromQL syntax — the `groups` structure is passed through directly, so all Prometheus-compatible fields work.

## Alerting Rules

```yaml
alerting:
  app-alerts:
    operator: prometheus
    groups:
      - name: high-error-rate
        interval: 1m
        rules:
          - alert: HighErrorRate
            expr: rate(http_errors_total{job="my-app"}[5m]) > 0.1
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "High error rate on {{ $labels.instance }}"
              runbook_url: https://runbooks.example.com/HighErrorRate
          - alert: PodCrashLooping
            expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
            for: 10m
            labels:
              severity: warning
```

## Recording Rules

Recording rules pre-compute expensive queries:

```yaml
alerting:
  recordings:
    groups:
      - name: http-recordings
        rules:
          - record: job:http_requests:rate5m
            expr: sum(rate(http_requests_total[5m])) by (job)
          - record: job:http_errors:rate5m
            expr: sum(rate(http_errors_total[5m])) by (job)
```

## Mixed Alerting and Recording Rules

Groups can contain both:

```yaml
alerting:
  app-rules:
    groups:
      - name: recordings
        rules:
          - record: job:http_requests:rate5m
            expr: sum(rate(http_requests_total[5m])) by (job)
      - name: alerts
        rules:
          - alert: HighRequests
            expr: job:http_requests:rate5m > 1000
            for: 5m
```

## VictoriaMetrics

```yaml
alerting:
  vm-alerts:
    operator: victoriametrics
    groups:
      - name: infra-alerts
        concurrency: 2
        rules:
          - alert: HighMemoryUsage
            expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "Node memory usage above 90%"
```

VMRule supports additional group-level fields: `concurrency`, `type`, `headers`, `params`. Rule-level `debug` is also available for troubleshooting.

## Resource Naming

Each alerting entry is named `<fullname>-<key>`. Custom annotations and labels can be set per entry:

```yaml
alerting:
  app-alerts:
    annotations:
      argocd.argoproj.io/sync-wave: "1"
    labels:
      team: platform
    groups:
      - name: alerts
        rules:
          - alert: Test
            expr: up == 0
```

[PrometheusRule reference](https://prometheus-operator.dev/docs/developer/alerting/) |
[VMRule reference](https://docs.victoriametrics.com/operator/resources/vmrule/)
