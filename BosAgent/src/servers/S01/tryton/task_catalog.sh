#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — Ficha tryton (S01 — erpserver)
# Instala Tryton ERP 7.4 como StatefulSet en K8s + BD tryton_db en PostgreSQL.
# Idempotente: si ya existe, actualiza y continúa.
#
# Variables de entorno:
#   TENANT_ID    — ID del tenant (default: skull)
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/tryton.log}"
FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S01/tryton}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NAMESPACE="${SBOS_NAMESPACE:-sbos-erp}"
TENANT_ID="${TENANT_ID:-skull}"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [tryton] $*" | tee -a "$FICHA_LOG"; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

# ── Pre-install ───────────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_postgresql"
    if ! _k get pod -n sbos-data postgresql-0 --no-headers 2>/dev/null | grep -q Running; then
        echo "${__STEP_FAIL__} verificar_postgresql: postgresql-0 no está Running"
        return 1
    fi
    echo "${__STEP_OK__} verificar_postgresql"

    echo "${__STEP_START__} verificar_namespace"
    if ! _k get namespace "$NAMESPACE" --no-headers 2>/dev/null | grep -q Active; then
        _k create namespace "$NAMESPACE" 2>/dev/null || true
        _k label namespace "$NAMESPACE" tenant="$TENANT_ID" managed-by="bos" --overwrite 2>/dev/null || true
    fi
    echo "${__STEP_OK__} verificar_namespace"

    return 0
}

# ── Install ───────────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # 1. Crear base de datos tryton_db en PostgreSQL
    echo "${__STEP_START__} crear_base_datos"
    local db_exists
    db_exists=$(_k exec -n sbos-data postgresql-0 -- psql -U postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='tryton_db'" 2>/dev/null || echo "0")
    if [ "$db_exists" != "1" ]; then
        _k exec -n sbos-data postgresql-0 -- psql -U postgres -c \
            "CREATE DATABASE tryton_db OWNER tryton;" 2>/dev/null || true
        _k exec -n sbos-data postgresql-0 -- psql -U postgres -c \
            "GRANT ALL PRIVILEGES ON DATABASE tryton_db TO tryton;" 2>/dev/null || true
        _log "tryton_db creada"
    else
        _log "tryton_db ya existe"
    fi
    echo "${__STEP_OK__} crear_base_datos"

    # 2. Aplicar StatefulSet de Tryton
    echo "${__STEP_START__} aplicar_statefulset"
    if [ -f "${FICHA_DIR}/resources/tryton.k8s.yml" ]; then
        _k apply -f "${FICHA_DIR}/resources/tryton.k8s.yml" >> "$FICHA_LOG" 2>&1
    elif [ -f "${FICHA_DIR}/tryton.k8s.yml" ]; then
        _k apply -f "${FICHA_DIR}/tryton.k8s.yml" >> "$FICHA_LOG" 2>&1
    else
        echo "${__STEP_FAIL__} aplicar_statefulset: no se encontró tryton.k8s.yml"
        return 1
    fi
    echo "${__STEP_OK__} aplicar_statefulset"

    # 3. Esperar a que el pod esté Ready
    echo "${__STEP_START__} esperar_ready"
    _k wait --for=condition=Ready pod -l app=tryton -n "$NAMESPACE" --timeout=300s 2>/dev/null || {
        _log "ADVERTENCIA: timeout esperando tryton — verificando estado..."
        _k get pods -n "$NAMESPACE" -l app=tryton >> "$FICHA_LOG" 2>&1
    }
    echo "${__STEP_OK__} esperar_ready"

    _log "Tryton instalado (namespace=$NAMESPACE)"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────────
ficha_post_install() {
    echo "${__STEP_START__} verificar_estado"
    _k get statefulset tryton -n "$NAMESPACE" -o wide 2>/dev/null | tee -a "$FICHA_LOG"
    _k get pods -n "$NAMESPACE" -l app=tryton 2>/dev/null | tee -a "$FICHA_LOG"
    echo "${__STEP_OK__} verificar_estado"
    return 0
}

# ── Repair ────────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reparar_tryton"
    _k rollout restart statefulset tryton -n "$NAMESPACE" 2>/dev/null || true
    _k wait --for=condition=Ready pod -l app=tryton -n "$NAMESPACE" --timeout=300s 2>/dev/null || true
    echo "${__STEP_OK__} reparar_tryton"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_statefulset"
    local ready
    ready=$(_k get statefulset tryton -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$ready" == "1" ]; then
        echo "${__STEP_OK__} test_statefulset (ready=$ready)"
    else
        echo "${__STEP_FAIL__} test_statefulset: ready=$ready (esperado 1)"
        ok=1
    fi

    echo "${__STEP_START__} test_base_datos"
    local db_exists
    db_exists=$(_k exec -n sbos-data postgresql-0 -- psql -U postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='tryton_db'" 2>/dev/null || echo "0")
    if [ "$db_exists" == "1" ]; then
        echo "${__STEP_OK__} test_base_datos (tryton_db existe)"
    else
        echo "${__STEP_FAIL__} test_base_datos: tryton_db no existe"
        ok=1
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────────
ficha_status() {
    echo "=== tryton STATUS ==="
    echo ""
    _k get statefulset tryton -n "$NAMESPACE" -o wide 2>/dev/null || echo "  (no disponible)"
    echo ""
    _k get pods -n "$NAMESPACE" -l app=tryton 2>/dev/null || echo "  (sin pods)"
    echo ""
    echo "Base de datos:"
    _k exec -n sbos-data postgresql-0 -- psql -U postgres -tAc \
        "SELECT datname, encoding FROM pg_database WHERE datname='tryton_db'" 2>/dev/null || echo "  (no disponible)"
}

# ── Uninstall ─────────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: eliminando Tryton"
    echo "${__STEP_START__} desinstalar"
    _k delete statefulset tryton -n "$NAMESPACE" --ignore-not-found --wait=false 2>/dev/null || true
    _k delete service tryton -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
    echo "${__STEP_OK__} desinstalar (BD tryton_db preservada)"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico tryton ==="
    _k describe statefulset tryton -n "$NAMESPACE" 2>/dev/null | grep -E "Name:|Replicas:|Image:" || echo "  no disponible"
    echo ""
    _k get events -n "$NAMESPACE" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
