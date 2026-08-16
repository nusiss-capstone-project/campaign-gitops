{{/*
Expand the name of the chart.
*/}}
{{- define "loongcollector-operator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "loongcollector-operator.fullname" -}}
loongcollector-operator
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "loongcollector-operator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "loongcollector-operator.labels" -}}
helm.sh/chart: {{ include "loongcollector-operator.chart" . }}
{{ include "loongcollector-operator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "loongcollector-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "loongcollector-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "pilotx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "pilotx.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "pilotx.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "pilotx.labels" -}}
helm.sh/chart: {{ include "pilotx.chart" . }}
{{ include "pilotx.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "pilotx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pilotx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}


{{- define "loongcollector.rawRegion" -}}
{{- if eq .Values.region "" -}} 
{{- if eq .Values.isFinance true -}}
{{- if eq .Values.default.region "cn-hangzhou" -}}
{{- printf "%s" "cn-hangzhou-finance" }}
{{- else -}}
{{- printf "%s" .Values.default.region }}
{{- end -}}
{{- else -}}
{{- printf "%s" .Values.default.region }}
{{- end -}}
{{- else -}}
{{- printf "%s" .Values.region }}
{{- end -}}
{{- end -}}



{{- define "loongcollector.region" -}}
{{- if eq .Values.net "Internet" -}} 
{{- printf "%s%s" (include "loongcollector.rawRegion" .) "-internet" }}
{{- else }}
{{- printf "%s" (include "loongcollector.rawRegion" .) }}
{{- end }}
{{- end -}}

{{- define "loongcollector.endpoint" -}}
{{- if .Values.slsEndpoint }}
{{- .Values.slsEndpoint }}
{{- else if eq .Values.net "Internet" -}} 
{{- printf "%s%s" (include "loongcollector.rawRegion" .) ".log.aliyuncs.com" }}
{{- else if eq .Values.net "Internal" -}}
{{- printf "%s%s" (include "loongcollector.rawRegion" .) "-internal.log.aliyuncs.com" }}
{{- else -}}
{{- printf "%s%s" (include "loongcollector.rawRegion" .) "-intranet.log.aliyuncs.com" }}
{{- end }}
{{- end -}}


{{- define "loongcollector.project" -}}
{{- if eq .Values.projectName "" -}} 
{{- printf "%s" .Values.default.projectName }}
{{- else }}
{{- printf "%s" .Values.projectName }}
{{- end }}
{{- end -}}


{{- define "loongcollector.uid" -}}
{{- if eq .Values.aliUid "" -}} 
{{- printf "%s" .Values.default.aliUid }}
{{- else }}
{{- printf "%s" .Values.aliUid }}
{{- end }}
{{- end -}}


{{/*
Check if the value is one of the specified Kubernetes types
*/}}
{{- define "isACK" -}}
{{- $input := .Values.clusterType -}}
{{- if or (eq $input "Kubernetes") (eq $input "ManagedKubernetes") (eq $input "ExternalKubernetes") -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Check if the value is one of the specified Kubernetes types
*/}}
{{- define "isNodeECS" -}}
{{- $clusterType := .Values.clusterType -}}
{{- if or (eq $clusterType "Kubernetes") (eq $clusterType "ManagedKubernetes") -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}


{{- define "shouldMountDSAddon" -}}
{{- $clusterType := .Values.clusterType -}}
{{- $clusterProfile := .Values.clusterProfile -}}
{{ if eq (include "isACK" . | trim) "true" }}
{{- if or (eq $clusterProfile "Edge") ((eq $clusterType "ExternalKubernetes")) }}
false
{{- else -}}
true
{{- end -}}
{{- else -}}
false
{{- end -}}
{{- end -}}


{{- define "shouldMountOperatorAddon" -}}
{{- $clusterType := .Values.clusterType -}}
{{- $clusterProfile := .Values.clusterProfile -}}
{{ if eq (include "isACK" . | trim) "true" }}
{{- if (eq $clusterType "ExternalKubernetes") }}
false
{{- else -}}
true
{{- end -}}
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Replace __ACK_REGION_ID__ with the provided value if it exists
*/}}
{{- define "replaceRegionId" -}}
{{- $top := index . 0 -}}
{{- $value := index . 1 -}}
{{- $replacement := (include "loongcollector.rawRegion" $top) -}}
{{- if contains "__ACK_REGION_ID__" $value -}}
{{- $value | replace "__ACK_REGION_ID__" $replacement -}}
{{- else -}}
{{- $value -}}
{{- end -}}
{{- end -}}


{{- define "loongcollector.baseMachineGroup" -}}
{{- if eq .Values.baseMachineGroupName "" -}} 
{{- printf "%s-%s" "k8s-group" .Values.clusterID }}
{{- else }}
{{- printf "%s" .Values.baseMachineGroupName }}
{{- end }}
{{- end -}}