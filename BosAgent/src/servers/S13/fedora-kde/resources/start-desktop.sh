#!/bin/bash
# start-desktop.sh — entrada del contenedor SBOS Desktop (Ubuntu 24.04)
# tini es PID 1; este script inicia Xtigervnc + XFCE4 + noVNC
set -e

VNC_RES="${RESOLUTION:-1920x1080}"
VNC_DEPTH="${DEPTH:-24}"
VNC_DISPLAY=":1"
VNC_PORT="5900"
HOME_DIR="/home/sbosuser"
UID_USER=1001

mkdir -p "/run/user/${UID_USER}"
chmod 700 "/run/user/${UID_USER}"
chown sbosuser:sbosuser "/run/user/${UID_USER}"

mkdir -p "$HOME_DIR/.vnc"
if [[ ! -x "$HOME_DIR/.vnc/xstartup" ]]; then
    cp /etc/sbos-desktop/xstartup "$HOME_DIR/.vnc/xstartup"
    chmod +x "$HOME_DIR/.vnc/xstartup"
fi
chown -R sbosuser:sbosuser "$HOME_DIR/.vnc"

rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# Detectar binario TigerVNC (Ubuntu 24.04 usa Xtigervnc)
VNC_BIN=$(command -v Xtigervnc 2>/dev/null || command -v Xvnc 2>/dev/null || echo "")
if [[ -z "$VNC_BIN" ]]; then
    echo "[start-desktop] ERROR: no se encontró Xtigervnc ni Xvnc" >&2
    exit 1
fi
echo "[start-desktop] VNC bin: $VNC_BIN"

su sbosuser -c "
    $VNC_BIN $VNC_DISPLAY \
        -geometry '$VNC_RES' \
        -depth '$VNC_DEPTH' \
        -SecurityTypes None \
        -localhost no \
        -rfbport $VNC_PORT \
        -desktop 'SBOS Desktop' \
        >> /tmp/xvnc.log 2>&1 &
    echo \$! > /tmp/xvnc.pid
"

# Esperar a que el servidor X esté listo
for i in $(seq 1 20); do
    if su sbosuser -c "DISPLAY=$VNC_DISPLAY xdpyinfo > /dev/null 2>&1"; then
        echo "[start-desktop] Servidor X listo (${i}s)"
        break
    fi
    sleep 1
done

su sbosuser -c "
    export DISPLAY=$VNC_DISPLAY
    export XDG_RUNTIME_DIR=/run/user/$UID_USER
    bash '$HOME_DIR/.vnc/xstartup' >> /tmp/xstartup.log 2>&1 &
"

echo "[start-desktop] noVNC en :6901 → VNC :${VNC_PORT}"
exec websockify --web /usr/share/novnc/ 6901 "localhost:${VNC_PORT}"
