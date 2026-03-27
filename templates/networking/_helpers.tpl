{{/*
Return the appropriate headless service name for StatefulSets
*/}}
{{- define "chartpack.headlessServiceName" -}}
{{- if .Values.statefulSet.serviceName }}
{{- .Values.statefulSet.serviceName }}
{{- else }}
{{- printf "%s-headless" (include "chartpack.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Return the service name for a given service key.
Usage: {{ include "chartpack.serviceName" (dict "key" "http" "context" $) }}
*/}}
{{- define "chartpack.serviceName" -}}
{{- printf "%s-%s" (include "chartpack.fullname" .context) .key }}
{{- end }}
