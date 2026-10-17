#!/usr/bin/env bash
# task_catalog.sh — OnlyOffice Document Server (editor colaborativo)
# BC-11 · BOS-REPAIR-09 §5 · SBOS-052 · Order 358
# R16: sin paths hardcodeados

set -euo pipefail

SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/vdiserver/onlyoffice}"
SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-vdi}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"

    # Crear onlyoffice_db en PostgreSQL
    kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='onlyoffice_db'" \
        | grep -q 1 || \
    kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -c "CREATE DATABASE onlyoffice_db" 2>/dev/null || true

    # Crear usuario onlyoffice con contraseña generada
    local db_pass="${ONLYOFFICE_DB_PASS:-$(openssl rand -base64 16)}"
    local jwt_secret="${ONLYOFFICE_JWT_SECRET:-$(openssl rand -base64 32)}"
    kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -c \
        "DO \$\$ BEGIN
           IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='onlyoffice') THEN
             CREATE ROLE onlyoffice WITH LOGIN PASSWORD '${db_pass}';
             GRANT ALL PRIVILEGES ON DATABASE onlyoffice_db TO onlyoffice;
           END IF;
         END \$\$;" 2>/dev/null || true

    # Secret con credenciales BD + JWT
    kubectl create secret generic onlyoffice-secret \
        -n "${SBOS_NAMESPACE}" \
        --from-literal=db-user="onlyoffice" \
        --from-literal=db-password="${db_pass}" \
        --from-literal=jwt-secret="${jwt_secret}" \
        --dry-run=client -o yaml | kubectl apply -f -

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/onlyoffice.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl rollout status statefulset/onlyoffice \
        -n "${SBOS_NAMESPACE}" --timeout=600s
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    ficha_health
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    kubectl rollout restart statefulset/onlyoffice -n "${SBOS_NAMESPACE}"
    kubectl rollout status statefulset/onlyoffice -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl delete pod -n "${SBOS_NAMESPACE}" -l app=onlyoffice --ignore-not-found
    kubectl rollout status statefulset/onlyoffice -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete statefulset onlyoffice -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete service onlyoffice -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete secret onlyoffice-secret -n "${SBOS_NAMESPACE}" --ignore-not-found
    # PVC data-onlyoffice-0 se conserva (documentos soberanos — Retain)
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    kubectl exec -n "${SBOS_NAMESPACE}" onlyoffice-0 -- \
        curl -sf http://localhost/healthcheck >/dev/null || \
        { echo "ERROR: OnlyOffice /healthcheck no responde" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} health"
}

# ── describe ───────────────────────────────────────────────────
ficha_describe() {
    echo "=== OnlyOffice Document Server ==="
    kubectl get statefulset onlyoffice -n "${SBOS_NAMESPACE}" 2>/dev/null || true
    kubectl get pvc data-onlyoffice-0 -n "${SBOS_NAMESPACE}" 2>/dev/null || true
}
