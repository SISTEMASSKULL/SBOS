#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — open-webui
# Imagen: ghcr.io/open-webui/open-webui:v0.5.20
# Namespace: sbos-ai
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/open-webui.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-ai"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [open-webui] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_ready() {
    local t="${1:-180}" e=0
    while (( e < t )); do
        local r
        r=$(_k get deployment open-webui -n "$NS" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5))
        (( e % 30 == 0 )) && _log "Esperando open-webui Ready... ${e}/${t}s"
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
    r=$(_k get deployment open-webui -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r >= 1 )); then
        echo "${__STEP_SKIP__} open-webui_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} crear_pvc_open_webui"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'PVCEOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: open-webui-data
  namespace: sbos-ai
  labels:
    app: open-webui
    sbos.app/managed-by: bos
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi
PVCEOF
    echo "${__STEP_OK__} crear_pvc_open_webui"

    echo "${__STEP_START__} aplicar_manifest_open-webui"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: open-webui
  namespace: sbos-ai
  labels:
    app: open-webui
    sbos.app/managed-by: bos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: open-webui
  template:
    metadata:
      labels:
        app: open-webui
    spec:
      containers:
        - name: open-webui
          image: ghcr.io/open-webui/open-webui:v0.5.20
          ports:
            - containerPort: 8080
          env:
            - name: OLLAMA_BASE_URL
              value: http://ollama.sbos-ai.svc.cluster.local:11434
            - name: WEBUI_SECRET_KEY
              value: sbos_openwebui_secret_change_in_prod
            - name: DATABASE_URL
              value: sqlite:////app/backend/data/webui.db
            - name: ENABLE_SIGNUP
              value: "true"
            - name: DEFAULT_LOCALE
              value: es
          resources:
            requests:
              cpu: "100m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          volumeMounts:
            - name: open-webui-data
              mountPath: /app/backend/data
      volumes:
        - name: open-webui-data
          persistentVolumeClaim:
            claimName: open-webui-data
K8SEOF
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'SVCINNER'
apiVersion: v1
kind: Service
metadata:
  name: open-webui
  namespace: sbos-ai
spec:
  selector:
    app: open-webui
  ports:
    - port: 8080
      targetPort: 8080
SVCINNER
    echo "${__STEP_OK__} aplicar_manifest_open-webui"

    echo "${__STEP_START__} esperar_open-webui_ready"
    _wait_ready 180 || { echo "${__STEP_FAIL__} esperar_open-webui_ready: timeout 180s"; return 1; }
    echo "${__STEP_OK__} esperar_open-webui_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_open-webui"
    local r
    r=$(_k get deployment open-webui -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) || { echo "${__STEP_FAIL__} verificar_open-webui: ${r}/1"; return 1; }
    echo "${__STEP_OK__} verificar_open-webui (${r}/1)"
    return 0
}

ficha_health() {
    local r
    r=$(_k get deployment open-webui -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: open-webui ${r}/1"
    return 1
}

ficha_repair() {
    _log "ficha_repair: re-aplicando manifests open-webui (idempotente)"
    ficha_install
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_open-webui_ready"
    local ready
    ready=$(_k get deployment open-webui -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_OK__} test_open-webui_ready (${ready}/1)"
    else
        echo "${__STEP_FAIL__} test_open-webui_ready: ${ready}/1"; ok=1
    fi
    return $ok
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_open-webui"
    _k delete deployment open-webui -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete service open-webui -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_open-webui"
    return 0
}
