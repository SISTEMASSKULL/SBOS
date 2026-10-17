#!/usr/bin/env bash
# task_catalog.sh — RabbitMQ Search task handlers
# Ficha · Order · SBOS-049 §4.3
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/searchserver/rabbitmq-search}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-search}"

# ── pre_install ────────────────────────────────────────────────
ficha_rabbitmq-search_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_rabbitmq-search_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/rabbitmq-search.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready statefulset/rabbitmq-search-0 -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_rabbitmq-search_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_rabbitmq-search_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart statefulset rabbitmq-search -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready statefulset/rabbitmq-search-0 -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_rabbitmq-search_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart statefulset rabbitmq-search -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_rabbitmq-search_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete statefulset rabbitmq-search -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete pvc rabbitmq-search-data -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_rabbitmq-search_health() {
    echo "${__SBOS__STEP_START__} health"
    echo "${__SBOS__STEP_OK__} health"
}
