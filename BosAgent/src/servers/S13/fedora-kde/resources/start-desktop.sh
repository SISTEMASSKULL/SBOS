#!/bin/bash
# start-desktop.sh — SBOS VDI (Fedora 44 + KDE Plasma 6)
# tini es PID 1; este script inicia Xvnc + KDE Plasma (X11) + noVNC websockify
set -e

VNC_RES="${RESOLUTION:-1920x1080}"
VNC_DEPTH="${DEPTH:-24}"
VNC_DISPLAY=":1"
VNC_PORT="5900"
VDIUSER="vdiuser"
UID_USER=1001

_log() { echo "[sbos-vdi] $*"; }

# ── Preparar entorno ──────────────────────────────────────────────────────────
mkdir -p /run/user/${UID_USER} /tmp/.X11-unix
chmod 700 /run/user/${UID_USER}
chmod 1777 /tmp/.X11-unix
chown ${VDIUSER}:${VDIUSER} /run/user/${UID_USER}
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# ── Servidor VNC (Xvnc — binario de TigerVNC en Fedora) ──────────────────────
_log "Iniciando Xvnc en ${VNC_DISPLAY} (${VNC_RES}x${VNC_DEPTH})"
su ${VDIUSER} -c "
    Xvnc ${VNC_DISPLAY} \
        -geometry ${VNC_RES} \
        -depth ${VNC_DEPTH} \
        -SecurityTypes None \
        -localhost no \
        -rfbport ${VNC_PORT} \
        -desktop 'SBOS VDI' \
        2>/tmp/xvnc.log &
"

# Esperar socket X (máx 60s) — más fiable que xdpyinfo en contenedores
for i in $(seq 1 60); do
    [ -S "/tmp/.X11-unix/X${VNC_DISPLAY#:}" ] && { _log "Socket X listo (${i}s)"; break; }
    [ $i -eq 60 ] && { _log "ERROR: Xvnc no inició en 60s"; cat /tmp/xvnc.log; exit 1; }
    sleep 1
done

# ── KDE Plasma 6 en modo X11 (kwin_x11 — Fedora 44) ─────────────────────────
# En Fedora 44, startplasma arranca Wayland por defecto; usamos kwin_x11 + plasmashell
_log "Iniciando KDE Plasma 6 (modo X11) en ${VNC_DISPLAY}"
su ${VDIUSER} -c "
    export DISPLAY=${VNC_DISPLAY}
    export XDG_RUNTIME_DIR=/run/user/${UID_USER}
    export XDG_SESSION_TYPE=x11
    export XDG_CURRENT_DESKTOP=KDE
    export XDG_SESSION_DESKTOP=KDE
    export KDE_FULL_SESSION=true
    export HOME=/home/${VDIUSER}

    eval \$(dbus-launch --sh-syntax)
    export DBUS_SESSION_BUS_ADDRESS

    kwin_x11 &
    sleep 2
    plasmashell &
" &

_log "noVNC escuchando en :6901 → VNC :${VNC_PORT}"
exec websockify --web /usr/share/novnc/ 6901 localhost:${VNC_PORT}
