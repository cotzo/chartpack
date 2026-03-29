{{/*
Map Helm hook events to Argo CD hook annotation value.
Takes a list of Helm events and returns the Argo CD hook value (or empty if no mapping).
Usage: {{ include "chartpack.hooks.argoEvent" (list "pre-install" "pre-upgrade") }}
*/}}
{{- define "chartpack.hooks.argoEvent" -}}
{{- $argoEvents := list -}}
{{- range . -}}
  {{- if or (eq . "pre-install") (eq . "pre-upgrade") -}}
    {{- $argoEvents = append $argoEvents "PreSync" -}}
  {{- else if or (eq . "post-install") (eq . "post-upgrade") -}}
    {{- $argoEvents = append $argoEvents "PostSync" -}}
  {{- else if eq . "pre-delete" -}}
    {{- $argoEvents = append $argoEvents "SyncFail" -}}
  {{- end -}}
{{- end -}}
{{- $argoEvents | uniq | join "," -}}
{{- end }}

{{/*
Map Helm hook delete policy to Argo CD hook-delete-policy annotation value.
Usage: {{ include "chartpack.hooks.argoDeletePolicy" "before-hook-creation" }}
*/}}
{{- define "chartpack.hooks.argoDeletePolicy" -}}
{{- if eq . "before-hook-creation" -}}BeforeHookCreation
{{- else if eq . "hook-succeeded" -}}HookSucceeded
{{- else if eq . "hook-failed" -}}HookFailed
{{- end -}}
{{- end }}
