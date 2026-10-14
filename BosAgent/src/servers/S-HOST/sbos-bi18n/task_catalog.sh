#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — Ficha sbos-bi18n
# Instala y administra el daemon bi18n (Orquestador Universal de i18n) en
# el host como servicio systemd. Runtime: Rust 1.85+ MUSL estático.
#
# Variables de entorno (provistas por BOS):
#   BI18N_BIN_SRC   — ruta del binario bi18nd real (si ausente usa stub)
#   BI18N_CTL_SRC   — ruta del binario bi18nctl
#   BI18N_CONF_SRC  — ruta del bi18n.toml de configuración
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-bi18n.log}"
BI18N_USER="${BI18N_USER:-bos}"
BI18N_GROUP="${BI18N_GROUP:-bosagent}"
BI18N_BIN_DST="${BI18N_BIN_DST:-/usr/local/bin/bi18nd}"
BI18N_CTL_DST="${BI18N_CTL_DST:-/usr/local/bin/bi18nctl}"
BI18N_CONF_DST="${BI18N_CONF_DST:-/etc/bos/bi18n.toml}"
BI18N_SERVICE_DST="${BI18N_SERVICE_DST:-/etc/systemd/system/bi18nd.service}"

FICHA_DIR="${FICHA_DIR:-$(dirname "$(readlink -f "$0")")}"
BI18N_STUB_SRC="${FICHA_DIR}/bin/bi18nd"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-bi18n] $*" | tee -a "$FICHA_LOG"; }

ficha_pre_install() {
    echo "${__STEP_START__} verificar_systemd"
    command -v systemctl &>/dev/null || { echo "${__STEP_FAIL__} verificar_systemd: systemd no disponible"; return 1; }
    echo "${__STEP_OK__} verificar_systemd"

    echo "${__STEP_START__} verificar_usuario"
    id "$BI18N_USER" &>/dev/null || {
        _log "creando usuario $BI18N_USER"
        useradd --system --no-create-home --shell /usr/sbin/nologin "$BI18N_USER" 2>/dev/null || true
    }
    getent group "$BI18N_GROUP" &>/dev/null || groupadd --system "$BI18N_GROUP" 2>/dev/null || true
    echo "${__STEP_OK__} verificar_usuario"

    echo "${__STEP_START__} verificar_directorios"
    mkdir -p \
        /etc/bos/bi18n \
        /opt/skull/country-rules \
        /opt/skull/locales/es-BO \
        /opt/skull/locales/en-US \
        /run/bos \
        /var/log/bos/fichas
    chown "${BI18N_USER}:${BI18N_GROUP}" /run/bos 2>/dev/null || true
    chmod 2770 /run/bos 2>/dev/null || true
    echo "${__STEP_OK__} verificar_directorios"

    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # Idempotencia: skip si ya activo y misma versión
    if systemctl is-active bi18nd &>/dev/null; then
        local cur_ver
        cur_ver=$("$BI18N_CTL_DST" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "0.0.0")
        if [[ "$cur_ver" == "1.0.0" ]]; then
            echo "${__STEP_SKIP__} bi18n_install: ya activo v${cur_ver} — skip"
            return 0
        fi
    fi

    # ── Binarios ──────────────────────────────────────────────────────────
    echo "${__STEP_START__} instalar_binarios"
    local bin_src="${BI18N_BIN_SRC:-$BI18N_STUB_SRC}"
    if [[ -f "$bin_src" ]]; then
        install -m 0755 "$bin_src" "$BI18N_BIN_DST"
        _log "bi18nd instalado desde $bin_src"
    else
        _log "ADVERTENCIA: binario bi18nd no encontrado en $bin_src — se requiere despliegue del binario real"
        echo "${__STEP_FAIL__} instalar_binarios: binario bi18nd no disponible"
        return 1
    fi

    if [[ -n "${BI18N_CTL_SRC:-}" && -f "$BI18N_CTL_SRC" ]]; then
        install -m 0755 "$BI18N_CTL_SRC" "$BI18N_CTL_DST"
        _log "bi18nctl instalado"
    fi
    echo "${__STEP_OK__} instalar_binarios"

    # ── Configuración ─────────────────────────────────────────────────────
    echo "${__STEP_START__} instalar_configuracion"
    if [[ -n "${BI18N_CONF_SRC:-}" && -f "$BI18N_CONF_SRC" ]]; then
        install -m 0640 "$BI18N_CONF_SRC" "$BI18N_CONF_DST"
        chown "${BI18N_USER}:${BI18N_GROUP}" "$BI18N_CONF_DST"
        _log "bi18n.toml instalado"
    elif [[ ! -f "$BI18N_CONF_DST" ]]; then
        # Configuración mínima bootstrap
        cat > "$BI18N_CONF_DST" <<'TOML'
[server]
socket_path = "/run/bos/bi18n.sock"
grpc_socket_path = "/run/bos/bi18n-grpc.sock"
max_connections = 256

[locale]
default = "es-BO"
fallback = "en-US"
country_rules_dir = "/opt/skull/country-rules"
locales_dir = "/opt/skull/locales"

[audit]
ctx_id_required = true
log_path = "/var/log/bos/bi18n-audit.log"
TOML
        chown "${BI18N_USER}:${BI18N_GROUP}" "$BI18N_CONF_DST"
        chmod 0640 "$BI18N_CONF_DST"
        _log "bi18n.toml bootstrap generado"
    fi
    echo "${__STEP_OK__} instalar_configuracion"

    # ── Reglas de país ────────────────────────────────────────────────────
    echo "${__STEP_START__} instalar_country_rules"
    local rules_src="${FICHA_DIR}/country-rules"
    if [[ -d "$rules_src" ]]; then
        cp -r "${rules_src}/." /opt/skull/country-rules/
        _log "reglas de país copiadas desde $rules_src"
    fi
    echo "${__STEP_OK__} instalar_country_rules"

    # ── Locales FTL ───────────────────────────────────────────────────────
    echo "${__STEP_START__} instalar_locales"
    local locales_src="${FICHA_DIR}/locales"
    if [[ -d "$locales_src" ]]; then
        cp -r "${locales_src}/." /opt/skull/locales/
        _log "locales FTL copiados desde $locales_src"
    fi
    echo "${__STEP_OK__} instalar_locales"

    # ── Unit systemd ──────────────────────────────────────────────────────
    echo "${__STEP_START__} instalar_servicio"
    local svc_src="${FICHA_DIR}/bi18nd.service"
    if [[ -f "$svc_src" ]]; then
        install -m 0644 "$svc_src" "$BI18N_SERVICE_DST"
    else
        # Unit mínima de bootstrap
        cat > "$BI18N_SERVICE_DST" <<UNIT
[Unit]
Description=SBOS bi18n — Orquestador Universal de Internacionalización
After=network.target

[Service]
Type=notify
ExecStart=${BI18N_BIN_DST}
ExecReload=/bin/kill -HUP \$MAINPID
Environment=BI18N_CONFIG=${BI18N_CONF_DST}
WatchdogSec=30
TimeoutStartSec=30
TimeoutStopSec=30
Restart=on-failure
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=3
User=${BI18N_USER}
Group=${BI18N_GROUP}
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=/run/bos
ReadOnlyPaths=/etc/bos /opt/skull/country-rules /opt/skull/locales
RuntimeDirectory=bos
RuntimeDirectoryMode=2770
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT
        _log "unit systemd bootstrap generada"
    fi
    systemctl daemon-reload
    echo "${__STEP_OK__} instalar_servicio"

    # ── Habilitar e iniciar ────────────────────────────────────────────────
    echo "${__STEP_START__} iniciar_bi18n"
    systemctl enable bi18nd 2>/dev/null || true
    systemctl restart bi18nd >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} iniciar_bi18n: no se pudo iniciar bi18nd"
        journalctl -u bi18nd -n 20 --no-pager >> "$FICHA_LOG" 2>&1 || true
        return 1
    }
    _log "bi18nd iniciado"
    echo "${__STEP_OK__} iniciar_bi18n"

    return 0
}

