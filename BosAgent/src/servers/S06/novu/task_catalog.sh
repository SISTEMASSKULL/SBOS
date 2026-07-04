#!/usr/bin/env bash
# task_catalog.sh — novu
# Novu 3.15: Motor de notificaciones multi-canal (self-hosted, MIT)
# Dependencias: postgresql, ferretdb, redis, keycloak, vault, postfix
set -euo pipefail

# readonly (removed for multi-source compatibility) __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
# readonly (removed for multi-source compatibility) __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
# readonly (removed for multi-source compatibility) __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
# readonly (removed for multi-source compatibility) __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/novu.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
# readonly (removed for multi-source compatibility) NS="sbos-notifier"
# readonly (removed for multi-source compatibility) NOVU_API_IMAGE="ghcr.io/novuhq/novu/api:3.15.0"
# readonly (removed for multi-source compatibility) NOVU_WS_IMAGE="ghcr.io/novuhq/novu/ws:3.15.0"
# readonly (removed for multi-source compatibility) FERRETDB_URL="mongodb://ferretdb.${NS}.svc.cluster.local:27017/novu"
# readonly (removed for multi-source compatibility) REDIS_HOST="redis.sbos-data.svc.cluster.local"
# readonly (removed for multi-source compatibility) REDIS_URL="redis://${REDIS_HOST}:6379/3"
# readonly (removed for multi-source compatibility) JWT_SECRET="${JWT_SECRET:-sbos-novu-dev-secret-32chars!!}"
# readonly (removed for multi-source compatibility) STORE_KEY="${STORE_KEY:-sbos-novu-store-key-32chars!!!!}"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [novu] $*" | tee -a "$FICHA_LOG"; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_pod() {
    local label="$1" timeout="${2:-180}" elapsed=0
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
    echo "${__STEP_START__} verificar_ferretdb"
    _k get pod -n "$NS" -l app=ferretdb > /dev/null 2>&1 || { echo "${__STEP_FAIL__} ferretdb no disponible"; return 1; }
    echo "${__STEP_OK__} verificar_ferretdb"

    echo "${__STEP_START__} verificar_redis"
    _k get pod redis-0 -n sbos-data > /dev/null 2>&1 || { echo "${__STEP_FAIL__} redis-0 no disponible"; return 1; }
    echo "${__STEP_OK__} verificar_redis"
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    echo "${__STEP_START__} deploy_novu_api"
    if _k get deployment novu-api -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_SKIP__} novu-api ya desplegado"
    else
        _k create deployment novu-api -n "$NS" --image="$NOVU_API_IMAGE" --replicas=1 --port=3000 \
            --dry-run=client -o yaml | _k apply -f -
    fi
    _k set env deploy/novu-api -n "$NS" \
        MONGO_URL="$FERRETDB_URL" \
        REDIS_HOST="$REDIS_HOST" \
        REDIS_URL="$REDIS_URL" \
        JWT_SECRET="$JWT_SECRET" \
        STORE_ENCRYPTION_KEY="$STORE_KEY" \
        NODE_ENV=production \
        STEP_RESOLVER_DISPATCH_URL=http://localhost:3000
    _wait_pod "novu-api" 180
    echo "${__STEP_OK__} deploy_novu_api"

    echo "${__STEP_START__} deploy_novu_ws"
    if _k get deployment novu-ws -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_SKIP__} novu-ws ya desplegado"
    else
        _k create deployment novu-ws -n "$NS" --image="$NOVU_WS_IMAGE" --replicas=1 --port=3002 \
            --dry-run=client -o yaml | _k apply -f -
    fi
    _k set env deploy/novu-ws -n "$NS" REDIS_URL="$REDIS_URL"
    _wait_pod "novu-ws" 180
    echo "${__STEP_OK__} deploy_novu_ws"

    echo "${__STEP_START__} expose_novu"
    if _k get svc novu-api -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_SKIP__} servicio novu ya existe"
    else
        _k expose deployment novu-api -n "$NS" --port=3000 --target-port=3000
        _k expose deployment novu-ws -n "$NS" --port=3002 --target-port=3002
        echo "${__STEP_OK__} expose_novu"
    fi
}

# ── Health ────────────────────────────────────────────────────────
ficha_health_check() {
    local phase
    phase=$(_k get pod -n "$NS" -l app=novu-api -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    [[ "$phase" == "True" ]] && { echo "${__STEP_OK__} novu-api Ready"; return 0; }
    echo "${__STEP_FAIL__} novu-api no Ready"; return 1
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    for d in novu-api novu-ws; do
        echo "${__STEP_START__} remove_${d}"
        _k delete deployment "$d" -n "$NS" --ignore-not-found=true
        echo "${__STEP_OK__} ${d} removido"
    done
    _k delete svc novu-api novu-ws -n "$NS" --ignore-not-found=true
}

export -f ficha_pre_install ficha_install ficha_health_check ficha_uninstall
