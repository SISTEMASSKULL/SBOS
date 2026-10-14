#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — sbos-kong-tenant
# Configura enrutamiento Kong por Host-header para el tenant inicial.
#
# Qué hace:
#   - Crea rutas Kong que coinciden por Host-header (dominio del tenant)
#   - Soporta dominio raíz y subdominios: *.tenant.domain
#   - Aplica JWT plugin por realm Keycloak del tenant
#   - Idempotente: usa los helpers _kong_ensure_* (skip si ya existe)
#
# Variables relevantes:
#   TENANT_ID        — ID del tenant inicial (default: skull)
#   BOS_DOMAIN       — dominio base SBOS (default: sbos.app)
#   KC_REALM_BASE    — URL base de Keycloak (default: autodetectada)
#
# Relación con otros componentes:
#   - Esta ficha configura el tenant INICIAL (day-0). Los tenants adicionales
#     se crean con la saga bos.tenant.create que invoca los mismos helpers.
#   - NO gestiona el ciclo de vida del pod Kong — eso lo hace la ficha kong.
#   - Las rutas de apps (/nextcloud, /grafana…) las gestiona la ficha kong.
#     Esta ficha agrega las rutas por DOMINIO del tenant.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-kong-tenant.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS_KONG="sbos-gateway"
readonly ADMIN_PORT=8001

TENANT_ID="${TENANT_ID:-skull}"
BOS_DOMAIN="${BOS_DOMAIN:-sbos.app}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-kong-tenant] $*" | tee -a "$FICHA_LOG"; }

_k() {
    local kubectl_bin
    kubectl_bin=$(command -v kubectl 2>/dev/null || echo "/usr/local/bin/kubectl")
    "$kubectl_bin" --kubeconfig="$KUBECONFIG_DEST" "$@"
}

# _kong_exec: ejecuta curl dentro del pod de Kong contra el Admin API.
_kong_exec() {
    _k exec deploy/kong -n "$NS_KONG" -- \
        curl -s --max-time 10 "$@" 2>/dev/null
}

# _kong_get: GET al Admin API. No falla en 404.
_kong_get() {
    _kong_exec "http://127.0.0.1:${ADMIN_PORT}${1}"
}

# _kong_post: POST JSON al Admin API.
_kong_post() {
    local path="$1" data="$2"
    _kong_exec \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$data" \
        "http://127.0.0.1:${ADMIN_PORT}${path}"
}

# _kong_patch: PATCH JSON al Admin API.
_kong_patch() {
    local path="$1" data="$2"
    _kong_exec \
        -X PATCH \
        -H "Content-Type: application/json" \
        -d "$data" \
        "http://127.0.0.1:${ADMIN_PORT}${path}"
}

# _kong_healthy: verifica que Kong Admin API responde.
_kong_healthy() {
    local health
    health=$(_k exec deploy/kong -n "$NS_KONG" -- kong health 2>/dev/null || echo "")
    echo "$health" | grep -q "healthy"
}

# _ensure_service: crea servicio Kong si no existe. Idempotente.
_ensure_service() {
    local name="$1" url="$2"
    local existing
    existing=$(_kong_get "/services/${name}" | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('name',''))" 2>/dev/null || echo "")
    if [[ "$existing" == "$name" ]]; then
        _log "  servicio '$name' ya existe"
        return 0
    fi
    _kong_post "/services" "{\"name\":\"${name}\",\"url\":\"${url}\"}" >> "$FICHA_LOG" 2>&1
    _log "  servicio '$name' creado → $url"
}

# _ensure_route_host: crea ruta Kong por Host-header. Idempotente.
# Args: $1=nombre_ruta  $2=nombre_servicio  $3=host  $4=strip_path(true|false)
_ensure_route_host() {
    local rname="$1" sname="$2" host="$3" strip="${4:-false}"
    local existing
    existing=$(_kong_get "/services/${sname}/routes/${rname}" | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('name',''))" 2>/dev/null || echo "")
    if [[ "$existing" == "$rname" ]]; then
        _log "  ruta '$rname' ya existe"
        return 0
    fi
    _kong_post "/services/${sname}/routes" \
        "{\"name\":\"${rname}\",\"hosts\":[\"${host}\"],\"strip_path\":${strip}}" >> "$FICHA_LOG" 2>&1
    _log "  ruta '$rname' creada (Host: $host)"
}

# _ensure_route_path: crea ruta Kong por path. Idempotente.
_ensure_route_path() {
    local rname="$1" sname="$2" path="$3" strip="${4:-false}"
    local existing
    existing=$(_kong_get "/services/${sname}/routes/${rname}" | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('name',''))" 2>/dev/null || echo "")
    if [[ "$existing" == "$rname" ]]; then
        _log "  ruta '$rname' ya existe"
        return 0
    fi
    _kong_post "/services/${sname}/routes" \
        "{\"name\":\"${rname}\",\"paths\":[\"${path}\"],\"strip_path\":${strip}}" >> "$FICHA_LOG" 2>&1
    _log "  ruta '$rname' creada (path: $path)"
}

