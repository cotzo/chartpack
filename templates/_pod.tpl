{{/*
Shared pod template spec used by all workload types.
Usage: {{ include "universal-helm.podTemplate" . }}
*/}}
{{- define "universal-helm.podTemplate" -}}
metadata:
  labels:
    {{- include "universal-helm.selectorLabels" . | nindent 4 }}
    {{- with .Values.podSettings.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "universal-helm.checksumAnnotations" . | nindent 4 }}
    {{- with .Values.podSettings.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- with .Values.podSettings.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  serviceAccountName: {{ include "universal-helm.serviceAccountName" . }}
  {{- with .Values.podSettings.securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if .Values.initContainers }}
  initContainers:
    {{- range $name, $config := .Values.initContainers }}
    {{- include "universal-helm.renderContainer" (dict "name" $name "config" $config "context" $) | nindent 4 }}
    {{- end }}
  {{- end }}
  containers:
    {{- range $name, $config := .Values.containers }}
    {{- include "universal-helm.renderContainer" (dict "name" $name "config" $config "context" $) | nindent 4 }}
    {{- end }}
  {{- $volumes := include "universal-helm.volumes" . }}
  {{- if $volumes }}
  volumes:
    {{- $volumes | nindent 4 }}
  {{- end }}
  {{- with .Values.podSettings.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.podSettings.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.podSettings.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.podSettings.topologySpreadConstraints }}
  topologySpreadConstraints:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.podSettings.priorityClassName }}
  priorityClassName: {{ . }}
  {{- end }}
  {{- with .Values.podSettings.terminationGracePeriodSeconds }}
  terminationGracePeriodSeconds: {{ . }}
  {{- end }}
  {{- with .Values.podSettings.dnsPolicy }}
  dnsPolicy: {{ . }}
  {{- end }}
  {{- with .Values.podSettings.dnsConfig }}
  dnsConfig:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if .Values.podSettings.hostNetwork }}
  hostNetwork: true
  {{- end }}
  {{- if or (eq .Values.workloadType "Job") (eq .Values.workloadType "CronJob") }}
  restartPolicy: {{ default "OnFailure" .Values.podSettings.restartPolicy }}
  {{- else if .Values.podSettings.restartPolicy }}
  restartPolicy: {{ .Values.podSettings.restartPolicy }}
  {{- end }}
{{- end }}
