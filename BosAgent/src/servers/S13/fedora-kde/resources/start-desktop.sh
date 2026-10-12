#!/bin/bash
# start-desktop.sh — punto de entrada del contenedor SBOS Desktop
# Inicia Xvnc + XFCE4 (xfwm4 compositor software, sin GPU) + noVNC
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

su sbosuser -c "
    Xvnc $VNC_DISPLAY \
        -geometry '$VNC_RES' \
        -depth '$VNC_DEPTH' \
        -SecurityTypes None \
        -localhost no \
        -rfbport $VNC_PORT \
        -desktop 'SBOS Desktop' \
        >> /tmp/xvnc.log 2>&1 &
    echo \$! > /tmp/xvnc.pid
"

for i in $(seq 1 20); do
    if netstat -tlnp 2>/dev/null | grep -q ":${VNC_PORT}" || \
       cat /proc/net/tcp6 2>/dev/null | grep -qi "170C"; then
        echo "[start-desktop] Xvnc listo en :${VNC_PORT} (${i}s)"
        break
    fi
    sleep 1
done

su sbosuser -c "
    export DISPLAY=$VNC_DISPLAY
    export XDG_RUNTIME_DIR=/run/user/$UID_USER
    bash '$HOME_DIR/.vnc/xstartup' >> /tmp/xstartup.log 2>&1 &
"

NOVNC_WEB="/usr/share/novnc"
if [[ ! -d "${NOVNC_WEB}/desktop" ]]; then
    mkdir "${NOVNC_WEB}/desktop"
    find "${NOVNC_WEB}" -maxdepth 1 -mindepth 1 -not -name 'desktop' \
        -exec cp -a {} "${NOVNC_WEB}/desktop/" \;
    echo "[start-desktop] Creado subdirectorio noVNC: ${NOVNC_WEB}/desktop/"
fi

echo "[start-desktop] noVNC en :6901 → VNC :${VNC_PORT}"
exec websockify --web /usr/share/novnc/ 6901 "localhost:${VNC_PORT}"
