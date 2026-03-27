{{/*
Return the appropriate headless service name for StatefulSets
*/}}
{{- define "universal-helm.headlessServiceName" -}}
{{- if .Values.statefulSet.serviceName }}
{{- .Values.statefulSet.serviceName }}
{{- else }}
{{- printf "%s-headless" (include "universal-helm.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Return the service name for a given service key.
Usage: {{ include "universal-helm.serviceName" (dict "key" "http" "context" $) }}
*/}}
{{- define "universal-helm.serviceName" -}}
{{- printf "%s-%s" (include "universal-helm.fullname" .context) .key }}
{{- end }}
