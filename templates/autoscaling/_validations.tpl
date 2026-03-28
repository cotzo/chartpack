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
{{- if .Values.autoscaling.hpa.enabled }}
{{- $compatible := list "Deployment" "StatefulSet" "Rollout" }}
{{- if not (has .Values.workloadType $compatible) }}
{{- fail (printf "autoscaling: not applicable to workloadType %s (only Deployment, StatefulSet, Rollout)" .Values.workloadType) }}
{{- end }}
{{- if and .Values.autoscaling.hpa.minReplicas .Values.autoscaling.hpa.maxReplicas }}
{{- if gt (int .Values.autoscaling.hpa.minReplicas) (int .Values.autoscaling.hpa.maxReplicas) }}
{{- fail (printf "autoscaling: minReplicas (%d) must be <= maxReplicas (%d)" (int .Values.autoscaling.hpa.minReplicas) (int .Values.autoscaling.hpa.maxReplicas)) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate KEDA is only enabled for compatible workload types and not with HPA.
*/}}
{{- define "chartpack.validation.autoscaling.keda" -}}
{{- if .Values.autoscaling.keda.enabled }}
{{- if .Values.autoscaling.hpa.enabled }}
{{- fail "keda: cannot enable both keda and autoscaling (HPA) — they would conflict" }}
{{- end }}
{{- $compatible := list "Deployment" "StatefulSet" "Rollout" "Job" }}
{{- if not (has .Values.workloadType $compatible) }}
{{- fail (printf "keda: not applicable to workloadType %s (only Deployment, StatefulSet, Rollout, Job)" .Values.workloadType) }}
{{- end }}
{{- if not .Values.autoscaling.keda.triggers }}
{{- fail "keda: triggers are required when keda is enabled" }}
{{- end }}
{{- if and .Values.autoscaling.keda.minReplicaCount .Values.autoscaling.keda.maxReplicaCount }}
{{- if gt (int .Values.autoscaling.keda.minReplicaCount) (int .Values.autoscaling.keda.maxReplicaCount) }}
{{- fail (printf "keda: minReplicaCount (%d) must be <= maxReplicaCount (%d)" (int .Values.autoscaling.keda.minReplicaCount) (int .Values.autoscaling.keda.maxReplicaCount)) }}
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
{{- include "chartpack.validation.autoscaling.keda" . }}
{{- end }}
