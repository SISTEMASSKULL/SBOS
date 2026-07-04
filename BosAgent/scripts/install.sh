#!/bin/bash
# install.sh — SBOS BOS Installer (one-shot, zero-touch)
#
# Usage:
#   bash install.sh --container              # Greenfield: deploy BOS in container
#   bash install.sh --host <IP>              # Bare metal: install BOS on host
#
# Modes:
#   --container   Deploy BOS in a privileged container (sudo podman).
#                 BOS auto-bootstraps and installs all 114 fichas.
#   --host <IP>   Install BOS directly on this host. Verifies prerequisites,
#                 compiles, deploys, configures systemd, and starts BOS.
#                 <IP> is the server's public/primary IP address.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
STAGING="$PROJECT_DIR/staging/core"
SRC="$PROJECT_DIR/src"
CONTAINER="sbos-greenfield"
IMAGE="ubuntu:26.04"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INSTALL]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Parse arguments ──────────────────────────────────────────────────
MODE=""
HOST_IP=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --container)
            MODE="container"
            shift
            ;;
        --host)
            MODE="host"
            shift
            if [[ $# -gt 0 && ! "$1" =~ ^-- ]]; then
                HOST_IP="$1"
                shift
            fi
            ;;
        --help|-h)
            echo "Usage: bash install.sh --container | --host <IP>"
            echo ""
            echo "  --container     Deploy BOS in a privileged container (greenfield testing)"
            echo "  --host <IP>     Install BOS directly on this host (bare metal)"
            echo "                  <IP> = server public/primary IP address"
            exit 0
            ;;
        *)
            err "Unknown argument: $1"
            echo "Usage: bash install.sh --container | --host <IP>"
            exit 1
            ;;
    esac
done

if [[ -z "$MODE" ]]; then
    err "Missing mode. Use --container or --host <IP>"
    echo "Usage: bash install.sh --container | --host <IP>"
    exit 1
fi

# ── Bootstrap env ────────────────────────────────────────────────────
BOOTSTRAP_ENV="$STAGING/bos-bootstrap.env"
if [[ ! -f "$BOOTSTRAP_ENV" ]]; then
    err "No se encuentra $BOOTSTRAP_ENV"
    exit 1
fi
# shellcheck source=/dev/null
source "$BOOTSTRAP_ENV"
ROOT_PASS="${BOS_ROOT_PASSWORD:-}"
if [[ -z "$ROOT_PASS" ]]; then
    err "BOS_ROOT_PASSWORD no definida en bos-bootstrap.env"
    exit 1
fi

# sudo wrapper — NO suprime stderr (necesario para diagnosticar fallos)
_sudo() {
    echo "$ROOT_PASS" | sudo -S "$@"
}

# Verify sudo works
if ! _sudo true; then
    err "Contraseña root del host incorrecta o sudo no disponible."
    err "Verifica BOS_ROOT_PASSWORD en bos-bootstrap.env"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════
# MODE: --container
# ═══════════════════════════════════════════════════════════════════════
if [[ "$MODE" == "container" ]]; then
    log "MODO: Contenedor (root podman)"
    log "=============================================="

    # ── 0. Host setup: podman Delegate=yes ──────────────────────────
    log "Configurando HOST: podman Delegate=yes..."
    _sudo mkdir -p /etc/systemd/system/podman.service.d
    echo '[Service]
