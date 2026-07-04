#!/usr/bin/env bash
# task_catalog.sh — Kong Gateway 3.9 task handlers
# Ficha 11 · Order 145 · SBOS-019 §9
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/gatewayserver/kong}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-gateway}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"

    # Create kong_db in postgresql
    kubectl exec postgresql-0 -n sbos-data -- psql -U postgres -c "CREATE DATABASE kong_db;" 2>/dev/null || true

    # Get postgresql password and create kong secret
    local pg_pass
    pg_pass=$(kubectl get secret postgresql-secret -n sbos-data -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "sbos-pg-pass")
    kubectl create secret generic kong-secret -n "${SBOS_NAMESPACE}" \
        --from-literal=db-password="$pg_pass" \
        --dry-run=client -o yaml | kubectl apply -f -

    echo "${__SBOS__STEP_OK__} pre_install"
}

ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/kong.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Available deployment/kong -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/kong.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Available deployment/kong -n "${SBOS_NAMESPACE}" --timeout=300s
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
    kubectl rollout restart deployment kong -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Available deployment/kong -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart deployment kong -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete deployment kong -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete service kong -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete secret kong-secret -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    curl -sf http://localhost:8001/status
    echo "${__SBOS__STEP_OK__} health"
}
