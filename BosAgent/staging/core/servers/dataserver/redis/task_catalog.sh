#!/usr/bin/env bash
# task_catalog.sh — Redis task handlers
# Ficha 06 · Order 110 · SBOS-019 §9

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/dataserver/redis}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-data}"

ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    echo "${__SBOS__STEP_OK__} pre_install"
}

ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/redis.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready pod/redis-0 -n "${SBOS_NAMESPACE}" --timeout=120s
    echo "${__SBOS__STEP_OK__} install"
}

ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    kubectl exec redis-0 -n "${SBOS_NAMESPACE}" -- redis-cli ping | grep -q PONG
    echo "${__SBOS__STEP_OK__} post_install"
}

ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart statefulset redis -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready pod/redis-0 -n "${SBOS_NAMESPACE}" --timeout=120s
    echo "${__SBOS__STEP_OK__} update"
}

ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl delete pod redis-0 -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl wait --for=condition=Ready pod/redis-0 -n "${SBOS_NAMESPACE}" --timeout=120s
    echo "${__SBOS__STEP_OK__} repair"
}

ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete statefulset redis -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete pvc redis-data -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    kubectl exec redis-0 -n "${SBOS_NAMESPACE}" -- redis-cli ping | grep -q PONG
    echo "${__SBOS__STEP_OK__} health"
}
