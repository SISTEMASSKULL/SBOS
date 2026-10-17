#!/usr/bin/env bash
# task_catalog.sh — Linkerd Service Mesh task handlers
# Ficha 04 · Order 060 · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/hostserver/linkerd}"
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
    sbos_k8s_core "${SBOS_FICHA_DIR}/linkerd.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready pod -l app=linkerd -n "${SBOS_NAMESPACE}" --timeout=300s
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
    kubectl rollout restart daemonset linkerd -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready pod -l app=linkerd -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart daemonset linkerd -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete daemonset linkerd -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete service linkerd -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete serviceaccount linkerd-sa -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    local ready
    ready=$(kubectl get daemonset linkerd -n "${SBOS_NAMESPACE}" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
    if [[ "$ready" -ge 1 ]]; then
        echo "linkerd: HEALTHY ($ready ready)"
        echo "${__SBOS__STEP_OK__} health"
    else
        echo "linkerd: DEGRADED"
        echo "${__SBOS__STEP_FAIL__} health"
        return 1
    fi
}

# ── diagnosis ──────────────────────────────────────────────────
ficha_diagnosis() {
    echo "=== Linkerd Diagnosis ==="
    kubectl get daemonset linkerd -n "${SBOS_NAMESPACE}" 2>/dev/null || echo "  No DaemonSet"
    kubectl get pods -l app=linkerd -n "${SBOS_NAMESPACE}" 2>/dev/null || echo "  No pods"
}
