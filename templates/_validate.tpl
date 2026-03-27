{{/*
Run all validations by delegating to component-specific validators.
Called once from the workload template.
*/}}
{{- define "chartpack.validate" -}}
{{- include "chartpack.validation.workloads" . }}
{{- include "chartpack.validation.containers" . }}
{{- include "chartpack.validation.networking" . }}
{{- include "chartpack.validation.autoscaling" . }}
{{- include "chartpack.validation.rbac" . }}
{{- include "chartpack.validation.monitoring" . }}
{{- end }}
