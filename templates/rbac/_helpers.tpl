{{/*
Create the name of the service account to use
*/}}
{{- define "chartpack.rbac.serviceAccountName" -}}
{{- $sa := default (dict) (default (dict) .Values.rbac).serviceAccount -}}
{{- if not (hasKey $sa "create") | ternary true $sa.create }}
{{- default (include "chartpack.fullname" .) $sa.name }}
{{- else }}
{{- default "default" $sa.name }}
{{- end }}
{{- end }}
