#!/usr/bin/env bash
# task_catalog.sh — Tesseract + EasyOCR task handlers
# Ficha · Order · SBOS-049 §4.3

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S08-docserver/tesseract}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-docs}"

ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"
    sbos_ensure_serviceaccount "tesseract-sa" "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} pre_install"
}

ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/tesseract.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl rollout status deployment/tesseract -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "${__SBOS__STEP_OK__} post_install"
}

ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart deployment tesseract -n "${SBOS_NAMESPACE}"
    kubectl rollout status deployment/tesseract -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart deployment tesseract -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment tesseract -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    if ! sbos_health_deployment "tesseract" "${SBOS_NAMESPACE}"; then exit 1; fi
    echo "${__SBOS__STEP_OK__} health"
}
