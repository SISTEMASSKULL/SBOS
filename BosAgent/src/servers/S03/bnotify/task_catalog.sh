#!/usr/bin/env bash
# task_catalog.sh — bnotify (Push MFA y Notificaciones)
# BC-12 · S03-identityserver · systemd daemon Rust/gRPC · ADR-020 · ADR-022
# R16: sin paths hardcodeados

set -euo pipefail

BNOTIFY_USER="${BNOTIFY_USER:-bnotify}"
BNOTIFY_BIN_DST="${BNOTIFY_BIN_DST:-/usr/local/bin/bnotify}"
BNOTIFY_CONFIG_DST="${BNOTIFY_CONFIG_DST:-/etc/bos/bnotify/bnotify.toml}"
BNOTIFY_SOCKET="${BNOTIFY_SOCKET:-/run/bos/bnotify.sock}"
BNOTIFY_SERVICE="bnotify.service"
BNOTIFY_SERVICE_DST="/etc/systemd/system/bnotify.service"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"

    id "${BNOTIFY_USER}" &>/dev/null || \
        useradd --system --no-create-home --shell /usr/sbin/nologin \
                --gid bosagent "${BNOTIFY_USER}" 2>/dev/null || true

    mkdir -p /etc/bos/bnotify /var/log/bnotify /run/bos
    chown -R "${BNOTIFY_USER}:bosagent" /etc/bos/bnotify /var/log/bnotify 2>/dev/null || true
    chmod 750 /etc/bos/bnotify

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"

    if [[ -n "${BNOTIFY_BIN_SRC:-}" && -f "${BNOTIFY_BIN_SRC}" ]]; then
        cp "${BNOTIFY_BIN_SRC}" "${BNOTIFY_BIN_DST}"
        chmod 755 "${BNOTIFY_BIN_DST}"
        chown "${BNOTIFY_USER}:bosagent" "${BNOTIFY_BIN_DST}"
    elif [[ ! -f "${BNOTIFY_BIN_DST}" ]]; then
        echo "ERROR: BNOTIFY_BIN_SRC no definido y ${BNOTIFY_BIN_DST} no existe" >&2
        return 1
    fi

    if [[ -n "${BNOTIFY_CONFIG_SRC:-}" && -f "${BNOTIFY_CONFIG_SRC}" ]]; then
        cp "${BNOTIFY_CONFIG_SRC}" "${BNOTIFY_CONFIG_DST}"
        chmod 640 "${BNOTIFY_CONFIG_DST}"
        chown "${BNOTIFY_USER}:bosagent" "${BNOTIFY_CONFIG_DST}"
    fi

    cat > "${BNOTIFY_SERVICE_DST}" <<'UNIT'
[Unit]
Description=bnotify — Push MFA y Notificaciones Soberanas SBOS
After=network-online.target bauth.service postgresql.service
Wants=network-online.target
Requires=bauth.service

[Service]
Type=notify
NotifyAccess=main
WatchdogSec=30
User=bnotify
Group=bosagent
ExecStart=/usr/local/bin/bnotify --config /etc/bos/bnotify/bnotify.toml
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5s
TimeoutStartSec=30
EnvironmentFile=-/etc/bos/bnotify/bnotify.env
RuntimeDirectory=bos
RuntimeDirectoryMode=0755
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/etc/bos/bnotify /var/log/bnotify /run/bos
PrivateTmp=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
UMask=0077
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bnotify

[Install]
WantedBy=multi-user.target
UNIT

    chmod 644 "${BNOTIFY_SERVICE_DST}"
    systemctl daemon-reload
    systemctl enable "${BNOTIFY_SERVICE}" 2>/dev/null || true

    if systemctl is-active --quiet "${BNOTIFY_SERVICE}"; then
        systemctl restart "${BNOTIFY_SERVICE}"
    else
        systemctl start "${BNOTIFY_SERVICE}" || true
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
    systemctl restart "${BNOTIFY_SERVICE}" || true
    sleep 3
    ficha_health
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    systemctl stop "${BNOTIFY_SERVICE}" 2>/dev/null || true
    systemctl disable "${BNOTIFY_SERVICE}" 2>/dev/null || true
    rm -f "${BNOTIFY_SERVICE_DST}" "${BNOTIFY_BIN_DST}"
    systemctl daemon-reload 2>/dev/null || true
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    systemctl is-active --quiet "${BNOTIFY_SERVICE}" || \
        { echo "ERROR: bnotify.service no está activo" >&2; return 1; }
    [[ -S "${BNOTIFY_SOCKET}" ]] || \
        { echo "ERROR: socket ${BNOTIFY_SOCKET} no existe" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} health"
}

# ── describe ───────────────────────────────────────────────────
ficha_describe() {
    echo "=== bnotify — Push MFA y Notificaciones ==="
    systemctl status "${BNOTIFY_SERVICE}" --no-pager 2>/dev/null | head -10 || true
    echo "Socket gRPC: ${BNOTIFY_SOCKET}"
}
