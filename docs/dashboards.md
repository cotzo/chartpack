# Dashboards

## Grafana Dashboards

Creates [GrafanaDashboard](https://grafana-operator.github.io/grafana-operator/docs/dashboards/) resources for the [Grafana Operator](https://grafana-operator.github.io/grafana-operator/). Requires the Grafana Operator (`grafana.integreatly.org/v1beta1`) installed in the cluster.

Dashboards are defined in the `dashboards.grafana` map. Each entry is named `<fullname>-<key>`.

### Inline JSON

```yaml
dashboards:
  grafana:
    app-overview:
      instanceSelector:
        matchLabels:
          dashboards: grafana
      folder: My App
      json: |
        { "title": "App Overview", "uid": "app-overview", "panels": [] }
```

### grafana.com Reference

Fetch a community dashboard by ID and revision:

```yaml
dashboards:
  grafana:
    node-exporter:
      instanceSelector:
        matchLabels:
          dashboards: grafana
      grafanaCom:
        id: 1860
        revision: 37
```

### URL Source

Fetch dashboard JSON from a URL:

```yaml
dashboards:
  grafana:
    from-url:
      instanceSelector:
        matchLabels:
          dashboards: grafana
      url: https://raw.githubusercontent.com/org/repo/main/dashboards/app.json
      contentCacheDuration: 1h
```

### ConfigMap Reference

Reference a key in an existing ConfigMap:

```yaml
dashboards:
  grafana:
    from-configmap:
      instanceSelector:
        matchLabels:
          dashboards: grafana
      configMapRef:
        name: my-dashboards
        key: app-dashboard.json
```

### Datasource Mapping

Map templated datasource variables to actual datasource names:

```yaml
dashboards:
  grafana:
    with-datasource:
      instanceSelector:
        matchLabels:
          dashboards: grafana
      json: '...'
      datasources:
        - inputName: DS_PROMETHEUS
          datasourceName: Prometheus
```

### Common Options

| Field | Description |
|-------|-------------|
| `instanceSelector` | **Required.** Label selector for target Grafana instances |
| `folder` | Folder title for the dashboard |
| `folderUID` | UID of the target folder (mutually exclusive with `folderRef`) |
| `folderRef` | Name of a GrafanaFolder resource in the same namespace |
| `resyncPeriod` | How often the resource is synced (default `10m0s`) |
| `allowCrossNamespaceImport` | Allow matching Grafana instances in other namespaces |
| `suspend` | Pause synchronization |
| `uid` | Manually set the dashboard UID (max 40 chars) |
| `plugins` | Required Grafana plugins |
| `contentCacheDuration` | Cache duration for URL-fetched content |

### Content Sources (mutually exclusive)

| Field | Description |
|-------|-------------|
| `json` | Inline dashboard JSON |
| `gzipJson` | Gzip-compressed JSON (base64-encoded) |
| `url` | URL to fetch dashboard JSON from |
| `configMapRef` | Reference to a ConfigMap key |
| `grafanaCom` | grafana.com dashboard reference (`id` + `revision`) |
| `jsonnet` | Inline Jsonnet source |

[Grafana Operator docs](https://grafana-operator.github.io/grafana-operator/) |
[GrafanaDashboard API](https://grafana-operator.github.io/grafana-operator/docs/dashboards/)