Delegate=yes' | _sudo tee /etc/systemd/system/podman.service.d/delegate.conf > /dev/null
    _sudo systemctl daemon-reload
    log "  Delegate=yes configurado + daemon-reload ejecutado"

    # ── 0.1 Crear red bridge sin DNS interno ────────────────────────
    BRIDGE_NET="sbos-bridge"
    if ! _sudo podman network inspect "$BRIDGE_NET" &>/dev/null; then
        log "Creando red bridge $BRIDGE_NET (dns disabled)..."
        _sudo podman network create --disable-dns --subnet 10.90.0.0/24 --gateway 10.90.0.1 "$BRIDGE_NET"
    fi
    # Obtener subnet de la red para la regla FORWARD
    BRIDGE_SUBNET=$(_sudo podman network inspect "$BRIDGE_NET" --format '{{range .Subnets}}{{.Subnet}}{{end}}')
    log "  Red: $BRIDGE_NET — Subnet: $BRIDGE_SUBNET"

    # ── 0.2 Abrir FORWARD para tráfico bridge ──────────────────────
    # El chain ip filter FORWARD tiene policy: drop y solo acepta tráfico
    # con mark 0x10000 (K8s/Calico). El tráfico de redes bridge de podman
    # no tiene esa marca y es descartado. Insertamos regla de accept.
    if _sudo nft list chain ip filter FORWARD 2>/dev/null | grep -q "ip saddr $BRIDGE_SUBNET accept"; then
        log "  Regla FORWARD para $BRIDGE_SUBNET ya existe"
    else
        log "Insertando regla FORWARD para $BRIDGE_SUBNET..."
        _sudo nft insert rule ip filter FORWARD ip saddr "$BRIDGE_SUBNET" accept
        log "  Regla FORWARD insertada"
    fi

    # ── 1. Verificar/compilar binarios ──────────────────────────────
    BOS_BIN="$SRC/cmd/bos/bos"
    BOSCTL_BIN="$SRC/cmd/bosctl/bosctl"
    if [[ -x "$BOS_BIN" ]] && [[ -x "$BOSCTL_BIN" ]] && \
       file "$BOS_BIN" | grep -q "ELF.*executable"; then
        log "Binarios ya compilados:"
        log "  bos:    $(file "$BOS_BIN" | cut -d: -f2)"
        log "  bosctl: $(file "$BOSCTL_BIN" | cut -d: -f2)"
    else
        log "Compilando binarios (golang:1.22)..."
        podman run --rm -v "$SRC:/src:Z" -w /src golang:1.22 sh -c "
          go build -o cmd/bos/bos ./cmd/bos/ && \
          go build -o cmd/bosctl/bosctl ./cmd/bosctl/ && \
          echo 'BUILD OK'
        " || { err "Compilación fallida"; exit 1; }
    fi

    # ── 2. Destruir contenedor anterior (root podman) ───────────────
    if _sudo podman ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        log "Destruyendo contenedor anterior: $CONTAINER"
        _sudo podman rm -f "$CONTAINER"
    fi

    # ── 3. Crear contenedor base ────────────────────────────────────
    log "Creando contenedor: $CONTAINER (bridge + DNS 8.8.8.8)"
    _sudo podman run -d --name "$CONTAINER" --hostname "$CONTAINER" \
        --privileged --cgroupns=host \
        --network "$BRIDGE_NET" \
        --dns 8.8.8.8 --dns 1.1.1.1 \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
        "$IMAGE" bash -c "sleep infinity"

    # ── 4. Instalar systemd + configurar root ───────────────────────
    log "Instalando systemd y configurando root..."
    _sudo podman exec "$CONTAINER" bash -c "
      apt-get update -qq && \
      apt-get install -y -qq systemd systemd-sysv curl wget netcat-openbsd ca-certificates
    " || { err "Instalación de systemd fallida"; exit 1; }

    # Configurar contraseña root en el contenedor = misma del host
    _sudo podman exec "$CONTAINER" bash -c "echo 'root:$ROOT_PASS' | chpasswd"
    log "  root password configurada en contenedor"

    # ── 5. Reiniciar con systemd ────────────────────────────────────
    log "Verificando /sbin/init en contenedor..."
    if ! _sudo podman exec "$CONTAINER" test -x /sbin/init; then
        err "/sbin/init no encontrado en contenedor — la instalación de systemd falló"
        exit 1
    fi
    log "  /sbin/init OK"

    log "Reiniciando contenedor con systemd..."
    _sudo podman stop "$CONTAINER"
    _sudo podman commit "$CONTAINER" "${CONTAINER}-base"
    _sudo podman rm "$CONTAINER"
    _sudo podman run -d --name "$CONTAINER" --hostname "$CONTAINER" \
        --privileged --cgroupns=host \
        --network "$BRIDGE_NET" \
        --dns 8.8.8.8 --dns 1.1.1.1 \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
        "${CONTAINER}-base" /sbin/init

    sleep 4
    CONTAINER_STATUS=$(_sudo podman ps --filter name=$CONTAINER --format '{{.Status}}' 2>&1) || true
    if [[ -z "$CONTAINER_STATUS" ]]; then
        err "Contenedor no arrancó con systemd. Últimas líneas de log:"
        _sudo podman logs "$CONTAINER" 2>&1 | tail -20 || true
        exit 1
    fi
    log "Contenedor listo: $CONTAINER_STATUS"

    # ── 6. Copiar archivos a /tmp/ ──────────────────────────────────
    log "Desplegando archivos a /tmp/..."

    _sudo podman cp "$SRC/cmd/bos/bos"          "$CONTAINER:/tmp/bos"
    _sudo podman cp "$SRC/cmd/bosctl/bosctl"    "$CONTAINER:/tmp/bosctl"
    _sudo podman cp "$BOOTSTRAP_ENV"            "$CONTAINER:/tmp/bos-bootstrap.env"

    for s in 00_MASTER_INSTALL_SBOS.sh 00_TASK_CATALOG_SBOS.sh 00_YAML_ENGINE_SBOS.sh 00_CLEANUP_SBOS.sh; do
        _sudo podman cp "$STAGING/$s" "$CONTAINER:/tmp/$s"
    done

    _sudo podman cp "$SCRIPT_DIR/host-setup.sh" "$CONTAINER:/tmp/host-setup.sh"
    _sudo podman cp "$STAGING/servers" "$CONTAINER:/tmp/servers"

    # ── 7. Crear bos.toml y bos-install.toml ────────────────────────
    log "Creando archivos de configuración..."

    _sudo podman exec "$CONTAINER" bash -c 'cat > /tmp/bos.toml << "TOML"
