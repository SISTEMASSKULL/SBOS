#!/usr/bin/env bash
# task_catalog.sh — calcom
# Cal.com 6.1: Calendario profesional open-source (AGPLv3)
# Dependencias: postgresql, keycloak, vault, kong
# DB: calcom_db en PostgreSQL S01 · Auth: OIDC contra Keycloak
set -euo pipefail

# readonly (removed for multi-source compatibility) __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
# readonly (removed for multi-source compatibility) __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
# readonly (removed for multi-source compatibility) __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
# readonly (removed for multi-source compatibility) __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/calcom.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
# readonly (removed for multi-source compatibility) NS="sbos-collab"
# readonly (removed for multi-source compatibility) CALCOM_IMAGE="calcom/cal.com:6.1.0"
# readonly (removed for multi-source compatibility) DB_URL="postgresql://postgres:$(kubectl --kubeconfig="$KUBECONFIG_DEST" get secret -n sbos-data pg-master-credentials -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)@postgresql.sbos-data.svc.cluster.local:5432/calcom_db"
# readonly (removed for multi-source compatibility) KC_ISSUER="https://keycloak.sbos-security.svc.cluster.local:8080/realms/sbos"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [calcom] $*" | tee -a "$FICHA_LOG"; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_pod() {
    local label="$1" timeout="${2:-120}" elapsed=0
    while (( elapsed < timeout )); do
        local phase
        phase=$(_k get pod -n "$NS" -l app="$label" --no-headers 2>/dev/null | awk '{print $3}' | head -1)
        [[ "$phase" == "Running" ]] && { _log "$label Running"; return 0; }
        sleep 5; elapsed=$((elapsed + 5))
    done
    return 1
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} crear_calcom_db"
    _k exec postgresql-0 -n sbos-data -- psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='calcom_db'" 2>/dev/null | grep -q 1 \
        && echo "${__STEP_SKIP__} calcom_db ya existe" \
        || { _k exec postgresql-0 -n sbos-data -- psql -U postgres -c "CREATE DATABASE calcom_db OWNER postgres;" 2>/dev/null \
             && echo "${__STEP_OK__} calcom_db creada" \
             || { echo "${__STEP_FAIL__} no se pudo crear calcom_db"; return 1; }; }

    echo "${__STEP_START__} verificar_keycloak"
    _k get pod -n sbos-security -l app=keycloak > /dev/null 2>&1 || { echo "${__STEP_FAIL__} keycloak no disponible"; return 1; }
    echo "${__STEP_OK__} verificar_keycloak"
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    echo "${__STEP_START__} deploy_calcom"
    if _k get deployment calcom -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_SKIP__} calcom ya desplegado"
    else
        _k create deployment calcom -n "$NS" --image="$CALCOM_IMAGE" --replicas=1 --port=3000 \
            --dry-run=client -o yaml | _k apply -f -
        _k set env deploy/calcom -n "$NS" \
            DATABASE_URL="$DB_URL" \
            CALCOM_OIDC_ISSUER="$KC_ISSUER" \
            CALCOM_OIDC_CLIENT_ID="calcom" \
            NEXTAUTH_URL="https://calcom.sbos.local" \
            NODE_ENV=production
        echo "${__STEP_OK__} deploy_calcom"
    fi
    _wait_pod "calcom" 180
}

# ── Health ────────────────────────────────────────────────────────
ficha_health_check() {
    _k exec deploy/calcom -n "$NS" -- curl -sf http://localhost:3000/api/health > /dev/null 2>&1 \
        && { echo "${__STEP_OK__} calcom health OK"; return 0; } \
        || { echo "${__STEP_FAIL__} calcom health fail"; return 1; }
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__STEP_START__} remove_calcom"
    _k delete deployment calcom -n "$NS" --ignore-not-found=true
    _k delete svc calcom -n "$NS" --ignore-not-found=true
    echo "${__STEP_OK__} calcom removido"
}

export -f ficha_pre_install ficha_install ficha_health_check ficha_uninstall
