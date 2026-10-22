#!/usr/bin/env bash
# task_catalog.sh — Apache Guacamole VDI Gateway
# BC-11 · BOS-REPAIR-09 §5 · SBOS-052 · Order 356
# R16: sin paths hardcodeados

set -euo pipefail

SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S11-vdiserver/guacamole}"
SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-vdi}"
SBOS_DOMAIN="${SBOS_DOMAIN:-sbos.app}"
SBOS_TENANT="${SBOS_TENANT:-skull}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"

    # 1. Crear guacamole_db
    kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='guacamole_db'" \
        | grep -q 1 || \
    kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -c "CREATE DATABASE guacamole_db" 2>/dev/null || true

    # 2. Crear usuario guacamole y permisos
    local db_pass="${GUACAMOLE_DB_PASS:-$(openssl rand -base64 16)}"
    kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -c \
        "DO \$\$ BEGIN
           IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='guacamole') THEN
             CREATE ROLE guacamole WITH LOGIN PASSWORD '${db_pass}';
             GRANT ALL PRIVILEGES ON DATABASE guacamole_db TO guacamole;
           END IF;
         END \$\$;" 2>/dev/null || true

    # 3. Inicializar schema Guacamole (idempotente — falla si ya existe, ignorar)
    kubectl run guacamole-initdb --rm --image=guacamole/guacamole:1.5.5 \
        -n "${SBOS_NAMESPACE}" --restart=Never \
        --command -- /opt/guacamole/bin/initdb.sh --postgresql 2>/dev/null | \
        kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U guacamole -d guacamole_db 2>/dev/null || true

    # 4. Actualizar Secret con la password real
    kubectl create secret generic guacamole-db \
        -n "${SBOS_NAMESPACE}" \
        --from-literal=username="guacamole" \
        --from-literal=password="${db_pass}" \
        --dry-run=client -o yaml | kubectl apply -f -

    # 5. Actualizar ConfigMap OIDC con los endpoints reales del tenant
    local kc_base="https://${SBOS_DOMAIN}/auth/realms/skbos"
    kubectl create configmap guacamole-oidc \
        -n "${SBOS_NAMESPACE}" \
        --from-literal=authorization_endpoint="${kc_base}/protocol/openid-connect/auth" \
        --from-literal=jwks_endpoint="${kc_base}/protocol/openid-connect/certs" \
        --from-literal=issuer="${kc_base}" \
        --from-literal=redirect_uri="https://${SBOS_DOMAIN}/guacamole/" \
        --dry-run=client -o yaml | kubectl apply -f -

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/guacamole.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl rollout status statefulset/guacamole \
        -n "${SBOS_NAMESPACE}" --timeout=300s
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
    kubectl rollout restart statefulset/guacamole -n "${SBOS_NAMESPACE}"
    kubectl rollout status statefulset/guacamole -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl rollout restart statefulset/guacamole -n "${SBOS_NAMESPACE}"
    kubectl rollout status statefulset/guacamole -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete statefulset guacamole -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete service guacamole -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete secret guacamole-db -n "${SBOS_NAMESPACE}" --ignore-not-found
    # guacamole_db NO se borra — datos de sesiones (Retain)
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    kubectl exec -n "${SBOS_NAMESPACE}" deployment/guacamole -c guacamole -- \
        curl -sf http://localhost:8080/guacamole/api/languages >/dev/null || \
        { echo "ERROR: Guacamole /api/languages no responde" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} health"
}

# ── describe ───────────────────────────────────────────────────
ficha_describe() {
    echo "=== Apache Guacamole VDI Gateway ==="
    kubectl get statefulset guacamole -n "${SBOS_NAMESPACE}" 2>/dev/null || true
    kubectl get configmap guacamole-oidc -n "${SBOS_NAMESPACE}" 2>/dev/null || true
}
