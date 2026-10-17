#!/usr/bin/env bash
# ============================================================
# SBOS — Instalador soberano
# ============================================================
#
#   git clone https://github.com/SISTEMASSKULL/SBOS.git && sudo SBOS/install.sh
#
# Una sola instrucción. SBOS instala todo automáticamente.
# ============================================================
set -euo pipefail

SBOS_GIT_URL="https://github.com/SISTEMASSKULL/SBOS.git"
SBOS_BRANCH="main"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC}  $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
die()  { echo -e "${RED}✗${NC}  $*" >&2; exit 1; }

# Detectar el directorio del repo — funciona con:
#   sudo SBOS/install.sh   (desde directorio padre)
#   sudo ./install.sh      (desde dentro del repo)
#   curl ... | sudo bash   (sin directorio — clona)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "/")"

# Si se ejecuta vía pipe (curl | bash) o no hay binario, clonar el repo
if [[ ! -f "$SCRIPT_DIR/BosAgent/src/dist/bos" ]]; then
    echo "SBOS: descargando repositorio..."
    WORK_DIR="$(mktemp -d)"
    git clone --depth=1 --branch "$SBOS_BRANCH" "$SBOS_GIT_URL" "$WORK_DIR"
    SCRIPT_DIR="$WORK_DIR"
fi

BOS_BIN="$SCRIPT_DIR/BosAgent/src/dist/bos"
BOSCTL_BIN="$SCRIPT_DIR/BosAgent/src/dist/bosctl"
CORE_DIR="$SCRIPT_DIR/BosAgent/src/dist/core"
SERVERS_DIR="$SCRIPT_DIR/servers"
DDL_DIR="$SCRIPT_DIR/DDLs"

# ── verificaciones ────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║        SBOS — Sistema Operativo Soberano             ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

[[ $EUID -eq 0 ]] || die "Ejecutar como root:  git clone https://github.com/SISTEMASSKULL/SBOS.git && sudo SBOS/install.sh"

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    [[ "$ID" == "ubuntu" ]] || die "SBOS requiere Ubuntu 24.04+ (detectado: $ID)"
    ok "Sistema operativo: Ubuntu $VERSION_ID"
fi

[[ -f "$BOS_BIN" ]]    || die "Binario bos no encontrado: $BOS_BIN"
[[ -f "$BOSCTL_BIN" ]] || die "Binario bosctl no encontrado: $BOSCTL_BIN"
ok "Binarios: bos + bosctl"

FICHA_COUNT=$(find "$SERVERS_DIR" -name "manifest.yml" ! -path "*/_descartadas/*" 2>/dev/null | wc -l)
[[ $FICHA_COUNT -gt 0 ]] || die "servers/ vacío"
ok "Fichas declarativas: $FICHA_COUNT aplicaciones"

# ── prerequisitos del SO ──────────────────────────────────────
echo ""
echo "Instalando prerequisitos..."
apt-get update -qq
apt-get install -y --no-install-recommends \
    git curl rsync ca-certificates apt-transport-https gnupg lsb-release \
    >/dev/null 2>&1
ok "Prerequisitos instalados"

# ── directorio de trabajo temporal ───────────────────────────
DEPLOY_DIR="$(mktemp -d /tmp/bos-deploy-XXXXXX)"
trap 'rm -rf "$DEPLOY_DIR"' EXIT

cp "$BOS_BIN"    "$DEPLOY_DIR/bos"
cp "$BOSCTL_BIN" "$DEPLOY_DIR/bosctl"
chmod 755 "$DEPLOY_DIR/bos" "$DEPLOY_DIR/bosctl"
[[ -d "$CORE_DIR"    ]] && cp -r "$CORE_DIR"    "$DEPLOY_DIR/core"
cp -r "$SERVERS_DIR"     "$DEPLOY_DIR/servers"
[[ -d "$DDL_DIR"     ]] && cp -r "$DDL_DIR"     "$DEPLOY_DIR/ddls"

# ── system-install ────────────────────────────────────────────
echo ""
echo "Instalando SBOS en el sistema..."
cd "$DEPLOY_DIR"
./bosctl system-install --mode=prod
ok "BOS instalado"

# ── configurar auto-sync de fichas desde git ──────────────────
# Al arrancar, BOS descarga automáticamente las fichas más recientes del repo
INSTALL_TOML="/etc/bos/bos-install.toml"
if [[ -f "$INSTALL_TOML" ]] && ! grep -q "servers_git_url" "$INSTALL_TOML"; then
    echo "" >> "$INSTALL_TOML"
    echo "# BOS sincroniza fichas automáticamente en cada arranque (pull-only, P5)" >> "$INSTALL_TOML"
    echo "servers_git_url = \"$SBOS_GIT_URL\"" >> "$INSTALL_TOML"
    ok "Auto-sync configurado: fichas se actualizan desde GitHub en cada arranque"
fi

# ── iniciar BOS ───────────────────────────────────────────────
echo ""
echo "Iniciando BOS..."
systemctl enable bos.service >/dev/null 2>&1 || true
systemctl start  bos.service

sleep 3
if systemctl is-active --quiet bos.service; then
    ok "bos.service activo"
else
    warn "bos.service no arrancó — revisar: journalctl -u bos.service -n 50"
fi

# ── resumen ───────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  SBOS instalado                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  BOS está instalando $FICHA_COUNT+ aplicaciones automáticamente."
echo "  No se requiere ninguna otra acción."
echo ""
echo "  Monitorear:  journalctl -u bos.service -f"
echo "  Estado:      bosctl status"
echo "  Fichas:      bosctl ficha list"
echo ""
echo "  Instalación completa: ~60 minutos (según hardware y red)."
echo ""
