{{/*
Return the appropriate headless service name for StatefulSets
*/}}
{{- define "chartpack.networking.headlessServiceName" -}}
{{- if .Values.workloads.statefulSet.serviceName }}
{{- .Values.workloads.statefulSet.serviceName }}
{{- else }}
{{- printf "%s-headless" (include "chartpack.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Return the service name for a given service key.
Usage: {{ include "chartpack.networking.serviceName" (dict "key" "http" "context" $) }}
*/}}
{{- define "chartpack.networking.serviceName" -}}
{{- printf "%s-%s" (include "chartpack.fullname" .context) .key }}
{{- end }}
