#!/bin/bash
# start-desktop.sh — punto de entrada del contenedor SBOS Desktop
set -e

VNC_PASS="${VNC_PASSWORD:-sbos_desk}"
VNC_RES="${RESOLUTION:-1920x1080}"
VNC_DEPTH="${DEPTH:-24}"
# TigerVNC limita la contraseña a 8 caracteres
VNC_PASS="${VNC_PASS:0:8}"

HOME_DIR="/home/sbosuser"

# Preparar directorio VNC
mkdir -p "$HOME_DIR/.vnc"

# Escribir contraseña VNC cifrada
printf '%s' "$VNC_PASS" | vncpasswd -f > "$HOME_DIR/.vnc/passwd"
chmod 600 "$HOME_DIR/.vnc/passwd"
chown sbosuser:sbosuser "$HOME_DIR/.vnc/passwd"

# Copiar xstartup si no existe aún
if [[ ! -x "$HOME_DIR/.vnc/xstartup" ]]; then
    cp /etc/sbos-desktop/xstartup "$HOME_DIR/.vnc/xstartup"
    chmod +x "$HOME_DIR/.vnc/xstartup"
    chown sbosuser:sbosuser "$HOME_DIR/.vnc/xstartup"
fi

chown -R sbosuser:sbosuser "$HOME_DIR/.vnc"

# Limpiar locks de sesiones VNC anteriores (reinicio del pod)
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# Iniciar TigerVNC (Xvnc) como sbosuser
su sbosuser -c \
    "vncserver :1 \
        -geometry '$VNC_RES' \
        -depth '$VNC_DEPTH' \
        -rfbauth '$HOME_DIR/.vnc/passwd' \
        -SecurityTypes VncAuth \
        -localhost no \
        -rfbport 5900 \
        >> /tmp/vncserver.log 2>&1"

# Esperar a que Xvnc esté listo
for i in $(seq 1 15); do
    if ss -tlnp 2>/dev/null | grep -q ':5900 '; then
        echo "[start-desktop] TigerVNC listo en :5900 (${i}s)"
        break
    fi
    sleep 1
done

echo "[start-desktop] noVNC en :6901 → VNC :5900"
# websockify como proceso principal (mantiene el contenedor activo)
exec websockify --web /usr/share/novnc/ 6901 localhost:5900
