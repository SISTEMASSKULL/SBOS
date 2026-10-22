#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — tryton-cron
# Proceso de tareas programadas de Tryton ERP (StatefulSet → tryton-cron-0).
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

_wait_sts_ready() {
    local sts="$1" ns="$2" timeout="${3:-120}" elapsed=0
    while (( elapsed < timeout )); do
        local ready
        ready=$(_k get statefulset "$sts" -n "$ns" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( ready >= 1 )) && return 0
        sleep 5; elapsed=$((elapsed + 5))
    done
    return 1
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"
    echo "${__STEP_START__} desplegar_tryton_cron"

    # Migrar Deployment→StatefulSet si existe el Deployment anterior
    if _k get deployment tryton-cron -n "$NS" >/dev/null 2>&1; then
        _log "Migrando Deployment→StatefulSet: eliminando Deployment tryton-cron"
        _k delete deployment tryton-cron -n "$NS" --wait=false 2>/dev/null || true
        _k delete svc tryton-cron -n "$NS" --ignore-not-found 2>/dev/null || true
    fi

    # Verificar si ya existe y está healthy
    local ready
    ready=$(_k get statefulset tryton-cron -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_SKIP__} desplegar_tryton_cron: StatefulSet ya Ready (${ready}/1)"
        return 0
    fi

    _k apply -f - >> "$FICHA_LOG" 2>&1 <<EOF
apiVersion: v1
kind: Service
metadata:
  name: tryton-cron
  namespace: ${NS}
  labels:
    app.kubernetes.io/name: tryton-cron
    app.kubernetes.io/component: erp-cron
    app.kubernetes.io/part-of: sbos
    app.kubernetes.io/managed-by: bos
spec:
  clusterIP: None
  selector:
    app.kubernetes.io/name: tryton-cron
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: tryton-cron
  namespace: ${NS}
  labels:
    app.kubernetes.io/name: tryton-cron
    app.kubernetes.io/component: erp-cron
    app.kubernetes.io/part-of: sbos
    app.kubernetes.io/managed-by: bos
spec:
  serviceName: tryton-cron
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: tryton-cron
  template:
    metadata:
      labels:
        app.kubernetes.io/name: tryton-cron
        app.kubernetes.io/component: erp-cron
        app.kubernetes.io/part-of: sbos
        app.kubernetes.io/managed-by: bos
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

    local rc=$?
    if (( rc != 0 )); then
        echo "${__STEP_FAIL__} desplegar_tryton_cron: kubectl apply falló (rc=${rc})"
        return 1
    fi

    _log "tryton-cron StatefulSet aplicado — esperando Ready"
    if ! _wait_sts_ready tryton-cron "$NS" 120; then
        echo "${__STEP_FAIL__} desplegar_tryton_cron: StatefulSet no Ready en 120s"
        return 1
    fi
    echo "${__STEP_OK__} desplegar_tryton_cron"
}

ficha_health() {
    local ready
    ready=$(_k get statefulset tryton-cron -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_OK__} health: tryton-cron-0 Ready (${ready}/1)"
        return 0
    fi
    echo "${__STEP_FAIL__} health: tryton-cron-0 no Ready"
    return 1
}

ficha_repair() {
    echo "${__STEP_START__} reiniciar_tryton_cron"
    _k rollout restart statefulset/tryton-cron -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} reiniciar_tryton_cron"
}

ficha_uninstall() {
    echo "${__STEP_START__} eliminar_tryton_cron"
    _k delete statefulset tryton-cron -n "$NS" --ignore-not-found 2>/dev/null || true
    _k delete service tryton-cron -n "$NS" --ignore-not-found 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_tryton_cron"
}

ficha_remove() { ficha_uninstall; }
