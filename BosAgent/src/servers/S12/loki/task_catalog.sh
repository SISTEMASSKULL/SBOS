#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — loki
# Grafana Loki 3.4.3 — agregador de logs del stack SBOS.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/loki.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-monitor"
LOKI_VERSION="${LOKI_VERSION:-3.4.3}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [loki] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_statefulset_ready() {
    local sts="$1" ns="$2" timeout="${3:-180}" elapsed=0
    while (( elapsed < timeout )); do
        local ready
        ready=$(_k get statefulset "$sts" -n "$ns" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( ready >= 1 )) && return 0
        sleep 5; elapsed=$((elapsed + 5))
        (( elapsed % 30 == 0 )) && _log "Esperando $sts Ready... ${elapsed}/${timeout}s"
    done
    return 1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || { echo "${__STEP_FAIL__} verificar_namespace: $NS no existe"; return 1; }
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")" /data/loki

    # Idempotencia
    local ready
    ready=$(_k get statefulset loki -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_SKIP__} loki_install: StatefulSet ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} crear_pv_loki"
    mkdir -p /data/loki
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: sbos-loki-pv
  labels:
    sbos.app/managed-by: bos
spec:
  capacity:
    storage: 20Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /data/loki
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    namespace: sbos-monitor
    name: loki-storage-loki-0
EOF
    echo "${__STEP_OK__} crear_pv_loki"

    echo "${__STEP_START__} instalar_loki_helm"
    if ! helm repo list 2>/dev/null | grep -q "^grafana"; then
        helm repo add grafana https://grafana.github.io/helm-charts >> "$FICHA_LOG" 2>&1
        helm repo update >> "$FICHA_LOG" 2>&1
    fi

    helm upgrade --install loki grafana/loki \
        --namespace "$NS" \
        --version "6.9.0" \
        --set loki.auth_enabled=false \
        --set loki.commonConfig.replication_factor=1 \
        --set singleBinary.replicas=1 \
        --set "singleBinary.resources.requests.cpu=50m" \
        --set "singleBinary.resources.requests.memory=128Mi" \
        --set "singleBinary.resources.limits.cpu=500m" \
        --set "singleBinary.resources.limits.memory=512Mi" \
        --set backend.replicas=0 \
        --set read.replicas=0 \
        --set write.replicas=0 \
        --set chunksCache.enabled=false \
        --set resultsCache.enabled=false \
        --timeout 8m \
        >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} instalar_loki_helm"

    echo "${__STEP_START__} esperar_loki_ready"
    if ! _wait_statefulset_ready loki "$NS" 180; then
        echo "${__STEP_FAIL__} esperar_loki_ready: StatefulSet no Ready en 180s"
        return 1
    fi
    echo "${__STEP_OK__} esperar_loki_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_loki_ready"
    local ready
    ready=$(_k get statefulset loki -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( ready >= 1 )) || { echo "${__STEP_FAIL__} verificar_loki_ready: ${ready}/1"; return 1; }
    echo "${__STEP_OK__} verificar_loki_ready (${ready}/1)"
    return 0
}

ficha_health() {
    local ready
    ready=$(_k get statefulset loki -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( ready >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: loki ${ready}/1"
    return 1
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_loki"
    helm uninstall loki -n "$NS" >> "$FICHA_LOG" 2>&1 || true
    _k delete pv sbos-loki-pv --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_loki"
    return 0
}
