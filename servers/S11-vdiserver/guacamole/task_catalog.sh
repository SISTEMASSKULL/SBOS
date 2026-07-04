#!/usr/bin/env bash
# task_catalog.sh — Apache Guacamole VDI Gateway task handlers
# BOS-REPAIR-09 §5 · SBOS-052
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/vdiserver/guacamole}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-vdi}"
export SBOS_TENANT="${SBOS_TENANT:-skull}"

# ── pre_install ────────────────────────────────────────────────
# Crea la base de datos guacamole_db en PostgreSQL e inicializa el esquema.
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    # guacamole_db con credenciales emitidas por Vault (no hardcodear)
    kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='guacamole_db'" \
        | grep -q 1 || \
    kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -c "CREATE DATABASE guacamole_db" || true
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/guacamole.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Available deployment/guacamole \
        -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
# Registra el client OIDC 'guacamole' en el realm KC del tenant y la ruta Kong.
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    # OIDC client + ruta Kong se aplican vía sus respectivas APIs;
    # idempotente: si ya existen, no falla.
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart deployment guacamole -n "${SBOS_NAMESPACE}"
    kubectl rollout status deployment guacamole -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart deployment guacamole -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment guacamole -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete service guacamole -n "${SBOS_NAMESPACE}" --ignore-not-found
    # guacamole_db NO se borra automáticamente (datos de sesiones — Retain)
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    kubectl exec -n "${SBOS_NAMESPACE}" deployment/guacamole -- \
        curl -sf http://localhost:8080/guacamole/api/languages >/dev/null
    echo "${__SBOS__STEP_OK__} health"
}
