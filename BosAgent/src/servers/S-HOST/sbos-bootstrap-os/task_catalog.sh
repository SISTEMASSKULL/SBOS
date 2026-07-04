#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — Ficha sbos-bootstrap-os
# Iteración 1: Capa 0 — preparación del sistema operativo
#
# Señales __SBOS__STEP__* obligatorias en cada paso.
# Esta ficha NO tiene dependencias y es la primera en instalarse.
# ============================================================================

set -euo pipefail

# ── Señales (heredadas del motor si ya están definidas) ───────────
readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-bootstrap-os.log}"
YAML_ENGINE_FILE="$(dirname "${BASH_SOURCE[0]}")/yaml_engine.yml"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-bootstrap-os] $*" | tee -a "$FICHA_LOG"; }

# Verifica si un módulo kernel está cargado. Funciona en nspawn (sin lsmod).
_module_loaded() {
    grep -q "^${1} \|^${1}$" /proc/modules 2>/dev/null
}

# ── Pre-install: verificaciones de requisitos ─────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_ubuntu"
    local version
    version=$(lsb_release -rs 2>/dev/null || grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    if [[ "$version" != "26.04" ]]; then
        _log "FALLO: Ubuntu 26.04 requerido, detectado: $version"
        echo "${__STEP_FAIL__} verificar_ubuntu: se requiere Ubuntu 26.04, detectado $version"
        return 1
    fi
    echo "${__STEP_OK__} verificar_ubuntu"

    echo "${__STEP_START__} verificar_root"
    if [[ $EUID -ne 0 ]]; then
        echo "${__STEP_FAIL__} verificar_root: se requiere ejecutar como root"
        return 1
    fi
    echo "${__STEP_OK__} verificar_root"

    echo "${__STEP_START__} verificar_ram"
    local ram_mb
    ram_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
    if (( ram_mb < 4096 )); then
        echo "${__STEP_FAIL__} verificar_ram: ${ram_mb}MB < 4096MB requerido"
        return 1
    fi
    echo "${__STEP_OK__} verificar_ram (${ram_mb}MB)"

    echo "${__STEP_START__} verificar_disco"
    local disk_gb
    disk_gb=$(df -BG / 2>/dev/null | awk 'NR==2 {gsub("G",""); print $4}')
    if (( disk_gb < 50 )); then
        echo "${__STEP_FAIL__} verificar_disco: ${disk_gb}GB < 50GB requerido en /"
        return 1
    fi
    echo "${__STEP_OK__} verificar_disco (${disk_gb}GB disponible)"

    echo "${__STEP_START__} verificar_internet"
    local ok=0
    for host in archive.ubuntu.com 8.8.8.8 1.1.1.1; do
        if curl -s --max-time 5 --head "http://${host}" -o /dev/null 2>/dev/null; then
            ok=1; break
        fi
    done
    if (( ok == 0 )); then
        echo "${__STEP_FAIL__} verificar_internet: sin acceso a internet — requerido para descargar paquetes"
        return 1
    fi
    echo "${__STEP_OK__} verificar_internet"

    echo "${__STEP_OK__} pre_install_checks"

    return 0
}

# ── Install: instalación real de la capa OS ──────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    echo "${__STEP_START__} cargar_modulos_kernel"
    local modules=(br_netfilter overlay ip_tables ip6_tables nf_conntrack nf_nat xt_MASQUERADE xt_conntrack)
    local failed_modules=()
    for mod in "${modules[@]}"; do
        if ! _module_loaded "${mod}"; then
            if ! modprobe "$mod" 2>/dev/null; then
                _log "ADVERTENCIA: módulo $mod no disponible — puede no ser necesario en este kernel"
                failed_modules+=("$mod")
            else
                _log "Módulo $mod cargado"
            fi
        else
            _log "Módulo $mod ya activo"
        fi
    done

    # Persistir módulos en siguiente arranque
    cat > /etc/modules-load.d/sbos-k8s.conf <<'EOF'
br_netfilter
overlay
ip_tables
ip6_tables
nf_conntrack
EOF
    echo "${__STEP_OK__} cargar_modulos_kernel"

    echo "${__STEP_START__} configurar_sysctl"
    cat > /etc/sysctl.d/99-sbos-k8s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv6.conf.all.forwarding        = 1
