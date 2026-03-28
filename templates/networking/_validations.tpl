{{/*
Validate service port containerPort references exist in container ports.
*/}}
{{- define "chartpack.validation.networking.servicePorts" -}}
{{- $allContainerPorts := dict }}
{{- range $cName, $c := .Values.containers }}
{{- range $pName, $pCfg := $c.ports }}
{{- $_ := set $allContainerPorts $pName true }}
{{- end }}
{{- end }}

{{- range $svcName, $svc := .Values.services }}
{{- range $portName, $portCfg := $svc.ports }}
{{- $targetPort := default $portName $portCfg.containerPort }}
{{- if not (hasKey $allContainerPorts $targetPort) }}
{{- fail (printf "services.%s.ports.%s: containerPort %q not found in any container's ports map" $svcName $portName $targetPort) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate Gateway API routes have required fields and backendRefs reference existing services.
*/}}
{{- define "chartpack.validation.networking.routes" -}}
{{- range $name, $route := .Values.gatewayApi.routes }}
{{- if $route }}
{{- if not $route.parentRefs }}
{{- fail (printf "gatewayApi.routes.%s: parentRefs is required" $name) }}
{{- end }}
{{- if not $route.rules }}
{{- fail (printf "gatewayApi.routes.%s: rules is required" $name) }}
{{- end }}
{{- range $ruleIdx, $rule := $route.rules }}
{{- range $rule.backendRefs }}
{{- if not (hasKey $.Values.services .name) }}
{{- fail (printf "gatewayApi.routes.%s.rules[%d].backendRefs: service %q not found in services map" $name $ruleIdx .name) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Run all networking validations.
*/}}
{{- define "chartpack.validation.networking" -}}
{{- include "chartpack.validation.networking.servicePorts" . }}
{{- include "chartpack.validation.networking.routes" . }}
{{- include "chartpack.validation.networking.oauth2Proxy" . }}
{{- end }}
