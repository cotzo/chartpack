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
{{- if not (hasKey $.Values.config.configMaps .configMap) }}
{{- fail (printf "containers.%s.mounts: configMap %q not found in configMaps map" $cName .configMap) }}
{{- end }}
{{- end }}
{{- end }}

{{- if .secret }}
{{- if not .external }}
{{- if not (hasKey $.Values.config.secrets .secret) }}
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
{{- range $envName, $envCfg := $c.env }}

{{- if $envCfg.valueFrom }}
{{- if $envCfg.valueFrom.configMapKeyRef }}
{{- if not $envCfg.valueFrom.configMapKeyRef.external }}
{{- if not (hasKey $.Values.config.configMaps $envCfg.valueFrom.configMapKeyRef.name) }}
{{- fail (printf "containers.%s.env.%s: configMapKeyRef name %q not found in configMaps map (add external: true for external resources)" $cName $envName $envCfg.valueFrom.configMapKeyRef.name) }}
{{- end }}
{{- end }}
{{- end }}
{{- if $envCfg.valueFrom.secretKeyRef }}
{{- if not $envCfg.valueFrom.secretKeyRef.external }}
{{- if not (hasKey $.Values.config.secrets $envCfg.valueFrom.secretKeyRef.name) }}
{{- fail (printf "containers.%s.env.%s: secretKeyRef name %q not found in secrets map (add external: true for external resources)" $cName $envName $envCfg.valueFrom.secretKeyRef.name) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- if $envCfg.configMapRef }}
{{- if not $envCfg.configMapRef.external }}
{{- if not (hasKey $.Values.config.configMaps $envCfg.configMapRef.name) }}
{{- fail (printf "containers.%s.env.%s: configMapRef name %q not found in configMaps map (add external: true for external resources)" $cName $envName $envCfg.configMapRef.name) }}
{{- end }}
{{- end }}
{{- end }}

{{- if $envCfg.secretRef }}
{{- if not $envCfg.secretRef.external }}
{{- if not (hasKey $.Values.config.secrets $envCfg.secretRef.name) }}
{{- fail (printf "containers.%s.env.%s: secretRef name %q not found in secrets map (add external: true for external resources)" $cName $envName $envCfg.secretRef.name) }}
{{- end }}
{{- end }}
{{- end }}

{{- end }}
{{- end }}
{{- end }}

{{/*
Validate restartPolicy is only set on initContainers, not containers.
*/}}
{{- define "chartpack.validation.containers.restartPolicy" -}}
{{- range $name, $c := .Values.containers }}
{{- if $c.restartPolicy }}
{{- fail (printf "containers.%s.restartPolicy: restartPolicy is only valid on initContainers (native sidecars), not containers" $name) }}
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
{{- include "chartpack.validation.containers.restartPolicy" . }}
{{- end }}
