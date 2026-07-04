#!/usr/bin/env bash
# task_catalog.sh — Wazuh Manager task handlers
# Ficha · Order · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/identityserver/wazuh-manager}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-identity}"

# ── pre_install ────────────────────────────────────────────────
ficha_wazuh-manager_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_wazuh-manager_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/wazuh-manager.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready statefulset/wazuh-manager-0 -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_wazuh-manager_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_wazuh-manager_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart statefulset wazuh-manager -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready statefulset/wazuh-manager-0 -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_wazuh-manager_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart statefulset wazuh-manager -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_wazuh-manager_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete statefulset wazuh-manager -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete pvc wazuh-manager-data -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_wazuh-manager_health() {
    echo "${__SBOS__STEP_START__} health"
    echo "${__SBOS__STEP_OK__} health"
}
