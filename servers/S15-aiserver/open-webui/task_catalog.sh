#!/usr/bin/env bash
# task_catalog.sh — Open WebUI task handlers
# Ficha · Order · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/aiserver/open-webui}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-ai}"

# ── pre_install ────────────────────────────────────────────────
ficha_open-webui_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_open-webui_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/open-webui.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready deployment/open-webui-0 -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_open-webui_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_open-webui_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart deployment open-webui -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready deployment/open-webui-0 -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_open-webui_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart deployment open-webui -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_open-webui_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment open-webui -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_open-webui_health() {
    echo "${__SBOS__STEP_START__} health"
    echo "${__SBOS__STEP_OK__} health"
}
