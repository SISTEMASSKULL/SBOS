#!/usr/bin/env bash
# install.sh — SBOS Bootstrap Installer
# Se ejecuta DENTRO del entorno (host bare-metal o contenedor podman).
# NO crea el contenedor — el operador ya debe haber creado el entorno.
# NO ejecuta las fichas — el BOS se encarga de todo autónomamente.
#
# El paquete de instalación se entrega como:
#   install.sh + sbos-bootstrap.zip
#
# Uso:
#   bash install.sh                          # zip en mismo directorio
#   bash install.sh --zip ./sbos-v1.0.zip    # zip en ruta específica

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_section() { echo -e "\n${GREEN}=== $1 ===${NC}"; }
log_ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_fail()    { echo -e "${RED}[FAIL]${NC} $1"; }

# ── Detección de entorno ─────────────────────────────────────────

detect_environment() {
    if [[ -f /run/.containerenv ]] || [[ -f /.containerenv ]]; then
        echo "container"; return 0
    fi
    if command -v systemd-detect-virt &>/dev/null; then
        local vt=$(systemd-detect-virt --container 2>/dev/null || echo "none")
        if [[ -n "$vt" && "$vt" != "none" ]]; then echo "container"; return 0; fi
    fi
    if grep -qE '/(docker|libpod|kubepods)/' /proc/self/cgroup 2>/dev/null; then
        echo "container"; return 0
    fi
    echo "baremetal"
}

# ── Dependencias ──────────────────────────────────────────────────

ensure_deps() {
    log_section "Verificando dependencias"

    # Necesitamos python3 o unzip para extraer el zip.
    if command -v python3 &>/dev/null; then
        log_ok "python3 disponible"
        return 0
    fi
    if command -v unzip &>/dev/null; then
        log_ok "unzip disponible"
        return 0
    fi

    log_warn "Ni python3 ni unzip encontrados — intentando instalar..."
    if command -v apt-get &>/dev/null; then
        apt-get update -qq && apt-get install -y -qq unzip 2>/dev/null && log_ok "unzip instalado via apt" && return 0
    fi
    if command -v dnf &>/dev/null; then
        dnf install -y unzip 2>/dev/null && log_ok "unzip instalado via dnf" && return 0
    fi
    if command -v yum &>/dev/null; then
        yum install -y unzip 2>/dev/null && log_ok "unzip instalado via yum" && return 0
    fi

    log_fail "No se pudo instalar python3 ni unzip. Instala uno manualmente."
    exit 1
}

# ── Extracción del paquete ───────────────────────────────────────

extract_package() {
    local zip_path="$1"
    log_section "Extrayendo paquete: $zip_path"

    if [[ ! -f "$zip_path" ]]; then
        log_fail "No se encontró el paquete: $zip_path"
        exit 1
    fi

    # BOS auto-bootstrap espera archivos en /tmp/ y los mueve a paths canónicos.
    # Extraemos todo a /tmp/ directamente.
    if command -v python3 &>/dev/null; then
        python3 -c "
import zipfile
with zipfile.ZipFile('$zip_path', 'r') as z:
    z.extractall('/tmp')
print('OK')
"
    elif command -v unzip &>/dev/null; then
        unzip -o "$zip_path" -d /tmp/ 2>&1
    else
        log_fail "Ni python3 ni unzip disponibles"
        exit 1
    fi

    log_ok "Paquete extraído a /tmp/"
    log_ok "  servers/  → /tmp/servers/"
    log_ok "  core/     → /tmp/"
    log_ok "  configs   → /tmp/"
}

# ── Cgroup delegation (P30 + P31) ─────────────────────────────────

