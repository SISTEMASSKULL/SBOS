#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — velero
# Imagen: velero/velero:v1.15.3
# Namespace: sbos-ops
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/velero.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-ops"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [velero] $*" | tee -a "$FICHA_LOG"; }
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

_wait_ready() {
    local t="${1:-180}" e=0
    while (( e < t )); do
        local r
        r=$(_k get deployment velero -n "$NS" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5))
        (( e % 30 == 0 )) && _log "Esperando velero Ready... ${e}/${t}s"
    done; return 1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || {
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
        _log "Namespace $NS creado"
    }
    echo "${__STEP_OK__} verificar_namespace"

    echo "${__STEP_START__} crear_serviceaccount_velero"
    _k get serviceaccount velero -n "$NS" > /dev/null 2>&1 || {
        _k create serviceaccount velero -n "$NS" >> "$FICHA_LOG" 2>&1
    }
    echo "${__STEP_OK__} crear_serviceaccount_velero"
    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"
    ficha_pre_install

    local r
    r=$(_k get deployment velero -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r >= 1 )); then
        echo "${__STEP_SKIP__} velero_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} portman_velero"
    local SVC_PORT; SVC_PORT=$(_portman "velero" 2 "S14" "sbos-ops")
    SVC_PORT="${SVC_PORT:-21420}"
    _log "Puerto ClusterIP portman: ${SVC_PORT}"
    echo "${__STEP_OK__} portman_velero"

    echo "${__STEP_START__} aplicar_manifest_velero"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: velero
  namespace: sbos-ops
  labels:
    app: velero
    sbos.app/managed-by: bos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: velero
  template:
    metadata:
      labels:
        app: velero
    spec:
      serviceAccountName: velero
      containers:
        - name: velero
          image: velero/velero:v1.15.3
          command: ["/velero"]
          args:
            - server
            - --uploader-type=kopia
          env:
            - name: VELERO_SCRATCH_DIR
              value: /scratch
            - name: VELERO_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: LD_LIBRARY_PATH
              value: /plugins
          volumeMounts:
            - name: plugins
              mountPath: /plugins
            - name: scratch
              mountPath: /scratch
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "1000m"
              memory: "512Mi"
      volumes:
        - name: plugins
          emptyDir: {}
        - name: scratch
          emptyDir: {}
K8SEOF

    echo "${__STEP_OK__} aplicar_manifest_velero"

    echo "${__STEP_START__} esperar_velero_ready"
    _wait_ready 180 || { echo "${__STEP_FAIL__} esperar_velero_ready: timeout 180s"; return 1; }
    echo "${__STEP_OK__} esperar_velero_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_velero"
    local r
    r=$(_k get deployment velero -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) || { echo "${__STEP_FAIL__} verificar_velero: ${r}/1"; return 1; }
    echo "${__STEP_OK__} verificar_velero (${r}/1)"
    return 0
}

ficha_health() {
    local r
    r=$(_k get deployment velero -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: velero ${r}/1"
    return 1
}

ficha_post_install() {
    # Evitar post_install_generic (usa namespace default con label errado)
    return 0
}

ficha_repair() {
    _log "ficha_repair: re-aplicando manifests velero (idempotente)"
    ficha_install
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_velero_ready"
    local ready
    ready=$(_k get deployment velero -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_OK__} test_velero_ready (${ready}/1)"
    else
        echo "${__STEP_FAIL__} test_velero_ready: ${ready}/1"; ok=1
    fi
    return $ok
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_velero"
    _k delete deployment velero -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete service velero -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_velero"
    return 0
}
