{{/*
Run all validations by delegating to component-specific validators.
Called once from the workload template.
*/}}
{{- define "universal-helm.validate" -}}
{{- include "universal-helm.validation.workloads" . }}
{{- include "universal-helm.validation.containers" . }}
{{- include "universal-helm.validation.networking" . }}
{{- include "universal-helm.validation.autoscaling" . }}
{{- include "universal-helm.validation.rbac" . }}
{{- include "universal-helm.validation.monitoring" . }}
{{- end }}
