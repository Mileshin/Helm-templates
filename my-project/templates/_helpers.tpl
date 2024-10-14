{{/*
Expand the namespace of the release.
Allows overriding.
*/}}
{{- define "myproject.namespace" -}}
{{- default .Release.Namespace .Values.namespace -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "myproject.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "myproject.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- default (printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-") .Values.fullnameOverride -}}
{{- end -}}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "myproject.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Set paths for images
*/}}
{{- define "myservice.image" -}}
{{- if .Values.myservice.image -}}
{{ .Values.myservice.image }}:{{ .Values.myservice.tag }}
{{- else -}}
{{ .Values.registry }}/my-service:{{ .Values.tag }}
{{- end -}}
{{- end -}}


{{/*
Selector labels
*/}}
{{- define "myproject.selectorLabels" -}}
app.kubernetes.io/name: {{ include "myproject.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create metalabels
*/}}
{{- define "myproject.metaLabels" -}}
{{ include "myproject.selectorLabels" . }}
helm.sh/chart: {{ template "myproject.chart" . }}
app.kubernetes.io/managed-by: "{{ .Release.Service }}"
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- if .Values.metaLabels}}
{{ toYaml .Values.metaLabels }}
{{- end }}
{{- end -}}


{{/*
Templates for probes
*/}}
{{- define "myproject.probes" -}}
{{- if .enabled -}}
{{- if .startupProbe.enabled }}
startupProbe:
  httpGet:
    path: {{ .startupProbe.path }}
    port: {{ .port }}
  initialDelaySeconds: {{ .startupProbe.initialDelaySeconds }}
  periodSeconds: {{ .startupProbe.periodSeconds }}
  timeoutSeconds: {{ .startupProbe.timeoutSeconds }}
  failureThreshold: {{ .startupProbe.failureThreshold }}
  successThreshold: {{ .startupProbe.successThreshold }}
{{- end }}
{{- if .readinessProbe.enabled }}
readinessProbe:
  httpGet:
    path: {{ .readinessProbe.path }}
    port: {{ .port }}
  initialDelaySeconds: {{ .readinessProbe.initialDelaySeconds }}
  periodSeconds: {{ .readinessProbe.periodSeconds }}
  timeoutSeconds: {{ .readinessProbe.timeoutSeconds }}
  failureThreshold: {{ .readinessProbe.failureThreshold }}
  successThreshold: {{ .readinessProbe.successThreshold }}
{{- end }}
{{- if .livenessProbe.enabled }}
livenessProbe:
  httpGet:
    path: {{ .livenessProbe.path }}
    port: {{ .port }}
  initialDelaySeconds: {{ .livenessProbe.initialDelaySeconds }}
  periodSeconds: {{ .livenessProbe.periodSeconds }}
  timeoutSeconds: {{ .livenessProbe.timeoutSeconds }}
  failureThreshold: {{ .livenessProbe.failureThreshold }}
  successThreshold: {{ .livenessProbe.successThreshold }}
{{- end }}
{{- end -}}
{{- end }}

