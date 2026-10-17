#!/usr/bin/env bash
# task_catalog.sh — Rancher Local Path Provisioner
# Provisionador dinámico de volúmenes locales para sbos-local-path StorageClass

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/hostserver/local-path-provisioner}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-kube-system}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    mkdir -p /opt/local-path-provisioner
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/local-path-provisioner.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Available deployment/local-path-provisioner -n "${SBOS_NAMESPACE}" --timeout=120s
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    kubectl get pods -n kube-system -l app=local-path-provisioner
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart deployment local-path-provisioner -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Available deployment/local-path-provisioner -n "${SBOS_NAMESPACE}" --timeout=120s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    sbos_k8s_core "${SBOS_FICHA_DIR}/local-path-provisioner.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Available deployment/local-path-provisioner -n "${SBOS_NAMESPACE}" --timeout=60s
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment local-path-provisioner -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete clusterrolebinding local-path-provisioner-binding --ignore-not-found
    kubectl delete clusterrole local-path-provisioner-role --ignore-not-found
    kubectl delete configmap local-path-provisioner-config -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete serviceaccount local-path-provisioner-sa -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    kubectl get pods -n kube-system -l app=local-path-provisioner --field-selector=status.phase=Running --no-headers | grep -q .
    echo "${__SBOS__STEP_OK__} health"
}
