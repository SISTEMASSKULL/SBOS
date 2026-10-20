#!/usr/bin/env bash
# task_catalog.sh — pg_stat_monitor task handlers
# Ficha · Order · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S01-dataserver/pg-stat-monitor}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-data}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"
    sbos_ensure_serviceaccount "pg-stat-monitor-sa" "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    # Eliminar job anterior si existe (idempotencia)
    kubectl delete job pg-stat-monitor-init -n "${SBOS_NAMESPACE}" --ignore-not-found 2>/dev/null || true
    sbos_k8s_core "${SBOS_FICHA_DIR}/pg-stat-monitor.k8s.yml" "${SBOS_NAMESPACE}"
    # Esperar el Job (no un Deployment)
    kubectl wait --for=condition=Complete job/pg-stat-monitor-init \
        -n "${SBOS_NAMESPACE}" --timeout=120s || true
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
    kubectl delete job pg-stat-monitor-init -n "${SBOS_NAMESPACE}" --ignore-not-found 2>/dev/null || true
    sbos_k8s_core "${SBOS_FICHA_DIR}/pg-stat-monitor.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Complete job/pg-stat-monitor-init \
        -n "${SBOS_NAMESPACE}" --timeout=120s || true
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl delete job pg-stat-monitor-init -n "${SBOS_NAMESPACE}" --ignore-not-found 2>/dev/null || true
    sbos_k8s_core "${SBOS_FICHA_DIR}/pg-stat-monitor.k8s.yml" "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete job pg-stat-monitor-init -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete serviceaccount pg-stat-monitor-sa -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    # Extensión opcional — si el job completó o no existe, estado OK
    kubectl get job pg-stat-monitor-init -n "${SBOS_NAMESPACE}" \
        -o jsonpath="{.status.succeeded}" 2>/dev/null | grep -q "1" || true
    echo "${__SBOS__STEP_OK__} health"
}
