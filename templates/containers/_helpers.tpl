{{/*
Render a single container from the standardized container spec.
Usage: {{ include "chartpack.containers.renderContainer" (dict "name" "app" "config" $containerConfig "context" $) }}
*/}}
{{- define "chartpack.containers.renderContainer" -}}
{{- $name := .name -}}
{{- $config := .config -}}
{{- $ctx := .context -}}
{{- $fullName := include "chartpack.fullname" $ctx -}}
- name: {{ $name }}
  image: "{{ $config.image.repository }}:{{ $config.image.tag | default $ctx.Chart.AppVersion }}"
  imagePullPolicy: {{ default "IfNotPresent" $config.image.pullPolicy }}
  {{- with $config.command }}
  command:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $config.args }}
  args:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if $config.ports }}
  ports:
    {{- range $portName, $portCfg := $config.ports }}
    - name: {{ $portName }}
      containerPort: {{ $portCfg.port }}
      protocol: {{ default "TCP" $portCfg.protocol }}
    {{- end }}
  {{- end }}
  {{- /* Build K8s env list from entries that have a name field */ -}}
  {{- $envList := list -}}
  {{- range $config.env -}}
  {{- if .name -}}
  {{- if .value }}
  {{- $envList = append $envList (dict "name" .name "value" .value) -}}
  {{- else if .valueFrom }}
  {{- $vf := dict -}}
  {{- if .valueFrom.fieldRef }}
  {{- $_ := set $vf "fieldRef" .valueFrom.fieldRef -}}
  {{- else if .valueFrom.resourceFieldRef }}
  {{- $_ := set $vf "resourceFieldRef" .valueFrom.resourceFieldRef -}}
  {{- else if .valueFrom.configMapKeyRef }}
  {{- $ref := .valueFrom.configMapKeyRef -}}
  {{- $resolvedName := $ref.name -}}
  {{- if not $ref.external }}
  {{- $resolvedName = printf "%s-%s" $fullName $ref.name -}}
  {{- end }}
  {{- $_ := set $vf "configMapKeyRef" (dict "name" $resolvedName "key" $ref.key) -}}
  {{- else if .valueFrom.secretKeyRef }}
  {{- $ref := .valueFrom.secretKeyRef -}}
  {{- $resolvedName := $ref.name -}}
  {{- if not $ref.external }}
  {{- $resolvedName = printf "%s-%s" $fullName $ref.name -}}
  {{- end }}
  {{- $_ := set $vf "secretKeyRef" (dict "name" $resolvedName "key" $ref.key) -}}
  {{- end }}
  {{- $envList = append $envList (dict "name" .name "valueFrom" $vf) -}}
  {{- end }}
  {{- end -}}
  {{- end -}}
  {{- if $envList }}
  env:
    {{- toYaml $envList | nindent 4 }}
  {{- end }}
  {{- /* Build K8s envFrom list from entries without a name field */ -}}
  {{- $envFrom := list -}}
  {{- range $config.env -}}
  {{- if not .name -}}
  {{- if .configMapRef }}
  {{- $ref := .configMapRef -}}
  {{- $resolvedName := $ref.name -}}
  {{- if not $ref.external }}
  {{- $resolvedName = printf "%s-%s" $fullName $ref.name -}}
  {{- end }}
  {{- $entry := dict "configMapRef" (dict "name" $resolvedName) -}}
  {{- if $ref.optional }}{{ $_ := set (index $entry "configMapRef") "optional" $ref.optional }}{{ end -}}
  {{- $envFrom = append $envFrom $entry -}}
  {{- else if .secretRef }}
  {{- $ref := .secretRef -}}
  {{- $resolvedName := $ref.name -}}
  {{- if not $ref.external }}
  {{- $resolvedName = printf "%s-%s" $fullName $ref.name -}}
  {{- end }}
  {{- $entry := dict "secretRef" (dict "name" $resolvedName) -}}
  {{- if $ref.optional }}{{ $_ := set (index $entry "secretRef") "optional" $ref.optional }}{{ end -}}
  {{- $envFrom = append $envFrom $entry -}}
  {{- end -}}
  {{- end -}}
  {{- end -}}
  {{- if $envFrom }}
  envFrom:
    {{- toYaml $envFrom | nindent 4 }}
  {{- end }}
  {{- with $config.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- /* Build volumeMounts from unified mounts list */ -}}
  {{- $volumeMounts := list -}}
  {{- range $config.mounts -}}
  {{- $mount := dict "mountPath" .path -}}
  {{- if .readOnly }}{{ $_ := set $mount "readOnly" true }}{{ end -}}
  {{- if .subPath }}{{ $_ := set $mount "subPath" .subPath }}{{ end -}}
  {{- if .configMap -}}
  {{- $volName := printf "configmap-%s" .configMap -}}
  {{- if .external }}{{ $volName = printf "configmap-ext-%s" .configMap }}{{ end -}}
  {{- $_ := set $mount "name" $volName -}}
  {{- else if .secret -}}
  {{- $volName := printf "secret-%s" .secret -}}
  {{- if .external }}{{ $volName = printf "secret-ext-%s" .secret }}{{ end -}}
  {{- $_ := set $mount "name" $volName -}}
  {{- else if .persistence -}}
  {{- $_ := set $mount "name" (printf "persistence-%s" .persistence) -}}
  {{- else if .volume -}}
  {{- $_ := set $mount "name" .volume -}}
  {{- end -}}
  {{- $volumeMounts = append $volumeMounts $mount -}}
  {{- end -}}
  {{- if $volumeMounts }}
  volumeMounts:
    {{- toYaml $volumeMounts | nindent 4 }}
  {{- end }}
  {{- with $config.healthChecks }}
  {{- with .liveness }}
  livenessProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .readiness }}
  readinessProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .startup }}
  startupProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}
  {{- with $config.lifecycle }}
  lifecycle:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $config.securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $config.workingDir }}
  workingDir: {{ . }}
  {{- end }}
{{- end }}
