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
{{- $incompatible := list "CronJob" "Job" }}
{{- if has .Values.workloadType $incompatible }}
{{- fail (printf "pdb: not applicable to workloadType %s" .Values.workloadType) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate HPA is only enabled for compatible workload types.
*/}}
{{- define "chartpack.validation.autoscaling.hpa" -}}
{{- if .Values.autoscaling.enabled }}
{{- $compatible := list "Deployment" "StatefulSet" }}
{{- if not (has .Values.workloadType $compatible) }}
{{- fail (printf "autoscaling: not applicable to workloadType %s (only Deployment, StatefulSet)" .Values.workloadType) }}
{{- end }}
{{- if and .Values.autoscaling.minReplicas .Values.autoscaling.maxReplicas }}
{{- if gt (int .Values.autoscaling.minReplicas) (int .Values.autoscaling.maxReplicas) }}
{{- fail (printf "autoscaling: minReplicas (%d) must be <= maxReplicas (%d)" (int .Values.autoscaling.minReplicas) (int .Values.autoscaling.maxReplicas)) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Run all autoscaling validations.
*/}}
{{- define "chartpack.validation.autoscaling" -}}
{{- include "chartpack.validation.autoscaling.pdb" . }}
{{- include "chartpack.validation.autoscaling.hpa" . }}
{{- end }}
