{{/*
Create the name of the service account to use
*/}}
{{- define "universal-helm.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "universal-helm.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
