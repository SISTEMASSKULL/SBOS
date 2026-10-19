#!/usr/bin/env bash
# task_catalog.sh — bNexus Host (bhnexus)
# BC-10 · Order 148 · SystemdService
# Proxy de hardware universal — escucha TLS mutual en :9444
# ADR-022: depende de bauth (debe estar activo antes de iniciar)

set -euo pipefail

BHNEXUS_BIN="${BHNEXUS_BIN:-/usr/local/bin/bhnexus}"
BHNEXUS_CONF_DIR="${BHNEXUS_CONF_DIR:-/etc/bhnexus}"
BHNEXUS_UNIT="${BHNEXUS_UNIT:-/etc/systemd/system/bhnexus.service}"
BHNEXUS_SOCK="${BHNEXUS_SOCK:-/run/bos/bhnexus.sock}"
SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S02-gatewayserver/bhnexus}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"

    # Directorio de configuración
    mkdir -p "${BHNEXUS_CONF_DIR}/dev"

    # Verificar que bauth esté activo (dependencia obligatoria)
    if ! systemctl is-active bauth.service >/dev/null 2>&1; then
        echo "ERROR: bauth.service debe estar activo antes de instalar bhnexus" >&2
        return 1
    fi

    # Verificar que /run/bos/ exista (creado por bos.service)
    mkdir -p /run/bos
    chmod 0755 /run/bos

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"

    [[ -x "${BHNEXUS_BIN}" ]] || \
        { echo "ERROR: binario ${BHNEXUS_BIN} no encontrado — descargar via bosctl release pull" >&2; return 1; }

    # Instalar unit
    cp "${SBOS_FICHA_DIR}/resources/bhnexus.service" "${BHNEXUS_UNIT}"
    chmod 644 "${BHNEXUS_UNIT}"

    # Generar bhnexus.toml (TLS prod — genera CA si no existe)
    if [[ ! -f "${BHNEXUS_CONF_DIR}/bhnexus.toml" ]]; then
        local ca_cert="${BHNEXUS_CONF_DIR}/dev/ca.crt"
        local ca_key="${BHNEXUS_CONF_DIR}/dev/ca.key"
        if [[ ! -f "${ca_cert}" ]]; then
            openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
                -keyout "${ca_key}" -out "${ca_cert}" -days 3650 \
                -nodes -subj "/CN=sbos-bhnexus-ca" 2>/dev/null
        fi
        sed -e "s|{{CA_CERT}}|${ca_cert}|g" \
            -e "s|{{CA_KEY}}|${ca_key}|g" \
            "${SBOS_FICHA_DIR}/resources/bhnexus.toml.tmpl" > "${BHNEXUS_CONF_DIR}/bhnexus.toml"
        chmod 640 "${BHNEXUS_CONF_DIR}/bhnexus.toml"
    fi

    systemctl daemon-reload
    systemctl enable bhnexus.service
    systemctl start bhnexus.service

    # Esperar socket (20s)
    local waited=0
    while [[ ! -S "${BHNEXUS_SOCK}" ]] && [[ $waited -lt 20 ]]; do
        sleep 1; waited=$((waited + 1))
    done
    [[ -S "${BHNEXUS_SOCK}" ]] || \
        { echo "ERROR: ${BHNEXUS_SOCK} no apareció en 20s" >&2; journalctl -u bhnexus.service -n 20 >&2; return 1; }

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
    local new_bin="${SBOS_FICHA_DIR}/bhnexus"
    if [[ -f "${new_bin}" ]]; then
        cp "${new_bin}" "${BHNEXUS_BIN}"
        chmod 755 "${BHNEXUS_BIN}"
    fi
    systemctl restart bhnexus.service
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    mkdir -p "${BHNEXUS_CONF_DIR}" /run/bos
    [[ -f "${BHNEXUS_UNIT}" ]] || { cp "${SBOS_FICHA_DIR}/resources/bhnexus.service" "${BHNEXUS_UNIT}"; systemctl daemon-reload; systemctl enable bhnexus.service; }
    systemctl restart bhnexus.service
    local waited=0
    while [[ ! -S "${BHNEXUS_SOCK}" ]] && [[ $waited -lt 20 ]]; do sleep 1; waited=$((waited+1)); done
    [[ -S "${BHNEXUS_SOCK}" ]] || { echo "ERROR: repair falló" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    systemctl stop bhnexus.service 2>/dev/null || true
    systemctl disable bhnexus.service 2>/dev/null || true
    rm -f "${BHNEXUS_UNIT}"
    systemctl daemon-reload
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    systemctl is-active bhnexus.service >/dev/null 2>&1 || \
        { echo "ERROR: bhnexus.service no activo" >&2; return 1; }
    test -S "${BHNEXUS_SOCK}" || \
        { echo "ERROR: ${BHNEXUS_SOCK} no existe" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} health"
}

# ── describe ───────────────────────────────────────────────────
ficha_describe() {
    echo "=== bNexus Host ==="
    echo "Binario: ${BHNEXUS_BIN}"
    echo "Socket:  ${BHNEXUS_SOCK}"
    echo "Puerto:  9444 (TLS mutual)"
    systemctl status bhnexus.service --no-pager 2>/dev/null || true
}
