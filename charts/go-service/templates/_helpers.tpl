{{/*
Expand the name of the chart.
*/}}
{{- define "go-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Uses serviceName when set, otherwise falls back to the release name.
*/}}
{{- define "go-service.fullname" -}}
{{- if .Values.serviceName }}
{{- .Values.serviceName | trunc 63 | trimSuffix "-" }}
{{- else if .Values.fullnameOverride }}
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
Common labels applied to all resources.
*/}}
{{- define "go-service.labels" -}}
helm.sh/chart: {{ include "go-service.name" . }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "go-service.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels used by Deployment and Service.
*/}}
{{- define "go-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "go-service.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Resolve the ServiceAccount name for the workload.
*/}}
{{- define "go-service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "go-service.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Resolve a named container port to its numeric value.
Supported names: "http", "grpc".
*/}}
{{- define "go-service.resolvePort" -}}
{{- $portName := .portName -}}
{{- $root := .root -}}
{{- if eq $portName "grpc" -}}
{{- $root.Values.containerPorts.grpc -}}
{{- else -}}
{{- $root.Values.containerPorts.http -}}
{{- end -}}
{{- end }}
