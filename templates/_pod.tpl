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
  {{- /* Each entry: (fieldName, defaultLabelKey, infraSettingsKey) */ -}}
  {{- range $entry := list
    (list "os"        "kubernetes.io/os"                 "os")
    (list "arch"      "kubernetes.io/arch"               "arch")
    (list "regions"   "topology.kubernetes.io/region"    "topologyRegion")
    (list "zones"     "topology.kubernetes.io/zone"      "topologyZone")
    (list "racks"     "topology.kubernetes.io/rack"      "topologyRack")
    (list "nodeTypes" "node.kubernetes.io/instance-type" "nodeType")
    (list "nodePools" "node.cluster.x-k8s.io/node-pool" "nodePool")
  }}
  {{- $raw := index $.Values.nodeTargeting (index $entry 0) }}
  {{- $vals := list }}
  {{- $enforcement := "soft" }}
  {{- if kindIs "slice" $raw }}
    {{- $vals = $raw }}
  {{- else }}
    {{- $obj := default (dict) $raw }}
    {{- $vals = default (list) $obj.values }}
    {{- $enforcement = default "soft" $obj.enforcement }}
  {{- end }}
  {{- if $vals }}
  {{- $expr := dict "key" (default (index $entry 1) (index $nl (index $entry 2))) "operator" "In" "values" $vals }}
  {{- if eq $enforcement "hard" }}{{ $hardNodeAffinityExpressions = append $hardNodeAffinityExpressions $expr }}{{ else }}{{ $softNodeAffinityExpressions = append $softNodeAffinityExpressions $expr }}{{ end }}
  {{- end }}
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
