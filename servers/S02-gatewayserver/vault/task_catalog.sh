#!/usr/bin/env bash
# task_catalog.sh — HashiCorp Vault task handlers
# Ficha 08 · Order 120 · SBOS-019 §9

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/dataserver/vault}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-security}"

ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"
    echo "${__SBOS__STEP_OK__} pre_install"
}

ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/vault.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready pod/vault-0 -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} install"
}

ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "${__SBOS__STEP_OK__} post_install"
}

ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart statefulset vault -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready pod/vault-0 -n "${SBOS_NAMESPACE}" --timeout=120s
    echo "${__SBOS__STEP_OK__} update"
}

ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl delete pod vault-0 -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl wait --for=condition=Ready pod/vault-0 -n "${SBOS_NAMESPACE}" --timeout=120s
    echo "${__SBOS__STEP_OK__} repair"
}

ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete statefulset vault -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete pvc data-vault-0 -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    kubectl exec vault-0 -n "${SBOS_NAMESPACE}" -- vault status 2>/dev/null | head -5
    echo "${__SBOS__STEP_OK__} health"
}
