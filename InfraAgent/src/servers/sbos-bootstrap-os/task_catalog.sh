#!/usr/bin/env bash
# task_catalog.sh — sbos-bootstrap-os (Ficha 01)
# Hardening del sistema operativo, CRI-O, kubeadm, kernel params
# Principios: P2 (pre_install ABORT), P7 (Absorber/Ejecutar/Liberar), P10 (dry-run)
# SKULL · SBOS · infra-agent · 2026-05-13
set -euo pipefail

# ── Signal protocol ────────────────────────────────────────────
signal_start()  { echo "__SBOS__STEP_START__ $1"; }
signal_ok()     { echo "__SBOS__STEP_OK__"; }
signal_fail()   { echo "__SBOS__STEP_FAIL__"; }
signal_skip()   { echo "__SBOS__STEP_SKIP__"; }
signal_cleanup(){ echo "__SBOS__CLEANUP_DONE__"; }
signal_rollback(){ echo "__SBOS__ROLLBACK_START__"; }

MIN_K8S="1.28"

# ═══════════════════════════════════════════════════════════════
# PRE-INSTALL
# ═══════════════════════════════════════════════════════════════

check_ubuntu_2604() {
    signal_start "verificar_ubuntu_26_04"
    if [ ! -f /etc/os-release ]; then
        echo "FATAL: /etc/os-release no encontrado"
        signal_fail; return 2
    fi
    source /etc/os-release
    if [ "$ID" != "ubuntu" ] || [ "${VERSION_ID:-}" != "26.04" ]; then
        echo "FATAL: Se requiere Ubuntu 26.04 LTS. Detectado: $ID $VERSION_ID"
        signal_fail; return 2
    fi

    # Verificar cgroup v2 (systemd 259+ solo soporta cgroup v2)
    if [ "$(stat -f -c %T /sys/fs/cgroup 2>/dev/null)" != "cgroup2fs" ]; then
        echo "FATAL: cgroup v2 requerido (systemd 259+). cgroup v1 detectado o no disponible."
        echo "Verificar: mount | grep cgroup"
        signal_fail; return 2
    fi

    echo "Ubuntu 26.04 LTS verificado — cgroup v2 OK"
    signal_ok
}

check_k8s_version_min() {
    signal_start "verificar_k8s_version"
    if command -v kubectl &>/dev/null; then
        local v
        v=$(kubectl version --client --short 2>/dev/null | awk '{print $3}' | sed 's/v//')
        if [ -n "$v" ]; then
            if ! printf '%s\n' "$MIN_K8S" "$v" | sort -V -C 2>/dev/null; then
                echo "WARN: kubectl $v detectado (mínimo $MIN_K8S). Se instalará la versión correcta."
            else
                echo "kubectl $v >= $MIN_K8S OK"
            fi
        fi
    fi
    signal_ok
}

check_root_or_sudo() {
    signal_start "verificar_root"
    if [ "$(id -u)" != "0" ]; then
        echo "FATAL: Este script debe ejecutarse como root o con sudo"
        signal_fail; return 2
    fi
    echo "Privilegios administrativos OK"
    signal_ok
}

# ═══════════════════════════════════════════════════════════════
# INSTALL
# ═══════════════════════════════════════════════════════════════

harden_ssh_config() {
    signal_start "hardening_ssh"

    local sshd_config="/etc/ssh/sshd_config.d/90-sbos-hardening.conf"
    local bak="/etc/ssh/sshd_config.d/90-sbos-hardening.conf.bak.$(date +%s)"

    if [ -f "$sshd_config" ]; then
        cp "$sshd_config" "$bak"
    fi

    cat > "$sshd_config" <<'SSHEOF'
# SBOS Hardening — generado por sbos-bootstrap-os (Ficha 01)
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
MaxAuthTries 3
MaxSessions 10
ClientAliveInterval 300
ClientAliveCountMax 2
SSHEOF

    sshd -t 2>&1 || {
        echo "FATAL: sshd_config inválido — restaurando backup"
        [ -f "$bak" ] && cp "$bak" "$sshd_config"
        signal_fail; return 2
    }

    systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true
    echo "SSH hardening aplicado: root login deshabilitado, solo key auth"
    signal_ok
}

