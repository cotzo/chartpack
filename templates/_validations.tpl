{{/*
Validate workloadType
*/}}
{{- define "universal-helm.validateWorkloadType" -}}
{{- $allowed := list "Deployment" "StatefulSet" "CronJob" "Job" "DaemonSet" }}
{{- if not (has .Values.workloadType $allowed) }}
{{- fail (printf "Invalid workloadType %q. Must be one of: %s" .Values.workloadType (join ", " $allowed)) }}
{{- end }}
{{- end }}