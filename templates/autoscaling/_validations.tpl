{{/*
Validate PDB cannot have both minAvailable and maxUnavailable.
*/}}
{{- define "chartpack.validation.autoscaling.pdb" -}}
{{- if .Values.pdb.enabled }}
{{- if and .Values.pdb.minAvailable .Values.pdb.maxUnavailable }}
{{- fail "pdb: cannot set both minAvailable and maxUnavailable" }}
{{- end }}
{{- if not (or .Values.pdb.minAvailable .Values.pdb.maxUnavailable) }}
{{- fail "pdb: must set either minAvailable or maxUnavailable" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Run all autoscaling validations.
*/}}
{{- define "chartpack.validation.autoscaling" -}}
{{- include "chartpack.validation.autoscaling.pdb" . }}
{{- end }}
