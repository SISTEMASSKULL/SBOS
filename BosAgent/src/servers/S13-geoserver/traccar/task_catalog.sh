#!/usr/bin/env bash
# task_catalog.sh — Traccar GPS task handlers
# Ficha · Order · SBOS-049 §4.3

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S13-geoserver/traccar}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-geo}"

ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"
    sbos_ensure_serviceaccount "traccar-sa" "${SBOS_NAMESPACE}"
    sbos_ensure_pg_database "traccar_db"
    echo "${__SBOS__STEP_OK__} pre_install"
}

ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/traccar.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl rollout status deployment/traccar -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "${__SBOS__STEP_OK__} post_install"
}

ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart deployment traccar -n "${SBOS_NAMESPACE}"
    kubectl rollout status deployment/traccar -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    sbos_ensure_pg_database "traccar_db"
    kubectl rollout restart deployment traccar -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment traccar -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    if ! sbos_health_deployment "traccar" "${SBOS_NAMESPACE}"; then exit 1; fi
    echo "${__SBOS__STEP_OK__} health"
}