set_kernel_params() {
    signal_start "hardening_kernel"

    local sysctl_file="/etc/sysctl.d/90-sbos-k8s.conf"
    cat > "$sysctl_file" <<'SYSCTLEOF'
# SBOS K8s Kernel Params — generado por sbos-bootstrap-os
# Requerido por CRI-O y Calico
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.tcp_tw_reuse = 1
net.core.somaxconn = 65535
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288
vm.swappiness = 0
vm.overcommit_memory = 1
kernel.panic = 10
kernel.panic_on_oops = 1
SYSCTLEOF

    sysctl --system >/dev/null 2>&1

    # Verificar módulos de kernel
    for mod in overlay br_netfilter; do
        if ! lsmod | grep -q "^$mod "; then
            modprobe "$mod" 2>/dev/null || {
                echo "FATAL: No se pudo cargar el módulo $mod"
                signal_fail; return 2
            }
        fi
        # Persistir en modules-load.d
        echo "$mod" > "/etc/modules-load.d/sbos-${mod}.conf"
    done

    echo "Kernel params K8s aplicados: bridge-nf-call, ip_forward, overlay, br_netfilter"
    signal_ok
}

set_system_limits() {
    signal_start "hardening_limits"

    local limits_file="/etc/security/limits.d/90-sbos-nofile.conf"
    cat > "$limits_file" <<'LIMITSEOF'
# SBOS System Limits
* soft nofile 1048576
* hard nofile 1048576
* soft nproc unlimited
* hard nproc unlimited
root soft nofile 1048576
root hard nofile 1048576
root soft nproc unlimited
root hard nproc unlimited
LIMITSEOF

    echo "Límites de sistema: nofile=1048576, nproc=unlimited"
    signal_ok
}

install_cri_o() {
    signal_start "install_crio"

    local crio_version="1.28"
    local os="xUbuntu_26.04"

    # Verificar si ya está instalado
    if command -v crio &>/dev/null; then
        local v
        v=$(crio --version 2>/dev/null | grep -oP 'Version:\s*\K\S+' | head -1 | sed 's/v//')
        if printf '%s\n' "1.28" "$v" | sort -V -C 2>/dev/null; then
            echo "CRI-O $v ya instalado >= 1.28 — omitiendo"
            signal_skip; return 0
        fi
    fi

    # Docker VETADO — verificar que no esté instalado
    if command -v docker &>/dev/null; then
        echo "FATAL: Docker detectado en el host. ORQUESTA-039: Docker VETADO."
        echo "Desinstale Docker antes de continuar: apt purge docker-ce docker-ce-cli containerd.io"
        signal_fail; return 2
    fi

    # Instalar CRI-O
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq apt-transport-https ca-certificates curl gpg 2>/dev/null

    mkdir -p /etc/apt/keyrings
    curl -fsSL "https://pkgs.k8s.io/addons:/cri-o:/stable:/v${crio_version}/deb/Release.key" \
        | gpg --dearmor -o /etc/apt/keyrings/cri-o-archive-keyring.gpg 2>/dev/null

    echo "deb [signed-by=/etc/apt/keyrings/cri-o-archive-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/v${crio_version}/deb/ /" \
        > /etc/apt/sources.list.d/cri-o.list

    apt-get update -qq
    apt-get install -y -qq cri-o cri-o-runc 2>&1 || {
        echo "FATAL: Falló la instalación de CRI-O"
        signal_fail; return 2
    }

    # Configurar CRI-O para systemd cgroup
    cat > /etc/crio/crio.conf.d/90-sbos-cgroup.conf <<'CRIOEOF'
[crio.runtime]
cgroup_manager = "systemd"
conmon_cgroup = "systemd"
CRIOEOF

    systemctl enable --now crio 2>&1
    echo "CRI-O 1.28+ instalado y corriendo"
    signal_ok
}

