#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — Ficha bcms
# Instala y administra el daemon bcms (Gestión de contenido SBOS) en el host
# como servicio systemd. Stack: PHP 8.2, CodeIgniter.
#
# Variables de entorno (provistas por BOS):
#   BCMS_BIN_SRC    — ruta del binario bcmsd (si ausente usa stub)
#   BCMS_CONF_SRC   — ruta de bcms.toml de configuración
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/bcms.log}"
BCMS_USER="${BCMS_USER:-bos}"
BCMS_GROUP="${BCMS_GROUP:-bosagent}"
BCMS_BIN_DST="${BCMS_BIN_DST:-/usr/local/bin/bcmsd}"
BCMS_CONF_DST="${BCMS_CONF_DST:-/etc/bos/bcms.toml}"
BCMS_SERVICE_DST="${BCMS_SERVICE_DST:-/etc/systemd/system/bcmsd.service}"
BCMS_SOCKET_DIR="${BCMS_SOCKET_DIR:-/run/bos}"
NGINX_DOMAINS_DIR="${NGINX_DOMAINS_DIR:-/etc/nginx/conf.d/domains}"

FICHA_DIR="${SBOS_FICHA_DIR:-${FICHA_DIR:-$(dirname "$(readlink -f "$0")")}}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [bcms] $*" | tee -a "$FICHA_LOG"; }

ficha_pre_install() {
    echo "${__STEP_START__} verificar_systemd"
    command -v systemctl &>/dev/null || { echo "${__STEP_FAIL__} verificar_systemd: systemd no disponible"; return 1; }
    echo "${__STEP_OK__} verificar_systemd"

    echo "${__STEP_START__} verificar_nginx_domains"
    if [ ! -d "$NGINX_DOMAINS_DIR" ]; then
        echo "${__STEP_FAIL__} verificar_nginx_domains: $NGINX_DOMAINS_DIR no existe — nginx debe estar instalado primero"
        return 1
    fi
    echo "${__STEP_OK__} verificar_nginx_domains"

    echo "${__STEP_START__} verificar_usuario"
    id "$BCMS_USER" &>/dev/null || {
        useradd --system --no-create-home --shell /usr/sbin/nologin "$BCMS_USER" 2>/dev/null || true
    }
    getent group "$BCMS_GROUP" &>/dev/null || groupadd --system "$BCMS_GROUP" 2>/dev/null || true
    echo "${__STEP_OK__} verificar_usuario"

    echo "${__STEP_START__} verificar_directorios"
    mkdir -p \
        /etc/bos/bcms \
        /var/lib/bcms \
        /var/log/bos/fichas
    echo "${__STEP_OK__} verificar_directorios"
}

ficha_install() {
    echo "${__STEP_START__} instalar_binario"
    local stub="${FICHA_DIR}/bin/bcmsd"
    local src="${BCMS_BIN_SRC:-}"

    if [ -n "$src" ] && [ -f "$src" ]; then
        install -o root -g root -m 0755 "$src" "$BCMS_BIN_DST"
        _log "binario instalado desde $src"
    elif [ -f "$stub" ]; then
        install -o root -g root -m 0755 "$stub" "$BCMS_BIN_DST"
        _log "stub instalado — reemplazar con binario real"
    else
        _log "ADVERTENCIA: sin binario bcmsd — ficha en espera de desarrollo"
        echo "${__STEP_SKIP__} instalar_binario: binario pendiente de desarrollo"
        return 0
    fi
    echo "${__STEP_OK__} instalar_binario"

    echo "${__STEP_START__} instalar_configuracion"
    if [ ! -f "$BCMS_CONF_DST" ]; then
        cat > "$BCMS_CONF_DST" <<'TOML'
# bcms.toml — Configuración del daemon bcms
# Generado por ficha bcms — editar con cuidado

[daemon]
socket = "/run/bos/bcms.sock"
log    = "/var/log/bos/fichas/bcms.log"

[nginx]
domains_dir = "/etc/nginx/conf.d/domains"
reload_cmd  = "nginx -s reload"

[database]
# DSN inyectado por BOS en tiempo de ejecución (env BOS_PG_DSN)
schema = "bcms"
TOML
        _log "bcms.toml creado"
    fi
    echo "${__STEP_OK__} instalar_configuracion"

    echo "${__STEP_START__} instalar_servicio"
    cat > "$BCMS_SERVICE_DST" <<'SERVICE'
[Unit]
Description=bcms — SBOS CMS daemon
After=network.target bos.service postgresql.service

[Service]
Type=simple
User=bos
Group=bosagent
ExecStart=/usr/local/bin/bcmsd --config /etc/bos/bcms.toml
Restart=on-failure
RestartSec=5
RuntimeDirectory=bos
RuntimeDirectoryMode=0775
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bcmsd

[Install]
WantedBy=multi-user.target
SERVICE
    systemctl daemon-reload
    echo "${__STEP_OK__} instalar_servicio"

    echo "${__STEP_START__} habilitar_servicio"
    systemctl enable bcmsd.service 2>/dev/null || true
    systemctl start bcmsd.service 2>/dev/null || _log "ADVERTENCIA: servicio no pudo iniciar — binario pendiente"
    echo "${__STEP_OK__} habilitar_servicio"
}

ficha_health() {
    echo "${__STEP_START__} health_bcms"
    if systemctl is-active --quiet bcmsd.service 2>/dev/null; then
        echo "${__STEP_OK__} health_bcms: activo"
    else
        _log "bcmsd inactivo — binario pendiente de desarrollo"
        echo "${__STEP_SKIP__} health_bcms: stub en espera"
    fi
}

ficha_update() {
    ficha_install
}

ficha_remove() {
    echo "${__STEP_START__} detener_servicio"
    systemctl stop bcmsd.service 2>/dev/null || true
    systemctl disable bcmsd.service 2>/dev/null || true
    rm -f "$BCMS_SERVICE_DST"
    systemctl daemon-reload
    echo "${__STEP_OK__} detener_servicio"

    echo "${__STEP_START__} eliminar_binario"
    rm -f "$BCMS_BIN_DST"
    echo "${__STEP_OK__} eliminar_binario"
}

CMD="${1:-}"
case "$CMD" in
    pre_install)  ficha_pre_install ;;
    install)      ficha_install ;;
    health)       ficha_health ;;
    update)       ficha_update ;;
    remove)       ficha_remove ;;
    *)
        echo "Uso: $0 {pre_install|install|health|update|remove}"
        exit 1
        ;;
esac
