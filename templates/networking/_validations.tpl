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
Run all networking validations.
*/}}
{{- define "chartpack.validation.networking" -}}
{{- include "chartpack.validation.networking.servicePorts" . }}
{{- end }}
