#!/usr/bin/env bash
# task_catalog.sh — Fedora KDE Desktop task handlers
# Ficha · Order · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/vdiserver/fedora-kde}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-vdi}"

# ── pre_install ────────────────────────────────────────────────
ficha_fedora-kde_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_fedora-kde_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/fedora-kde.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready deployment/fedora-kde-0 -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_fedora-kde_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_fedora-kde_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart deployment fedora-kde -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready deployment/fedora-kde-0 -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_fedora-kde_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart deployment fedora-kde -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_fedora-kde_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment fedora-kde -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_fedora-kde_health() {
    echo "${__SBOS__STEP_START__} health"
    echo "${__SBOS__STEP_OK__} health"
}
