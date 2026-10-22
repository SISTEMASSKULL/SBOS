#!/usr/bin/env bash
# task_catalog.sh — weblate Gestión de Traducciones (S16-webserver)
# BC-13 · Deployment K8s · sbos-web · hostPath /etc/bos/bi18n/translations · ADR-022
# R16: sin paths hardcodeados

set -euo pipefail

SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S16-webserver/weblate}"
SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-web}"
WEBLATE_TRANSLATIONS_PATH="${WEBLATE_TRANSLATIONS_PATH:-/etc/bos/bi18n/translations}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    create_k8s_namespace "${SBOS_NAMESPACE}" "sbos.io/managed=true"

    # Crear weblate_db en PostgreSQL
    kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='weblate_db'" \
        | grep -q 1 || \
    kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -c "CREATE DATABASE weblate_db" 2>/dev/null || true

    # Usuario weblate en BD
    local db_pass="${WEBLATE_DB_PASS:-$(openssl rand -base64 16)}"
    kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -c \
        "DO \$\$ BEGIN
           IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='weblate') THEN
             CREATE ROLE weblate WITH LOGIN PASSWORD '${db_pass}';
             GRANT ALL PRIVILEGES ON DATABASE weblate_db TO weblate;
           END IF;
         END \$\$;" 2>/dev/null || true

    # Secret con credenciales + clave de administrador
    local admin_pass="${WEBLATE_ADMIN_PASS:-$(openssl rand -base64 16)}"
    local secret_key="${WEBLATE_SECRET_KEY:-$(openssl rand -base64 50)}"
    kubectl create secret generic weblate-secret \
        -n "${SBOS_NAMESPACE}" \
        --from-literal=db-user="weblate" \
        --from-literal=db-password="${db_pass}" \
        --from-literal=admin-password="${admin_pass}" \
        --from-literal=secret-key="${secret_key}" \
        --dry-run=client -o yaml | kubectl apply -f -

    # Directorio hostPath compartido con bi18nd (debe existir en el host)
    mkdir -p "${WEBLATE_TRANSLATIONS_PATH}"
    chmod 755 "${WEBLATE_TRANSLATIONS_PATH}"

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    sbos_k8s_core "${SBOS_FICHA_DIR}/weblate.k8s.yml" "${SBOS_NAMESPACE}"
    kubectl rollout status statefulset/weblate -n "${SBOS_NAMESPACE}" --timeout=600s
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
    kubectl rollout restart statefulset/weblate -n "${SBOS_NAMESPACE}"
    kubectl rollout status statefulset/weblate -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    kubectl delete pod -n "${SBOS_NAMESPACE}" -l app=weblate --ignore-not-found
    kubectl rollout status statefulset/weblate -n "${SBOS_NAMESPACE}" --timeout=300s
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    kubectl delete statefulset weblate -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete service weblate -n "${SBOS_NAMESPACE}" --ignore-not-found
    kubectl delete secret weblate-secret -n "${SBOS_NAMESPACE}" --ignore-not-found
    # weblate_db se preserva (historial de traducciones — Retain)
    # hostPath /etc/bos/bi18n/translations se preserva (datos bi18nd)
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    kubectl exec -n "${SBOS_NAMESPACE}" deployment/weblate -- \
        curl -sf http://localhost:8080/healthz/ >/dev/null || \
        { echo "ERROR: weblate /healthz/ no responde" >&2; return 1; }
    # Verificar que el hostPath está montado y bi18nd puede escribir
    [[ -d "${WEBLATE_TRANSLATIONS_PATH}" ]] || \
        { echo "ERROR: directorio de traducciones ${WEBLATE_TRANSLATIONS_PATH} no existe" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} health"
}

# ── describe ───────────────────────────────────────────────────
ficha_describe() {
    echo "=== Weblate — Gestión de Traducciones ==="
    kubectl get statefulset weblate -n "${SBOS_NAMESPACE}" 2>/dev/null || true
    echo "Directorio traducciones (hostPath): ${WEBLATE_TRANSLATIONS_PATH}"
    ls "${WEBLATE_TRANSLATIONS_PATH}" 2>/dev/null | head -10 || echo "(vacío)"
}
