#!/usr/bin/env bash
# task_catalog.sh — bNexus Agent (banexus)
# BC-10 · Order 149 · SystemdService
# Centinela edge — depende de bhnexus (Requires en el unit)
# ADR-022: sin apt-get ni dependencias manuales en este script

set -euo pipefail

BANEXUS_BIN="${BANEXUS_BIN:-/usr/local/bin/banexus}"
BANEXUS_CONF_DIR="${BANEXUS_CONF_DIR:-/etc/banexus}"
BANEXUS_UNIT="${BANEXUS_UNIT:-/etc/systemd/system/banexus.service}"
SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S02-gatewayserver/banexus}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"

    mkdir -p "${BANEXUS_CONF_DIR}/dev"

    # bhnexus debe estar activo (Requires lo garantiza en runtime, pero verificamos en install)
    systemctl is-active bhnexus.service >/dev/null 2>&1 || \
        { echo "ERROR: bhnexus.service debe estar activo antes de instalar banexus" >&2; return 1; }

    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"

    # Si el binario no está instalado, intentar desde la ficha (stub o release)
    if [[ ! -x "${BANEXUS_BIN}" ]]; then
        local stub_src="${SBOS_FICHA_DIR}/bin/banexus"
        if [[ -f "${stub_src}" ]]; then
            cp "${stub_src}" "${BANEXUS_BIN}"
            chmod 755 "${BANEXUS_BIN}"
        else
            echo "ERROR: binario ${BANEXUS_BIN} no encontrado — descargar via bosctl release pull" >&2
            return 1
        fi
    fi

    # Unit systemd
    cp "${SBOS_FICHA_DIR}/resources/banexus.service" "${BANEXUS_UNIT}"
    chmod 644 "${BANEXUS_UNIT}"

    # Generar banexus.toml
    if [[ ! -f "${BANEXUS_CONF_DIR}/banexus.toml" ]]; then
        local node_id
        node_id="$(hostname)-$(cat /etc/machine-id 2>/dev/null | head -c 8 || echo "000")"
        local cert_path="${BANEXUS_CONF_DIR}/dev/client.crt"
        local key_path="${BANEXUS_CONF_DIR}/dev/client.key"

        # Generar cert de cliente si no existe (firmado por CA de bhnexus)
        if [[ ! -f "${cert_path}" ]]; then
            local bhnexus_ca="/etc/bhnexus/dev/ca.crt"
            local bhnexus_key="/etc/bhnexus/dev/ca.key"
            if [[ -f "${bhnexus_ca}" ]]; then
                openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
                    -keyout "${key_path}" -out /tmp/banexus-csr.pem \
                    -nodes -subj "/CN=${node_id}" 2>/dev/null
                openssl x509 -req -in /tmp/banexus-csr.pem \
                    -CA "${bhnexus_ca}" -CAkey "${bhnexus_key}" \
                    -CAcreateserial -out "${cert_path}" -days 3650 2>/dev/null
                rm -f /tmp/banexus-csr.pem
            else
                # Modo dev: cert autofirmado
                openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
                    -keyout "${key_path}" -out "${cert_path}" -days 3650 \
                    -nodes -subj "/CN=${node_id}" 2>/dev/null
            fi
        fi

        sed -e "s|{{NODE_ID}}|${node_id}|g" \
            -e "s|{{CLIENT_CERT}}|${cert_path}|g" \
            -e "s|{{CLIENT_KEY}}|${key_path}|g" \
            "${SBOS_FICHA_DIR}/resources/banexus.toml.tmpl" > "${BANEXUS_CONF_DIR}/banexus.toml"
        chmod 640 "${BANEXUS_CONF_DIR}/banexus.toml"
    fi

    systemctl daemon-reload
    systemctl enable banexus.service
    systemctl start banexus.service

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
    local new_bin="${SBOS_FICHA_DIR}/banexus"
    if [[ -f "${new_bin}" ]]; then
        cp "${new_bin}" "${BANEXUS_BIN}"
        chmod 755 "${BANEXUS_BIN}"
    fi
    systemctl restart banexus.service
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    mkdir -p "${BANEXUS_CONF_DIR}/dev"
    [[ -f "${BANEXUS_UNIT}" ]] || { cp "${SBOS_FICHA_DIR}/resources/banexus.service" "${BANEXUS_UNIT}"; systemctl daemon-reload; systemctl enable banexus.service; }
    systemctl restart banexus.service
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    systemctl stop banexus.service 2>/dev/null || true
    systemctl disable banexus.service 2>/dev/null || true
    rm -f "${BANEXUS_UNIT}"
    systemctl daemon-reload
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    systemctl is-active banexus.service >/dev/null 2>&1 || \
        { echo "ERROR: banexus.service no activo" >&2; return 1; }
    echo "${__SBOS__STEP_OK__} health"
}

# ── describe ───────────────────────────────────────────────────
ficha_describe() {
    echo "=== bNexus Agent ==="
    echo "Binario: ${BANEXUS_BIN}"
    echo "Config:  ${BANEXUS_CONF_DIR}/banexus.toml"
    echo "Puerto:  127.0.0.1:9446"
    systemctl status banexus.service --no-pager 2>/dev/null || true
}
