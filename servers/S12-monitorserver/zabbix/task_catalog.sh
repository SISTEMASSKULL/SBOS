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

# Motor de puertos BOS — asigna puerto ClusterIP según SBOS-050
_portman() {
    local ficha_id="$1" ficha_index="$2" server="$3" ns="${4:-default}"
    local TOKEN; TOKEN="$(cat /etc/bos/rpc-token 2>/dev/null)"
    BOS_RPC_TOKEN="$TOKEN" bosctl rpc bos.portman.assign \
      "{\"ficha_id\":\"$ficha_id\",\"ficha_index\":$ficha_index,\"logical_server\":\"$server\",\"port_types\":[\"K8S_CLUSTER_IP\"],\"namespace\":\"$ns\",\"ctx_id\":\"install-$ficha_id\"}" \
      2>/dev/null | python3 -I -c \
      "import json,sys; d=json.load(sys.stdin); a=d.get('assignments',[]); print(a[0]['port'] if a else '')" \
    2>/dev/null
}

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
    local path="${VAULT_PATH:-secret/tenants/${TENANT_ID:-tenant}/zabbix}"
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

    echo "${__STEP_START__} networkpolicy_monitor_postgresql"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitor-postgresql
  namespace: sbos-data
spec:
  podSelector:
    matchLabels:
      app: postgresql
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: sbos-monitor
    ports:
    - port: 5432
      protocol: TCP
K8SEOF
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitor-egress-data
  namespace: sbos-monitor
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: sbos-data
    ports:
    - port: 5432
      protocol: TCP
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
K8SEOF
    echo "${__STEP_OK__} networkpolicy_monitor_postgresql"
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

    echo "${__STEP_START__} portman_zabbix"
    local SVC_PORT; SVC_PORT=$(_portman "zabbix" 7 "S12" "sbos-monitor")
    SVC_PORT="${SVC_PORT:-21270}"
    _log "Puerto ClusterIP portman: ${SVC_PORT}"
    echo "${__STEP_OK__} portman_zabbix"

    echo "${__STEP_START__} instalar_zabbix_helm"
    if ! helm repo list 2>/dev/null | grep -q "^zabbix-community"; then
        helm repo add zabbix-community https://zabbix-community.github.io/helm-zabbix >> "$FICHA_LOG" 2>&1
        helm repo update >> "$FICHA_LOG" 2>&1
    fi

    local pg_host="postgresql.sbos-data.svc"
    # Parchar secret existente antes de upgrade para que helm use el host correcto
    local encoded_host; encoded_host=$(echo -n "$pg_host" | base64)
    _k patch secret zabbix-db-access -n "$NS" --type=json \
        -p "[{\"op\":\"replace\",\"path\":\"/data/host\",\"value\":\"${encoded_host}\"}]" \
        >> "$FICHA_LOG" 2>&1 || true

    # El helm chart de zabbix 7.1.0 deja el Service con puertos duplicados
    # en upgrades sucesivos — eliminar antes para que helm lo recree limpio.
    if _k get svc zabbix-zabbix-web -n "$NS" &>/dev/null; then
        local dup
        dup=$(_k get svc zabbix-zabbix-web -n "$NS" \
            -o jsonpath='{.spec.ports[*].name}' 2>/dev/null | \
            tr ' ' '\n' | sort | uniq -d || echo "")
        if [[ -n "$dup" ]]; then
            _log "Service zabbix-zabbix-web tiene puertos duplicados ($dup) — eliminando"
            _k delete svc zabbix-zabbix-web -n "$NS" >> "$FICHA_LOG" 2>&1 || true
        fi
    fi

    KUBECONFIG="$KUBECONFIG_DEST" helm upgrade --install zabbix zabbix-community/zabbix \
        --namespace "$NS" \
        --version "7.1.0" \
        --set postgresAccess.host="$pg_host" \
        --set postgresAccess.user="zabbix" \
        --set postgresAccess.password="zabbix_pass" \
        --set postgresAccess.database="zabbix_db" \
        --set zabbixServer.replicaCount=1 \
        --set zabbixWeb.replicaCount=1 \
        --set postgresql.enabled=false \
        --set zabbixServer.resources.requests.cpu=100m \
        --set zabbixServer.resources.requests.memory=256Mi \
        --set zabbixWeb.resources.requests.cpu=50m \
        --set zabbixWeb.resources.requests.memory=128Mi \
        --set zabbixWeb.service.port="${SVC_PORT}" \
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

ficha_post_install() {
    # Evitar post_install_generic (usa namespace default con label errado)
    return 0
}

ficha_repair() {
    _log "ficha_repair: re-aplicando Helm zabbix (idempotente via upgrade --install)"
    ficha_install
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_zabbix-server_ready"
    local ready
    ready=$(_k get deployment zabbix-server -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_OK__} test_zabbix-server_ready (${ready}/1)"
    else
        echo "${__STEP_FAIL__} test_zabbix-server_ready: ${ready}/1"; ok=1
    fi
    return $ok
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_zabbix"
    helm uninstall zabbix -n "$NS" >> "$FICHA_LOG" 2>&1 || true
    echo "${__STEP_OK__} eliminar_zabbix"
    return 0
}
