#!/usr/bin/env bash
# os-prereqs.sh — Verificador de requisitos del OS para sbos-bootstrap-os
# Retorna 0 si todos los requisitos se cumplen, 1 si alguno falla.
# Usado por ficha_pre_install() del task_catalog.sh.

set -euo pipefail

PASS=0
WARN=0
FAIL=0

check() {
    local label="$1" result="$2" msg="$3"
    case "$result" in
        ok)   echo "  [OK]   $label"; PASS=$((PASS+1)) ;;
        warn) echo "  [WARN] $label: $msg"; WARN=$((WARN+1)) ;;
        fail) echo "  [FAIL] $label: $msg"; FAIL=$((FAIL+1)) ;;
    esac
}

echo "=== Verificación de Requisitos OS — SBOS ==="

# Ubuntu 26.04
version=$(grep VERSION_ID /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "desconocido")
[[ "$version" == "26.04" ]] && check "Ubuntu 26.04 LTS" ok "" || check "Ubuntu 26.04 LTS" fail "detectado: $version"

# Kernel >= 7.0
kernel=$(uname -r | cut -d'.' -f1)
(( kernel >= 7 )) && check "Kernel >= 7.0" ok "" || check "Kernel >= 7.0" warn "kernel $kernel puede funcionar pero no es la versión canónica"

# RAM >= 4GB
ram_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
(( ram_mb >= 4096 )) && check "RAM >= 4GB (${ram_mb}MB)" ok "" || check "RAM >= 4GB" fail "${ram_mb}MB < 4096MB"

# CPU >= 2
cpu=$(nproc)
(( cpu >= 2 )) && check "CPU >= 2 (${cpu} cores)" ok "" || check "CPU >= 2" fail "${cpu} < 2"

# Disco >= 50GB en /
disk_gb=$(df -BG / | awk 'NR==2 {gsub("G",""); print $4}')
(( disk_gb >= 50 )) && check "Disco >= 50GB (${disk_gb}GB libres)" ok "" || check "Disco >= 50GB" fail "${disk_gb}GB < 50GB"

# Root o sudo
[[ $EUID -eq 0 ]] && check "Ejecutando como root" ok "" || check "Ejecutando como root" fail "EUID=$EUID"

# systemd
systemctl --version > /dev/null 2>&1 && check "systemd disponible" ok "" || check "systemd disponible" fail "systemd no encontrado"

# cgroups v2
if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
    check "cgroup v2 activo" ok ""
else
    check "cgroup v2" warn "cgroup v1 detectado — puede requerir configuración adicional"
fi

echo ""
echo "Resultado: ${PASS} OK, ${WARN} ADVERTENCIAS, ${FAIL} FALLOS"

(( FAIL == 0 )) && exit 0 || exit 1
