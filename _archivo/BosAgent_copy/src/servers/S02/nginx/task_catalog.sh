#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — nginx (HOST S02)
# Iteración 1: Nginx 1.28.0 en host vía systemd. Página de bienvenida SBOS,
#              reverse proxy con subdominios, hardening headers CIS+OWASP.
# Dependencias: kong (K8s, accesible vía ClusterIP o NodePort)
#
# ⚠️  Esta ficha corre en el HOST, no en un pod. Usa apt, systemctl, /etc/nginx.
# ⚠️  NO usa kubectl — el runtime es bash puro en el sistema operativo.
#
# NOTA PHP: El stack SBOS es Go/Rust/Python. No se instala PHP-FPM.
#           El contenido dinámico lo sirven los daemons vía Kong proxy_pass.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/nginx.log}"
# K8s solo se usa para verificar que kong existe; en Iteración 2 esto irá por health check
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NGINX_CONF="/etc/nginx"
readonly NGINX_WEBROOT="/var/www/html"
readonly KONG_SVC="kong.sbos-gateway.svc.cluster.local"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [nginx] $*" | tee -a "$FICHA_LOG" >&2; }

# _kubectl: solo para verificar dependencia kong en pre_install.
# El resto de la ficha NO usa kubectl.
_kubectl() { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@" 2>/dev/null; }

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_root"
    if [[ $EUID -ne 0 ]]; then
        echo "${__STEP_FAIL__} verificar_root: se requiere root para instalar nginx en el host"
        return 1
    fi
    echo "${__STEP_OK__} verificar_root"

    echo "${__STEP_START__} verificar_ubuntu"
    local version
    version=$(lsb_release -rs 2>/dev/null || grep VERSION_ID /etc/os-release | cut -d'"' -f2 || echo "0")
    if [[ ! "$version" =~ ^(24|26)\. ]]; then
        _log "ADVERTENCIA: Ubuntu 24.04+ esperado, detectado: $version"
    fi
    echo "${__STEP_OK__} verificar_ubuntu ($version)"

    echo "${__STEP_START__} verificar_kong"
    # Verificar que Kong responde vía ClusterIP desde el host
    if _kubectl get pod -n sbos-gateway -l app=kong --no-headers 2>/dev/null | grep -q "."; then
        echo "${__STEP_OK__} verificar_kong (pod existe)"
    else
        _log "ADVERTENCIA: kong no detectado en K8s — nginx hará proxy_pass a $KONG_SVC:8000"
        echo "${__STEP_SKIP__} verificar_kong: kong no detectado, se continuará"
    fi

    echo "${__STEP_START__} verificar_puerto_80"
    if ss -tlnp 2>/dev/null | grep -q ':80 '; then
        _log "ADVERTENCIA: puerto 80 ocupado — se detendrá el servicio existente"
        systemctl stop nginx 2>/dev/null || true
        systemctl stop apache2 2>/dev/null || true
    fi
    echo "${__STEP_OK__} verificar_puerto_80"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")" "$NGINX_CONF" "$NGINX_WEBROOT"

    # ── 1. Instalar nginx vía apt ────────────────────────────────
    echo "${__STEP_START__} instalar_nginx_paquete"
    export DEBIAN_FRONTEND=noninteractive
    if ! command -v nginx > /dev/null 2>&1; then
        apt-get update -qq 2>/dev/null || _log "ADVERTENCIA: apt-get update falló (sin internet?)"
        apt-get install -y -qq nginx 2>/dev/null || {
            echo "${__STEP_FAIL__} instalar_nginx_paquete: apt-get install nginx falló"
            return 1
        }
    fi
    local nginx_ver
    nginx_ver=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo "?")
    _log "nginx versión $nginx_ver instalado"
    echo "${__STEP_OK__} instalar_nginx_paquete (v${nginx_ver})"

    # ── 2. Configurar nginx.conf principal ───────────────────────
    echo "${__STEP_START__} configurar_nginx_conf"
    cat > "${NGINX_CONF}/nginx.conf" <<'NGINX_EOF'
