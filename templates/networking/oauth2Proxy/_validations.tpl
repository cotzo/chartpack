{{/*
Validate oauth2Proxy references on ingresses and routes exist in oauth2Proxies map.
*/}}
{{- define "chartpack.validation.networking.oauth2Proxy.references" -}}
{{- range $name, $ing := .Values.networking.ingresses }}
{{- if and $ing $ing.oauth2Proxy }}
{{- if not (hasKey $.Values.networking.oauth2Proxies $ing.oauth2Proxy) }}
{{- fail (printf "ingresses.%s.oauth2Proxy: %q not found in oauth2Proxies map" $name $ing.oauth2Proxy) }}
{{- end }}
{{- end }}
{{- end }}
{{- range $name, $route := .Values.networking.gatewayApi.routes }}
{{- if and $route $route.oauth2Proxy }}
{{- if not (hasKey $.Values.networking.oauth2Proxies $route.oauth2Proxy) }}
{{- fail (printf "gatewayApi.routes.%s.oauth2Proxy: %q not found in oauth2Proxies map" $name $route.oauth2Proxy) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate deployment-mode proxies have explicit upstream.
*/}}
{{- define "chartpack.validation.networking.oauth2Proxy.upstream" -}}
{{- range $name, $proxy := .Values.networking.oauth2Proxies }}
{{- if and $proxy (eq (default "sidecar" $proxy.mode) "deployment") }}
{{- if not $proxy.upstream }}
{{- fail (printf "oauth2Proxies.%s: upstream is required when mode is deployment (e.g., upstream: http://<fullname>-<service>:<port>)" $name) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Run all oauth2 proxy validations.
*/}}
{{- define "chartpack.validation.networking.oauth2Proxy" -}}
{{- include "chartpack.validation.networking.oauth2Proxy.references" . }}
{{- include "chartpack.validation.networking.oauth2Proxy.upstream" . }}
{{- end }}
