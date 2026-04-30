{{/*
Shared Deployment template. Call with: {{ include "library.deployment" . }}
*/}}
{{- define "library.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "library.fullname" . }}
  labels:
    {{- include "library.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "library.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "library.selectorLabels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    spec:
      {{- with (coalesce .Values.imagePullSecrets .Values.global.imagePullSecrets) }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "library.serviceAccountName" . }}
      securityContext:
        {{- toYaml (coalesce .Values.podSecurityContext .Values.global.podSecurityContext) | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml (coalesce .Values.securityContext .Values.global.securityContext) | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP
          {{- with .Values.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (coalesce .Values.nodeSelector .Values.global.nodeSelector) }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (coalesce .Values.affinity .Values.global.affinity) }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (coalesce .Values.tolerations .Values.global.tolerations) }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
