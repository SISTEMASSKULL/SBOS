#!/bin/bash
# agente_enviar — shim para BauthAgent
# Carga la función desde el script canónico de la fábrica.
# PROHIBIDO usar tmux send-keys directamente.
#
# USO: source scripts/agente_enviar.sh && agente_enviar <pane> "<mensaje>"

FABRICA_SCRIPT="/opt/skull/orquestador/proyectos/fabrica/scripts/agente_enviar.sh"

if [ -f "$FABRICA_SCRIPT" ]; then
    source "$FABRICA_SCRIPT"
else
    echo "ERROR: No se encuentra el script de fábrica en $FABRICA_SCRIPT" >&2
    return 1
fi
