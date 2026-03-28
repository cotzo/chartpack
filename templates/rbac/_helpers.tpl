{{/*
Create the name of the service account to use
*/}}
{{- define "chartpack.rbac.serviceAccountName" -}}
{{- if .Values.rbac.serviceAccount.create }}
{{- default (include "chartpack.fullname" .) .Values.rbac.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.rbac.serviceAccount.name }}
{{- end }}
{{- end }}