# ============================================================================
# nginx.conf — SBOS (HOST S02)
# Punto de entrada único del sistema. Recibe tráfico externo en :80 y :443.
# ============================================================================

user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log warn;

include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # ── Performance ──────────────────────────────────────────────
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    client_max_body_size 50m;

    # ── Log formato SBOS con ctx_id ─────────────────────────────
    log_format sbos 'ctx_id="$http_x_ctx_id" '
                    'remote=$remote_addr '
                    'host=$host '
                    'method=$request_method '
                    'uri=$request_uri '
                    'status=$status '
                    'upstream=$upstream_addr '
                    'duration=$request_time '
                    'ua="$http_user_agent"';

    access_log /var/log/nginx/access.log sbos buffer=32k flush=5s;
    error_log /var/log/nginx/error.log warn;

    # ── Mapa de subdominios → upstream ──────────────────────────
    # Convención SBOS:
    #   admin.<tenant>.sksistemas.com    → Core UI
    #   api.<tenant>.sksistemas.com      → Kong API Gateway
    #   monitor.<tenant>.sksistemas.com  → Grafana
    #   identity.<tenant>.sksistemas.com → Keycloak
    #   CUALQUIER OTRO subdominio        → Página bienvenida SBOS

    map $host $subdomain_backend {
        ~^admin\.       "http://127.0.0.1:3000";
        ~^api\.         "http://127.0.0.1:8000";
        ~^monitor\.     "http://127.0.0.1:3000";
        ~^identity\.    "http://127.0.0.1:8080";
        ~^status\.      "http://127.0.0.1:8080";
        default         "kong";
    }

    # ── Interno: health check ───────────────────────────────────
    server {
        listen 127.0.0.1:8080;
        server_name localhost;

        location /health {
            return 200 'OK';
        }
        location /health/ready {
            return 200 'OK';
        }
        location /nginx_status {
            stub_status on;
            allow 127.0.0.1;
            deny all;
        }
    }

    # ── SERVIDOR PRINCIPAL :80 ──────────────────────────────────
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;

        root /var/www/html;

        # ── Hardening headers (CIS + OWASP) ──────────────────────
        add_header X-Frame-Options "DENY" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Content-Security-Policy "default-src 'self'; connect-src 'self' *.sksistemas.com; img-src 'self' data:; style-src 'self' 'unsafe-inline'; font-src 'self'" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
        add_header X-Permitted-Cross-Domain-Policies "none" always;

        # ── Health check público ──────────────────────────────────
        location /health {
            return 200 'OK';
        }

        # ── Página de bienvenida SBOS (/) ────────────────────────
        location = / {
            try_files /index.html =404;
        }

        # ── Proxy a Kong (default) o al backend del subdominio ───
        location / {
            set $backend "http://127.0.0.1:8000";

            # Resolver según subdominio
            if ($subdomain_backend != "kong") {
                set $backend $subdomain_backend;
            }

            proxy_pass $backend;

            # Headers de proxy estándar
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port $server_port;
            proxy_set_header X-Original-URI $request_uri;

            # Timeouts generosos para APIs y WebSocket
            proxy_read_timeout 120s;
            proxy_connect_timeout 10s;
            proxy_send_timeout 60s;

            # Buffering optimizado
            proxy_buffering on;
            proxy_buffer_size 16k;
            proxy_buffers 32 16k;

            # WebSocket support (Core UI, bSearch, Centrifugo)
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
NGINX_EOF
    echo "${__STEP_OK__} configurar_nginx_conf"

    # ── 3. Página de bienvenida SBOS ────────────────────────────
    echo "${__STEP_START__} crear_pagina_bienvenida"
    cat > "${NGINX_WEBROOT}/index.html" <<'HTML_EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SBOS — Sistema Operativo Empresarial</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #0a0e27 0%, #1a1040 50%, #0a0e27 100%);
            color: #e0e0e0;
            display: flex; justify-content: center; align-items: center;
            min-height: 100vh;
        }
        .container { text-align: center; max-width: 700px; padding: 2rem; }
        .logo { font-size: 5rem; margin-bottom: 0.5rem; }
        h1 { font-size: 2.8rem; color: #00d4aa; margin-bottom: 0.3rem; letter-spacing: 0.3rem; }
        .tagline { font-size: 1.2rem; color: #8892b0; margin-bottom: 2.5rem; }
        .status {
            display: inline-flex; align-items: center; gap: 0.5rem;
            background: #00d4aa15; border: 1px solid #00d4aa55;
            color: #00d4aa; padding: 0.6rem 2rem; border-radius: 2rem;
            font-size: 1rem; font-weight: 600; margin-bottom: 2.5rem;
        }
        .status-dot { width: 10px; height: 10px; background: #00d4aa; border-radius: 50%; animation: pulse 2s infinite; }
        @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.3; } }
        .links {
            display: grid; grid-template-columns: 1fr 1fr; gap: 0.8rem;
            margin-bottom: 2.5rem;
        }
        .links a {
            display: flex; flex-direction: column; align-items: flex-start;
            padding: 1rem 1.2rem;
            background: #1a1f3a; border: 1px solid #2d3561;
            border-radius: 10px; color: #ccd6f6; text-decoration: none;
            font-size: 0.9rem; transition: all 0.2s; text-align: left;
        }
        .links a:hover { border-color: #00d4aa; background: #1a2a3a; transform: translateY(-1px); }
        .links a strong { display: block; color: #00d4aa; font-size: 1rem; margin-bottom: 0.2rem; }
        .stack { display: flex; gap: 0.5rem; justify-content: center; flex-wrap: wrap; margin-bottom: 1.5rem; }
        .stack span {
            background: #1a1f3a; border: 1px solid #2d3561;
            padding: 0.3rem 0.8rem; border-radius: 1rem; font-size: 0.75rem;
            color: #8892b0;
        }
        .footer { font-size: 0.8rem; color: #555; }
        .footer a { color: #666; text-decoration: none; }
        .footer a:hover { color: #00d4aa; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🏛️</div>
        <h1>SBOS</h1>
        <p class="tagline">Sistema Operativo Empresarial Soberano</p>
        <div class="status">
            <span class="status-dot"></span> Operativo
        </div>
        <div class="links">
            <a href="/admin"><strong>🔧 Panel Admin</strong>Core UI · Administración del sistema</a>
            <a href="/api"><strong>🔌 API Gateway</strong>Kong · Servicios integrados</a>
            <a href="/monitor"><strong>📊 Monitoreo</strong>Grafana · Métricas y dashboards</a>
            <a href="/docs"><strong>📚 Documentación</strong>Manual SBOS · Referencia técnica</a>
        </div>
        <div class="stack">
            <span>Ubuntu 26.04 LTS</span>
            <span>Kubernetes 1.32</span>
            <span>Go</span>
            <span>Rust</span>
            <span>Python</span>
            <span>PostgreSQL 18</span>
            <span>Keycloak 26</span>
        </div>
        <p class="footer">
            <a href="https://sksistemas.com">SKULL Sistemas</a> &middot; SBOS v3.1 &middot; Junio 2026
        </p>
    </div>
</body>
</html>
HTML_EOF
    chown www-data:www-data "${NGINX_WEBROOT}/index.html" 2>/dev/null || true
    echo "${__STEP_OK__} crear_pagina_bienvenida"

    # ── 4. Validar sintaxis ─────────────────────────────────────
    echo "${__STEP_START__} validar_sintaxis"
    if nginx -t 2>&1 | grep -q "syntax is ok\|test is successful"; then
        echo "${__STEP_OK__} validar_sintaxis"
    else
        local err
        err=$(nginx -t 2>&1 || true)
        _log "ERROR: sintaxis nginx inválida: $err"
        echo "${__STEP_FAIL__} validar_sintaxis: error de configuración"
        return 1
    fi

    # ── 5. Habilitar e iniciar nginx ────────────────────────────
    echo "${__STEP_START__} iniciar_nginx"
    systemctl enable nginx 2>/dev/null || true
    systemctl restart nginx 2>/dev/null || {
        echo "${__STEP_FAIL__} iniciar_nginx: systemctl restart falló"
        return 1
    }
    sleep 2
    if systemctl is-active nginx > /dev/null 2>&1; then
        echo "${__STEP_OK__} iniciar_nginx (systemd active)"
    else
        echo "${__STEP_FAIL__} iniciar_nginx: nginx no se levantó"
        journalctl -u nginx --no-pager -n 20 2>/dev/null | tail -5
        return 1
    fi

    # ── 6. Firewall UFW (si está activo) ────────────────────────
    echo "${__STEP_START__} configurar_firewall"
    if command -v ufw > /dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw allow 80/tcp 2>/dev/null || true
        ufw allow 443/tcp 2>/dev/null || true
        _log "UFW: puertos 80 y 443 abiertos"
    else
        _log "UFW no activo — omitiendo reglas de firewall"
    fi
    echo "${__STEP_OK__} configurar_firewall"

    _log "nginx instalado en HOST S02"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado nginx:"
    local active
    active=$(systemctl is-active nginx 2>/dev/null || echo "inactive")
    _log "  systemd: $active"
    if command -v curl > /dev/null 2>&1; then
        local health
        health=$(curl -sf -o /dev/null -w '%{http_code}' http://localhost/health 2>/dev/null || echo "000")
        _log "  health endpoint: HTTP $health"
    fi
    _log "  config: ${NGINX_CONF}/nginx.conf"
    _log "  webroot: ${NGINX_WEBROOT}"
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reparar_nginx"
    # Validar sintaxis
    if ! nginx -t 2>&1 | grep -q "syntax is ok\|test is successful"; then
        _log "ADVERTENCIA: sintaxis rota — se necesita intervención manual"
        echo "${__STEP_FAIL__} reparar_nginx: sintaxis inválida"
        return 1
    fi
    # Reiniciar si no está activo
    if ! systemctl is-active nginx > /dev/null 2>&1; then
        systemctl restart nginx 2>/dev/null || true
    else
        systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true
    fi
    sleep 2
    if systemctl is-active nginx > /dev/null 2>&1; then
        echo "${__STEP_OK__} reparar_nginx"
    else
        echo "${__STEP_FAIL__} reparar_nginx: no se pudo levantar"
        return 1
    fi
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_systemd_active"
    if systemctl is-active nginx > /dev/null 2>&1; then
        echo "${__STEP_OK__} test_systemd_active"
    else
        echo "${__STEP_FAIL__} test_systemd_active: nginx no está corriendo"
        ok=1
    fi

    echo "${__STEP_START__} test_syntax"
    if nginx -t 2>&1 | grep -qE "syntax is ok|test is successful"; then
        echo "${__STEP_OK__} test_syntax"
    else
        echo "${__STEP_FAIL__} test_syntax"
        ok=1
    fi

    echo "${__STEP_START__} test_health_local"
    local health_code
    health_code=$(curl -sf -o /dev/null -w '%{http_code}' http://localhost/health 2>/dev/null || echo "000")
    if [[ "$health_code" == "200" ]]; then
        echo "${__STEP_OK__} test_health_local (HTTP $health_code)"
    else
        echo "${__STEP_FAIL__} test_health_local: HTTP $health_code"
        ok=1
    fi

    echo "${__STEP_START__} test_pagina_bienvenida"
    local html
    html=$(curl -sf http://localhost/ 2>/dev/null || echo "")
    if echo "$html" | grep -q "SBOS.*Sistema Operativo"; then
        echo "${__STEP_OK__} test_pagina_bienvenida (index.html sirve)"
    else
        echo "${__STEP_FAIL__} test_pagina_bienvenida: index.html no sirve o está vacío"
        ok=1
    fi

    echo "${__STEP_START__} test_headers_seguridad"
    local headers
    headers=$(curl -sI http://localhost/ 2>/dev/null || echo "")
    local header_ok=0
    echo "$headers" | grep -qi "X-Frame-Options" && header_ok=$((header_ok+1))
    echo "$headers" | grep -qi "X-Content-Type-Options" && header_ok=$((header_ok+1))
    echo "$headers" | grep -qi "Strict-Transport-Security" && header_ok=$((header_ok+1))
    if (( header_ok >= 3 )); then
        echo "${__STEP_OK__} test_headers_seguridad (3/3 hardening)"
    else
        echo "${__STEP_FAIL__} test_headers_seguridad: ${header_ok}/3"
        ok=1
    fi

    echo "${__STEP_START__} test_puerto_80"
    if ss -tlnp 2>/dev/null | grep -q ':80 '; then
        echo "${__STEP_OK__} test_puerto_80 (escuchando)"
    else
        echo "${__STEP_FAIL__} test_puerto_80: no escucha en :80"
        ok=1
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== nginx STATUS (HOST S02) ==="
    echo ""
    echo "systemd: $(systemctl is-active nginx 2>/dev/null || echo 'inactive')"
    echo "version: $(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+' || echo '?')"
    echo "config:  ${NGINX_CONF}/nginx.conf"
    echo "webroot: ${NGINX_WEBROOT}"
    echo ""
    echo "Puertos:"
    ss -tlnp 2>/dev/null | grep -E ':80 |:443 ' | awk '{printf "  %s\n", $0}' || echo "  (no disponible)"
    echo ""
    echo "Conexiones activas:"
    ss -tn state established 2>/dev/null | grep -c ESTAB || echo "0"
    echo ""
    echo "Health:"
    curl -sf http://localhost/health 2>/dev/null && echo "" || echo "  (no disponible)"
    echo ""
    echo "Headers hardening:"
    curl -sI http://localhost/ 2>/dev/null | grep -iE "X-Frame|X-Content|Strict-Transport|Content-Security" \
        | awk '{printf "  %s\n", $0}' || echo "  (no disponible)"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando nginx del host"
    echo "${__STEP_START__} detener_nginx"
    systemctl stop nginx 2>/dev/null || true
    systemctl disable nginx 2>/dev/null || true
    echo "${__STEP_OK__} detener_nginx"

    echo "${__STEP_START__} eliminar_config"
    # Respaldar antes de eliminar
    if [[ -f "${NGINX_CONF}/nginx.conf" ]]; then
        cp "${NGINX_CONF}/nginx.conf" "${NGINX_CONF}/nginx.conf.sbos-backup-$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi
    rm -f "${NGINX_CONF}/nginx.conf" 2>/dev/null || true
    rm -f "${NGINX_WEBROOT}/index.html" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_config"

    echo "${__STEP_START__} cerrar_firewall"
    if command -v ufw > /dev/null 2>&1; then
        ufw delete allow 80/tcp 2>/dev/null || true
        ufw delete allow 443/tcp 2>/dev/null || true
    fi
    echo "${__STEP_OK__} cerrar_firewall"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico nginx (HOST S02) ==="
    echo "systemd status:"
    systemctl status nginx --no-pager -l 2>/dev/null | head -20 || echo "  no disponible"
    echo ""
    echo "Últimos errores:"
    journalctl -u nginx --no-pager -n 20 2>/dev/null | grep -iE "error|fail|warn" || echo "  sin errores"
    echo ""
    echo "Test sintaxis:"
    nginx -t 2>&1 || true
    echo ""
    echo "Conexiones en :80:"
    ss -tlnp 2>/dev/null | grep ':80 ' || echo "  ninguna"
    echo ""
    echo "UFW status:"
    ufw status 2>/dev/null || echo "  ufw no disponible"
}
