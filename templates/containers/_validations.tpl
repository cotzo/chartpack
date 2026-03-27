{{/*
Validate at least one container is defined.
*/}}
{{- define "chartpack.validation.containers.required" -}}
{{- if not .Values.containers }}
{{- fail "containers: at least one container must be defined" }}
{{- end }}
{{- end }}

{{/*
Validate container images are set.
*/}}
{{- define "chartpack.validation.containers.images" -}}
{{- range $name, $c := .Values.containers }}
{{- if not $c.image }}
{{- fail (printf "containers.%s: image is required" $name) }}
{{- end }}
{{- if not $c.image.repository }}
{{- fail (printf "containers.%s.image.repository: must not be empty" $name) }}
{{- end }}
{{- end }}
{{- range $name, $c := .Values.initContainers }}
{{- if not $c.image }}
{{- fail (printf "initContainers.%s: image is required" $name) }}
{{- end }}
{{- if not $c.image.repository }}
{{- fail (printf "initContainers.%s.image.repository: must not be empty" $name) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate mounts reference existing resources.
*/}}
{{- define "chartpack.validation.containers.mounts" -}}
{{- $allContainers := dict }}
{{- range $k, $v := .Values.containers }}{{ $_ := set $allContainers $k $v }}{{ end }}
{{- range $k, $v := .Values.initContainers }}{{ $_ := set $allContainers $k $v }}{{ end }}

{{- range $cName, $c := $allContainers }}
{{- range $c.mounts }}

{{- if .configMap }}
{{- if not .external }}
{{- if not (hasKey $.Values.configMaps .configMap) }}
{{- fail (printf "containers.%s.mounts: configMap %q not found in configMaps map" $cName .configMap) }}
{{- end }}
{{- end }}
{{- end }}

{{- if .secret }}
{{- if not .external }}
{{- if not (hasKey $.Values.secrets .secret) }}
{{- fail (printf "containers.%s.mounts: secret %q not found in secrets map" $cName .secret) }}
{{- end }}
{{- end }}
{{- end }}

{{- if .persistence }}
{{- if not (hasKey $.Values.persistence .persistence) }}
{{- fail (printf "containers.%s.mounts: persistence %q not found in persistence map" $cName .persistence) }}
{{- end }}
{{- end }}

{{- end }}
{{- end }}
{{- end }}

{{/*
Validate env references to chart-managed resources.
*/}}
{{- define "chartpack.validation.containers.env" -}}
{{- range $cName, $c := .Values.containers }}
{{- range $c.env }}

{{- if .valueFrom }}
{{- if .valueFrom.configMapKeyRef }}
{{- if not .valueFrom.configMapKeyRef.external }}
{{- if not (hasKey $.Values.configMaps .valueFrom.configMapKeyRef.name) }}
{{- fail (printf "containers.%s.env: configMapKeyRef name %q not found in configMaps map (add external: true for external resources)" $cName .valueFrom.configMapKeyRef.name) }}
{{- end }}
{{- end }}
{{- end }}
{{- if .valueFrom.secretKeyRef }}
{{- if not .valueFrom.secretKeyRef.external }}
{{- if not (hasKey $.Values.secrets .valueFrom.secretKeyRef.name) }}
{{- fail (printf "containers.%s.env: secretKeyRef name %q not found in secrets map (add external: true for external resources)" $cName .valueFrom.secretKeyRef.name) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- if .configMapRef }}
{{- if not .configMapRef.external }}
{{- if not (hasKey $.Values.configMaps .configMapRef.name) }}
{{- fail (printf "containers.%s.env: configMapRef name %q not found in configMaps map (add external: true for external resources)" $cName .configMapRef.name) }}
{{- end }}
{{- end }}
{{- end }}

{{- if .secretRef }}
{{- if not .secretRef.external }}
{{- if not (hasKey $.Values.secrets .secretRef.name) }}
{{- fail (printf "containers.%s.env: secretRef name %q not found in secrets map (add external: true for external resources)" $cName .secretRef.name) }}
{{- end }}
{{- end }}
{{- end }}

{{- end }}
{{- end }}
{{- end }}

{{/*
Run all container validations.
*/}}
{{- define "chartpack.validation.containers" -}}
{{- include "chartpack.validation.containers.required" . }}
{{- include "chartpack.validation.containers.images" . }}
{{- include "chartpack.validation.containers.mounts" . }}
{{- include "chartpack.validation.containers.env" . }}
{{- end }}