ficha_post_install() {
    echo "${__STEP_START__} verificar_socket"
    local t=0
    while (( t < 15 )); do
        [[ -S "/run/bos/bi18n.sock" ]] && break
        sleep 1; t=$((t+1))
    done
    if [[ ! -S "/run/bos/bi18n.sock" ]]; then
        echo "${__STEP_FAIL__} verificar_socket: /run/bos/bi18n.sock no aparece tras 15s"
        return 1
    fi
    echo "${__STEP_OK__} verificar_socket"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_bi18n"
    systemctl is-active bi18nd &>/dev/null || {
        echo "${__STEP_FAIL__} verificar_bi18n: bi18nd no activo"
        return 1
    }
    echo "${__STEP_OK__} verificar_bi18n"
    return 0
}

ficha_health() {
    if systemctl is-active bi18nd &>/dev/null; then
        echo "HEALTHY"
        return 0
    fi
    echo "DEGRADED: bi18nd no activo ($(systemctl is-active bi18nd 2>/dev/null || echo unknown))"
    return 1
}

ficha_repair() {
    _log "ficha_repair: reiniciando bi18nd"
    systemctl restart bi18nd >> "$FICHA_LOG" 2>&1 && _log "bi18nd reiniciado" || {
        _log "FALLO restart — reintentando instalación"
        ficha_install
    }
}

ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_servicio_activo"
    if systemctl is-active bi18nd &>/dev/null; then
        echo "${__STEP_OK__} test_servicio_activo"
    else
        echo "${__STEP_FAIL__} test_servicio_activo: bi18nd no activo"
        ok=1
    fi

    echo "${__STEP_START__} test_socket"
    if [[ -S "/run/bos/bi18n.sock" ]]; then
        echo "${__STEP_OK__} test_socket (/run/bos/bi18n.sock presente)"
    else
        echo "${__STEP_FAIL__} test_socket: /run/bos/bi18n.sock no existe"
        ok=1
    fi

    echo "${__STEP_START__} test_health_rpc"
    local resp
    resp=$(echo '{"jsonrpc":"2.0","id":1,"method":"bi18n.health.check","params":{}}' \
        | socat - UNIX-CONNECT:/run/bos/bi18n.sock 2>/dev/null || echo "")
    if echo "$resp" | grep -q '"status"'; then
        echo "${__STEP_OK__} test_health_rpc"
    else
        echo "${__STEP_FAIL__} test_health_rpc: sin respuesta JSON-RPC"
        ok=1
    fi

    return $ok
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_bi18n"
    systemctl stop bi18nd 2>/dev/null || true
    systemctl disable bi18nd 2>/dev/null || true
    rm -f "$BI18N_SERVICE_DST" "$BI18N_BIN_DST" "$BI18N_CTL_DST"
    systemctl daemon-reload
    _log "bi18nd eliminado"
    echo "${__STEP_OK__} eliminar_bi18n"
    return 0
}
