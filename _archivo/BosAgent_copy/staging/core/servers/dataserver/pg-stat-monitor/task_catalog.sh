#!/usr/bin/env bash
# task_catalog.sh — pg_stat_monitor task handlers
# Ficha · Order · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/dataserver/pg-stat-monitor}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-data}"

# ── pre_install ────────────────────────────────────────────────
ficha_pg-stat-monitor_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_pg-stat-monitor_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/pg-stat-monitor.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready deployment/pg-stat-monitor-0 -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_pg-stat-monitor_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_pg-stat-monitor_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart deployment pg-stat-monitor -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready deployment/pg-stat-monitor-0 -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_pg-stat-monitor_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart deployment pg-stat-monitor -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_pg-stat-monitor_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment pg-stat-monitor -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_pg-stat-monitor_health() {
    echo "${__SBOS__STEP_START__} health"
    echo "${__SBOS__STEP_OK__} health"
}
