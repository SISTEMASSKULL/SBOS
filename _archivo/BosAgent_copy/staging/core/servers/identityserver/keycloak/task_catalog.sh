#!/usr/bin/env bash
# task_catalog.sh — Keycloak 26.x IAM task handlers
# Ficha 09 · Order 130 · SBOS-019 §9
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/identityserver/keycloak}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-identity}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"

    # Create keycloak_db in postgresql if not exists
    kubectl exec postgresql-0 -n sbos-data -- psql -U postgres -c "CREATE DATABASE keycloak_db;" 2>/dev/null || true

    # Get postgresql password and create keycloak secret
    local pg_pass
    pg_pass=$(kubectl get secret postgresql-secret -n sbos-data -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "")
    if [[ -z "$pg_pass" ]]; then
        pg_pass="sbos-pg-pass"
    fi
    kubectl create secret generic keycloak-secret -n "${SBOS_NAMESPACE}" \
        --from-literal=db-password="$pg_pass" \
        --from-literal=admin-password="admin123" \
        --dry-run=client -o yaml | kubectl apply -f -

    # Create sbos-dns ConfigMap
    kubectl create configmap sbos-dns -n "${SBOS_NAMESPACE}" \
        --from-literal=auth_fqdn="keycloak.sbos-identity.svc.cluster.local" \
        --dry-run=client -o yaml | kubectl apply -f -

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/keycloak.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready pod/keycloak-0 -n "${SBOS_NAMESPACE}" --timeout=600s
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
    kubectl rollout restart statefulset keycloak -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready pod/keycloak-0 -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl delete pod keycloak-0 -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete statefulset keycloak -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete pvc data-keycloak-0 -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete secret keycloak-secret -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    curl -sf http://localhost:9000/health/live
    echo "${__SBOS__STEP_OK__} health"
}
