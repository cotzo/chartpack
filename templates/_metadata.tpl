{{/*
Resource metadata builder.
Usage: {{ include "chartpack.metadata" (dict "name" "myname" "context" $ "extraLabels" (dict) "extraAnnotations" (dict)) }}
All fields except "context" are optional.
*/}}
{{- define "chartpack.metadata" -}}
{{- $ctx := .context }}
{{- $name := default (include "chartpack.fullname" $ctx) .name }}
metadata:
  name: {{ $name }}
  namespace: {{ $ctx.Release.Namespace | quote }}
  labels:
    {{- include "chartpack.labels" $ctx | nindent 4 }}
    {{- with .extraLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- $annotations := merge (default (dict) .extraAnnotations) (default (dict) $ctx.Values.global.annotations) }}
  {{- with $annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
