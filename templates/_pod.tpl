{{/*
Shared pod template spec used by all workload types.
Usage: {{ include "chartpack.podTemplate" . }}
*/}}
{{- define "chartpack.podTemplate" -}}
metadata:
  labels:
    {{- include "chartpack.selectorLabels" . | nindent 4 }}
    {{- with .Values.podSettings.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- $checksumAnnotations := include "chartpack.persistence.checksumAnnotations" . }}
  {{- if or $checksumAnnotations .Values.podSettings.annotations }}
  annotations:
    {{- $checksumAnnotations | nindent 4 }}
    {{- with .Values.podSettings.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
spec:
  {{- with .Values.podSettings.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  serviceAccountName: {{ include "chartpack.rbac.serviceAccountName" . }}
  {{- with .Values.podSettings.securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- $oauth2Sidecars := include "chartpack.networking.oauth2Proxy.sidecars" . -}}
  {{- if or .Values.initContainers $oauth2Sidecars }}
  initContainers:
    {{- range $name, $config := .Values.initContainers }}
    {{- include "chartpack.containers.renderContainer" (dict "name" $name "config" $config "context" $) | nindent 4 }}
    {{- end }}
    {{- if $oauth2Sidecars }}
    {{- $oauth2Sidecars | nindent 4 }}
    {{- end }}
  {{- end }}
  containers:
    {{- range $name, $config := .Values.containers }}
    {{- include "chartpack.containers.renderContainer" (dict "name" $name "config" $config "context" $) | nindent 4 }}
    {{- end }}
  {{- $volumes := include "chartpack.persistence.volumes" . }}
  {{- if $volumes }}
  volumes:
    {{- $volumes | nindent 4 }}
  {{- end }}
  {{- with .Values.podSettings.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- /* Build nodeAffinity expressions from nodeTargeting */ -}}
  {{- $nodeAffinityExpressions := list }}
  {{- if .Values.nodeTargeting.os }}
  {{- $nodeAffinityExpressions = append $nodeAffinityExpressions (dict "key" .Values.infraSettings.nodeLabels.os "operator" "In" "values" .Values.nodeTargeting.os) }}
  {{- end }}
  {{- if .Values.nodeTargeting.arch }}
  {{- $nodeAffinityExpressions = append $nodeAffinityExpressions (dict "key" .Values.infraSettings.nodeLabels.arch "operator" "In" "values" .Values.nodeTargeting.arch) }}
  {{- end }}
  {{- if or .Values.podSettings.affinity $nodeAffinityExpressions }}
  affinity:
    {{- with .Values.podSettings.affinity.podAffinity }}
    podAffinity:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.podSettings.affinity.podAntiAffinity }}
    podAntiAffinity:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- if or $nodeAffinityExpressions .Values.podSettings.affinity.nodeAffinity }}
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          {{- if and .Values.podSettings.affinity.nodeAffinity .Values.podSettings.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution }}
          {{- range .Values.podSettings.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms }}
          - matchExpressions:
              {{- $allExpressions := concat (default (list) .matchExpressions) $nodeAffinityExpressions }}
              {{- toYaml $allExpressions | nindent 14 }}
          {{- end }}
          {{- else if $nodeAffinityExpressions }}
          - matchExpressions:
              {{- toYaml $nodeAffinityExpressions | nindent 14 }}
          {{- end }}
      {{- with .Values.podSettings.affinity.nodeAffinity }}
      {{- with .preferredDuringSchedulingIgnoredDuringExecution }}
      preferredDuringSchedulingIgnoredDuringExecution:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- with .Values.podSettings.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- if .Values.podSettings.topologySpreadConstraints }}
  topologySpreadConstraints:
    {{- range $name, $tsc := .Values.podSettings.topologySpreadConstraints }}
    {{- if $tsc }}
    {{- $topologyKey := $tsc.topologyKey -}}
    {{- $infraLabel := index $.Values.infraSettings.nodeLabels $tsc.topologyKey -}}
    {{- if $infraLabel }}{{ $topologyKey = $infraLabel }}{{ end }}
    - maxSkew: {{ default 1 $tsc.maxSkew }}
      topologyKey: {{ $topologyKey }}
      whenUnsatisfiable: {{ default "DoNotSchedule" $tsc.whenUnsatisfiable }}
      {{- if $tsc.labelSelector }}
      labelSelector:
        {{- toYaml $tsc.labelSelector | nindent 8 }}
      {{- else }}
      labelSelector:
        matchLabels:
          {{- include "chartpack.selectorLabels" $ | nindent 10 }}
      {{- end }}
      {{- with $tsc.matchLabelKeys }}
      matchLabelKeys:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $tsc.minDomains }}
      minDomains: {{ . }}
      {{- end }}
      {{- with $tsc.nodeAffinityPolicy }}
      nodeAffinityPolicy: {{ . }}
      {{- end }}
      {{- with $tsc.nodeTaintsPolicy }}
      nodeTaintsPolicy: {{ . }}
      {{- end }}
    {{- end }}
    {{- end }}
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
