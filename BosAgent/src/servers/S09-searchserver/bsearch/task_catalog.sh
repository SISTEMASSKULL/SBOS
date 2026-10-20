#!/usr/bin/env bash
# task_catalog.sh — bsearch (Motor de Búsqueda Soberano)
# BC-12 · S09-searchserver · systemd daemon · ADR-020 · ADR-022
# R16: sin paths hardcodeados

set -euo pipefail

BSEARCH_USER="${BSEARCH_USER:-bsearch}"
BSEARCH_BIN_DST="${BSEARCH_BIN_DST:-/usr/local/bin/bsearch}"
BSEARCH_BIN_SRC="${BSEARCH_BIN_SRC:-${SBOS_FICHA_DIR}/bin/bsearch}"
BSEARCH_CONFIG_DST="${BSEARCH_CONFIG_DST:-/etc/bos/bsearch/bsearch.toml}"
BSEARCH_SOCKET="${BSEARCH_SOCKET:-/run/bos/bsearch.sock}"
BSEARCH_SERVICE="bsearch.service"
BSEARCH_SERVICE_DST="/etc/systemd/system/bsearch.service"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"

    id "${BSEARCH_USER}" &>/dev/null || \
        useradd --system --no-create-home --shell /usr/sbin/nologin \
                --gid bosagent "${BSEARCH_USER}" 2>/dev/null || true

    mkdir -p /etc/bos/bsearch /var/log/bsearch /run/bos
    chown -R "${BSEARCH_USER}:bosagent" /etc/bos/bsearch /var/log/bsearch 2>/dev/null || true
    chmod 750 /etc/bos/bsearch

    # Crear schema bsearch en SBOS_db si PG está disponible
    if kubectl exec -n sbos-data statefulset/postgresql -- \
        psql -U postgres -tc "SELECT 1" &>/dev/null 2>&1; then
        kubectl exec -n sbos-data statefulset/postgresql -- \
            psql -U postgres -c \
            "CREATE SCHEMA IF NOT EXISTS bsearch AUTHORIZATION postgres;" \
            2>/dev/null || true
    fi

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"

    if [[ -n "${BSEARCH_BIN_SRC:-}" && -f "${BSEARCH_BIN_SRC}" ]]; then
        cp "${BSEARCH_BIN_SRC}" "${BSEARCH_BIN_DST}"
        chmod 755 "${BSEARCH_BIN_DST}"
        chown "${BSEARCH_USER}:bosagent" "${BSEARCH_BIN_DST}"
    elif [[ ! -f "${BSEARCH_BIN_DST}" ]]; then
        echo "ERROR: BSEARCH_BIN_SRC no definido y ${BSEARCH_BIN_DST} no existe" >&2
        return 1
    fi

    if [[ -n "${BSEARCH_CONFIG_SRC:-}" && -f "${BSEARCH_CONFIG_SRC}" ]]; then
        cp "${BSEARCH_CONFIG_SRC}" "${BSEARCH_CONFIG_DST}"
        chmod 640 "${BSEARCH_CONFIG_DST}"
        chown "${BSEARCH_USER}:bosagent" "${BSEARCH_CONFIG_DST}"
    fi

    cat > "${BSEARCH_SERVICE_DST}" <<'UNIT'
[Unit]
Description=bsearch — Motor de Búsqueda Soberano SBOS (PostgreSQL 18+)
After=network-online.target bauth.service postgresql.service
Wants=network-online.target
Requires=bauth.service

[Service]
Type=notify
NotifyAccess=main
WatchdogSec=60
User=bsearch
Group=bosagent
ExecStart=/usr/local/bin/bsearch --config /etc/bos/bsearch/bsearch.toml
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10s
TimeoutStartSec=60
Environment=DAEMON_NAME=bsearch
Environment=DAEMON_SOCKET=/run/bos/bsearch.sock
EnvironmentFile=-/etc/bos/bsearch/bsearch.env
ExecStartPre=+/bin/mkdir -p /run/bos
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/etc/bos/bsearch /var/log/bsearch /run/bos
PrivateTmp=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
UMask=0077
StandardOutput=journal
StandardError=journal
SyslogIdentifier=bsearch

[Install]
WantedBy=multi-user.target
UNIT

    chmod 644 "${BSEARCH_SERVICE_DST}"
    systemctl daemon-reload
    systemctl enable "${BSEARCH_SERVICE}" 2>/dev/null || true

    if systemctl is-active --quiet "${BSEARCH_SERVICE}"; then
        systemctl restart "${BSEARCH_SERVICE}"
    else
        systemctl start "${BSEARCH_SERVICE}" || true
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
    systemctl restart "${BSEARCH_SERVICE}" || true
    sleep 5
    ficha_health
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    systemctl stop "${BSEARCH_SERVICE}" 2>/dev/null || true
    systemctl disable "${BSEARCH_SERVICE}" 2>/dev/null || true
    rm -f "${BSEARCH_SERVICE_DST}" "${BSEARCH_BIN_DST}"
    systemctl daemon-reload 2>/dev/null || true
    # schema bsearch en BD se preserva (datos soberanos)
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    systemctl is-active --quiet "${BSEARCH_SERVICE}" || \
        { echo "ERROR: bsearch.service no está activo" >&2; return 1; }
    [[ -S "${BSEARCH_SOCKET}" ]] || \
        { echo "ERROR: socket ${BSEARCH_SOCKET} no existe" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} health"
}

# ── describe ───────────────────────────────────────────────────
ficha_describe() {
    echo "=== bsearch — Motor de Búsqueda Soberano ==="
    systemctl status "${BSEARCH_SERVICE}" --no-pager 2>/dev/null | head -10 || true
    echo "Socket RPC: ${BSEARCH_SOCKET}"
}
