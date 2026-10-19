#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — Ficha sbos-bkernel
# Instala y administra el daemon bKernel CDC en el host (systemd).
# bkernel es CERRADO — cero puertos TCP (F-02).
#
# Variables de entorno (provistas por BOS):
#   TENANT_ID           — ID del tenant
#   BKERNEL_BIN_SRC     — ruta del binario MUSL (default: /opt/skull/sbos/bos/blibs/bkernel/bkernel-daemon)
#   BKERNEL_CONFIG_SRC  — ruta del config TOML
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-bkernel.log}"
BKERNEL_USER="${BKERNEL_USER:-bkernel}"
BKERNEL_GROUP="${BKERNEL_GROUP:-bkernel}"
BKERNEL_BIN_DST="${BKERNEL_BIN_DST:-/usr/local/bin/bkernel-daemon}"
BKERNEL_CONFIG_DST="${BKERNEL_CONFIG_DST:-/etc/bos/blibs/bkernel/bkernel.toml}"
BKERNEL_SERVICE="${BKERNEL_SERVICE:-bkernel.service}"
BKERNEL_SERVICE_DST="${BKERNEL_SERVICE_DST:-/etc/systemd/system/bkernel.service}"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-bkernel] $*" | tee -a "$FICHA_LOG"; }

# ── Pre-install ───────────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_systemd"
    if ! command -v systemctl &>/dev/null; then
        echo "${__STEP_FAIL__} verificar_systemd: systemd no disponible"
        return 1
    fi
    echo "${__STEP_OK__} verificar_systemd"

    echo "${__STEP_START__} verificar_usuario"
    if ! id "$BKERNEL_USER" &>/dev/null; then
        _log "creando usuario $BKERNEL_USER"
        useradd --system --no-create-home --shell /usr/sbin/nologin "$BKERNEL_USER" 2>/dev/null || true
    fi
    echo "${__STEP_OK__} verificar_usuario"

    echo "${__STEP_START__} verificar_directorios"
    mkdir -p /etc/bos/blibs/bkernel/servers /etc/bos/env.d /var/lib/bkernel /var/log/bos/fichas
    chown -R "$BKERNEL_USER:$BKERNEL_GROUP" /etc/bos/blibs/bkernel /var/lib/bkernel 2>/dev/null || true
    echo "${__STEP_OK__} verificar_directorios"

    return 0
}

# ── Install ───────────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # 1. Copiar binario
    echo "${__STEP_START__} copiar_binario"
    if [ -n "${BKERNEL_BIN_SRC:-}" ] && [ -f "$BKERNEL_BIN_SRC" ]; then
        cp "$BKERNEL_BIN_SRC" "$BKERNEL_BIN_DST"
        chmod 755 "$BKERNEL_BIN_DST"
        chown "$BKERNEL_USER:$BKERNEL_GROUP" "$BKERNEL_BIN_DST"
        _log "binario copiado de $BKERNEL_BIN_SRC"
    elif [ -f "$BKERNEL_BIN_DST" ]; then
        _log "binario ya existe en $BKERNEL_BIN_DST"
    else
        echo "${__STEP_FAIL__} copiar_binario: BKERNEL_BIN_SRC no definido y $BKERNEL_BIN_DST no existe"
        return 1
    fi
    echo "${__STEP_OK__} copiar_binario"

    # 2. Copiar config
    echo "${__STEP_START__} copiar_config"
    if [ -n "${BKERNEL_CONFIG_SRC:-}" ] && [ -f "$BKERNEL_CONFIG_SRC" ]; then
        mkdir -p "$(dirname "$BKERNEL_CONFIG_DST")"
        cp "$BKERNEL_CONFIG_SRC" "$BKERNEL_CONFIG_DST"
        chmod 640 "$BKERNEL_CONFIG_DST"
        chown "$BKERNEL_USER:$BKERNEL_GROUP" "$BKERNEL_CONFIG_DST"
        _log "config copiado de $BKERNEL_CONFIG_SRC"
    elif [ -f "$BKERNEL_CONFIG_DST" ]; then
        _log "config ya existe en $BKERNEL_CONFIG_DST"
    else
        _log "ADVERTENCIA: sin config TOML — bkernel usará defaults"
    fi
    echo "${__STEP_OK__} copiar_config"

    # 3. Instalar systemd unit
    echo "${__STEP_START__} instalar_systemd_unit"
    if [ -f "${BKERNEL_SERVICE_SRC:-}" ]; then
        cp "$BKERNEL_SERVICE_SRC" "$BKERNEL_SERVICE_DST"
    else
        # Generar unit desde template inline
        cat > "$BKERNEL_SERVICE_DST" <<'SYSTEMD_UNIT'
[Unit]
Description=bKernel CDC Daemon — PostgreSQL WAL Change Data Capture
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
NotifyAccess=main
WatchdogSec=30
User=bkernel
Group=bkernel
ExecStart=/usr/local/bin/bkernel-daemon --config /etc/bos/blibs/bkernel/bkernel.toml
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5s
TimeoutStartSec=30
TimeoutStopSec=15

