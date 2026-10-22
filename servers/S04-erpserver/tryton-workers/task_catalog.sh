#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — tryton-workers
# Workers de cola asíncrona de Tryton ERP (StatefulSet → tryton-workers-0/1).
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

_wait_sts_ready() {
    local sts="$1" ns="$2" expected="$3" timeout="${4:-120}" elapsed=0
    while (( elapsed < timeout )); do
        local ready
        ready=$(_k get statefulset "$sts" -n "$ns" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( ready >= expected )) && return 0
        sleep 5; elapsed=$((elapsed + 5))
        (( elapsed % 30 == 0 )) && _log "Esperando $sts Ready... ${elapsed}/${timeout}s (${ready}/${expected})"
    done
    return 1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_tryton_instalado"
    local st_ready
    st_ready=$(_k get statefulset tryton -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( st_ready < 1 )); then
        echo "${__STEP_FAIL__} verificar_tryton_instalado: StatefulSet tryton no está Ready"
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

    # Migrar Deployment→StatefulSet si existe el Deployment anterior
    if _k get statefulset tryton-workers -n "$NS" >/dev/null 2>&1; then
        _log "Migrando Deployment→StatefulSet: eliminando Deployment tryton-workers"
        _k delete statefulset tryton-workers -n "$NS" --wait=false 2>/dev/null || true
    fi

    # Verificar si ya existe y está healthy
    local ready
    ready=$(_k get statefulset tryton-workers -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 2 )); then
        echo "${__STEP_SKIP__} desplegar_tryton_workers: StatefulSet ya Ready (${ready}/2)"
        return 0
    fi

    _k apply -f - >> "$FICHA_LOG" 2>&1 <<EOF
apiVersion: v1
kind: Service
metadata:
  name: tryton-workers
  namespace: ${NS}
  labels:
    app.kubernetes.io/name: tryton-workers
    app.kubernetes.io/component: erp-worker
    app.kubernetes.io/part-of: sbos
    app.kubernetes.io/managed-by: bos
spec:
  clusterIP: None
  selector:
    app.kubernetes.io/name: tryton-workers
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: tryton-workers
  namespace: ${NS}
  labels:
    app.kubernetes.io/name: tryton-workers
    app.kubernetes.io/component: erp-worker
    app.kubernetes.io/part-of: sbos
    app.kubernetes.io/managed-by: bos
spec:
  serviceName: tryton-workers
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: tryton-workers
  template:
    metadata:
      labels:
        app.kubernetes.io/name: tryton-workers
        app.kubernetes.io/component: erp-worker
        app.kubernetes.io/part-of: sbos
        app.kubernetes.io/managed-by: bos
    spec:
      serviceAccountName: tryton-sa
      containers:
        - name: worker
          image: tryton/tryton:${TRYTON_VERSION}
          command: ["/bin/bash", "-c"]
          args: ["while true; do trytond-worker -c /etc/tryton/trytond.conf -d tryton_db --timeout 60; sleep 5; done"]
          volumeMounts:
            - name: config
              mountPath: /etc/tryton
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
            items:
              - key: trytond.conf
                path: trytond.conf
EOF

    local rc=$?
    if (( rc != 0 )); then
        echo "${__STEP_FAIL__} desplegar_tryton_workers: kubectl apply falló (rc=${rc})"
        return 1
    fi

    _log "tryton-workers StatefulSet aplicado — esperando Ready"
    if ! _wait_sts_ready tryton-workers "$NS" 2 120; then
        echo "${__STEP_FAIL__} desplegar_tryton_workers: StatefulSet no Ready en 120s"
        return 1
    fi
    echo "${__STEP_OK__} desplegar_tryton_workers"
    return 0
}

ficha_health() {
    local ready
    ready=$(_k get statefulset tryton-workers -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 2 )); then
        echo "${__STEP_OK__} health: tryton-workers-0/1 Ready (${ready}/2)"
        return 0
    fi
    echo "${__STEP_FAIL__} health: tryton-workers ${ready}/2 Ready"
    return 1
}

ficha_repair() {
    echo "${__STEP_START__} reiniciar_tryton_workers"
    _k rollout restart statefulset/tryton-workers -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} reiniciar_tryton_workers"
}

ficha_uninstall() {
    echo "${__STEP_START__} eliminar_tryton_workers"
    _k delete statefulset tryton-workers -n "$NS" --ignore-not-found 2>/dev/null || true
    _k delete service tryton-workers -n "$NS" --ignore-not-found 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_tryton_workers"
}

ficha_remove() { ficha_uninstall; }
