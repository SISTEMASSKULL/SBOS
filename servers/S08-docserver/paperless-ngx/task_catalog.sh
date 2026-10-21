#!/usr/bin/env bash
# task_catalog.sh — Paperless-NGX task handlers
# Ficha · Order · SBOS-049 §4.3

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S08-docserver/paperless-ngx}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-docs}"

ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"
    sbos_ensure_serviceaccount "paperless-ngx-sa" "${SBOS_NAMESPACE}"
    sbos_ensure_pg_database "paperless_db"
    local pg_pod
    pg_pod=$(kubectl get pod -n sbos-data -l app=postgresql \
        --field-selector=status.phase=Running \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [[ -n "${pg_pod}" ]]; then
        kubectl exec "${pg_pod}" -n sbos-data -- \
            psql -U postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='paperless'" 2>/dev/null \
            | grep -q 1 || \
        kubectl exec "${pg_pod}" -n sbos-data -- \
            psql -U postgres -c "CREATE USER paperless WITH PASSWORD 'paperless_pass';" 2>/dev/null || true
        kubectl exec "${pg_pod}" -n sbos-data -- \
            psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE paperless_db TO paperless;" 2>/dev/null || true
    fi
    echo "${__SBOS__STEP_OK__} pre_install"
}

ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/paperless-ngx.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl rollout status statefulset/paperless-ngx -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    echo "${__SBOS__STEP_OK__} post_install"
}

ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart statefulset paperless-ngx -n "${SBOS_NAMESPACE}"
    kubectl rollout status statefulset/paperless-ngx -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    sbos_ensure_pg_database "paperless_db"
    kubectl rollout restart statefulset paperless-ngx -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete statefulset paperless-ngx -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete pvc paperless-ngx-data -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    if ! sbos_health_statefulset "paperless-ngx" "${SBOS_NAMESPACE}"; then exit 1; fi
    echo "${__SBOS__STEP_OK__} health"
}
