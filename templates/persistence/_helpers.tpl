{{/*
Build the complete pod-level volumes list.
Collects volumes from podSettings.volumes, container mounts (configMap/secret/persistence),
and init container mounts. Deduplicates by volume name.
*/}}
{{- define "chartpack.persistence.volumes" -}}
{{- $volumes := list }}
{{- $seen := dict }}
{{- $fullName := include "chartpack.fullname" . }}

{{- /* Explicit volumes from podSettings */ -}}
{{- range .Values.podSettings.volumes }}
{{- $volumes = append $volumes . }}
{{- $_ := set $seen .name true }}
{{- end }}

{{- /* Collect mounts from all containers + initContainers */ -}}
{{- $allContainers := dict }}
{{- range $k, $v := .Values.containers }}{{ $_ := set $allContainers $k $v }}{{ end }}
{{- range $k, $v := .Values.initContainers }}{{ $_ := set $allContainers $k $v }}{{ end }}

{{- range $cName, $container := $allContainers }}
{{- range $container.mounts }}

{{- /* ConfigMap volumes */ -}}
{{- if .configMap }}
{{- $volName := printf "configmap-%s" .configMap }}
{{- if .external }}{{ $volName = printf "configmap-ext-%s" .configMap }}{{ end }}
{{- if not (hasKey $seen $volName) }}
{{- $_ := set $seen $volName true }}
{{- $resolvedName := include "chartpack.resolveResourceName" (dict "name" .configMap "fullName" $fullName "external" .external) }}
{{- $vol := dict "name" $volName "configMap" (dict "name" $resolvedName) }}
{{- if .items }}{{ $_ := set (index $vol "configMap") "items" .items }}{{ end }}
{{- if .defaultMode }}{{ $_ := set (index $vol "configMap") "defaultMode" .defaultMode }}{{ end }}
{{- $volumes = append $volumes $vol }}
{{- end }}
{{- end }}

{{- /* Secret volumes */ -}}
{{- if .secret }}
{{- $volName := printf "secret-%s" .secret }}
{{- if .external }}{{ $volName = printf "secret-ext-%s" .secret }}{{ end }}
{{- if not (hasKey $seen $volName) }}
{{- $_ := set $seen $volName true }}
{{- $resolvedName := include "chartpack.resolveResourceName" (dict "name" .secret "fullName" $fullName "external" .external) }}
{{- $vol := dict "name" $volName "secret" (dict "secretName" $resolvedName) }}
{{- if .items }}{{ $_ := set (index $vol "secret") "items" .items }}{{ end }}
{{- if .defaultMode }}{{ $_ := set (index $vol "secret") "defaultMode" .defaultMode }}{{ end }}
{{- $volumes = append $volumes $vol }}
{{- end }}
{{- end }}

{{- /* Persistence volumes (non-StatefulSet only) */ -}}
{{- if .persistence }}
{{- $volName := printf "persistence-%s" .persistence }}
{{- if and (not (hasKey $seen $volName)) (ne $.Values.workloadType "StatefulSet") }}
{{- $_ := set $seen $volName true }}
{{- $pConfig := index $.Values.persistence .persistence }}
{{- $claimName := default (printf "%s-%s" $fullName .persistence) $pConfig.existingClaim }}
{{- $vol := dict "name" $volName "persistentVolumeClaim" (dict "claimName" $claimName) }}
{{- $volumes = append $volumes $vol }}
{{- end }}
{{- end }}

{{- end }}
{{- end }}

{{- /* Certificate volumes (cert-manager automount) */ -}}
{{- range $name, $cert := .Values.networking.certificates }}
{{- if and $cert $cert.mount }}
{{- $volName := printf "cert-%s" $name }}
{{- if not (hasKey $seen $volName) }}
{{- $_ := set $seen $volName true }}
{{- $secretName := default (printf "%s-%s-tls" $fullName $name) $cert.secretName }}
{{- $vol := dict "name" $volName "secret" (dict "secretName" $secretName) }}
{{- $volumes = append $volumes $vol }}
{{- end }}
{{- end }}
{{- end }}

{{- if $volumes }}
{{- toYaml $volumes }}
{{- end }}
{{- end }}

{{/*
Generate volumeClaimTemplates for StatefulSets.
Only includes persistence entries without existingClaim.
*/}}
{{- define "chartpack.persistence.volumeClaimTemplates" -}}
{{- $templates := list }}
{{- range $name, $config := .Values.persistence }}
{{- if not $config.existingClaim }}
{{- $vct := dict }}
{{- $metadata := dict "name" (printf "persistence-%s" $name) }}
{{- if $config.annotations }}
{{- $_ := set $metadata "annotations" $config.annotations }}
{{- end }}
{{- if $config.labels }}
{{- $_ := set $metadata "labels" $config.labels }}
{{- end }}
{{- $_ := set $vct "metadata" $metadata }}
{{- $spec := dict }}
{{- $_ := set $spec "accessModes" (default (list "ReadWriteOnce") $config.accessModes) }}
{{- $resources := dict "requests" (dict "storage" (default "1Gi" $config.size)) }}
{{- $_ := set $spec "resources" $resources }}
{{- if $config.storageClass }}
{{- if eq $config.storageClass "-" }}
{{- $_ := set $spec "storageClassName" "" }}
{{- else }}
{{- $_ := set $spec "storageClassName" $config.storageClass }}
{{- end }}
{{- end }}
{{- $_ := set $vct "spec" $spec }}
{{- $templates = append $templates $vct }}
{{- end }}
{{- end }}
{{- if $templates }}
{{- toYaml $templates }}
{{- end }}
{{- end }}

{{/*
Generate checksum annotations for configMaps and secrets to trigger pod rollouts on changes.
*/}}
{{- define "chartpack.persistence.checksumAnnotations" -}}
{{- range $name, $config := .Values.config.configMaps }}
{{- if $config }}
checksum/configmap-{{ $name }}: {{ toJson $config.data | sha256sum }}
{{- end }}
{{- end }}
{{- range $name, $config := .Values.config.secrets }}
{{- if $config }}
checksum/secret-{{ $name }}: {{ toJson (merge (dict) (default (dict) $config.data) (default (dict) $config.stringData)) | sha256sum }}
{{- end }}
{{- end }}
{{- end }}
