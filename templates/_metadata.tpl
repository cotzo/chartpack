{{/*
Resource metadata builder.
Usage: {{ include "chartpack.metadata" (dict "name" "myname" "context" $ "extraLabels" (dict) "extraAnnotations" (dict)) }}
All fields except "context" are optional.
Set "clusterScoped" to true to omit namespace (for ClusterRole, ClusterRoleBinding, etc.).
*/}}
{{- define "chartpack.metadata" -}}
{{- $ctx := .context }}
{{- $name := default (include "chartpack.fullname" $ctx) .name }}
metadata:
  name: {{ $name }}
  {{- if not .clusterScoped }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  {{- end }}
  labels:
    {{- include "chartpack.labels" $ctx | nindent 4 }}
    {{- with .extraLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- $annotations := merge (dict) (default (dict) .extraAnnotations) (default (dict) $ctx.Values.global.annotations) }}
  {{- with $annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
