{{/*
Common job spec fields shared by Job, CronJob jobTemplate, and ScaledJob jobTargetRef.
Usage: {{ include "chartpack.workloads.jobSpec" . }}
*/}}
{{- define "chartpack.workloads.jobSpec" -}}
{{- with .Values.workloads.job.backoffLimit }}
backoffLimit: {{ . }}
{{- end }}
{{- with .Values.workloads.job.activeDeadlineSeconds }}
activeDeadlineSeconds: {{ . }}
{{- end }}
{{- with .Values.workloads.job.ttlSecondsAfterFinished }}
ttlSecondsAfterFinished: {{ . }}
{{- end }}
{{- with .Values.workloads.job.completions }}
completions: {{ . }}
{{- end }}
{{- with .Values.workloads.job.parallelism }}
parallelism: {{ . }}
{{- end }}
{{- with .Values.workloads.job.completionMode }}
completionMode: {{ . }}
{{- end }}
{{- with .Values.workloads.job.podReplacementPolicy }}
podReplacementPolicy: {{ . }}
{{- end }}
{{- end }}