install_kubeadm_kubelet_kubectl() {
    signal_start "install_k8s_packages"

    local k8s_version="1.28"
    export DEBIAN_FRONTEND=noninteractive

    # Verificar si ya están instalados con la versión correcta
    if command -v kubeadm &>/dev/null; then
        local v
        v=$(kubeadm version -o short 2>/dev/null | sed 's/v//')
        if printf '%s\n' "1.28" "$v" | sort -V -C 2>/dev/null; then
            echo "K8s packages $v ya instalados >= 1.28 — omitiendo"
            signal_skip; return 0
        fi
    fi

    mkdir -p /etc/apt/keyrings
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/Release.key" \
        | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null

    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/ /" \
        > /etc/apt/sources.list.d/kubernetes.list

    apt-get update -qq
    apt-get install -y -qq kubelet kubeadm kubectl 2>&1 || {
        echo "FATAL: Falló la instalación de paquetes K8s"
        signal_fail; return 2
    }

    echo "kubeadm, kubelet, kubectl 1.28+ instalados"
    signal_ok
}

apt_mark_hold_k8s() {
    signal_start "hold_k8s_packages"
    apt-mark hold kubelet kubeadm kubectl 2>/dev/null || true
    echo "Paquetes K8s marcados hold — no se actualizarán automáticamente"
    signal_ok
}

systemctl_enable_kubelet() {
    signal_start "enable_kubelet"
    systemctl enable kubelet 2>&1 || {
        echo "FATAL: No se pudo habilitar kubelet"
        signal_fail; return 2
    }
    echo "kubelet habilitado via systemd"
    signal_ok
}

install_configure_fail2ban() {
    signal_start "install_fail2ban"

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq fail2ban 2>/dev/null || {
        echo "WARN: No se pudo instalar fail2ban — continuando sin él"
        signal_skip; return 0
    }

    cat > /etc/fail2ban/jail.d/90-sbos-ssh.conf <<'F2BEOF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
F2BEOF

    systemctl enable --now fail2ban 2>/dev/null || true
    echo "fail2ban instalado con jail SSH"
    signal_ok
}

configure_ufw_k8s_ports() {
    signal_start "configure_firewall"

    if ! command -v ufw &>/dev/null; then
        echo "ufw no instalado — omitiendo"
        signal_skip; return 0
    fi

    # Puertos K8s control plane
    ufw allow 6443/tcp comment 'K8s API server' 2>/dev/null || true
    ufw allow 2379:2380/tcp comment 'etcd client/peer' 2>/dev/null || true
    ufw allow 10250/tcp comment 'kubelet API' 2>/dev/null || true
    ufw allow 10251/tcp comment 'kube-scheduler' 2>/dev/null || true
    ufw allow 10252/tcp comment 'kube-controller-manager' 2>/dev/null || true
    ufw allow 10255/tcp comment 'kubelet read-only' 2>/dev/null || true

    # Calico networking
    ufw allow 179/tcp comment 'Calico BGP' 2>/dev/null || true

    # Servicios SBOS
    ufw allow 22/tcp comment 'SSH' 2>/dev/null || true

    # No habilitar UFW automáticamente — el operador decide
    echo "Reglas UFW para K8s configuradas (ufw no habilitado automáticamente)"
    signal_ok
}

# ═══════════════════════════════════════════════════════════════
# POST-INSTALL
# ═══════════════════════════════════════════════════════════════

verify_crio_running() {
    signal_start "verificar_crio"
    if ! systemctl is-active --quiet crio; then
        echo "FATAL: CRI-O no está corriendo"
        signal_fail; return 2
    fi
    crictl info >/dev/null 2>&1 || {
        echo "FATAL: crictl no puede conectar con CRI-O"
        signal_fail; return 2
    }
    echo "CRI-O activo y respondiendo via crictl"
    signal_ok
}