setup_cgroups() {
    local env_type="$1"
    log_section "Configurando cgroup v2 delegation (P30+P31)"

    echo "Entorno: $env_type"
    echo "Root cgroup.controllers: $(cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null || echo 'no cgroup2')"
    echo "Root subtree_control BEFORE: $(cat /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || echo 'no cgroup2')"

    for ctrl in $(cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null); do
        echo "+$ctrl" > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || true
    done
    echo "Root subtree_control AFTER: $(cat /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null)"

    local probe_dir="/sys/fs/cgroup/.bos-probe-$$"
    mkdir -p "$probe_dir" 2>/dev/null || true
    local inherited=$(cat "$probe_dir/cgroup.controllers" 2>/dev/null || echo "")
    rmdir "$probe_dir" 2>/dev/null || true

    if [[ -z "$inherited" ]]; then
        log_fail "FATAL: cgroup controllers no heredan a cgroups hijos"
        if [[ "$env_type" == "container" ]]; then
            log_fail "Recrea el contenedor con --cgroupns=private"
        fi
        exit 1
    fi
    log_ok "CGROUP DELEGATION OK — heredados: $inherited"
}

# ── Entrypoint ────────────────────────────────────────────────────

main() {
    local zip_path=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --zip) zip_path="$2"; shift 2 ;;
            --help|-h)
                echo "Uso: bash install.sh [--zip <ruta>]"
                echo "Sin --zip, busca sbos-bootstrap.zip en el directorio actual."
                exit 0 ;;
            *) log_fail "Opción desconocida: $1"; exit 1 ;;
        esac
    done

    echo "=== SBOS Bootstrap Installer ==="
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Hostname: $(hostname)"

    if [[ $EUID -ne 0 ]]; then
        log_fail "Debe ejecutarse como root"
        exit 1
    fi

    local env_type=$(detect_environment)
    log_ok "Entorno detectado: $env_type"

    # 0. Verificar e instalar dependencias
    ensure_deps

    # 1. Extraer paquete a /tmp/
    if [[ -n "$zip_path" ]]; then
        extract_package "$zip_path"
    elif [[ -f "./sbos-bootstrap.zip" ]]; then
        extract_package "./sbos-bootstrap.zip"
    else
        log_fail "No se encontró sbos-bootstrap.zip. Usa --zip <ruta>"
        exit 1
    fi

    # 2. Configurar root password desde el .env antes de ceder control a BOS.
    #    BOS también lo hará en su autoBootstrap, pero instalar.sh lo garantiza
    #    desde el inicio de la instalación (el entorno debe tener root operativo).
    if [[ -f /tmp/bos-bootstrap.env ]]; then
        set -a; source /tmp/bos-bootstrap.env; set +a
        if [[ -n "${BOS_ROOT_PASSWORD:-}" ]]; then
            echo "root:${BOS_ROOT_PASSWORD}" | chpasswd 2>/dev/null && \
                log_ok "Contraseña root configurada desde bos-bootstrap.env" || \
                log_warn "No se pudo configurar contraseña root (chpasswd no disponible)"
        fi
    fi

    # 3. Configurar cgroups ANTES de que BOS arranque containerd
    setup_cgroups "$env_type"

    # 4. Ejecutar BOS — él hace todo: auto-bootstrap, copiar a canonical paths,
    #    iniciar containerd, instalar fichas en orden topológico.
    log_section "Ejecutando BOS daemon"
    log_ok "BOS iniciando — auto-bootstrap + instalación de fichas bootstrap"

    if [[ -f /tmp/bos ]]; then
        chmod +x /tmp/bos
        # BOS en foreground — auto-bootstrap copia todo a paths canónicos,
        # inicia containerd, despliega fichas bootstrap.
        exec /tmp/bos --config /tmp/bos.toml
    elif [[ -f /opt/bos/bin/bos ]]; then
        exec /opt/bos/bin/bos --config /etc/bos/bos.toml
    else
        log_fail "No se encontró el binario BOS en /tmp/bos ni /opt/bos/bin/bos"
        log_fail "Asegúrate de que sbos-bootstrap.zip incluya el binario 'bos'"
        exit 1
    fi
}

main "$@"
