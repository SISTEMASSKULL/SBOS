#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — langfuse
# Imagen: langfuse/langfuse:3.32.0
# Namespace: sbos-ai
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/langfuse.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-ai"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [langfuse] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_ready() {
    local t="${1:-180}" e=0
    while (( e < t )); do
        local r
        r=$(_k get deployment langfuse -n "$NS" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5))
        (( e % 30 == 0 )) && _log "Esperando langfuse Ready... ${e}/${t}s"
    done; return 1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || {
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
        _log "Namespace $NS creado"
    }
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    local r
    r=$(_k get deployment langfuse -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r >= 1 )); then
        echo "${__STEP_SKIP__} langfuse_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} aplicar_manifest_langfuse"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: langfuse
  namespace: sbos-ai
  labels:
    app: langfuse
    sbos.app/managed-by: bos
spec:

  replicas: 1
  selector:
    matchLabels:
      app: langfuse
  template:
    metadata:
      labels:
        app: langfuse
    spec:
      containers:
        - name: langfuse
          image: langfuse/langfuse:3.32.0
          ports:
            - containerPort: 3000
          resources:
            requests:
              cpu: "100m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
K8SEOF
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'SVCINNER'
apiVersion: v1
kind: Service
metadata:
  name: langfuse
  namespace: sbos-ai
spec:
  selector:
    app: langfuse
  ports:
    - port: 3000
      targetPort: 3000
SVCINNER
    echo "${__STEP_OK__} aplicar_manifest_langfuse"

    echo "${__STEP_START__} esperar_langfuse_ready"
    _wait_ready 180 || { echo "${__STEP_FAIL__} esperar_langfuse_ready: timeout 180s"; return 1; }
    echo "${__STEP_OK__} esperar_langfuse_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_langfuse"
    local r
    r=$(_k get deployment langfuse -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) || { echo "${__STEP_FAIL__} verificar_langfuse: ${r}/1"; return 1; }
    echo "${__STEP_OK__} verificar_langfuse (${r}/1)"
    return 0
}

ficha_health() {
    local r
    r=$(_k get deployment langfuse -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: langfuse ${r}/1"
    return 1
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_langfuse"
    _k delete deployment langfuse -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete service langfuse -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_langfuse"
    return 0
}
