#!/usr/bin/env bash
# install.sh — Bootstrap de SBOS en el servidor.
#
# NORMA IRRENUNCIABLE (ADR-022):
#   Este script hace UNA SOLA COSA: copiar los binarios y delegar
#   TODA la instalación a "bosctl install".
#   Sin apt-get. Sin useradd. Sin systemctl. Sin configuraciones manuales.
#   Cualquier dependencia del SO = ficha declarativa bos-preflight.
#
# Uso (como root):
#   cd /tmp/sbos && sudo bash install.sh [--mode=dev|prod] [--seed=<ruta>]
#
# Un solo comando — hace todo: instala el daemon + despliega el stack completo.

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

# Copiar bosctl a /usr/local/bin para ejecutarlo desde cualquier directorio
install -m 755 "$DIR/bosctl" /usr/local/bin/bosctl
install -m 755 "$DIR/bos"    /usr/local/bin/bos
ok "bosctl disponible"

# Detectar seed file: argumento explícito → junto a install.sh → default
SEED=""
MODE="dev"
for arg in "$@"; do
    case "$arg" in
        --seed=*)  SEED="${arg#--seed=}" ;;
        --mode=*)  MODE="${arg#--mode=}" ;;
    esac
done

if [[ -z "$SEED" ]]; then
    if [[ -f "$DIR/servers/seed-skull.yml" ]]; then
        SEED="$DIR/servers/seed-skull.yml"
    else
        fail "Seed no encontrado. Usar: bash install.sh --seed=<ruta>"
    fi
fi

[[ -f "$SEED" ]] || fail "Seed no existe: $SEED"
ok "seed: $SEED"

# Delegar TODO a bosctl install — instala daemon + despliega stack completo
echo ""
echo "  Ejecutando bosctl install --mode=$MODE --seed=$SEED"
echo "  (instala daemon, K8s, PG, Redis, Vault, Keycloak, fichas)"
echo ""

exec bosctl install --mode="$MODE" --seed="$SEED"
