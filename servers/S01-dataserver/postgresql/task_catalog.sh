#!/usr/bin/env bash
# task_catalog.sh — PostgreSQL 18 + Patroni HA task handlers
# Ficha 05 · Order 100 · SBOS-019 §9
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S01-dataserver/postgresql}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-data}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"
    kubectl create secret generic postgresql-secret -n "${SBOS_NAMESPACE}" \
        --from-literal=password="sbos-postgres-$(date +%s)" \
        --dry-run=client -o yaml | kubectl apply -f -
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/postgresql.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready pod/postgresql-0 -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    # Crear base de datos principal SBOSDATA
    kubectl exec postgresql-0 -n "${SBOS_NAMESPACE}" -- \
        psql -U postgres -c "CREATE DATABASE \"SBOSDATA\" WITH ENCODING='UTF8' LC_COLLATE='en_US.utf8' LC_CTYPE='en_US.utf8' TEMPLATE=template0;" 2>/dev/null || \
        echo "SBOSDATA ya existe — omitiendo creación"
    kubectl exec postgresql-0 -n "${SBOS_NAMESPACE}" -- \
        psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"SBOSDATA\" TO postgres;" 2>/dev/null || true
    echo "  → BD SBOSDATA lista"
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart statefulset postgresql -n "${SBOS_NAMESPACE}"
    kubectl wait --for=condition=Ready pod/postgresql-0 -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart statefulset postgresql -n "${SBOS_NAMESPACE}"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete statefulset postgresql -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete pvc data-postgresql-0 -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete secret postgresql-secret -n "${SBOS_NAMESPACE}" --ignore-not-found
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    kubectl exec postgresql-0 -n "${SBOS_NAMESPACE}" -- pg_isready -U postgres -h localhost -p 5432
    echo "${__SBOS__STEP_OK__} health"
}
