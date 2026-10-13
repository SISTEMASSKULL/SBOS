#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — paperless-ngx
# Imagen: ghcr.io/paperless-ngx/paperless-ngx:2.14.7
# Namespace: sbos-docs
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/paperless-ngx.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-docs"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [paperless-ngx] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_ready() {
    local t="${1:-180}" e=0
    while (( e < t )); do
        local r
        r=$(_k get deployment paperless-ngx -n "$NS" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5))
        (( e % 30 == 0 )) && _log "Esperando paperless-ngx Ready... ${e}/${t}s"
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
    r=$(_k get deployment paperless-ngx -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r >= 1 )); then
        echo "${__STEP_SKIP__} paperless-ngx_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} crear_pvcs_paperless"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'PVCEOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: paperless-media
  namespace: sbos-docs
  labels:
    app: paperless-ngx
    sbos.app/managed-by: bos
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: local-path
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: paperless-data
  namespace: sbos-docs
  labels:
    app: paperless-ngx
    sbos.app/managed-by: bos
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi
PVCEOF
    echo "${__STEP_OK__} crear_pvcs_paperless"

    echo "${__STEP_START__} aplicar_manifest_paperless-ngx"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: paperless-ngx
  namespace: sbos-docs
  labels:
    app: paperless-ngx
    sbos.app/managed-by: bos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: paperless-ngx
  template:
    metadata:
      labels:
        app: paperless-ngx
    spec:
      containers:
        - name: paperless-ngx
          image: ghcr.io/paperless-ngx/paperless-ngx:2.14.7
          ports:
            - containerPort: 8000
          env:
            - name: PAPERLESS_REDIS
              value: redis://:sbos_redis_bootstrap@redis.sbos-data.svc.cluster.local:6379/4
            - name: PAPERLESS_DBHOST
              value: postgresql.sbos-data.svc.cluster.local
            - name: PAPERLESS_DBNAME
              value: paperless_db
            - name: PAPERLESS_DBUSER
              value: postgres
            - name: PAPERLESS_SECRET_KEY
              value: sbos_paperless_secret_key_change_in_prod
            - name: PAPERLESS_URL
              value: https://paperless.sbos.local
          resources:
            requests:
              cpu: "100m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          volumeMounts:
            - name: paperless-media
              mountPath: /usr/src/paperless/media
            - name: paperless-data
              mountPath: /usr/src/paperless/data
      volumes:
        - name: paperless-media
          persistentVolumeClaim:
            claimName: paperless-media
        - name: paperless-data
          persistentVolumeClaim:
            claimName: paperless-data
K8SEOF
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'SVCINNER'
apiVersion: v1
kind: Service
metadata:
  name: paperless-ngx
  namespace: sbos-docs
spec:
  selector:
    app: paperless-ngx
  ports:
    - port: 8000
      targetPort: 8000
SVCINNER
    echo "${__STEP_OK__} aplicar_manifest_paperless-ngx"

    echo "${__STEP_START__} esperar_paperless-ngx_ready"
    _wait_ready 180 || { echo "${__STEP_FAIL__} esperar_paperless-ngx_ready: timeout 180s"; return 1; }
    echo "${__STEP_OK__} esperar_paperless-ngx_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_paperless-ngx"
    local r
    r=$(_k get deployment paperless-ngx -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) || { echo "${__STEP_FAIL__} verificar_paperless-ngx: ${r}/1"; return 1; }
    echo "${__STEP_OK__} verificar_paperless-ngx (${r}/1)"
    return 0
}

ficha_health() {
    local r
    r=$(_k get deployment paperless-ngx -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: paperless-ngx ${r}/1"
    return 1
}

ficha_repair() {
    _log "ficha_repair: re-aplicando manifests paperless-ngx (idempotente)"
    ficha_install
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_paperless-ngx"
    _k delete deployment paperless-ngx -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete service paperless-ngx -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_paperless-ngx"
    return 0
}
