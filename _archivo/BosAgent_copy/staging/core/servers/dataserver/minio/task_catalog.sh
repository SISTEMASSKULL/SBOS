#!/usr/bin/env bash
# task_catalog.sh — MinIO Object Storage task handlers
# Ficha 07 · Order 115 · SBOS-019 §9

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/dataserver/minio}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-data}"

ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    echo "${__SBOS__STEP_OK__} pre_install"
}

ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/minio.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready pod/minio-0 -n "${SBOS_NAMESPACE}" --timeout=120s
    echo "${__SBOS__STEP_OK__} install"
}

ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    curl -sf http://localhost:9000/minio/health/live || true
    echo "${__SBOS__STEP_OK__} post_install"
}

ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart statefulset minio -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready pod/minio-0 -n "${SBOS_NAMESPACE}" --timeout=120s
    echo "${__SBOS__STEP_OK__} update"
}

ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl delete pod minio-0 -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl wait --for=condition=Ready pod/minio-0 -n "${SBOS_NAMESPACE}" --timeout=120s
    echo "${__SBOS__STEP_OK__} repair"
}

ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete statefulset minio -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete pvc minio-data -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    curl -sf http://localhost:9000/minio/health/live
    echo "${__SBOS__STEP_OK__} health"
}
