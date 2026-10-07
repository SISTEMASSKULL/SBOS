#!/usr/bin/env bash
# task_catalog.sh — Nextcloud Files (almacenamiento soberano)
# BC-11 · Order 357 · StatefulSet · sbos-vdi · PVC 500Gi
# R16: sin paths hardcodeados

set -euo pipefail

SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/vdiserver/nextcloud}"
SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-vdi}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"

    # Crear nextcloud_db en PostgreSQL
    kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='nextcloud_db'" \
        | grep -q 1 || \
    kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -c "CREATE DATABASE nextcloud_db" 2>/dev/null || true

    # Secret con credenciales admin + BD
    local admin_pass="${NEXTCLOUD_ADMIN_PASS:-$(openssl rand -base64 16)}"
    local db_pass="${NEXTCLOUD_DB_PASS:-$(openssl rand -base64 16)}"
    kubectl create secret generic nextcloud-secret \
        -n "${SBOS_NAMESPACE}" \
        --from-literal=admin-user="admin" \
        --from-literal=admin-password="${admin_pass}" \
        --from-literal=db-user="nextcloud" \
        --from-literal=db-password="${db_pass}" \
        --dry-run=client -o yaml | kubectl apply -f -

    # Crear usuario BD nextcloud
    kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -c \
        "DO \$\$ BEGIN
           IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='nextcloud') THEN
             CREATE ROLE nextcloud WITH LOGIN PASSWORD '${db_pass}';
             GRANT ALL PRIVILEGES ON DATABASE nextcloud_db TO nextcloud;
           END IF;
         END \$\$;" 2>/dev/null || true

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/nextcloud.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl rollout status statefulset/nextcloud \
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
    kubectl rollout restart statefulset/nextcloud -n "${SBOS_NAMESPACE}"
    kubectl rollout status statefulset/nextcloud -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl delete pod -n "${SBOS_NAMESPACE}" -l app=nextcloud --ignore-not-found
    kubectl rollout status statefulset/nextcloud -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete statefulset nextcloud -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete service nextcloud -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete secret nextcloud-secret -n "${SBOS_NAMESPACE}" --ignore-not-found
    # PVC data-nextcloud-0 se conserva (datos soberanos — Retain)
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    kubectl exec -n "${SBOS_NAMESPACE}" nextcloud-0 -- \
        curl -sf http://localhost/status.php >/dev/null || \
        { echo "ERROR: Nextcloud /status.php no responde" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} health"
}

# ── describe ───────────────────────────────────────────────────
ficha_describe() {
    echo "=== Nextcloud Files ==="
    kubectl get statefulset nextcloud -n "${SBOS_NAMESPACE}" 2>/dev/null || true
    kubectl get pvc data-nextcloud-0 -n "${SBOS_NAMESPACE}" 2>/dev/null || true
}
