{{/*
Return the oauth2 proxy service name for a given proxy key.
Usage: {{ include "chartpack.networking.oauth2Proxy.serviceName" (dict "key" "corporate" "context" $) }}
*/}}
{{- define "chartpack.networking.oauth2Proxy.serviceName" -}}
{{- printf "%s-oauth2-%s" (include "chartpack.fullname" .context) .key }}
{{- end }}

{{/*
Check if a given oauth2Proxies key is referenced by any ingress or route.
Usage: {{ include "chartpack.networking.oauth2Proxy.needed" (dict "key" "corporate" "context" $) }}
Returns "true" or "".
*/}}
{{- define "chartpack.networking.oauth2Proxy.needed" -}}
{{- $key := .key -}}
{{- $needed := false -}}
{{- range $name, $ing := .context.Values.networking.ingresses -}}
{{- if and $ing (eq (default "" $ing.oauth2Proxy) $key) -}}
{{- $needed = true -}}
{{- end -}}
{{- end -}}
{{- range $name, $route := .context.Values.networking.gatewayApi.routes -}}
{{- if and $route (eq (default "" $route.oauth2Proxy) $key) -}}
{{- $needed = true -}}
{{- end -}}
{{- end -}}
{{- if $needed -}}true{{- end -}}
{{- end }}

{{/*
Check if any referenced oauth2 proxy uses sidecar mode.
Usage: {{ include "chartpack.networking.oauth2Proxy.hasSidecars" . }}
Returns "true" or "".
*/}}
{{- define "chartpack.networking.oauth2Proxy.hasSidecars" -}}
{{- $found := false -}}
{{- range $name, $proxy := .Values.networking.oauth2Proxies -}}
{{- if and $proxy (eq (default "sidecar" $proxy.mode) "sidecar") -}}
{{- if include "chartpack.networking.oauth2Proxy.needed" (dict "key" $name "context" $) -}}
{{- $found = true -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $found -}}true{{- end -}}
{{- end }}

{{/*
Render the oauth2-proxy container spec (shared between deployment and sidecar modes).
Usage: {{ include "chartpack.networking.oauth2Proxy.containerSpec" (dict "proxy" $proxy "upstream" $upstream "port" $port "fullName" $fullName) }}
*/}}
{{- define "chartpack.networking.oauth2Proxy.containerSpec" -}}
{{- $proxy := .proxy -}}
{{- $port := .port -}}
{{- $upstream := .upstream -}}
{{- $fullName := .fullName -}}
image: "{{ default "quay.io/oauth2-proxy/oauth2-proxy" $proxy.image.repository }}:{{ default "v7.15.1" $proxy.image.tag }}"
imagePullPolicy: {{ default "IfNotPresent" $proxy.image.pullPolicy }}
args:
  - --http-address=0.0.0.0:{{ $port }}
  - --upstream={{ $upstream }}
  - --provider={{ default "oidc" $proxy.provider }}
  {{- with $proxy.issuerUrl }}
  - --oidc-issuer-url={{ . }}
  {{- end }}
  {{- range default (list "*") $proxy.emailDomains }}
  - --email-domain={{ . }}
  {{- end }}
  - --client-id=$(CLIENT_ID)
  - --client-secret=$(CLIENT_SECRET)
  - --cookie-secret=$(COOKIE_SECRET)
  {{- range $k, $v := $proxy.extraArgs }}
  - --{{ $k }}={{ $v }}
  {{- end }}
  {{- with $proxy.args }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
ports:
  - name: oauth2-{{ default "proxy" $proxy.portName }}
    containerPort: {{ $port }}
    protocol: TCP
{{- $envList := list -}}
{{- range $envName, $envCfg := $proxy.env -}}
{{- if $envCfg.value }}
{{- $envList = append $envList (dict "name" $envName "value" $envCfg.value) -}}
{{- else if $envCfg.valueFrom }}
{{- $vf := dict -}}
{{- if $envCfg.valueFrom.secretKeyRef }}
{{- $ref := $envCfg.valueFrom.secretKeyRef -}}
{{- $resolvedName := include "chartpack.resolveResourceName" (dict "name" $ref.name "fullName" $fullName "external" $ref.external) -}}
{{- $_ := set $vf "secretKeyRef" (dict "name" $resolvedName "key" $ref.key) -}}
{{- else if $envCfg.valueFrom.configMapKeyRef }}
{{- $ref := $envCfg.valueFrom.configMapKeyRef -}}
{{- $resolvedName := include "chartpack.resolveResourceName" (dict "name" $ref.name "fullName" $fullName "external" $ref.external) -}}
{{- $_ := set $vf "configMapKeyRef" (dict "name" $resolvedName "key" $ref.key) -}}
{{- end }}
{{- $envList = append $envList (dict "name" $envName "valueFrom" $vf) -}}
{{- end }}
{{- end -}}
{{- if $envList }}
env:
  {{- toYaml $envList | nindent 2 }}
{{- end }}
{{- with $proxy.resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $proxy.securityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
livenessProbe:
  httpGet:
    path: /ping
    port: oauth2-{{ default "proxy" $proxy.portName }}
  initialDelaySeconds: 5
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /ready
    port: oauth2-{{ default "proxy" $proxy.portName }}
  initialDelaySeconds: 3
  periodSeconds: 5
{{- end }}

{{/*
Render all sidecar oauth2-proxy init containers (native sidecars with restartPolicy: Always).
Called from _pod.tpl.
Usage: {{ include "chartpack.networking.oauth2Proxy.sidecars" . }}
*/}}
{{- define "chartpack.networking.oauth2Proxy.sidecars" -}}
{{- $fullName := include "chartpack.fullname" . -}}
{{- /* Derive first non-headless service port for sidecar upstream */ -}}
{{- $firstServicePort := "" -}}
{{- range $svcName, $svc := .Values.networking.services -}}
{{- if and $svc (not $svc.headless) (not $firstServicePort) -}}
{{- range $pName, $pCfg := $svc.ports -}}
{{- if not $firstServicePort -}}
{{- /* Resolve container port name to actual port number */ -}}
{{- $cpName := default $pName $pCfg.containerPort -}}
{{- range $cName, $c := $.Values.containers -}}
{{- range $cPortName, $cPortCfg := $c.ports -}}
{{- if and (eq $cPortName $cpName) (not $firstServicePort) -}}
{{- $firstServicePort = toString $cPortCfg.port -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $defaultSidecarUpstream := printf "http://localhost:%s" (default "8080" $firstServicePort) -}}
{{- range $name, $proxy := .Values.networking.oauth2Proxies -}}
{{- if and $proxy (eq (default "sidecar" $proxy.mode) "sidecar") -}}
{{- if include "chartpack.networking.oauth2Proxy.needed" (dict "key" $name "context" $) -}}
{{- $port := default 4180 $proxy.port }}
{{- $upstream := default $defaultSidecarUpstream $proxy.upstream }}
- name: oauth2-{{ $name }}
  restartPolicy: Always
  {{- include "chartpack.networking.oauth2Proxy.containerSpec" (dict "proxy" $proxy "upstream" $upstream "port" $port "fullName" $fullName) | nindent 2 }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end }}
