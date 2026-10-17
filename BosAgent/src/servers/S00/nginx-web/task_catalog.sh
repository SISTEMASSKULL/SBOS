#!/usr/bin/env bash
# task_catalog.sh — NGINX Web Server task handlers
# Ficha 01 · Order 050 · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/hostserver/nginx-web}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-installer}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/nginx-web.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Available deployment/nginx-web -n "${SBOS_NAMESPACE}" --timeout=300s
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
    kubectl rollout restart deployment nginx-web -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Available deployment/nginx-web -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart deployment nginx-web -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment nginx-web -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete service nginx-web -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete serviceaccount nginx-web-sa -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    local ready
    ready=$(kubectl get deployment nginx-web -n "${SBOS_NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [[ "$ready" -ge 1 ]]; then
        echo "nginx-web: HEALTHY ($ready/1 ready)"
        echo "${__SBOS__STEP_OK__} health"
    else
        echo "nginx-web: DEGRADED"
        echo "${__SBOS__STEP_FAIL__} health"
        return 1
    fi
}

# ── diagnosis ──────────────────────────────────────────────────
ficha_diagnosis() {
    echo "=== nginx-web Diagnosis ==="
    kubectl get deployment nginx-web -n "${SBOS_NAMESPACE}" 2>/dev/null || echo "  No Deployment"
    kubectl get pods -l app=nginx-web -n "${SBOS_NAMESPACE}" 2>/dev/null || echo "  No pods"
}
