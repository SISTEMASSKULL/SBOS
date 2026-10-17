#!/usr/bin/env bash
# ============================================================================
# host-setup.sh — Configuración del host para BOS + K8s
#
# Ejecutado por el daemon bos durante auto-bootstrap cuando la delegación
# de cgroups falla o cuando se ejecuta en un contenedor sin cgroupns=host.
#
# Requisitos: Ubuntu 26.04 LTS, systemd, bash 5.x
# ============================================================================

set -euo pipefail

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [host-setup] $*" >&2; }

# ── 1. Delegación de cgroups (Delegate=yes) ───────────────────────
configure_cgroup_delegation() {
    log "Configurando delegación de cgroups para kubelet/runc..."

    # Si ya hay un drop-in, no sobrescribir
    local dropin="/etc/systemd/system/bos.service.d/delegate.conf"
    if [[ -f "$dropin" ]]; then
        log "Delegación ya configurada en $dropin"
        return 0
    fi

    mkdir -p "$(dirname "$dropin")"
    cat > "$dropin" <<'EOF'
[Service]
Delegate=yes
EOF
    log "Drop-in creado: $dropin"
    return 0
}

# ── 2. Módulos del kernel ─────────────────────────────────────────
load_kernel_modules() {
    log "Cargando módulos del kernel para K8s..."

    local modules=(br_netfilter overlay ip_tables ip6_tables nf_conntrack)
    for mod in "${modules[@]}"; do
        if ! lsmod | grep -q "^${mod}"; then
            modprobe "$mod" 2>/dev/null && log "Módulo $mod cargado" || log "Advertencia: $mod no disponible"
        fi
    done

    # Persistir
    cat > /etc/modules-load.d/sbos-k8s.conf <<'EOF'
br_netfilter
overlay
ip_tables
ip6_tables
nf_conntrack
EOF
    log "Módulos configurados para arranque automático"
}

# ── 3. Parámetros sysctl para K8s ────────────────────────────────
configure_sysctl() {
    log "Aplicando parámetros sysctl para K8s..."

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
    log "Parámetros sysctl aplicados"
}

# ── 4. Swap deshabilitado ─────────────────────────────────────────
disable_swap() {
    log "Deshabilitando swap (requerido por K8s)..."
    swapoff -a 2>/dev/null || true
    sed -i '/\bswap\b/d' /etc/fstab 2>/dev/null || true
    log "Swap deshabilitado"
}

# ── 5. Estructura /data/ ──────────────────────────────────────────
create_data_directories() {
    log "Creando estructura /data/ para PersistentVolumes..."

    declare -A dir_owners=(
        ["/data"]="root:root:0755"
        ["/data/postgres"]="999:999:0700"
        ["/data/redis"]="999:999:0700"
        ["/data/vault"]="100:100:0700"
        ["/data/keycloak"]="root:root:0755"
        ["/data/minio"]="root:root:0755"
        ["/data/prometheus"]="65534:65534:0755"
        ["/data/grafana"]="472:472:0755"
        ["/data/bkernel"]="root:root:0755"
        ["/data/biedata"]="root:root:0755"
        ["/data/bsearch"]="root:root:0755"
        ["/data/bauth"]="root:root:0755"
        ["/data/notifier"]="root:root:0755"
    )

    for dir in "${!dir_owners[@]}"; do
        IFS=':' read -r user group mode <<< "${dir_owners[$dir]}"
        mkdir -p "$dir"
        chmod "$mode" "$dir"
        chown "${user}:${group}" "$dir" 2>/dev/null || true
    done

    log "/data/ configurado con $(ls /data/ | wc -l) subdirectorios"
}

# ── 6. containerd ────────────────────────────────────────────────
configure_containerd() {
    if ! command -v containerd > /dev/null 2>&1; then
        log "containerd no instalado — omitiendo configuración"
        return 0
    fi

    log "Configurando containerd (SystemdCgroup=true)..."
    mkdir -p /etc/containerd

    if [[ ! -f /etc/containerd/config.toml ]]; then
        containerd config default > /etc/containerd/config.toml 2>/dev/null || true
    fi

    if [[ -f /etc/containerd/config.toml ]]; then
        sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml || true
        log "SystemdCgroup=true configurado"
    fi

    systemctl enable containerd 2>/dev/null || true
    systemctl restart containerd 2>/dev/null || true
    log "containerd reiniciado"
}

# ── Main ──────────────────────────────────────────────────────────
main() {
    log "=== host-setup.sh iniciando ==="

    configure_cgroup_delegation
    load_kernel_modules
    configure_sysctl
    disable_swap
    create_data_directories
    configure_containerd

    log "=== host-setup.sh completado ==="
    return 0
}

main "$@"
