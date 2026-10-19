#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — tryton-workers
# Workers de cola asíncrona de Tryton ERP.
# Comparte ConfigMap y credenciales con la ficha tryton principal.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/tryton-workers.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-erp"
TRYTON_VERSION="${TRYTON_VERSION:-8.0}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [tryton-workers] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_deploy_ready() {
    local deploy="$1" ns="$2" timeout="${3:-120}" elapsed=0
    while (( elapsed < timeout )); do
        local ready
        ready=$(_k get deployment "$deploy" -n "$ns" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( ready >= 2 )) && return 0
        sleep 5; elapsed=$((elapsed + 5))
        (( elapsed % 30 == 0 )) && _log "Esperando $deploy Ready... ${elapsed}/${timeout}s (${ready}/2)"
    done
    return 1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_tryton_instalado"
    local st_ready
    st_ready=$(_k get statefulset tryton -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( st_ready < 1 )); then
        echo "${__STEP_FAIL__} verificar_tryton_instalado: StatefulSet tryton no está Ready — instalar tryton primero"
        return 1
    fi
    echo "${__STEP_OK__} verificar_tryton_instalado (readyReplicas=${st_ready})"

    echo "${__STEP_START__} verificar_configmap_tryton"
    if ! _k get configmap tryton-config -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_configmap_tryton: ConfigMap tryton-config no existe"
        return 1
    fi
    echo "${__STEP_OK__} verificar_configmap_tryton"
    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    echo "${__STEP_START__} desplegar_tryton_workers"

    local ya_existe
    ya_existe=$(_k get deployment tryton-workers -n "$NS" --no-headers 2>/dev/null | wc -l || echo "0")
    if (( ya_existe > 0 )); then
        local ready
        ready=$(_k get deployment tryton-workers -n "$NS" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        if (( ready >= 2 )); then
            echo "${__STEP_SKIP__} desplegar_tryton_workers: ya existe y Ready (${ready}/2)"
            return 0
        fi
    fi

    _k apply -f - >> "$FICHA_LOG" 2>&1 <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tryton-workers
  namespace: ${NS}
  labels:
    app: tryton-workers
    app.kubernetes.io/part-of: erpserver
    sbos.app/managed-by: bos
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tryton-workers
  template:
    metadata:
      labels:
        app: tryton-workers
    spec:
      serviceAccountName: tryton-sa
      containers:
        - name: worker
          image: tryton/tryton:${TRYTON_VERSION}
          command: ["/bin/bash", "-c"]
          args: ["while true; do trytond-worker -c /etc/trytond.conf -d tryton_db --timeout 60; sleep 5; done"]
          volumeMounts:
            - name: config
              mountPath: /etc/trytond.conf
              subPath: trytond.conf
              readOnly: true
          envFrom:
            - configMapRef:
                name: tryton-config
            - secretRef:
                name: tryton-pg-secret
          resources:
            requests:
              cpu: "100m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
      volumes:
        - name: config
          configMap:
            name: tryton-config
EOF

    if ! _wait_deploy_ready tryton-workers "$NS" 120; then
        echo "${__STEP_FAIL__} desplegar_tryton_workers: Deployment no Ready en 120s"
        return 1
    fi
    echo "${__STEP_OK__} desplegar_tryton_workers"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_workers_ready"
    local ready
    ready=$(_k get deployment tryton-workers -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready < 2 )); then
        echo "${__STEP_FAIL__} verificar_workers_ready: ${ready}/2 workers Ready"
        return 1
    fi
    echo "${__STEP_OK__} verificar_workers_ready (${ready}/2)"
    return 0
}

ficha_health() {
    local ready
    ready=$(_k get deployment tryton-workers -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 2 )); then
        echo "HEALTHY"
        return 0
    fi
    echo "DEGRADED: ${ready}/2 workers Ready"
    return 1
}

ficha_post_install() {
    # Evitar post_install_generic (usa namespace default con label errado)
    return 0
}

ficha_repair() {
    _log "ficha_repair: re-aplicando manifests tryton-workers (idempotente)"
    ficha_install
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_tryton_workers_ready"
    local ready
    ready=$(_k get deployment tryton-workers -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_OK__} test_tryton_workers_ready (${ready}/2)"
    else
        echo "${__STEP_FAIL__} test_tryton_workers_ready: ${ready}/2"; ok=1
    fi
    return $ok
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_tryton_workers"
    _k delete deployment tryton-workers -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_tryton_workers"
    return 0
}