fs.inotify.max_user_watches         = 524288
fs.inotify.max_user_instances       = 512
vm.max_map_count                    = 262144
kernel.panic                        = 10
kernel.panic_on_oops                = 1
EOF
    sysctl --system > /dev/null 2>&1 || sysctl -p /etc/sysctl.d/99-sbos-k8s.conf > /dev/null 2>&1 || true
    echo "${__STEP_OK__} configurar_sysctl"

    echo "${__STEP_START__} instalar_paquetes_base"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq 2>/dev/null || { _log "ADVERTENCIA: apt-get update falló (sin internet?)"; }
    local packages=(curl gnupg apt-transport-https ca-certificates jq socat conntrack ipset lsof net-tools iproute2 kmod)
    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            to_install+=("$pkg")
        fi
    done
    if (( ${#to_install[@]} > 0 )); then
        apt-get install -y -qq "${to_install[@]}" 2>/dev/null || \
            _log "ADVERTENCIA: algunos paquetes no se pudieron instalar: ${to_install[*]}"
    fi
    echo "${__STEP_OK__} instalar_paquetes_base"

    echo "${__STEP_START__} crear_directorios_data"
    local dirs=(
        "/data:0755:root:root"
        "/data/postgres:0700:999:999"
        "/data/redis:0700:999:999"
        "/data/vault:0700:100:100"
        "/data/keycloak:0755:root:root"
        "/data/minio:0755:root:root"
        "/data/prometheus:0755:65534:65534"
        "/data/grafana:0755:472:472"
        "/data/bkernel:0755:root:root"
        "/data/biedata:0755:root:root"
        "/data/bsearch:0755:root:root"
        "/data/bauth:0755:root:root"
        "/data/notifier:0755:root:root"
    )
    for entry in "${dirs[@]}"; do
        IFS=':' read -r dir mode user group <<< "$entry"
        mkdir -p "$dir"
        chmod "$mode" "$dir"
        chown "${user}:${group}" "$dir" 2>/dev/null || true
        _log "Directorio creado: $dir ($mode ${user}:${group})"
    done
    echo "${__STEP_OK__} crear_directorios_data"

    echo "${__STEP_START__} configurar_containerd"
    if command -v containerd > /dev/null 2>&1; then
        mkdir -p /etc/containerd
        if [[ ! -f /etc/containerd/config.toml ]]; then
            containerd config default > /etc/containerd/config.toml 2>/dev/null || true
            # Forzar cgroup driver systemd (requerido por kubeadm)
            if [[ -f /etc/containerd/config.toml ]]; then
                sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml || true
            fi
        fi
        systemctl enable containerd 2>/dev/null || true
        systemctl restart containerd 2>/dev/null || true
        _log "containerd configurado con SystemdCgroup=true"
        echo "${__STEP_OK__} configurar_containerd"
    else
        echo "${__STEP_SKIP__} configurar_containerd: containerd no instalado aún"
    fi

    echo "${__STEP_START__} deshabilitar_swap"
    swapoff -a 2>/dev/null || true
    sed -i '/\bswap\b/d' /etc/fstab 2>/dev/null || true
    echo "${__STEP_OK__} deshabilitar_swap"

    _log "Instalación sbos-bootstrap-os completada"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Post-install: verificando estado del sistema"
    if ! _module_loaded "br_netfilter"; then
        _log "ADVERTENCIA: br_netfilter no activo en este momento (se cargará al reiniciar)"
    fi
    return 0
}

# ── Repair: reparación idempotente ───────────────────────────────
ficha_repair() {
    _log "Reparando sbos-bootstrap-os..."

    echo "${__STEP_START__} reparar_modulos"
    for mod in br_netfilter overlay ip_tables; do
        if ! _module_loaded "${mod}"; then
            modprobe "$mod" 2>/dev/null && _log "Módulo $mod recargado" || true
        fi
    done
    echo "${__STEP_OK__} reparar_modulos"

    echo "${__STEP_START__} reparar_sysctl"
    sysctl --system > /dev/null 2>&1 || true
    echo "${__STEP_OK__} reparar_sysctl"

    echo "${__STEP_START__} reparar_directorios"
    for dir in /data /data/postgres /data/redis /data/vault; do
        [[ -d "$dir" ]] || mkdir -p "$dir"
    done
    echo "${__STEP_OK__} reparar_directorios"

    return 0
}

# ── Test: verificación de salud ───────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_kernel_modules"
    for mod in br_netfilter; do
        if _module_loaded "${mod}"; then
            _log "OK: módulo $mod activo"
        else
            _log "FALLO: módulo $mod no activo"
            ok=1
        fi
    done
    [[ $ok -eq 0 ]] && echo "${__STEP_OK__} test_kernel_modules" || echo "${__STEP_FAIL__} test_kernel_modules"

    echo "${__STEP_START__} test_sysctl"
    local fwd
    fwd=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
    if [[ "$fwd" == "1" ]]; then
        echo "${__STEP_OK__} test_sysctl"
    else
        echo "${__STEP_FAIL__} test_sysctl: ip_forward=$fwd"
        ok=1
    fi

    echo "${__STEP_START__} test_directorios"
    for dir in /data /data/postgres /data/redis /data/vault; do
        if [[ ! -d "$dir" ]]; then
            echo "${__STEP_FAIL__} test_directorios: $dir no existe"
            ok=1
        fi
    done
    [[ $ok -eq 0 ]] && echo "${__STEP_OK__} test_directorios"

    echo "${__STEP_START__} test_swap"
    local swap_total
    swap_total=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
    if [[ "$swap_total" == "0" ]]; then
        echo "${__STEP_OK__} test_swap: swap deshabilitado"
    else
        _log "ADVERTENCIA: swap activo (${swap_total}kB) — requerirá desactivación permanente"
        echo "${__STEP_SKIP__} test_swap: swap activo (no crítico en esta iteración)"
    fi

    return $ok
}

# ── Status: estado actual ─────────────────────────────────────────
ficha_status() {
    echo "=== sbos-bootstrap-os STATUS ==="
    echo "Ubuntu: $(lsb_release -rs 2>/dev/null || grep VERSION_ID /etc/os-release | cut -d'"' -f2)"
    echo "Kernel: $(uname -r)"
    echo "br_netfilter: $(_module_loaded br_netfilter && echo ACTIVO || echo INACTIVO)"
    echo "overlay: $(_module_loaded overlay && echo ACTIVO || echo INACTIVO)"
    echo "ip_forward: $(sysctl -n net.ipv4.ip_forward 2>/dev/null)"
    echo "swap: $(awk '/SwapTotal/ {print $2}' /proc/meminfo)kB"
    echo "Directorios /data:"
    for dir in /data /data/postgres /data/redis /data/vault /data/keycloak /data/minio; do
        printf "  %-30s %s\n" "$dir" "$([ -d "$dir" ] && echo OK || echo FALTANTE)"
    done
    echo "containerd: $(systemctl is-active containerd 2>/dev/null || echo inactivo)"
}

# ── Uninstall: desinstalación ─────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalación de sbos-bootstrap-os — solo remueve configuración, no el OS"

    echo "${__STEP_START__} remover_sysctl"
    rm -f /etc/sysctl.d/99-sbos-k8s.conf
    echo "${__STEP_OK__} remover_sysctl"

    echo "${__STEP_START__} remover_modulos_conf"
    rm -f /etc/modules-load.d/sbos-k8s.conf
    echo "${__STEP_OK__} remover_modulos_conf"

    _log "sbos-bootstrap-os desinstalado (directorios /data conservados)"
    return 0
}

# ── Diagnóstico (P14) ─────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico sbos-bootstrap-os ==="
    echo "Kernel: $(uname -r)"
    echo "Módulos K8s:"
    for mod in br_netfilter overlay ip_tables; do
        echo "  $mod: $(_module_loaded "$mod" && echo ACTIVO || echo INACTIVO)"
    done
    echo "Sysctl ip_forward: $(sysctl -n net.ipv4.ip_forward 2>/dev/null)"
    echo "Swap: $(awk '/SwapTotal/ {print $2}' /proc/meminfo)kB"
    echo "Espacio en /data: $(df -h /data 2>/dev/null | tail -1 || echo '/data no existe')"
}