log_level = "info"

[state]
lock_timeout_seconds = 5

[health]
health_check_interval_seconds = 30
consecutive_failures_threshold = 3

[reconcile]
reconcile_interval_seconds = 300
drift_check = true

[sagas]
install_timeout_minutes = 30
update_timeout_minutes = 15
repair_timeout_minutes = 10
uninstall_timeout_minutes = 10
deploy_timeout_minutes = 120

[growth]
cpu_threshold_percent = 80
ram_threshold_percent = 85
disk_threshold_percent = 75
evaluation_window_minutes = 30
TOML'

    _sudo podman exec "$CONTAINER" bash -c 'cat > /tmp/bos-install.toml << "TOML"
org_name = "SkullSystems"
client_domain = "skull.local"
server_ip = "144.91.76.130"
release_server_url = "https://releases.skull.local"
channel = "testing"
http_port = 9443
servers_path = "/etc/bos/blibs/servers"
kubeconfig_path = "/etc/bos/.kube/config"
unix_socket = "/run/bos/bos.sock"
bos_user = "root"
bos_group = "root"
log_path = "/var/log/bos"

[dns]
base_domain = "skull.local"
TOML'

    log "Archivos en /tmp/:"
    _sudo podman exec "$CONTAINER" ls /tmp/

    # ── 8. Ejecutar BOS ─────────────────────────────────────────────
    log "Ejecutando BOS — desde aquí BOS controla todo..."
    log "=============================================="
    _sudo podman exec -d "$CONTAINER" /tmp/bos --config /etc/bos/bos.toml

    sleep 5
    log "BOS iniciado. Últimas líneas del log:"
    _sudo podman exec "$CONTAINER" cat /var/log/bos/bos.log 2>/dev/null | tail -20 || \
        warn "Log aún no disponible — espera unos segundos más"

    echo ""
    log "=============================================="
    log "Instalación completada. BOS está corriendo."
    log "Verificar progreso:"
    log "  sudo podman exec $CONTAINER cat /var/log/bos/bos.log | grep -E '(saga completed|saga failed|auto-install: triggering)'"
    log "=============================================="

