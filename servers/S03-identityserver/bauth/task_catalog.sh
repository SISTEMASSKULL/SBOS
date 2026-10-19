#!/usr/bin/env bash
# task_catalog.sh — bAuth Identity Control Plane
# BC-09 · Order 148 · SystemdService
# Daemon soberano — se instala en el HOST, no en K8s.
# ADR-022: dependencias del SO via manifest.yml, nunca en este script.

set -euo pipefail

BAUTH_BIN="${BAUTH_BIN:-/usr/local/bin/bauth}"
BAUTH_DIR="${BAUTH_DIR:-/opt/bauth}"
BAUTH_SOCK_DIR="${BAUTH_SOCK_DIR:-/tmp/bauth}"
BAUTH_UNIT="${BAUTH_UNIT:-/etc/systemd/system/bauth.service}"
BAUTH_TOML="${BAUTH_TOML:-/etc/bos/bauth.toml}"
SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S03-identityserver/bauth}"
BAUTH_USER="${BAUTH_USER:-bauth}"
BAUTH_GROUP="${BAUTH_GROUP:-bosagent}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"

    # Crear usuario bauth si no existe
    if ! id "${BAUTH_USER}" &>/dev/null; then
        useradd --system --no-create-home --shell /usr/sbin/nologin \
            --gid "${BAUTH_GROUP}" "${BAUTH_USER}"
    fi

    # Directorios
    mkdir -p "${BAUTH_DIR}"
    mkdir -p "${BAUTH_SOCK_DIR}"
    chown "${BAUTH_USER}:${BAUTH_GROUP}" "${BAUTH_DIR}" "${BAUTH_SOCK_DIR}"
    chmod 0750 "${BAUTH_DIR}"
    chmod 0770 "${BAUTH_SOCK_DIR}"

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"

    # Verificar que el binario existe (debe venir del Release Plane)
    if [[ ! -x "${BAUTH_BIN}" ]]; then
        echo "ERROR: binario ${BAUTH_BIN} no encontrado — debe descargarse via bosctl release pull" >&2
        return 1
    fi

    # Instalar unit de systemd
    cp "${SBOS_FICHA_DIR}/resources/bauth.service" "${BAUTH_UNIT}"
    chmod 644 "${BAUTH_UNIT}"

    # Generar bauth.toml desde template
    # BAUTH_PG_DSN debe ser inyectada por BOS desde integrations.database.dsn_env del manifest
    local pg_dsn="${BAUTH_PG_DSN:?BAUTH_PG_DSN no definida — BOS debe inyectarla antes de ejecutar install}"
    local socket_path="${BAUTH_SOCK_DIR}/bauth.sock"
    sed -e "s|{{PG_DSN}}|${pg_dsn}|g" \
        -e "s|{{SOCKET_PATH}}|${socket_path}|g" \
        "${SBOS_FICHA_DIR}/resources/bauth.toml.tmpl" > "${BAUTH_TOML}"
    chmod 640 "${BAUTH_TOML}"
    chown root:"${BAUTH_GROUP}" "${BAUTH_TOML}"

    # Detener instancia previa si existe (evita EADDRINUSE en socket)
    systemctl stop bauth.service 2>/dev/null || true
    rm -f "${BAUTH_SOCK_DIR}/bauth.sock"

    # Habilitar y arrancar
    systemctl daemon-reload
    systemctl enable bauth.service
    systemctl start bauth.service

    # Esperar a que el socket aparezca (hasta 60s)
    local waited=0
    while [[ ! -S "${BAUTH_SOCK_DIR}/bauth.sock" ]] && [[ $waited -lt 60 ]]; do
        sleep 1
        waited=$((waited + 1))
    done
    if [[ ! -S "${BAUTH_SOCK_DIR}/bauth.sock" ]]; then
        echo "ERROR: bauth.sock no apareció en 60s" >&2
        journalctl -u bauth.service --no-pager -n 20 >&2
        return 1
    fi

    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    # Verificar respuesta del daemon via socket
    ficha_health
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    # P15: no destructivo — solo reiniciar si el binario cambió
    local new_bin="${SBOS_FICHA_DIR}/bauth"
    if [[ -f "${new_bin}" ]]; then
        cp "${new_bin}" "${BAUTH_BIN}"
        chmod 755 "${BAUTH_BIN}"
    fi
    systemctl restart bauth.service
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"

    # Recrear directorios/permisos si faltan
    mkdir -p "${BAUTH_SOCK_DIR}"
    chown "${BAUTH_USER}:${BAUTH_GROUP}" "${BAUTH_SOCK_DIR}"
    chmod 0770 "${BAUTH_SOCK_DIR}"

    # Reinstalar unit si falta
    if [[ ! -f "${BAUTH_UNIT}" ]]; then
        cp "${SBOS_FICHA_DIR}/resources/bauth.service" "${BAUTH_UNIT}"
        systemctl daemon-reload
        systemctl enable bauth.service
    fi

    systemctl restart bauth.service

    local waited=0
    while [[ ! -S "${BAUTH_SOCK_DIR}/bauth.sock" ]] && [[ $waited -lt 30 ]]; do
        sleep 1; waited=$((waited + 1))
    done
    [[ -S "${BAUTH_SOCK_DIR}/bauth.sock" ]] || { echo "ERROR: repair falló — socket no apareció" >&2; return 1; }

    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    systemctl stop bauth.service 2>/dev/null || true
    systemctl disable bauth.service 2>/dev/null || true
    rm -f "${BAUTH_UNIT}"
    systemctl daemon-reload
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    # Verificar: servicio activo + socket existe
    systemctl is-active bauth.service >/dev/null 2>&1 || \
        { echo "ERROR: bauth.service no está activo" >&2; return 1; }
    test -S "${BAUTH_SOCK_DIR}/bauth.sock" || \
        { echo "ERROR: ${BAUTH_SOCK_DIR}/bauth.sock no existe" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} health"
}

# ── describe ───────────────────────────────────────────────────
ficha_describe() {
    echo "=== bAuth Identity Control Plane ==="
    echo "Binario:  ${BAUTH_BIN}"
    echo "Socket:   ${BAUTH_SOCK_DIR}/bauth.sock"
    echo "Config:   ${BAUTH_TOML}"
    systemctl status bauth.service --no-pager 2>/dev/null || true
}
