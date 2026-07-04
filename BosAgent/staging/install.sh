#!/usr/bin/env bash
# install.sh — Bootstrap de SBOS en el servidor.
#
# NORMA IRRENUNCIABLE (ADR-022):
#   Este script hace UNA SOLA COSA: copiar los binarios y delegar
#   TODA la instalación a "bosctl system-install".
#   Sin apt-get. Sin useradd. Sin systemctl. Sin configuraciones manuales.
#   Cualquier dependencia del SO = ficha declarativa bos-preflight.
#
# Uso (como root):
#   cd /tmp/sbos && sudo bash install.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✔${NC} $1"; }
fail() { echo -e "${RED}  ✗${NC} $1"; exit 1; }

echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         SBOS — Bootstrap Inicial                          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo "  $(hostname)  |  $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

[[ $EUID -eq 0 ]] || fail "Requiere root: sudo bash install.sh"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verificar que los binarios necesarios están aquí
for f in bos bosctl; do
    [[ -f "$DIR/$f" ]] || fail "Falta el binario: $f (copiar junto a install.sh)"
done
ok "binarios presentes"

# Dar permisos de ejecución si hace falta
chmod +x "$DIR/bos" "$DIR/bosctl"

# Copiar bosctl temporalmente a /usr/local/bin para poder ejecutarlo
install -m 755 "$DIR/bosctl" /usr/local/bin/bosctl
install -m 755 "$DIR/bos"    /usr/local/bin/bos
ok "bosctl disponible"

# Delegar TODO a bosctl — el instalador cubre cualquier necesidad
echo ""
echo "  Ejecutando bosctl system-install..."
echo "  (instala dependencias, crea usuario, dirs, cgroups, servicios)"
echo ""

exec bosctl system-install
