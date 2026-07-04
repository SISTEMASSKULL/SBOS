#!/usr/bin/env bash
# task_catalog.sh — bCompass Service task handlers
# Ficha · Order · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/aiserver/bcompass-svc}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-ai}"

# ── pre_install ────────────────────────────────────────────────
ficha_bcompass-svc_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_bcompass-svc_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/bcompass-svc.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready deployment/bcompass-svc-0 -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_bcompass-svc_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_bcompass-svc_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart deployment bcompass-svc -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready deployment/bcompass-svc-0 -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_bcompass-svc_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart deployment bcompass-svc -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_bcompass-svc_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment bcompass-svc -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_bcompass-svc_health() {
    echo "${__SBOS__STEP_START__} health"
    echo "${__SBOS__STEP_OK__} health"
}
