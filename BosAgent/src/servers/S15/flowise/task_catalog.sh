#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — flowise
# Imagen: flowiseai/flowise:2.2.6
# Namespace: sbos-ai
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/flowise.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-ai"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [flowise] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_ready() {
    local t="${1:-180}" e=0
    while (( e < t )); do
        local r
        r=$(_k get deployment flowise -n "$NS" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5))
        (( e % 30 == 0 )) && _log "Esperando flowise Ready... ${e}/${t}s"
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
    r=$(_k get deployment flowise -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r >= 1 )); then
        echo "${__STEP_SKIP__} flowise_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} aplicar_manifest_flowise"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flowise
  namespace: sbos-ai
  labels:
    app: flowise
    sbos.app/managed-by: bos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: flowise
  template:
    metadata:
      labels:
        app: flowise
    spec:
      containers:
        - name: flowise
          image: flowiseai/flowise:2.2.6
          ports:
            - containerPort: 3000
          env:
            - name: DATABASE_TYPE
              value: postgres
            - name: DATABASE_HOST
              value: postgresql.sbos-data.svc.cluster.local
            - name: DATABASE_PORT
              value: "5432"
            - name: DATABASE_USER
              value: postgres
            - name: DATABASE_PASSWORD
              value: sbos_bootstrap_pass
            - name: DATABASE_NAME
              value: flowise_db
            - name: FLOWISE_USERNAME
              value: admin
            - name: FLOWISE_PASSWORD
              value: sbos_flowise_admin_change_in_prod
            - name: SECRETKEY_PATH
              value: /root/.flowise
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
  name: flowise
  namespace: sbos-ai
spec:
  selector:
    app: flowise
  ports:
    - port: 3000
      targetPort: 3000
SVCINNER
    echo "${__STEP_OK__} aplicar_manifest_flowise"

    echo "${__STEP_START__} esperar_flowise_ready"
    _wait_ready 180 || { echo "${__STEP_FAIL__} esperar_flowise_ready: timeout 180s"; return 1; }
    echo "${__STEP_OK__} esperar_flowise_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_flowise"
    local r
    r=$(_k get deployment flowise -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) || { echo "${__STEP_FAIL__} verificar_flowise: ${r}/1"; return 1; }
    echo "${__STEP_OK__} verificar_flowise (${r}/1)"
    return 0
}

ficha_health() {
    local r
    r=$(_k get deployment flowise -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: flowise ${r}/1"
    return 1
}

ficha_repair() {
    _log "ficha_repair: re-aplicando manifests flowise (idempotente)"
    ficha_install
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_flowise_ready"
    local ready
    ready=$(_k get deployment flowise -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_OK__} test_flowise_ready (${ready}/1)"
    else
        echo "${__STEP_FAIL__} test_flowise_ready: ${ready}/1"; ok=1
    fi
    return $ok
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_flowise"
    _k delete deployment flowise -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete service flowise -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_flowise"
    return 0
}
