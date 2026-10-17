#!/usr/bin/env bash
# task_catalog.sh — OAuth2-Proxy task handlers
# Ficha · Order · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/identityserver/oauth2-proxy}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-identity}"

# ── pre_install ────────────────────────────────────────────────
ficha_oauth2-proxy_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_oauth2-proxy_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/oauth2-proxy.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready deployment/oauth2-proxy-0 -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_oauth2-proxy_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_oauth2-proxy_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart deployment oauth2-proxy -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready deployment/oauth2-proxy-0 -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_oauth2-proxy_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart deployment oauth2-proxy -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_oauth2-proxy_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment oauth2-proxy -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_oauth2-proxy_health() {
    echo "${__SBOS__STEP_START__} health"
    echo "${__SBOS__STEP_OK__} health"
}
