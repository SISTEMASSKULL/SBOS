#!/usr/bin/env bash
# build.sh — Compila BOS y empaqueta sbos-bootstrap.zip listo para copiar al servidor.
#
# Uso:
#   bash build.sh
#
# Resultado:
#   sbos-bootstrap.zip  — copiar al servidor y ejecutar: unzip + bash install.sh
#
# Requisitos: go >= 1.22 en PATH (o GOBIN apuntando al binario correcto)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(dirname "$SCRIPT_DIR")/src"
ZIP="$SCRIPT_DIR/sbos-bootstrap.zip"

# Detectar go
GO_BIN="${GOBIN:-$(which go 2>/dev/null || echo /home/skull/go-dist/go/bin/go)}"
if [ ! -x "$GO_BIN" ]; then
    echo "ERROR: go no encontrado. Configura GOBIN o instala go." >&2
    exit 1
fi
GO_VER="$($GO_BIN version)"
echo "=== SBOS Build — $GO_VER ==="
echo ""

# ── 1. Compilar bos (daemon) ────────────────────────────────────────────────
echo "── 1/3  Compilando bos (daemon)..."
CGO_ENABLED=0 "$GO_BIN" build \
    -C "$SRC_DIR" \
    -ldflags="-s -w" \
    -o "$SCRIPT_DIR/bos" \
    ./cmd/bos/
echo "        bos → $(ls -lh "$SCRIPT_DIR/bos" | awk '{print $5}')"

# ── 2. Compilar bosctl (TUI + CLI) ──────────────────────────────────────────
echo "── 2/3  Compilando bosctl (TUI + CLI)..."
CGO_ENABLED=0 "$GO_BIN" build \
    -C "$SRC_DIR" \
    -ldflags="-s -w" \
    -o "$SCRIPT_DIR/bosctl" \
    ./cmd/bosctl/
echo "        bosctl → $(ls -lh "$SCRIPT_DIR/bosctl" | awk '{print $5}')"

# ── 3. Empaquetar sbos-bootstrap.zip ────────────────────────────────────────
echo "── 3/3  Empaquetando sbos-bootstrap.zip..."
rm -f "$ZIP"

# Archivos raíz del zip
ROOT_FILES=(
    bos
    bosctl
    install.sh
    bos.service
    bos-console.service
    bosagent-sudoers
    bos.toml
    bos-install.toml
)

cd "$SCRIPT_DIR"

# Binarios y archivos raíz
for f in "${ROOT_FILES[@]}"; do
    if [ -f "$f" ]; then
        zip -q "$ZIP" "$f"
        echo "        + $f"
    else
        echo "        ⚠ no encontrado: $f"
    fi
done

# core/ completo (scripts maestros + servers/)
if [ -d core ]; then
    zip -qr "$ZIP" core/
    N=$(find core/ -type f | wc -l)
    echo "        + core/  ($N archivos)"
fi

SIZE=$(du -sh "$ZIP" | awk '{print $1}')
echo ""
echo "=== Build completo ==="
echo "   ZIP: $ZIP  ($SIZE)"
echo ""
echo "── Deploy al servidor ──────────────────────────────────────────────────"
echo "   scp $ZIP root@<servidor>:/tmp/"
echo "   ssh root@<servidor>"
echo "   cd /tmp && unzip sbos-bootstrap.zip -d sbos && cd sbos && bash install.sh"
