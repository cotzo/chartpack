{{/*
Create the name of the service account to use
*/}}
{{- define "chartpack.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "chartpack.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
