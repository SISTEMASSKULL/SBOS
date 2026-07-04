#!/usr/bin/env bash
# task_catalog.sh — Certbot task handlers
# Ficha 12 · Order 142 · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/gatewayserver/certbot}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-gateway}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/certbot.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Available deployment/certbot -n "${SBOS_NAMESPACE}" --timeout=300s
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
    kubectl rollout restart deployment certbot -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Available deployment/certbot -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart deployment certbot -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment certbot -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete service certbot -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete serviceaccount certbot-sa -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    if kubectl get deployment certbot -n "${SBOS_NAMESPACE}" &>/dev/null; then
        local ready
        ready=$(kubectl get deployment certbot -n "${SBOS_NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        if [[ "$ready" -ge 1 ]]; then
            echo "certbot: HEALTHY ($ready/1 ready)"
            echo "${__SBOS__STEP_OK__} health"
        else
            echo "certbot: DEGRADED ($ready/1 ready)"
            echo "${__SBOS__STEP_FAIL__} health"
            return 1
        fi
    else
        echo "certbot: NOT INSTALLED"
        echo "${__SBOS__STEP_FAIL__} health"
        return 1
    fi
}
