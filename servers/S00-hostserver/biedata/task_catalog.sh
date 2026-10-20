#!/usr/bin/env bash
# task_catalog.sh — biedata (Orquestador JSON-RPC 2.0)
# BC-12 · S00-hostserver · systemd daemon · ADR-020 · ADR-022
# R16: sin paths hardcodeados

set -euo pipefail

BIEDATA_USER="${BIEDATA_USER:-biedata}"
BIEDATA_BIN_DST="${BIEDATA_BIN_DST:-/usr/local/bin/biedata}"
BIEDATA_BIN_SRC="${BIEDATA_BIN_SRC:-${SBOS_FICHA_DIR}/bin/biedata}"
BIEDATA_CONFIG_DST="${BIEDATA_CONFIG_DST:-/etc/bos/biedata/biedata.toml}"
BIEDATA_SOCKET="${BIEDATA_SOCKET:-/run/bos/biedata.sock}"
BIEDATA_SERVICE="biedata.service"
BIEDATA_SERVICE_DST="/etc/systemd/system/biedata.service"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"

    # Usuario del sistema
    id "${BIEDATA_USER}" &>/dev/null || \
        useradd --system --no-create-home --shell /usr/sbin/nologin \
                --gid bosagent "${BIEDATA_USER}" 2>/dev/null || true

    # Directorios
    mkdir -p /etc/bos/biedata /var/log/biedata /run/bos
    chown -R "${BIEDATA_USER}:bosagent" /etc/bos/biedata /var/log/biedata 2>/dev/null || true
    chmod 750 /etc/bos/biedata

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"

    # Binario
    if [[ -n "${BIEDATA_BIN_SRC:-}" && -f "${BIEDATA_BIN_SRC}" ]]; then
        cp "${BIEDATA_BIN_SRC}" "${BIEDATA_BIN_DST}"
        chmod 755 "${BIEDATA_BIN_DST}"
        chown "${BIEDATA_USER}:bosagent" "${BIEDATA_BIN_DST}"
    elif [[ ! -f "${BIEDATA_BIN_DST}" ]]; then
        echo "ERROR: BIEDATA_BIN_SRC no definido y ${BIEDATA_BIN_DST} no existe" >&2
        return 1
    fi

    # Config desde template o existente
    if [[ -n "${BIEDATA_CONFIG_SRC:-}" && -f "${BIEDATA_CONFIG_SRC}" ]]; then
        cp "${BIEDATA_CONFIG_SRC}" "${BIEDATA_CONFIG_DST}"
        chmod 640 "${BIEDATA_CONFIG_DST}"
        chown "${BIEDATA_USER}:bosagent" "${BIEDATA_CONFIG_DST}"
    fi

    # Unidad systemd
    cat > "${BIEDATA_SERVICE_DST}" <<'UNIT'
[Unit]
Description=biedata — Orquestador JSON-RPC 2.0 SBOS
After=network-online.target bauth.service postgresql.service
Wants=network-online.target
Requires=bauth.service

[Service]
Type=notify
NotifyAccess=main
WatchdogSec=30
User=biedata
Group=bosagent
ExecStart=/usr/local/bin/biedata --config /etc/bos/biedata/biedata.toml
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5s
TimeoutStartSec=45
EnvironmentFile=-/etc/bos/biedata/biedata.env
RuntimeDirectory=bos
RuntimeDirectoryMode=0755
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/etc/bos/biedata /var/log/biedata /run/bos
PrivateTmp=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
UMask=0077
StandardOutput=journal
StandardError=journal
SyslogIdentifier=biedata

[Install]
WantedBy=multi-user.target
UNIT

    chmod 644 "${BIEDATA_SERVICE_DST}"
    systemctl daemon-reload
    systemctl enable "${BIEDATA_SERVICE}" 2>/dev/null || true

    if systemctl is-active --quiet "${BIEDATA_SERVICE}"; then
        systemctl restart "${BIEDATA_SERVICE}"
    else
        systemctl start "${BIEDATA_SERVICE}" || true
    fi
    sleep 3

    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    ficha_health
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    ficha_install
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    systemctl restart "${BIEDATA_SERVICE}" || true
    sleep 3
    ficha_health
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    systemctl stop "${BIEDATA_SERVICE}" 2>/dev/null || true
    systemctl disable "${BIEDATA_SERVICE}" 2>/dev/null || true
    rm -f "${BIEDATA_SERVICE_DST}" "${BIEDATA_BIN_DST}"
    systemctl daemon-reload 2>/dev/null || true
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    systemctl is-active --quiet "${BIEDATA_SERVICE}" || \
        { echo "ERROR: biedata.service no está activo" >&2; return 1; }
    [[ -S "${BIEDATA_SOCKET}" ]] || \
        { echo "ERROR: socket ${BIEDATA_SOCKET} no existe" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} health"
}

# ── describe ───────────────────────────────────────────────────
ficha_describe() {
    echo "=== biedata — Orquestador JSON-RPC 2.0 ==="
    systemctl status "${BIEDATA_SERVICE}" --no-pager 2>/dev/null | head -10 || true
    echo "Socket: ${BIEDATA_SOCKET}"
}