# ═══════════════════════════════════════════════════════════════════════
# MODE: --host
# ═══════════════════════════════════════════════════════════════════════
elif [[ "$MODE" == "host" ]]; then
    if [[ -z "$HOST_IP" ]]; then
        err "--host requiere la IP del servidor."
        err "Uso: bash install.sh --host <IP>"
        exit 1
    fi

    log "MODO: Bare Metal — instalando BOS en el host"
    log "IP del servidor: $HOST_IP"
    log "=============================================="

    # ── 0. Prerequisite verification ────────────────────────────────
    log "Verificando prerrequisitos..."

    PREREQ_OK=true

    # systemd
    if command -v systemctl &>/dev/null && systemctl --version &>/dev/null; then
        log "  [OK] systemd: $(systemctl --version 2>&1 | head -1)"
    else
        err "  [FAIL] systemd no encontrado — requerido"
        PREREQ_OK=false
    fi

    # cgroup v2
    if stat -f /sys/fs/cgroup 2>/dev/null | grep -q cgroup2fs; then
        log "  [OK] cgroup v2"
    else
        err "  [FAIL] cgroup v2 no detectado — requerido para Kubernetes"
        PREREQ_OK=false
    fi

    # kernel >= 5.4
    KERNEL_MAJOR=$(uname -r | cut -d. -f1)
    KERNEL_MINOR=$(uname -r | cut -d. -f2)
    if [[ "$KERNEL_MAJOR" -gt 5 || ("$KERNEL_MAJOR" -eq 5 && "$KERNEL_MINOR" -ge 4) ]]; then
        log "  [OK] kernel: $(uname -r)"
    else
        warn "  [WARN] kernel $(uname -r) < 5.4 — Kubernetes puede no funcionar"
    fi

    # podman (para compilar si no hay go)
    if command -v podman &>/dev/null; then
        log "  [OK] podman: $(podman --version)"
    else
        warn "  [WARN] podman no encontrado — se necesita para compilar (no hay go nativo)"
    fi

    # go (opcional — se usa podman si no está)
    if command -v go &>/dev/null; then
        log "  [OK] go: $(go version)"
    else
        warn "  [INFO] go no instalado — se usará contenedor golang para compilar"
    fi

    # Espacio en disco
    DISK_AVAIL=$(df -BG /opt | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ "$DISK_AVAIL" -ge 20 ]]; then
        log "  [OK] espacio en /opt: ${DISK_AVAIL}G disponible"
    else
        warn "  [WARN] espacio en /opt: ${DISK_AVAIL}G — se recomiendan 20G+"
    fi

    # RAM
    MEM_TOTAL=$(free -g | awk '/^Mem:/ {print $2}')
    if [[ "$MEM_TOTAL" -ge 8 ]]; then
        log "  [OK] RAM: ${MEM_TOTAL}G"
    else
        warn "  [WARN] RAM: ${MEM_TOTAL}G — se recomiendan 8G+ para Kubernetes"
    fi

    if ! $PREREQ_OK; then
        err "Prerrequisitos críticos no cumplidos. Instale los componentes faltantes y reintente."
        exit 1
    fi
    log "Todos los prerrequisitos verificados."

    # ── 1. Compilar binarios ────────────────────────────────────────
    if command -v go &>/dev/null; then
        log "Compilando binarios (go nativo)..."
        cd "$SRC"
        go build -o cmd/bos/bos ./cmd/bos/ && go build -o cmd/bosctl/bosctl ./cmd/bosctl/
        cd "$PROJECT_DIR"
        log "  BUILD OK (nativo)"
    else
        log "Compilando binarios (golang:1.22 contenedor)..."
        podman run --rm -v "$SRC:/src:Z" -w /src golang:1.22 sh -c "
          go build -o cmd/bos/bos ./cmd/bos/ && \
          go build -o cmd/bosctl/bosctl ./cmd/bosctl/ && \
          echo 'BUILD OK'
        " || { err "Compilación fallida"; exit 1; }
    fi

    # ── 2. Crear estructura de directorios ──────────────────────────
    log "Creando estructura de directorios..."
    _sudo mkdir -p /opt/bos/bin /opt/bos/core /etc/bos/blibs/servers /etc/bos/.kube /var/log/bos /run/bos

    # ── 3. Desplegar binarios ───────────────────────────────────────
    log "Desplegando binarios..."
    _sudo cp "$SRC/cmd/bos/bos"       /opt/bos/bin/bos
    _sudo cp "$SRC/cmd/bosctl/bosctl" /opt/bos/bin/bosctl
    _sudo chmod 0755 /opt/bos/bin/bos /opt/bos/bin/bosctl

    # ── 4. Desplegar configuración y scripts ────────────────────────
    log "Desplegando configuración..."

    # bos.toml
    _sudo tee /etc/bos/bos.toml > /dev/null << 'TOML'
