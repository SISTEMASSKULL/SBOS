#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — embedding-worker
# Imagen: ghcr.io/huggingface/text-embeddings-inference:cpu-1.2.3
# Namespace: sbos-ai
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/embedding-worker.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-ai"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [embedding-worker] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

# Motor de puertos BOS — asigna puerto ClusterIP según SBOS-050
_portman() {
    local ficha_id="$1" ficha_index="$2" server="$3" ns="${4:-default}"
    local TOKEN; TOKEN="$(cat /etc/bos/rpc-token 2>/dev/null)"
    BOS_RPC_TOKEN="$TOKEN" bosctl rpc bos.portman.assign \
      "{\"ficha_id\":\"$ficha_id\",\"ficha_index\":$ficha_index,\"logical_server\":\"$server\",\"port_types\":[\"K8S_CLUSTER_IP\"],\"namespace\":\"$ns\",\"ctx_id\":\"install-$ficha_id\"}" \
      2>/dev/null | python3 -I -c \
      "import json,sys; d=json.load(sys.stdin); a=d.get('assignments',[]); print(a[0]['port'] if a else '')" \
    2>/dev/null
}

# Consulta el puerto ya asignado a una ficha en el kardex portman
_portman_get() {
    local ficha_id="$1" port_type="${2:-K8S_CLUSTER_IP}"
    local TOKEN; TOKEN="$(cat /etc/bos/rpc-token 2>/dev/null)"
    BOS_RPC_TOKEN="$TOKEN" bosctl rpc bos.portman.list '{}' 2>/dev/null | python3 -I -c "
import json,sys
d=json.load(sys.stdin)
for a in d.get('items',[]):
    if a.get('ficha_id')=='$ficha_id' and a.get('port_type')=='$port_type' and a.get('status')=='assigned':
        print(a.get('port',''))
        break
" 2>/dev/null
}

_wait_ready() {
    local t="${1:-180}" e=0
    while (( e < t )); do
        local r
        r=$(_k get deployment embedding-worker -n "$NS" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5))
        (( e % 30 == 0 )) && _log "Esperando embedding-worker Ready... ${e}/${t}s"
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
    r=$(_k get deployment embedding-worker -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r >= 1 )); then
        echo "${__STEP_SKIP__} embedding-worker_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} portman_obtener_dependencias"
    local OLLAMA_SVC_PORT; OLLAMA_SVC_PORT=$(_portman_get "ollama")
    OLLAMA_SVC_PORT="${OLLAMA_SVC_PORT:-21530}"
    local QDRANT_SVC_PORT; QDRANT_SVC_PORT=$(_portman_get "qdrant")
    QDRANT_SVC_PORT="${QDRANT_SVC_PORT:-21550}"
    _log "Puertos portman: ollama=${OLLAMA_SVC_PORT} qdrant=${QDRANT_SVC_PORT}"
    echo "${__STEP_OK__} portman_obtener_dependencias"

    echo "${__STEP_START__} aplicar_manifest_embedding-worker"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<K8SEOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: embedding-worker
  namespace: sbos-ai
  labels:
    app: embedding-worker
    sbos.app/managed-by: bos
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: embedding-worker
  template:
    metadata:
      labels:
        app: embedding-worker
    spec:
      containers:
        - name: embedding-worker
          image: ghcr.io/huggingface/text-embeddings-inference:cpu-1.2.3
          args: ["--model-id", "BAAI/bge-small-en-v1.5", "--port", "8090"]
          ports:
            - containerPort: 8090
          env:
            - name: HF_ENDPOINT
              value: https://huggingface.co
            - name: HUGGINGFACE_HUB_CACHE
              value: /data/cache
            - name: OLLAMA_URL
              value: http://ollama.sbos-ai.svc.cluster.local:${OLLAMA_SVC_PORT}
            - name: QDRANT_URL
              value: http://qdrant.sbos-ai.svc.cluster.local:${QDRANT_SVC_PORT}
            - name: REDIS_URL
              value: redis://:sbos_redis_bootstrap@redis.sbos-data.svc.cluster.local:6379/5
          resources:
            requests:
              cpu: "50m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "2Gi"
K8SEOF
    echo "${__STEP_START__} portman_embedding-worker"
    local SVC_PORT; SVC_PORT=$(_portman "embedding-worker" 0 "S15" "sbos-ai")
    SVC_PORT="${SVC_PORT:-21500}"
    _log "Puerto ClusterIP portman: ${SVC_PORT}"
    echo "${__STEP_OK__} portman_embedding-worker"

    _k apply -f - >> "$FICHA_LOG" 2>&1 <<SVCINNER
apiVersion: v1
kind: Service
metadata:
  name: embedding-worker
  namespace: sbos-ai
spec:
  selector:
    app: embedding-worker
  ports:
    - port: ${SVC_PORT}
      targetPort: 8090
SVCINNER
    echo "${__STEP_OK__} aplicar_manifest_embedding-worker"

    echo "${__STEP_START__} esperar_embedding-worker_ready"
    _wait_ready 180 || { echo "${__STEP_FAIL__} esperar_embedding-worker_ready: timeout 180s"; return 1; }
    echo "${__STEP_OK__} esperar_embedding-worker_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_embedding-worker"
    local r
    r=$(_k get deployment embedding-worker -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) || { echo "${__STEP_FAIL__} verificar_embedding-worker: ${r}/1"; return 1; }
    echo "${__STEP_OK__} verificar_embedding-worker (${r}/1)"
    return 0
}

ficha_health() {
    local r
    r=$(_k get deployment embedding-worker -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: embedding-worker ${r}/1"
    return 1
}

ficha_post_install() {
    # Evitar post_install_generic (usa namespace default con label errado)
    return 0
}

ficha_repair() {
    _log "ficha_repair: re-aplicando manifests embedding-worker (idempotente)"
    ficha_install
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_embedding-worker_ready"
    local ready
    ready=$(_k get deployment embedding-worker -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_OK__} test_embedding-worker_ready (${ready}/1)"
    else
        echo "${__STEP_FAIL__} test_embedding-worker_ready: ${ready}/1"; ok=1
    fi
    return $ok
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_embedding-worker"
    _k delete deployment embedding-worker -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete service embedding-worker -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_embedding-worker"
    return 0
}
