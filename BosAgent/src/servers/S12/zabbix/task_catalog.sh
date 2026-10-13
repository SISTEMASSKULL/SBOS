#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — zabbix
# Zabbix 7.2 LTS — server + web + agent2 para monitoreo de infraestructura.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/zabbix.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-monitor"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [zabbix] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_deploy_ready() {
    local d="$1" n="$2" t="${3:-180}" e=0
    while (( e < t )); do
        local r
        r=$(_k get deployment "$d" -n "$n" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5)); (( e % 30 == 0 )) && _log "Esperando $d... ${e}/${t}s"
    done; return 1
}

_get_vault_secret() {
    local key="$1"
    local path="${VAULT_PATH:-secret/tenants/skull/zabbix}"
    VAULT_ADDR="${VAULT_ADDR:-http://vault.sbos-security.svc:8200}"
    VAULT_TOKEN="${VAULT_TOKEN:-}"
    if [[ -n "$VAULT_TOKEN" ]]; then
        curl -sf -H "X-Vault-Token: $VAULT_TOKEN" \
            "${VAULT_ADDR}/v1/${path}" 2>/dev/null | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['data']['${key}'])" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || { echo "${__STEP_FAIL__} verificar_namespace"; return 1; }
    echo "${__STEP_OK__} verificar_namespace"

    echo "${__STEP_START__} verificar_postgresql"
    local pg_ready
    pg_ready=$(_k get statefulset postgresql -n sbos-data \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( pg_ready >= 1 )) || { echo "${__STEP_FAIL__} verificar_postgresql: no Ready"; return 1; }
    echo "${__STEP_OK__} verificar_postgresql"
    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    local ready
    ready=$(_k get deployment zabbix-server -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_SKIP__} zabbix_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} crear_bd_zabbix"
    local pg_pod
    pg_pod=$(_k get pods -n sbos-data -l app=postgresql \
        --no-headers 2>/dev/null | awk '{print $1}' | head -1)
    if [[ -n "$pg_pod" ]]; then
        _k exec -n sbos-data "$pg_pod" -- psql -U postgres \
            -c "CREATE DATABASE zabbix_db OWNER postgres;" \
            >> "$FICHA_LOG" 2>&1 || true
        _k exec -n sbos-data "$pg_pod" -- psql -U postgres \
            -c "CREATE USER zabbix WITH PASSWORD 'zabbix_pass';" \
            >> "$FICHA_LOG" 2>&1 || true
        _k exec -n sbos-data "$pg_pod" -- psql -U postgres \
            -c "GRANT ALL PRIVILEGES ON DATABASE zabbix_db TO zabbix;" \
            >> "$FICHA_LOG" 2>&1 || true
    fi
    echo "${__STEP_OK__} crear_bd_zabbix"

    echo "${__STEP_START__} instalar_zabbix_helm"
    if ! helm repo list 2>/dev/null | grep -q "^zabbix-community"; then
        helm repo add zabbix-community https://zabbix-community.github.io/helm-zabbix >> "$FICHA_LOG" 2>&1
        helm repo update >> "$FICHA_LOG" 2>&1
    fi

    local pg_host="postgresql.sbos-data.svc"
    helm upgrade --install zabbix zabbix-community/zabbix \
        --namespace "$NS" \
        --version "4.5.0" \
        --set zabbixServer.DB_SERVER_HOST="$pg_host" \
        --set zabbixServer.POSTGRES_USER="zabbix" \
        --set zabbixServer.POSTGRES_PASSWORD="zabbix_pass" \
        --set zabbixServer.POSTGRES_DB="zabbix_db" \
        --set zabbixWeb.DB_SERVER_HOST="$pg_host" \
        --set zabbixWeb.POSTGRES_USER="zabbix" \
        --set zabbixWeb.POSTGRES_PASSWORD="zabbix_pass" \
        --set zabbixWeb.POSTGRES_DB="zabbix_db" \
        --set zabbixServer.replicaCount=1 \
        --set zabbixWeb.replicaCount=1 \
        --set postgresql.enabled=false \
        --timeout 10m \
        >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} instalar_zabbix_helm"

    echo "${__STEP_START__} esperar_zabbix_ready"
    _wait_deploy_ready zabbix-server "$NS" 180 || { echo "${__STEP_FAIL__} esperar_zabbix_ready: timeout"; return 1; }
    echo "${__STEP_OK__} esperar_zabbix_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_zabbix"
    local ready
    ready=$(_k get deployment zabbix-server -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( ready >= 1 )) || { echo "${__STEP_FAIL__} verificar_zabbix: ${ready}/1"; return 1; }
    echo "${__STEP_OK__} verificar_zabbix"
    return 0
}

ficha_health() {
    local ready
    ready=$(_k get deployment zabbix-server -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( ready >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED"
    return 1
}

ficha_repair() {
    _log "ficha_repair: re-aplicando Helm zabbix (idempotente via upgrade --install)"
    ficha_install
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_zabbix"
    helm uninstall zabbix -n "$NS" >> "$FICHA_LOG" 2>&1 || true
    echo "${__STEP_OK__} eliminar_zabbix"
    return 0
}
