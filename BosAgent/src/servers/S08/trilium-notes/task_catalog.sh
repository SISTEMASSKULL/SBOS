#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — trilium-notes
# Trilium Notes 0.63.7 — base de conocimiento soberana.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/trilium-notes.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-collab"
TRILIUM_VERSION="${TRILIUM_VERSION:-0.63.7}"
DOMAIN="${BOS_DOMAIN:-sksistemas.com}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [trilium-notes] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_deploy_ready() {
    local d="$1" n="$2" t="${3:-120}" e=0
    while (( e < t )); do
        local r
        r=$(_k get deployment "$d" -n "$n" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5)); (( e % 30 == 0 )) && _log "Esperando $d... ${e}/${t}s"
    done; return 1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || {
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
        _log "Namespace $NS creado"
    }
    echo "${__STEP_OK__} verificar_namespace"
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")" /data/trilium

    local ready
    ready=$(_k get deployment trilium-notes -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_SKIP__} trilium_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} aplicar_manifests_trilium"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<EOF
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: sbos-trilium-pv
  labels:
    sbos.app/managed-by: bos
spec:
  capacity:
    storage: 10Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /data/trilium
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    namespace: ${NS}
    name: trilium-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: trilium-data
  namespace: ${NS}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trilium-notes
  namespace: ${NS}
  labels:
    app: trilium-notes
    sbos.app/managed-by: bos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: trilium-notes
  template:
    metadata:
      labels:
        app: trilium-notes
    spec:
      securityContext:
        fsGroup: 1000
      containers:
        - name: trilium
          image: zadam/trilium:${TRILIUM_VERSION}
          env:
            - name: TRILIUM_DATA_DIR
              value: "/home/node/trilium-data"
            - name: TRILIUM_PORT
              value: "8080"
          ports:
            - containerPort: 8080
          volumeMounts:
            - name: data
              mountPath: /home/node/trilium-data
          resources:
            requests:
              cpu: "100m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          readinessProbe:
            httpGet:
              path: /
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 10
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: trilium-data
---
apiVersion: v1
kind: Service
metadata:
  name: trilium-notes
  namespace: ${NS}
spec:
  selector:
    app: trilium-notes
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-trilium-ingress
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: trilium-notes
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-gateway
      ports:
        - port: 8080
EOF
    echo "${__STEP_OK__} aplicar_manifests_trilium"

    echo "${__STEP_START__} esperar_trilium_ready"
    _wait_deploy_ready trilium-notes "$NS" 120 || {
        echo "${__STEP_FAIL__} esperar_trilium_ready: timeout 120s"
        return 1
    }
    echo "${__STEP_OK__} esperar_trilium_ready"

    echo "${__STEP_START__} registrar_ruta_kong"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: trilium-notes-ingress
  namespace: ${NS}
  annotations:
    konghq.com/strip-path: "false"
    konghq.com/protocols: "https"
spec:
  ingressClassName: kong
  rules:
    - host: "notas.${DOMAIN}"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: trilium-notes
                port:
                  number: 8080
EOF
    echo "${__STEP_OK__} registrar_ruta_kong"
    return 0
}

ficha_repair() {
    _log "Repair trilium-notes: verificando deployment"
    local ready
    ready=$(_k get deployment trilium-notes -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready < 1 )); then
        _log "trilium-notes caído — re-ejecutando install"
        ficha_install
    else
        _log "trilium-notes OK (ready=$ready)"
    fi
}

ficha_status() {
    local ready
    ready=$(_k get deployment trilium-notes -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    echo "trilium-notes ready=$ready"
}

ficha_remove() {
    _log "Eliminando trilium-notes"
    _k delete deployment trilium-notes -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    _k delete service trilium-notes -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    _k delete ingress trilium-notes-ingress -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} trilium_remove"
}