EnvironmentFile=-/etc/bos/env.d/bkernel

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/etc/bos/blibs/bkernel /var/lib/bkernel /run/bos
PrivateTmp=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
SystemCallFilter=@network-io @file-system @signal @process
UMask=0077

StandardOutput=journal
StandardError=journal
SyslogIdentifier=bkernel-daemon

[Install]
WantedBy=multi-user.target
SYSTEMD_UNIT
    fi

    chmod 644 "$BKERNEL_SERVICE_DST"
    systemctl daemon-reload
    systemctl enable "$BKERNEL_SERVICE" 2>/dev/null || true
    echo "${__STEP_OK__} instalar_systemd_unit"

    # 4. Iniciar servicio
    echo "${__STEP_START__} iniciar_servicio"
    if systemctl is-active --quiet "$BKERNEL_SERVICE" 2>/dev/null; then
        systemctl restart "$BKERNEL_SERVICE" 2>/dev/null || true
        _log "servicio reiniciado"
    else
        systemctl start "$BKERNEL_SERVICE" 2>/dev/null || true
        _log "servicio iniciado"
    fi
    sleep 3
    echo "${__STEP_OK__} iniciar_servicio"

    _log "bkernel instalado (user=$BKERNEL_USER, binary=$BKERNEL_BIN_DST)"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────────
ficha_post_install() {
    echo "${__STEP_START__} verificar_estado"
    if systemctl is-active --quiet "$BKERNEL_SERVICE" 2>/dev/null; then
        _log "bkernel.service: ACTIVE"
    else
        _log "bkernel.service: INACTIVE — verificar journalctl -u bkernel"
    fi

    # Verificar que NO hay puertos TCP abiertos (F-02)
    local listeners
    listeners=$(ss -tlnp 2>/dev/null | grep bkernel || true)
    if [ -n "$listeners" ]; then
        _log "⚠️  ALERTA: bkernel tiene puertos TCP abiertos (viola F-02):"
        _log "$listeners"
    else
        _log "✅ bkernel CERRADO — cero puertos TCP (F-02)"
    fi

    echo "${__STEP_OK__} verificar_estado"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_servicio"
    if systemctl is-active --quiet "$BKERNEL_SERVICE" 2>/dev/null; then
        echo "${__STEP_OK__} test_servicio (active)"
    else
        echo "${__STEP_FAIL__} test_servicio: no está active"
        ok=1
    fi

    echo "${__STEP_START__} test_puertos_cerrados"
    local listeners
    listeners=$(ss -tlnp 2>/dev/null | grep bkernel || true)
    if [ -z "$listeners" ]; then
        echo "${__STEP_OK__} test_puertos_cerrados (F-02 ✅)"
    else
        echo "${__STEP_FAIL__} test_puertos_cerrados: bkernel tiene puertos TCP abiertos"
        ok=1
    fi

    echo "${__STEP_START__} test_proceso"
    if pgrep -u "$BKERNEL_USER" bkernel-daemon > /dev/null 2>&1; then
        echo "${__STEP_OK__} test_proceso (running as $BKERNEL_USER)"
    else
        echo "${__STEP_FAIL__} test_proceso: no running"
        ok=1
    fi

    return $ok
}

# ── Repair ────────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reparar_bkernel"
    systemctl stop "$BKERNEL_SERVICE" 2>/dev/null || true
    sleep 1
    ficha_install
    echo "${__STEP_OK__} reparar_bkernel"
    return 0
}

# ── Status ────────────────────────────────────────────────────────────
ficha_status() {
    echo "=== sbos-bkernel STATUS ==="
    echo ""
    systemctl status "$BKERNEL_SERVICE" 2>/dev/null | head -15 || echo "  (no disponible)"
    echo ""
    echo "Puertos TCP abiertos (deben ser 0):"
    ss -tlnp 2>/dev/null | grep bkernel || echo "  ✅ NINGUNO — bkernel CERRADO (F-02)"
    echo ""
    echo "Proceso:"
    ps aux 2>/dev/null | grep bkernel-daemon | grep -v grep || echo "  (no running)"
}

# ── Uninstall ─────────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando bkernel"
    echo "${__STEP_START__} desinstalar"

    systemctl stop "$BKERNEL_SERVICE" 2>/dev/null || true
    systemctl disable "$BKERNEL_SERVICE" 2>/dev/null || true
    rm -f "$BKERNEL_SERVICE_DST"
    rm -f "$BKERNEL_BIN_DST"
    systemctl daemon-reload 2>/dev/null || true

    _log "bkernel desinstalado (config preservado en $BKERNEL_CONFIG_DST)"
    echo "${__STEP_OK__} desinstalar"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico sbos-bkernel ==="
    echo "Servicio:"
    systemctl status "$BKERNEL_SERVICE" 2>/dev/null | grep -E "Active:|Main PID|Loaded:" || echo "  no disponible"
    echo ""
    echo "Últimas 10 líneas de log:"
    journalctl -u "$BKERNEL_SERVICE" --no-pager -n 10 2>/dev/null || echo "  sin logs"
    echo ""
    echo "Puertos abiertos:"
    ss -tlnp 2>/dev/null | grep -E "bkernel|LISTEN" || echo "  ✅ cero puertos"
}
