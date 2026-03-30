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
  {{- /* Build nodeAffinity expressions from nodeTargeting, split by enforcement */ -}}
  {{- $nl := default (dict) (default (dict) .Values.infraSettings).nodeLabels }}
  {{- $hardNodeAffinityExpressions := list }}
  {{- $softNodeAffinityExpressions := list }}
  {{- $osObj := default (dict) .Values.nodeTargeting.os }}
  {{- if $osObj.values }}
  {{- $expr := dict "key" (default "kubernetes.io/os" $nl.os) "operator" "In" "values" $osObj.values }}
  {{- if eq (default "soft" $osObj.enforcement) "hard" }}{{ $hardNodeAffinityExpressions = append $hardNodeAffinityExpressions $expr }}{{ else }}{{ $softNodeAffinityExpressions = append $softNodeAffinityExpressions $expr }}{{ end }}
  {{- end }}
  {{- $archObj := default (dict) .Values.nodeTargeting.arch }}
  {{- if $archObj.values }}
  {{- $expr := dict "key" (default "kubernetes.io/arch" $nl.arch) "operator" "In" "values" $archObj.values }}
  {{- if eq (default "soft" $archObj.enforcement) "hard" }}{{ $hardNodeAffinityExpressions = append $hardNodeAffinityExpressions $expr }}{{ else }}{{ $softNodeAffinityExpressions = append $softNodeAffinityExpressions $expr }}{{ end }}
  {{- end }}
  {{- $regionsObj := default (dict) .Values.nodeTargeting.regions }}
  {{- if $regionsObj.values }}
  {{- $expr := dict "key" (default "topology.kubernetes.io/region" $nl.topologyRegion) "operator" "In" "values" $regionsObj.values }}
  {{- if eq (default "soft" $regionsObj.enforcement) "hard" }}{{ $hardNodeAffinityExpressions = append $hardNodeAffinityExpressions $expr }}{{ else }}{{ $softNodeAffinityExpressions = append $softNodeAffinityExpressions $expr }}{{ end }}
  {{- end }}
  {{- $zonesObj := default (dict) .Values.nodeTargeting.zones }}
  {{- if $zonesObj.values }}
  {{- $expr := dict "key" (default "topology.kubernetes.io/zone" $nl.topologyZone) "operator" "In" "values" $zonesObj.values }}
  {{- if eq (default "soft" $zonesObj.enforcement) "hard" }}{{ $hardNodeAffinityExpressions = append $hardNodeAffinityExpressions $expr }}{{ else }}{{ $softNodeAffinityExpressions = append $softNodeAffinityExpressions $expr }}{{ end }}
  {{- end }}
  {{- $nodeTypesObj := default (dict) .Values.nodeTargeting.nodeTypes }}
  {{- if $nodeTypesObj.values }}
  {{- $expr := dict "key" (default "node.kubernetes.io/instance-type" $nl.nodeType) "operator" "In" "values" $nodeTypesObj.values }}
  {{- if eq (default "soft" $nodeTypesObj.enforcement) "hard" }}{{ $hardNodeAffinityExpressions = append $hardNodeAffinityExpressions $expr }}{{ else }}{{ $softNodeAffinityExpressions = append $softNodeAffinityExpressions $expr }}{{ end }}
  {{- end }}
  {{- $nodePoolsObj := default (dict) .Values.nodeTargeting.nodePools }}
  {{- if $nodePoolsObj.values }}
  {{- $expr := dict "key" (default "node.cluster.x-k8s.io/node-pool" $nl.nodePool) "operator" "In" "values" $nodePoolsObj.values }}
  {{- if eq (default "soft" $nodePoolsObj.enforcement) "hard" }}{{ $hardNodeAffinityExpressions = append $hardNodeAffinityExpressions $expr }}{{ else }}{{ $softNodeAffinityExpressions = append $softNodeAffinityExpressions $expr }}{{ end }}
  {{- end }}
  {{- $r := default (dict) (default (dict) .Values.nodeTargeting).restrictions }}
  {{- $rType := default "differentNodes" $r.type }}
  {{- $rEnforcement := default "soft" $r.enforcement }}
  {{- $rSchedulingKey := "preferredDuringSchedulingIgnoredDuringExecution" }}
  {{- if eq $rEnforcement "hard" }}{{ $rSchedulingKey = "requiredDuringSchedulingIgnoredDuringExecution" }}{{ end }}
  {{- if or .Values.podSettings.affinity $hardNodeAffinityExpressions $softNodeAffinityExpressions (ne $rType "none") }}
  affinity:
    {{- if or .Values.podSettings.affinity.podAffinity (eq $rType "sameNode") }}
    podAffinity:
      {{- with .Values.podSettings.affinity.podAffinity }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
      {{- if eq $rType "sameNode" }}
      {{- if eq $rEnforcement "hard" }}
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              {{- include "chartpack.selectorLabels" . | nindent 14 }}
          topologyKey: kubernetes.io/hostname
      {{- else }}
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                {{- include "chartpack.selectorLabels" . | nindent 16 }}
            topologyKey: kubernetes.io/hostname
      {{- end }}
      {{- end }}
    {{- end }}
    {{- if or .Values.podSettings.affinity.podAntiAffinity (eq $rType "differentNodes") }}
    podAntiAffinity:
      {{- with .Values.podSettings.affinity.podAntiAffinity }}
      {{- toYaml . | nindent 6 }}
      {{- end }}
      {{- if eq $rType "differentNodes" }}
      {{- if eq $rEnforcement "hard" }}
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              {{- include "chartpack.selectorLabels" . | nindent 14 }}
          topologyKey: kubernetes.io/hostname
      {{- else }}
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            labelSelector:
              matchLabels:
                {{- include "chartpack.selectorLabels" . | nindent 16 }}
            topologyKey: kubernetes.io/hostname
      {{- end }}
      {{- end }}
    {{- end }}
    {{- if or $hardNodeAffinityExpressions $softNodeAffinityExpressions .Values.podSettings.affinity.nodeAffinity }}
    nodeAffinity:
      {{- if or $hardNodeAffinityExpressions (and .Values.podSettings.affinity.nodeAffinity .Values.podSettings.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution) }}
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          {{- if and .Values.podSettings.affinity.nodeAffinity .Values.podSettings.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution }}
          {{- range .Values.podSettings.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms }}
          - matchExpressions:
              {{- $allExpressions := concat (default (list) .matchExpressions) $hardNodeAffinityExpressions }}
              {{- toYaml $allExpressions | nindent 14 }}
          {{- end }}
          {{- else if $hardNodeAffinityExpressions }}
          - matchExpressions:
              {{- toYaml $hardNodeAffinityExpressions | nindent 14 }}
          {{- end }}
      {{- end }}
      {{- if or $softNodeAffinityExpressions (and .Values.podSettings.affinity.nodeAffinity .Values.podSettings.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution) }}
      preferredDuringSchedulingIgnoredDuringExecution:
        {{- if $softNodeAffinityExpressions }}
        - weight: 100
          preference:
            matchExpressions:
              {{- toYaml $softNodeAffinityExpressions | nindent 14 }}
        {{- end }}
        {{- with .Values.podSettings.affinity.nodeAffinity }}
        {{- with .preferredDuringSchedulingIgnoredDuringExecution }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
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
    {{- $nlTsc := default (dict) (default (dict) $.Values.infraSettings).nodeLabels -}}
    {{- $infraLabel := index $nlTsc $tsc.topologyKey -}}
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
