#!/usr/bin/env bash
# task_catalog.sh — pg_partman task handlers
# Ficha · Order · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S01-dataserver/pg-partman}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-data}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"
    sbos_ensure_serviceaccount "pg-partman-sa" "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/pg-partman.k8s.yml" "${SBOS_NAMESPACE}"
    # El YAML crea un CronJob — verificar que exista
    kubectl get cronjob pg-partman -n "${SBOS_NAMESPACE}" >/dev/null
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
    sbos_k8s_core "${SBOS_FICHA_DIR}/pg-partman.k8s.yml" "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    sbos_k8s_core "${SBOS_FICHA_DIR}/pg-partman.k8s.yml" "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete cronjob pg-partman -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete serviceaccount pg-partman-sa -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    kubectl get cronjob pg-partman -n "${SBOS_NAMESPACE}" >/dev/null
    echo "${__SBOS__STEP_OK__} health"
}
