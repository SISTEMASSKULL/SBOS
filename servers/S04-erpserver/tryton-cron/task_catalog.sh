#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — tryton-cron
# Proceso de tareas programadas de Tryton ERP (trytond-cron).
# Comparte ConfigMap y credenciales con la ficha tryton principal.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/tryton-cron.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-erp"
TRYTON_VERSION="${TRYTON_VERSION:-7.4}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [tryton-cron] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_deploy_ready() {
    local deploy="$1" ns="$2" timeout="${3:-120}" elapsed=0
    while (( elapsed < timeout )); do
        local ready
        ready=$(_k get deployment "$deploy" -n "$ns" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( ready >= 1 )) && return 0
        sleep 5; elapsed=$((elapsed + 5))
    done
    return 1
}

# ── install ────────────────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"
    echo "${__STEP_START__} desplegar_tryton_cron"

    local ya_existe
    ya_existe=$(_k get deployment tryton-cron -n "$NS" --no-headers 2>/dev/null | wc -l || echo "0")
    if (( ya_existe > 0 )); then
        local ready
        ready=$(_k get deployment tryton-cron -n "$NS" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        if (( ready >= 1 )); then
            echo "${__STEP_SKIP__} desplegar_tryton_cron: ya existe y Ready (${ready}/1)"
            return 0
        fi
    fi

    _k apply -f - >> "$FICHA_LOG" 2>&1 <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tryton-cron
  namespace: ${NS}
  labels:
    app: tryton-cron
    app.kubernetes.io/part-of: erpserver
    sbos.app/managed-by: bos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tryton-cron
  template:
    metadata:
      labels:
        app: tryton-cron
    spec:
      serviceAccountName: tryton-sa
      containers:
        - name: cron
          image: tryton/tryton:${TRYTON_VERSION}
          command: ["/bin/bash", "-c"]
          args: ["while true; do trytond-cron -c /etc/tryton/trytond.conf -d tryton_db --timeout 60; sleep 5; done"]
          envFrom:
            - configMapRef:
                name: tryton-config
            - secretRef:
                name: tryton-pg-secret
          volumeMounts:
            - name: config
              mountPath: /etc/tryton
              readOnly: true
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
      volumes:
        - name: config
          configMap:
            name: tryton-config
            items:
              - key: trytond.conf
                path: trytond.conf
EOF

    rc=$?
    if (( rc != 0 )); then
        echo "${__STEP_FAIL__} desplegar_tryton_cron: kubectl apply falló (rc=${rc})"
        return 1
    fi

    _log "tryton-cron Deployment aplicado — esperando Ready"
    if ! _wait_deploy_ready tryton-cron "$NS" 120; then
        echo "${__STEP_FAIL__} desplegar_tryton_cron: Deployment no Ready en 120s"
        return 1
    fi
    echo "${__STEP_OK__} desplegar_tryton_cron"
}

# ── repair ─────────────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reiniciar_tryton_cron"
    _k rollout restart deployment/tryton-cron -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} reiniciar_tryton_cron"
}

# ── uninstall ──────────────────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__STEP_START__} eliminar_tryton_cron"
    _k delete deployment tryton-cron -n "$NS" --ignore-not-found 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_tryton_cron"
}

# ── health ─────────────────────────────────────────────────────────────────
ficha_health() {
    echo "${__STEP_START__} health"
    local ready
    ready=$(_k get deployment tryton-cron -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_OK__} health: tryton-cron Ready (${ready}/1)"
    else
        echo "${__STEP_FAIL__} health: tryton-cron no Ready"
        return 1
    fi
}
