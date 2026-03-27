{{/*
Validate workload type.
*/}}
{{- define "universal-helm.validation.workloads.type" -}}
{{- $allowedTypes := list "Deployment" "StatefulSet" "CronJob" "Job" "DaemonSet" }}
{{- if not (has .Values.workloadType $allowedTypes) }}
{{- fail (printf "workloadType %q is invalid. Must be one of: %s" .Values.workloadType (join ", " $allowedTypes)) }}
{{- end }}
{{- end }}

{{/*
Validate CronJob requires schedule.
*/}}
{{- define "universal-helm.validation.workloads.cronjob" -}}
{{- if eq .Values.workloadType "CronJob" }}
{{- if not .Values.cronJob.schedule }}
{{- fail "cronJob.schedule: required when workloadType is CronJob" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Run all workload validations.
*/}}
{{- define "universal-helm.validation.workloads" -}}
{{- include "universal-helm.validation.workloads.type" . }}
{{- include "universal-helm.validation.workloads.cronjob" . }}
{{- end }}
