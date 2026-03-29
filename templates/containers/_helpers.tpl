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
  {{- /* Build K8s env list from map entries with value/valueFrom (key = env var name) */ -}}
  {{- $envList := list -}}
  {{- $envFrom := list -}}
  {{- range $envName, $envCfg := $config.env -}}
  {{- if or (hasKey $envCfg "value") $envCfg.valueFrom -}}
  {{- /* Individual env var — key is the env var name */ -}}
  {{- if hasKey $envCfg "value" }}
  {{- $envList = append $envList (dict "name" $envName "value" ($envCfg.value | toString)) -}}
  {{- else if $envCfg.valueFrom }}
  {{- $vf := dict -}}
  {{- if $envCfg.valueFrom.fieldRef }}
  {{- $_ := set $vf "fieldRef" $envCfg.valueFrom.fieldRef -}}
  {{- else if $envCfg.valueFrom.resourceFieldRef }}
  {{- $_ := set $vf "resourceFieldRef" $envCfg.valueFrom.resourceFieldRef -}}
  {{- else if $envCfg.valueFrom.configMapKeyRef }}
  {{- $ref := $envCfg.valueFrom.configMapKeyRef -}}
  {{- $resolvedName := include "chartpack.resolveResourceName" (dict "name" $ref.name "fullName" $fullName "external" $ref.external) -}}
  {{- $_ := set $vf "configMapKeyRef" (dict "name" $resolvedName "key" $ref.key) -}}
  {{- else if $envCfg.valueFrom.secretKeyRef }}
  {{- $ref := $envCfg.valueFrom.secretKeyRef -}}
  {{- $resolvedName := include "chartpack.resolveResourceName" (dict "name" $ref.name "fullName" $fullName "external" $ref.external) -}}
  {{- $_ := set $vf "secretKeyRef" (dict "name" $resolvedName "key" $ref.key) -}}
  {{- end }}
  {{- $envList = append $envList (dict "name" $envName "valueFrom" $vf) -}}
  {{- end }}
  {{- else if $envCfg.configMapRef -}}
  {{- /* Bulk envFrom — configMapRef */ -}}
  {{- $ref := $envCfg.configMapRef -}}
  {{- $resolvedName := include "chartpack.resolveResourceName" (dict "name" $ref.name "fullName" $fullName "external" $ref.external) -}}
  {{- $entry := dict "configMapRef" (dict "name" $resolvedName) -}}
  {{- if $ref.optional }}{{ $_ := set (index $entry "configMapRef") "optional" $ref.optional }}{{ end -}}
  {{- $envFrom = append $envFrom $entry -}}
  {{- else if $envCfg.secretRef -}}
  {{- /* Bulk envFrom — secretRef */ -}}
  {{- $ref := $envCfg.secretRef -}}
  {{- $resolvedName := include "chartpack.resolveResourceName" (dict "name" $ref.name "fullName" $fullName "external" $ref.external) -}}
  {{- $entry := dict "secretRef" (dict "name" $resolvedName) -}}
  {{- if $ref.optional }}{{ $_ := set (index $entry "secretRef") "optional" $ref.optional }}{{ end -}}
  {{- $envFrom = append $envFrom $entry -}}
  {{- end -}}
  {{- end -}}
  {{- if $envList }}
  env:
    {{- toYaml $envList | nindent 4 }}
  {{- end }}
  {{- if $envFrom }}
  envFrom:
    {{- toYaml $envFrom | nindent 4 }}
  {{- end }}
  {{- with $config.restartPolicy }}
  restartPolicy: {{ . }}
  {{- end }}
  {{- with $config.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $config.resizePolicy }}
  resizePolicy:
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
  {{- /* Auto-mount certificate volumes */ -}}
  {{- range $certName, $cert := $ctx.Values.networking.certificates -}}
  {{- if and $cert $cert.mount -}}
  {{- $volumeMounts = append $volumeMounts (dict "name" (printf "cert-%s" $certName) "mountPath" $cert.mount.path "readOnly" true) -}}
  {{- end -}}
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