{{/*
Templates for resources
*/}}
{{- define "myproject.resources" -}}
{{- if .enabled }}
resources:
  {{- if .requests.enabled }}
  requests:
    {{- if .requests.cpu }}
    cpu: {{ .requests.cpu }}
    {{- end }}
    {{- if .requests.memory }}
    memory: {{ .requests.memory }}
    {{- end }}
  {{- end }}
  {{- if .limits.enabled }}
  limits:
    {{- if .limits.cpu }}
    cpu: {{ .limits.cpu }}
    {{- end }}
    {{- if .limits.memory }}
    memory: {{ .limits.memory }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Define a common Ingress template
*/}}
{{- define "myproject.ingress" -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .fullName }}-{{ .serviceName }}
  namespace: {{ .namespace }}
  labels:
  {{- .metaLabels | nindent 4 }}
  {{- range $key, $value := .ingress.labels }}
    {{- $key | nindent 4 }}: {{ $value | quote }}
  {{- end }}
    app.kubernetes.io/component: {{ .serviceName }}
  annotations:
    {{- range $key, $value := .ingress.annotations }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
spec:
  ingressClassName: {{ .ingressType }}
  rules:
  {{- range .hosts }}
  - host: {{ .host }}
    http:
      paths:
      {{- range .paths }}
      - path: {{ .path }}
        pathType: {{ .pathType }}
        backend:
          service:
            name: {{ $.fullName }}-{{ $.serviceName }}
            port:
              number: {{ $.service.port }}
      {{- end }}
  {{- end }}
  {{- if .ingress.tls.enabled }}  
  tls:
  {{- range .hosts }}
  - hosts:
    - {{ .host }}
  {{- end }}
    secretName: {{ .ingress.tls.name }}
  {{- end }}
{{- end }}

{{/*
Define a universal LoadBalancer Service template
*/}}
{{- define "myproject.loadBalancer" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .fullName }}-{{ .serviceName }}-{{ .portName }}-lb
  namespace: {{ .namespace }}
  labels:
    app: {{ .fullName }}-{{ .serviceName }}
    {{- .metaLabels | nindent 4 }}
    {{- range $key, $value := .labels }}
    {{- $key | nindent 4 }}: {{ $value | quote }}
    {{- end }}
    app.kubernetes.io/component: {{ .serviceName }}
    app: {{ .serviceName }}
  annotations:
    {{- range $key, $value := .annotations }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
spec:
  type: LoadBalancer
  externalTrafficPolicy: {{ .externalTrafficPolicy }}
  selector:
    app: {{ .serviceName }}
  ports:
    - name: {{ .portName }}
      port: {{ .port }}
      targetPort: {{ .targetPort }}
      protocol: {{ .protocol }}
{{- end }}

{{/*
Define a universal NodePort Service template
*/}}
{{- define "myproject.nodePort" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .fullName }}-{{ .serviceName }}-{{ .portName }}-nodeport
  namespace: {{ .namespace }}
  labels:
    {{- .metaLabels | nindent 4 }}
    {{- range $key, $value := .labels }}
    {{- $key | nindent 4 }}: {{ $value | quote }}
    {{- end }}
    app.kubernetes.io/component: {{ .serviceName }}
    app: {{ .serviceName }}
  annotations:
    {{- range $key, $value := .annotations }}
    {{ $key }}: {{ $value | quote }}
    {{- end }}
spec:
  type: NodePort
  externalTrafficPolicy: {{ .externalTrafficPolicy }}
  selector:
    app: {{ .serviceName }}
  ports:
    {{- range .ports }}
    - name: {{ .name }}
      port: {{ .port }}
      targetPort: {{ .targetPort }}
      protocol: {{ .protocol }}
      {{- if .nodePort }}
      nodePort: {{ .nodePort }}
      {{- end }}
    {{- end }}
{{- end }}

{{/*
Define a universal ClusterIp Service template
*/}}
{{- define "myproject.ClusterIP" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .fullName }}-{{ .serviceName }}
  namespace: {{ .namespace }}
  labels:
    {{- .metaLabels | nindent 4 }}
    app.kubernetes.io/component: {{ .serviceName }}
    app: {{ .serviceName }}
    service-type: clusterip 
spec:
  type: ClusterIP
  selector:
    app: {{ .serviceName }}
  ports:
    {{- range .ports }}
    - name: {{ .name }}
      port: {{ .port }}
      targetPort: {{ .targetPort }}
      protocol: {{ .protocol }}
    {{- end }}
{{- end }}

{{/*
Define a universal ServiceMonitoring template
*/}}
{{- define "myproject.ServiceMonitoring" -}}
{{- if or (eq .provider "prometheus") (eq .provider "victoriametrics") }}
apiVersion: {{ if eq .provider "prometheus" -}} monitoring.coreos.com/v1 {{- else -}} operator.victoriametrics.com/v1beta1 {{- end }}
kind: {{ if eq .provider "prometheus" -}} ServiceMonitor {{- else -}} VMServiceScrape {{- end }}
metadata:
  name: {{ .fullName }}-{{ .serviceName }}
  namespace: {{ .namespace }}
  labels:
    {{- .metaLabels | nindent 4 }}
    app.kubernetes.io/component: {{ .serviceName }}
spec:
  selector:
    matchLabels:
      {{- .matchLabels| nindent 6 }}
      app.kubernetes.io/component: {{ .serviceName }}
      service-type: clusterip 
  namespaceSelector:
    matchNames:
      - {{ .namespace }}
  endpoints:
    {{- range .endpoints }}
    - port: {{ .port }}
      path: {{ .path }}
      interval: {{ .interval }}
      scrapeTimeout: {{ .scrapeTimeout }}
    {{- end }}
{{- else }}
{{- fail "`provider` must be either 'prometheus' or 'victoriametrics'. Got: " .provider }}
{{- end }}
{{- end }}

{{/*
Define a universal UDPIngress template this need for kong
*/}}
{{- define "myproject.udpIngress" -}}
apiVersion: configuration.konghq.com/v1beta1
kind: UDPIngress
metadata:
  name: {{ .fullName }}-udpingress
  namespace: {{ .namespace }}
  labels:
    {{- .metaLabels | nindent 4 }}
    app.kubernetes.io/component: {{ .serviceName }}
  annotations:
    kubernetes.io/ingress.class: kong
spec:
  rules:
    {{- range .rules }}
    - backend:
        serviceName: {{ .serviceName }}
        servicePort: {{ .servicePort }}
      port: {{ .port }}
    {{- end }}
{{- end }}