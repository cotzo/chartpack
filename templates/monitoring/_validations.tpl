{{/*
Validate monitor port references exist in service ports (service kind) or container ports (pod kind).
*/}}
{{- define "chartpack.validation.monitoring.ports" -}}
{{- $allContainerPorts := dict }}
{{- range $cName, $c := .Values.containers }}
{{- range $pName, $pCfg := $c.ports }}
{{- $_ := set $allContainerPorts $pName true }}
{{- end }}
{{- end }}

{{- $allServicePorts := dict }}
{{- range $svcName, $svc := .Values.services }}
{{- range $portName, $portCfg := $svc.ports }}
{{- $_ := set $allServicePorts $portName true }}
{{- end }}
{{- end }}

{{- range $name, $mon := .Values.monitors }}
{{- if and $mon $mon.port (not $mon.endpoints) }}
{{- $kind := default "service" $mon.kind }}
{{- if eq $kind "service" }}
{{- if not (hasKey $allServicePorts $mon.port) }}
{{- fail (printf "monitors.%s: port %q not found in any service's ports map" $name $mon.port) }}
{{- end }}
{{- else if eq $kind "pod" }}
{{- if not (hasKey $allContainerPorts $mon.port) }}
{{- fail (printf "monitors.%s: port %q not found in any container's ports map" $name $mon.port) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Run all monitoring validations.
*/}}
{{- define "chartpack.validation.monitoring" -}}
{{- include "chartpack.validation.monitoring.ports" . }}
{{- end }}
