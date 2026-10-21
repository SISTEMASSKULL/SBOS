#!/usr/bin/env bash
# task_catalog.sh — Cypht Webmail task handlers
# Ficha · Order · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S10-commsserver/cypht}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-comms}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"

    # 1. Namespace y ServiceAccount
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"
    kubectl create serviceaccount cypht-sa -n "${SBOS_NAMESPACE}" \
        --dry-run=client -o yaml | kubectl apply -f -

    # 2. Secret con password de BD (evita plaintext en manifest)
    local pg_pass="${SBOS_PG_CYPHT_PASS:-sbos_bootstrap_pass}"
    kubectl create secret generic cypht-db-secret \
        -n "${SBOS_NAMESPACE}" \
        --from-literal=password="${pg_pass}" \
        --dry-run=client -o yaml | kubectl apply -f -

    # 3. Crear base de datos cypht_db en PostgreSQL si no existe
    local pg_pod
    pg_pod=$(kubectl get pod -n sbos-data -l app=postgresql \
        --field-selector=status.phase=Running \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -z "${pg_pod}" ]; then
        echo "ADVERTENCIA: pod postgresql no encontrado en sbos-data — cypht_db no creada"
    else
        kubectl exec "${pg_pod}" -n sbos-data -- \
            psql -U postgres -c "CREATE DATABASE cypht_db;" 2>/dev/null || true
        kubectl exec "${pg_pod}" -n sbos-data -- \
            psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE cypht_db TO postgres;" 2>/dev/null || true
        echo "cypht_db creada (o ya existía)"
    fi

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/cypht.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl rollout status deployment/cypht-0 -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart deployment cypht -n "${SBOS_NAMESPACE}"
    kubectl rollout status deployment/cypht-0 -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"

    # Re-verificar que cypht_db existe (puede haberse perdido por re-instalación de PostgreSQL)
    local pg_pod
    pg_pod=$(kubectl get pod -n sbos-data -l app=postgresql \
        --field-selector=status.phase=Running \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "${pg_pod}" ]; then
        kubectl exec "${pg_pod}" -n sbos-data -- \
            psql -U postgres -c "CREATE DATABASE cypht_db;" 2>/dev/null || true
    fi

    kubectl rollout restart deployment cypht -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment cypht -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    local ready
    ready=$(kubectl get deployment cypht -n "${SBOS_NAMESPACE}" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    ready="${ready:-0}"
    if [ "${ready}" -lt 1 ] 2>/dev/null; then
        echo "FALLO: cypht sin réplicas listas (ready=${ready})"
        exit 1
    fi
    echo "${__SBOS__STEP_OK__} health"
}
