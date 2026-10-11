#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — elasticsearch
# Imagen: docker.elastic.co/elasticsearch/elasticsearch:8.17.3
# Namespace: sbos-search
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/elasticsearch.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-search"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [elasticsearch] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_ready() {
    local t="${1:-180}" e=0
    while (( e < t )); do
        local r
        r=$(_k get statefulset elasticsearch -n "$NS" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5))
        (( e % 30 == 0 )) && _log "Esperando elasticsearch Ready... ${e}/${t}s"
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
    r=$(_k get statefulset elasticsearch -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r >= 1 )); then
        echo "${__STEP_SKIP__} elasticsearch_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} aplicar_manifest_elasticsearch"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: apps/v1
kind: Statefulset
metadata:
  name: elasticsearch
  namespace: sbos-search
  labels:
    app: elasticsearch
    sbos.app/managed-by: bos
spec:
  serviceName: elasticsearch
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
        - name: elasticsearch
          image: docker.elastic.co/elasticsearch/elasticsearch:8.17.3
          ports:
            - containerPort: 9200
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
  name: elasticsearch
  namespace: sbos-search
spec:
  selector:
    app: elasticsearch
  ports:
    - port: 9200
      targetPort: 9200
SVCINNER
    echo "${__STEP_OK__} aplicar_manifest_elasticsearch"

    echo "${__STEP_START__} esperar_elasticsearch_ready"
    _wait_ready 180 || { echo "${__STEP_FAIL__} esperar_elasticsearch_ready: timeout 180s"; return 1; }
    echo "${__STEP_OK__} esperar_elasticsearch_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_elasticsearch"
    local r
    r=$(_k get statefulset elasticsearch -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) || { echo "${__STEP_FAIL__} verificar_elasticsearch: ${r}/1"; return 1; }
    echo "${__STEP_OK__} verificar_elasticsearch (${r}/1)"
    return 0
}

ficha_health() {
    local r
    r=$(_k get statefulset elasticsearch -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: elasticsearch ${r}/1"
    return 1
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_elasticsearch"
    _k delete statefulset elasticsearch -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete service elasticsearch -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_elasticsearch"
    return 0
}