# _ensure_route_plugin: activa plugin en una ruta. Idempotente.
_ensure_route_plugin() {
    local rname="$1" pname="$2" config_json="${3:-{}}"
    local existing
    existing=$(_kong_get "/routes/${rname}/plugins" | \
        python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    names=[p.get('name','') for p in d.get('data',[])]
    print('${pname}' in names and 'exists' or '')
except: print('')
" 2>/dev/null || echo "")
    if [[ "$existing" == "exists" ]]; then
        _log "  plugin '$pname' ya activo en ruta '$rname'"
        return 0
    fi
    _kong_post "/routes/${rname}/plugins" \
        "{\"name\":\"${pname}\",\"config\":${config_json}}" >> "$FICHA_LOG" 2>&1
    _log "  plugin '$pname' activado en ruta '$rname'"
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    echo "${__STEP_START__} verificar_kong"
    if ! _k get deployment kong -n "$NS_KONG" > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_kong: Kong Deployment no encontrado"
        return 1
    fi
    local ready
    ready=$(_k get pod -n "$NS_KONG" -l app=kong \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' \
        2>/dev/null || echo "False")
    if [[ "$ready" != "True" ]]; then
        echo "${__STEP_FAIL__} verificar_kong: Kong pod no Ready"
        return 1
    fi
    if ! _kong_healthy; then
        echo "${__STEP_FAIL__} verificar_kong: Admin API no responde"
        return 1
    fi
    echo "${__STEP_OK__} verificar_kong (Admin API :${ADMIN_PORT} OK)"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    local tenant="$TENANT_ID"
    local domain="$BOS_DOMAIN"
    local realm_url="http://keycloak.sbos-security.svc.cluster.local:8080/realms/${tenant}"
    local jwt_cfg="{\"uri_param_names\":[\"jwt\"],\"header_names\":[\"authorization\"],\"claims_to_verify\":[\"exp\"]}"

    _log "Configurando Kong para tenant='$tenant' dominio='$domain'"

    # ── 1. Servicio del tenant (apunta al proxy interno Kong) ─────
    # El servicio del tenant es un "meta-servicio" que agrupa sus rutas.
    # Las apps individuales ya tienen sus propios servicios (nextcloud, grafana…).
    # Aquí creamos el servicio raíz del tenant para rutas de dominio.
    echo "${__STEP_START__} servicio_tenant"
    # El servicio del tenant apunta a Kong mismo en la ruta catch-all interna.
    # Las rutas por Host-header que creamos aquí hacen que Kong reenvíe al servicio
    # correcto de la app según el path (/nextcloud, /grafana…).
    _ensure_service "tenant-${tenant}" "http://kong.sbos-gateway.svc.cluster.local:8000"
    echo "${__STEP_OK__} servicio_tenant (tenant-${tenant})"

    # ── 2. Rutas por Host-header del tenant ───────────────────────
    echo "${__STEP_START__} rutas_dominio_tenant"

    # Ruta dominio raíz: Host: <domain>
    _ensure_route_host \
        "tenant-${tenant}-root" \
        "tenant-${tenant}" \
        "$domain" \
        "false"

    # Ruta subdominio del tenant: Host: <tenant>.<domain>
    _ensure_route_host \
        "tenant-${tenant}-sub" \
        "tenant-${tenant}" \
        "${tenant}.${domain}" \
        "false"

    # Ruta wildcard de apps del tenant: Host: *.tenant.<domain> (si aplica)
    # Permite que empresa.skull.sbos.app llegue al tenant skull
    _ensure_route_host \
        "tenant-${tenant}-wildcard" \
        "tenant-${tenant}" \
        "*.${tenant}.${domain}" \
        "false"

    _log "Rutas de dominio configuradas para tenant '$tenant'"
    echo "${__STEP_OK__} rutas_dominio_tenant (3 rutas: root + sub + wildcard)"

    # ── 3. Plugin JWT en rutas del tenant ─────────────────────────
    echo "${__STEP_START__} jwt_tenant"
    for rname in \
        "tenant-${tenant}-root" \
        "tenant-${tenant}-sub" \
        "tenant-${tenant}-wildcard"; do
        _ensure_route_plugin "$rname" "jwt" "$jwt_cfg"
    done
    _log "JWT plugin configurado para rutas del tenant '$tenant' (realm: $realm_url)"
    echo "${__STEP_OK__} jwt_tenant"

    # ── 4. Rate limiting por tenant ───────────────────────────────
    echo "${__STEP_START__} rate_limiting_tenant"
    local rl_cfg="{\"minute\":1000,\"hour\":10000,\"policy\":\"local\"}"
    for rname in \
        "tenant-${tenant}-root" \
        "tenant-${tenant}-sub"; do
        _ensure_route_plugin "$rname" "rate-limiting" "$rl_cfg"
    done
    echo "${__STEP_OK__} rate_limiting_tenant"

    _log "sbos-kong-tenant completado para tenant='$tenant'"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    local total
    total=$(_kong_get "/routes" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',[])))" \
        2>/dev/null || echo "?")
    _log "Rutas Kong totales después de configurar tenant: $total"
    return 0
}

# ── Health ────────────────────────────────────────────────────────
ficha_health() {
    local tenant="$TENANT_ID"
    local existing
    existing=$(_kong_get "/services/tenant-${tenant}" | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('name',''))" 2>/dev/null || echo "")
    if [[ "$existing" == "tenant-${tenant}" ]]; then
        echo "HEALTHY"
        return 0
    fi
    echo "DEGRADED: servicio tenant-${tenant} no encontrado en Kong"
    return 1
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    _log "ficha_repair: re-aplicando configuración de tenant"
    ficha_pre_install || return 1
    ficha_install
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local tenant="$TENANT_ID"
    local ok=0

    echo "${__STEP_START__} test_servicio_tenant"
    local svc
    svc=$(_kong_get "/services/tenant-${tenant}" | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('name',''))" 2>/dev/null || echo "")
    if [[ "$svc" == "tenant-${tenant}" ]]; then
        echo "${__STEP_OK__} test_servicio_tenant (tenant-${tenant})"
    else
        echo "${__STEP_FAIL__} test_servicio_tenant: servicio no encontrado"
        ok=1
    fi

    echo "${__STEP_START__} test_rutas_tenant"
    local rutas_ok=0
    for rname in "tenant-${tenant}-root" "tenant-${tenant}-sub" "tenant-${tenant}-wildcard"; do
        local ruta
        ruta=$(_kong_get "/routes/${rname}" | \
            python3 -c "import sys,json; print(json.load(sys.stdin).get('name',''))" 2>/dev/null || echo "")
        [[ "$ruta" == "$rname" ]] && rutas_ok=$((rutas_ok+1))
    done
    if (( rutas_ok == 3 )); then
        echo "${__STEP_OK__} test_rutas_tenant (3/3)"
    else
        echo "${__STEP_FAIL__} test_rutas_tenant: ${rutas_ok}/3 rutas"
        ok=1
    fi

    echo "${__STEP_START__} test_jwt_plugin"
    local jwt_ok=0
    for rname in "tenant-${tenant}-root" "tenant-${tenant}-sub"; do
        local has_jwt
        has_jwt=$(_kong_get "/routes/${rname}/plugins" | \
            python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    names=[p.get('name','') for p in d.get('data',[])]
    print('ok' if 'jwt' in names else '')
except: print('')
" 2>/dev/null || echo "")
        [[ "$has_jwt" == "ok" ]] && jwt_ok=$((jwt_ok+1))
    done
    if (( jwt_ok == 2 )); then
        echo "${__STEP_OK__} test_jwt_plugin (2/2 rutas con JWT)"
    else
        echo "${__STEP_FAIL__} test_jwt_plugin: ${jwt_ok}/2 rutas con JWT"
        ok=1
    fi

    return $ok
}

# ── Remove ────────────────────────────────────────────────────────
ficha_remove() {
    local tenant="$TENANT_ID"
    _log "Eliminando configuración Kong para tenant '$tenant'"

    # Eliminar rutas primero (dependen del servicio)
    for rname in "tenant-${tenant}-root" "tenant-${tenant}-sub" "tenant-${tenant}-wildcard"; do
        _kong_exec -X DELETE \
            "http://127.0.0.1:${ADMIN_PORT}/routes/${rname}" >> "$FICHA_LOG" 2>&1 || true
        _log "  ruta '$rname' eliminada"
    done

    # Eliminar servicio
    _kong_exec -X DELETE \
        "http://127.0.0.1:${ADMIN_PORT}/services/tenant-${tenant}" >> "$FICHA_LOG" 2>&1 || true
    _log "  servicio 'tenant-${tenant}' eliminado"

    echo "${__STEP_OK__} remove_kong_tenant (tenant-${tenant})"
    return 0
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    local tenant="$TENANT_ID"
    echo "=== sbos-kong-tenant STATUS ==="
    echo "Tenant: $tenant"
    echo "Dominio: $BOS_DOMAIN"
    echo ""
    echo "Servicio tenant-${tenant}:"
    _kong_get "/services/tenant-${tenant}" | \
        python3 -c "
import sys,json
d=json.load(sys.stdin)
print(f'  name={d.get(\"name\",\"?\")} url={d.get(\"url\",\"?\")} id={d.get(\"id\",\"?\")}')
" 2>/dev/null || echo "  no encontrado"
    echo ""
    echo "Rutas del tenant:"
    for rname in "tenant-${tenant}-root" "tenant-${tenant}-sub" "tenant-${tenant}-wildcard"; do
        local info
        info=$(_kong_get "/routes/${rname}" | \
            python3 -c "
import sys,json
d=json.load(sys.stdin)
hosts=d.get('hosts',[])
paths=d.get('paths',[])
print(f'  {d.get(\"name\",\"?\")} hosts={hosts} paths={paths}')
" 2>/dev/null || echo "  $rname: no encontrado")
        echo "$info"
    done
}
