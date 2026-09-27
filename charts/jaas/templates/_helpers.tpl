{{- /*
SPDX-FileCopyrightText: The helm-charts Authors
SPDX-License-Identifier: 0BSD
*/ -}}

{{- /* The registry one image is pulled from: global.imageRegistry when it is set,
       otherwise that image's own registry key. Every image reference the chart
       composes goes through here, so a cluster that admits one registry needs one
       value rather than one override per image — and a new image added later
       cannot quietly escape it. dig keeps it safe against `--set global=null`.

       The `snippets` and `additionalLibraries` maps are not routed through this:
       their values are whole image references, not a registry plus repository.

       `with` rather than `dig`, because .Values is a chartutil.Values and dig
       only accepts a plain map — and because it keeps `--set global=null` from
       erroring. */ -}}
{{- define "jaas.registry" -}}
{{- $global := "" -}}
{{- with .root.Values.global -}}
{{- $global = default "" .imageRegistry -}}
{{- end -}}
{{- default .registry $global -}}
{{- end -}}

{{- /* One cleanup-Job container running `kubectl delete jsonnetsnippets`. Expects
       a dict: root (the chart context $), name (container name), scopeArg (either
       --all-namespaces or --namespace=<ns>), cacheDir (a unique discovery-cache
       path so concurrent per-namespace containers don't race on one dir).
       registry.k8s.io/kubectl is distroless (no /bin/sh), so each container can
       run only one kubectl invocation — hence one container per watched namespace
       rather than a shell loop. */ -}}
{{- define "jaas.cleanupContainer" -}}
- name: {{ .name }}
  image: "{{ include "jaas.registry" (dict "root" .root "registry" .root.Values.operator.cleanupOnDelete.image.registry) }}/{{ .root.Values.operator.cleanupOnDelete.image.repository }}:{{ .root.Values.operator.cleanupOnDelete.image.tag }}"
  imagePullPolicy: {{ .root.Values.operator.cleanupOnDelete.image.pullPolicy }}
  args:
    - delete
    - jsonnetsnippets.jaas.metio.wtf
    - --all
    - {{ .scopeArg }}
    - --wait=true
    - --timeout={{ .root.Values.operator.cleanupOnDelete.kubectlTimeout }}
    - --ignore-not-found
    - --cache-dir={{ .cacheDir }}
  volumeMounts:
    - name: cache
      mountPath: /tmp
  securityContext:
    runAsNonRoot: true
    runAsGroup: 65532
    runAsUser: 65532
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
    seccompProfile:
      type: RuntimeDefault
  resources:
    requests:
      cpu: {{ .root.Values.operator.cleanupOnDelete.resources.cpu }}
      memory: {{ .root.Values.operator.cleanupOnDelete.resources.memory }}
      ephemeral-storage: {{ .root.Values.operator.cleanupOnDelete.resources.ephemeralStorage }}
    limits:
      cpu: {{ .root.Values.operator.cleanupOnDelete.resources.cpu }}
      memory: {{ .root.Values.operator.cleanupOnDelete.resources.memory }}
      ephemeral-storage: {{ .root.Values.operator.cleanupOnDelete.resources.ephemeralStorage }}
{{- end -}}
