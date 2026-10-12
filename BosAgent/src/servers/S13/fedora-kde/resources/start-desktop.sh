#!/bin/bash
# start-desktop.sh — punto de entrada del contenedor SBOS Desktop
# Inicia Xvnc directamente (bypasa wrapper vncserver deprecated) + KDE + noVNC
set -e

VNC_RES="${RESOLUTION:-1920x1080}"
VNC_DEPTH="${DEPTH:-24}"
VNC_DISPLAY=":1"
VNC_PORT="5900"
HOME_DIR="/home/sbosuser"
UID_USER=1001

# Crear XDG_RUNTIME_DIR (requerido por KDE Plasma 6)
mkdir -p "/run/user/${UID_USER}"
chmod 700 "/run/user/${UID_USER}"
chown sbosuser:sbosuser "/run/user/${UID_USER}"

# Preparar directorio .vnc y xstartup (sin contraseña VNC — auth vía Keycloak SSO)
mkdir -p "$HOME_DIR/.vnc"

# Copiar xstartup si aún no existe
if [[ ! -x "$HOME_DIR/.vnc/xstartup" ]]; then
    cp /etc/sbos-desktop/xstartup "$HOME_DIR/.vnc/xstartup"
    chmod +x "$HOME_DIR/.vnc/xstartup"
fi
chown -R sbosuser:sbosuser "$HOME_DIR/.vnc"

# Limpiar locks de sesiones anteriores
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true

# Iniciar Xvnc sin autenticación VNC — la autenticación la maneja Keycloak + oauth2-proxy
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

# Esperar a que Xvnc esté escuchando
for i in $(seq 1 20); do
    if ss -tlnp 2>/dev/null | grep -q ":${VNC_PORT}"; then
        echo "[start-desktop] Xvnc listo en :${VNC_PORT} (${i}s)"
        break
    fi
    sleep 1
done

# Iniciar sesión KDE como sbosuser
su sbosuser -c "
    export DISPLAY=$VNC_DISPLAY
    export XDG_RUNTIME_DIR=/run/user/$UID_USER
    bash '$HOME_DIR/.vnc/xstartup' >> /tmp/xstartup.log 2>&1 &
"

# Crear subdirectorio /desktop/ dentro del directorio web de noVNC.
# nginx pasa el path completo (/desktop/...) a oauth2-proxy, que lo reenvía al upstream.
# websockify busca archivos en /usr/share/novnc/desktop/ para servir GET /desktop/*.
NOVNC_WEB="/usr/share/novnc"
if [[ ! -d "${NOVNC_WEB}/desktop" ]]; then
    mkdir "${NOVNC_WEB}/desktop"
    # Copiar solo los items en el primer nivel, excluye el propio desktop/ para no entrar en loop
    find "${NOVNC_WEB}" -maxdepth 1 -mindepth 1 -not -name 'desktop' \
        -exec cp -a {} "${NOVNC_WEB}/desktop/" \;
    echo "[start-desktop] Creado subdirectorio noVNC: ${NOVNC_WEB}/desktop/"
fi

echo "[start-desktop] noVNC en :6901 → VNC :${VNC_PORT}"
exec websockify --web /usr/share/novnc/ 6901 "localhost:${VNC_PORT}"
