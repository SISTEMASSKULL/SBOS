#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — sbos-fichas-migrator
# Reorganiza fichas en /opt/bos/servers/ hacia sus servidores lógicos
# correctos. Elimina duplicados legacy en la raíz. Idempotente.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-fichas-migrator.log}"
SERVERS_DIR="${SBOS_SERVERS_DIR:-/opt/bos/servers}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-fichas-migrator] $*" | tee -a "$FICHA_LOG"; }

# Mapa: ficha_en_raiz|servidor_incorrecto → servidor_destino
# Formato: "ORIGEN|FICHA|DESTINO"
MIGRACIONES=(
    # Fichas en raíz con duplicado correcto → eliminar raíz
    "raiz|alertmanager|S12"
    "raiz|alloy|S12"
    "raiz|bareos|S14"
    "raiz|embedding-worker|S15"
    "raiz|fedora-kde|S13"
    "raiz|flowise|S15"
    "raiz|gitlab|S14"
    "raiz|grafana|S12"
    "raiz|guacamole|S13"
    "raiz|langfuse|S15"
    "raiz|loki|S12"
    "raiz|nextcloud|S13"
    "raiz|oauth2-proxy-desktop|S13"
    "raiz|ollama|S15"
    "raiz|onlyoffice|S13"
    "raiz|open-webui|S15"
    "raiz|postgresql-extensions|S12"
    "raiz|prometheus|S12"
    "raiz|qdrant|S15"
    "raiz|sbos-vdi-config|S13"
    "raiz|tempo|S12"
    "raiz|velero|S14"
    "raiz|zabbix|S12"
    # Fichas en servidor incorrecto → servidor correcto
    # S-HOST es el nombre real de S00 en esta VPS
    "S03|kyverno|S-HOST"
    "S03|linkerd|S-HOST"
    "S04|gnu-health|S06"
    "S04|orangehrm|S06"
)

ficha_pre_install() {
    echo "${__STEP_START__} verificar_servers_dir"
    [[ -d "$SERVERS_DIR" ]] || { echo "${__STEP_FAIL__} verificar_servers_dir: $SERVERS_DIR no existe"; return 1; }
    echo "${__STEP_OK__} verificar_servers_dir"
    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    echo "${__STEP_START__} reorganizar_fichas"
    local moved=0 skipped=0

    for entrada in "${MIGRACIONES[@]}"; do
        IFS='|' read -r origen ficha destino <<< "$entrada"

        if [[ "$origen" == "raiz" ]]; then
            local src_path="${SERVERS_DIR}/${ficha}"
        else
            local src_path="${SERVERS_DIR}/${origen}/${ficha}"
        fi
        local dst_path="${SERVERS_DIR}/${destino}/${ficha}"

        [[ -d "$src_path" ]] || continue

        if [[ -d "$dst_path" ]]; then
            _log "SKIP ${origen}/${ficha} — ya existe en ${destino} (eliminando duplicado)"
            rm -rf "$src_path"
            skipped=$((skipped + 1))
        else
            mkdir -p "${SERVERS_DIR}/${destino}"
            mv "$src_path" "$dst_path"
            _log "MOVIDO ${src_path} → ${dst_path}"
            moved=$((moved + 1))
        fi
    done

    _log "Reorganización completada: ${moved} movidas, ${skipped} duplicados eliminados"
    echo "${__STEP_OK__} reorganizar_fichas"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_reorganizacion"
    local pendientes=0

    for entrada in "${MIGRACIONES[@]}"; do
        IFS='|' read -r origen ficha destino <<< "$entrada"

        if [[ "$origen" == "raiz" ]]; then
            local src_path="${SERVERS_DIR}/${ficha}"
        else
            local src_path="${SERVERS_DIR}/${origen}/${ficha}"
        fi

        if [[ -d "$src_path" ]]; then
            _log "PENDIENTE: $src_path todavía fuera de lugar"
            pendientes=$((pendientes + 1))
        fi
    done

    if (( pendientes > 0 )); then
        echo "${__STEP_FAIL__} verificar_reorganizacion: ${pendientes} fichas fuera de lugar"
        return 1
    fi
    echo "${__STEP_OK__} verificar_reorganizacion: estructura correcta"
    return 0
}

ficha_health() {
    ficha_verify &>/dev/null && echo "HEALTHY" && return 0
    echo "DEGRADED"
    return 1
}

ficha_repair() {
    ficha_install
}

ficha_test() {
    ficha_verify
}

ficha_post_install() {
    return 0
}

ficha_remove() {
    _log "sbos-fichas-migrator no tiene estado propio — noop"
    return 0
}