verify_kubelet_active() {
    signal_start "verificar_kubelet"
    if ! systemctl is-enabled --quiet kubelet; then
        echo "FATAL: kubelet no está habilitado"
        signal_fail; return 2
    fi
    echo "kubelet habilitado"
    signal_ok
}

verify_kernel_modules() {
    signal_start "verificar_modulos_kernel"
    for mod in overlay br_netfilter; do
        if ! lsmod | grep -q "^$mod "; then
            echo "FATAL: Módulo $mod no cargado"
            signal_fail; return 2
        fi
    done
    echo "Módulos overlay y br_netfilter cargados"
    signal_ok
}

verify_k8s_128_plus() {
    signal_start "verificar_k8s_version_final"

    if ! command -v kubectl &>/dev/null; then
        echo "FATAL: kubectl no encontrado"
        signal_fail; return 2
    fi

    local v
    v=$(kubectl version --client --short 2>/dev/null | awk '{print $3}' | sed 's/v//')
    if [ -z "$v" ]; then
        echo "FATAL: No se pudo determinar la versión de kubectl"
        signal_fail; return 2
    fi

    if ! printf '%s\n' "$MIN_K8S" "$v" | sort -V -C 2>/dev/null; then
        echo "FATAL: kubectl $v está por debajo del mínimo $MIN_K8S"
        signal_fail; return 2
    fi

    echo "K8s $v >= $MIN_K8S verificado"
    signal_ok
}

# ═══════════════════════════════════════════════════════════════
# ROLLBACK
# ═══════════════════════════════════════════════════════════════

desinstalar_paquetes_k8s() {
    signal_rollback
    echo "Rollback: desinstalando paquetes K8s..."
    export DEBIAN_FRONTEND=noninteractive
    apt-mark unhold kubelet kubeadm kubectl 2>/dev/null || true
    apt-get purge -y -qq kubelet kubeadm kubectl cri-o cri-o-runc 2>/dev/null || true
    apt-get autoremove -y -qq 2>/dev/null || true

    # Limpiar repos
    rm -f /etc/apt/sources.list.d/cri-o.list /etc/apt/sources.list.d/kubernetes.list
    rm -f /etc/apt/keyrings/cri-o-archive-keyring.gpg /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # Limpiar configs
    rm -f /etc/sysctl.d/90-sbos-k8s.conf
    rm -f /etc/modules-load.d/sbos-overlay.conf /etc/modules-load.d/sbos-br_netfilter.conf
    rm -f /etc/ssh/sshd_config.d/90-sbos-hardening.conf

    echo "Paquetes K8s y configs eliminados"
    signal_cleanup
}

# ── Entry point ────────────────────────────────────────────────
case "${1:-}" in
    check_ubuntu_2604)          check_ubuntu_2604 ;;
    check_k8s_version_min)      check_k8s_version_min ;;
    check_root_or_sudo)         check_root_or_sudo ;;
    harden_ssh_config)          harden_ssh_config ;;
    set_kernel_params)          set_kernel_params ;;
    set_system_limits)          set_system_limits ;;
    install_cri_o)              install_cri_o ;;
    install_kubeadm_kubelet_kubectl) install_kubeadm_kubelet_kubectl ;;
    apt_mark_hold_k8s)          apt_mark_hold_k8s ;;
    systemctl_enable_kubelet)   systemctl_enable_kubelet ;;
    install_configure_fail2ban) install_configure_fail2ban ;;
    configure_ufw_k8s_ports)    configure_ufw_k8s_ports ;;
    verify_crio_running)        verify_crio_running ;;
    verify_kubelet_active)      verify_kubelet_active ;;
    verify_kernel_modules)      verify_kernel_modules ;;
    verify_k8s_128_plus)        verify_k8s_128_plus ;;
    desinstalar_paquetes_k8s)   desinstalar_paquetes_k8s ;;
    *)
        echo "task_catalog.sh: función no reconocida: ${1:-}"
        exit 1
        ;;
esac