log_level = "info"

[state]
lock_timeout_seconds = 5

[health]
health_check_interval_seconds = 30
consecutive_failures_threshold = 3

[reconcile]
reconcile_interval_seconds = 300
drift_check = true

[sagas]
install_timeout_minutes = 30
update_timeout_minutes = 15
repair_timeout_minutes = 10
uninstall_timeout_minutes = 10
deploy_timeout_minutes = 120

[growth]
cpu_threshold_percent = 80
ram_threshold_percent = 85
disk_threshold_percent = 75
evaluation_window_minutes = 30
TOML

    # bos-install.toml
    _sudo tee /etc/bos/bos-install.toml > /dev/null << TOML
org_name = "SkullSystems"
client_domain = "skull.local"
server_ip = "${HOST_IP}"
release_server_url = "https://releases.skull.local"
channel = "testing"
http_port = 9443
servers_path = "/etc/bos/blibs/servers"
kubeconfig_path = "/etc/bos/.kube/config"
unix_socket = "/run/bos/bos.sock"
bos_user = "root"
bos_group = "root"
log_path = "/var/log/bos"

[dns]
base_domain = "skull.local"
TOML

    # bos-bootstrap.env
    _sudo cp "$BOOTSTRAP_ENV" /etc/bos/bos-bootstrap.env
    _sudo chmod 0600 /etc/bos/bos-bootstrap.env

    # Core scripts
    for s in 00_MASTER_INSTALL_SBOS.sh 00_TASK_CATALOG_SBOS.sh 00_YAML_ENGINE_SBOS.sh 00_CLEANUP_SBOS.sh; do
        _sudo cp "$STAGING/$s" "/opt/bos/core/$s"
        _sudo chmod 0755 "/opt/bos/core/$s"
    done

    _sudo cp "$SCRIPT_DIR/host-setup.sh" /opt/bos/core/host-setup.sh
    _sudo chmod 0755 /opt/bos/core/host-setup.sh

    # Servers (fichas)
    if [[ -d /etc/bos/blibs/servers ]] && [[ -z "$(ls -A /etc/bos/blibs/servers 2>/dev/null)" ]]; then
        _sudo cp -r "$STAGING/servers/"* /etc/bos/blibs/servers/
    fi

    log "Archivos desplegados en paths canónicos."

    # ── 5. Configurar systemd Delegate=yes para bos.service ─────────
    log "Configurando systemd Delegate=yes para bos.service..."
    _sudo mkdir -p /etc/systemd/system/bos.service.d
    echo '[Service]
Delegate=yes' | _sudo tee /etc/systemd/system/bos.service.d/delegate.conf > /dev/null
    _sudo systemctl daemon-reload
    log "  Delegate=yes configurado para bos.service"

    # ── 6. Crear bos.service unit ───────────────────────────────────
    log "Creando bos.service systemd unit..."
    _sudo tee /etc/systemd/system/bos.service > /dev/null << 'UNIT'
[Unit]
Description=BOS — Sovereign Business OS (IAM Installer)
Documentation=https://github.com/SISTEMASSKULL/sbos
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/bos/bin/bos --config /etc/bos/bos.toml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
User=root
Group=root
Environment=HOME=/root
Delegate=yes

[Install]
WantedBy=multi-user.target
UNIT

    _sudo systemctl daemon-reload
    log "  bos.service creado"

    # ── 7. Iniciar BOS ──────────────────────────────────────────────
    log "Iniciando BOS como servicio del host..."
    log "=============================================="
    _sudo systemctl enable bos.service
    _sudo systemctl start bos.service

    sleep 3
    BOS_STATUS=$(_sudo systemctl is-active bos.service 2>&1 || true)
    log "Estado del servicio: $BOS_STATUS"

    echo ""
    log "=============================================="
    log "Instalación completada. BOS está corriendo en el host."
    log "Verificar logs:"
    log "  sudo journalctl -u bos.service -f"
    log "  tail -f /var/log/bos/bos.log"
    log "Verificar progreso:"
    log "  grep -E '(saga completed|saga failed|auto-install: triggering)' /var/log/bos/bos.log"
    log "=============================================="
fi
