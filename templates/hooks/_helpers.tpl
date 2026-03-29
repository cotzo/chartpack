{{/*
Validate hook definitions.
*/}}
{{- define "chartpack.validation.hooks" -}}
{{- $validEvents := list "pre-install" "post-install" "pre-upgrade" "post-upgrade" "pre-delete" "post-delete" "pre-rollback" "post-rollback" -}}
{{- $validDeletePolicies := list "before-hook-creation" "hook-succeeded" "hook-failed" -}}
{{- range $name, $hook := .Values.hooks }}
{{- if $hook }}
{{- if not $hook.events }}
{{- fail (printf "hooks.%s: events is required" $name) }}
{{- end }}
{{- range $hook.events }}
{{- if not (has . $validEvents) }}
{{- fail (printf "hooks.%s: invalid event %q. Must be one of: %s" $name . ($validEvents | join ", ")) }}
{{- end }}
{{- end }}
{{- if not $hook.containers }}
{{- fail (printf "hooks.%s: containers is required" $name) }}
{{- end }}
{{- with $hook.deletePolicy }}
{{- if not (has . $validDeletePolicies) }}
{{- fail (printf "hooks.%s: invalid deletePolicy %q. Must be one of: %s" $name . ($validDeletePolicies | join ", ")) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

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
