#!/bin/bash
# host-setup.sh — Configura el HOST para SBOS greenfield testing
# BOS ejecuta este script con privilegios root durante autoBootstrap.
# Idempotente: seguro ejecutar múltiples veces.
#
# Requisito detectado en certificación S-24:
#   runc (dentro de containerd) necesita escribir en
#   /sys/fs/cgroup/k8s.io/<hash>/cgroup.procs.
#   Sin Delegate=yes en el servicio podman del host, el kernel no delega
#   un subárbol de cgroups escribible al contenedor.
#
# Modos de operación:
#   - Bare metal: escribe en /etc/systemd/system/ directamente.
#   - Contenedor: escribe en /host-systemd/ (montaje bind del host).
#
# Uso:
#   bash host-setup.sh          # ejecutar configuración
#   bash host-setup.sh --check  # solo verifica, no modifica

set -euo pipefail

# Detectar dónde está el systemd del host.
# /host-systemd es un bind mount de /etc/systemd/system del host (solo en contenedores).
if [[ -d /host-systemd ]] && [[ -f /run/.containerenv || -f /.containerenv ]]; then
    # Dentro del contenedor: /host-systemd YA ES /etc/systemd/system del host
    DELEGATE_DIR="/host-systemd/podman.service.d"
    NEEDS_HOST_RELOAD=1   # systemctl daemon-reload debe ejecutarse en el HOST
else
    # Bare metal: usar paths absolutos normales
    DELEGATE_DIR="/etc/systemd/system/podman.service.d"
    NEEDS_HOST_RELOAD=0
fi
DELEGATE_FILE="$DELEGATE_DIR/delegate.conf"
DELEGATE_CONTENT="[Service]
Delegate=yes
"

# ── Check mode ──────────────────────────────────────────────────
if [[ "${1:-}" == "--check" ]]; then
    echo "=== SBOS Host Setup — CHECK ONLY ==="
    echo "  SYSTEMD_BASE: ${SYSTEMD_BASE:-/}"
    if [[ -f "$DELEGATE_FILE" ]]; then
        echo "  podman Delegate=yes: CONFIGURED"
        cat "$DELEGATE_FILE" | sed 's/^/    /'
    else
        echo "  podman Delegate=yes: NOT CONFIGURED"
        echo "  Path: $DELEGATE_FILE"
        echo "  Run: bash host-setup.sh"
    fi
    exit 0
fi

echo "=== SBOS Host Setup ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Target: $DELEGATE_FILE"

# ── 1. podman Delegate=yes ──────────────────────────────────────
echo ""
echo "--- Configurando podman Delegate=yes ---"
mkdir -p "$DELEGATE_DIR"

cat > "$DELEGATE_FILE" << 'EOF'
[Service]
Delegate=yes
EOF

echo "  Creado: $DELEGATE_FILE"
cat "$DELEGATE_FILE" | sed 's/^/  /'

# ── 2. systemd daemon-reload ────────────────────────────────────
echo ""
echo "--- Recargando systemd ---"
if [[ $NEEDS_HOST_RELOAD -eq 1 ]]; then
    echo "  AVISO: Ejecutando dentro de contenedor."
    echo "  El archivo se escribió en el systemd del HOST vía /host-systemd."
    echo "  Debes ejecutar EN EL HOST: sudo systemctl daemon-reload"
    echo "  Luego recrear el contenedor: podman rm -f sbos-greenfield && bash install.sh"
else
    systemctl daemon-reload
    echo "  systemctl daemon-reload: OK"
fi

echo ""
echo "=== Host setup completado ==="
