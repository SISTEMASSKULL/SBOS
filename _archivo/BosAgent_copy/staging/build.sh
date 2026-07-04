#!/usr/bin/env bash
# build.sh — Compila BOS y construye sbos-bootstrap.zip
# Uso: bash build.sh
# Requiere: podman, python3
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== SBOS Build ==="
echo "Project: $PROJECT_DIR"
echo "Staging: $SCRIPT_DIR"

# ── 1. Compilar BOS ──────────────────────────────────────────────
echo ""
echo "── 1/3 Compilando BOS (golang:1.22)..."

podman run --rm \
    -v "$PROJECT_DIR:/src:Z" \
    -w /src/src \
    golang:1.22 sh -c 'CGO_ENABLED=0 go build -ldflags="-s -w" -o ../staging/bos ./cmd/bos/'

echo "   BOS binario: $(ls -lh "$SCRIPT_DIR/bos" | awk '{print $5}')"

# ── 2. Compilar bosctl ───────────────────────────────────────────
echo ""
echo "── 2/3 Compilando bosctl (golang:1.22)..."

podman run --rm \
    -v "$PROJECT_DIR:/src:Z" \
    -w /src/src \
    golang:1.22 sh -c 'CGO_ENABLED=0 go build -ldflags="-s -w" -o ../staging/bosctl ./cmd/bosctl/' 2>/dev/null || {
    echo "   bosctl: sin fuentes — creando stub"
    echo '#!/bin/sh
# bosctl — stub (sin fuentes Go compilables)
echo "bosctl: no buildable source found"
exit 1' > "$SCRIPT_DIR/bosctl"
    chmod +x "$SCRIPT_DIR/bosctl"
}

# ── 3. Construir sbos-bootstrap.zip ──────────────────────────────
echo ""
echo "── 3/3 Construyendo sbos-bootstrap.zip..."

export SCRIPT_DIR
python3 <<'PYEOF'
import zipfile, os, sys

staging = os.environ['SCRIPT_DIR']
zip_path = os.path.join(staging, 'sbos-bootstrap.zip')

with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as z:
    # Binarios
    for f in ['bos', 'bosctl']:
        fp = os.path.join(staging, f)
        if os.path.exists(fp):
            z.write(fp, f)
            print(f"  + {f}")

    # Config files
    for f in ['bos.toml', 'bos-install.toml']:
        fp = os.path.join(staging, f)
        if os.path.exists(fp):
            z.write(fp, f)
            print(f"  + {f}")

    # Core scripts (flat, sin subdirectorio core/)
    core = os.path.join(staging, 'core')
    for fname in sorted(os.listdir(core)):
        fp = os.path.join(core, fname)
        if os.path.isfile(fp) and not fname.startswith('.'):
            z.write(fp, fname)
            print(f"  + {fname}")

    # Servers (servers/... sin prefijo core/)
    servers_root = os.path.join(core, 'servers')
    file_count = 0
    for root, dirs, files in os.walk(servers_root):
        for fname in files:
            src = os.path.join(root, fname)
            arcname = os.path.relpath(src, core)
            z.write(src, arcname)
            file_count += 1
    print(f"  + servers/: {file_count} archivos")

size_mb = os.path.getsize(zip_path) / (1024 * 1024)
print(f"\n  ZIP creado: {zip_path} ({size_mb:.1f} MB)")
PYEOF

echo ""
echo "=== Build completo ==="
echo "  binario: $SCRIPT_DIR/bos"
echo "  zip:     $SCRIPT_DIR/sbos-bootstrap.zip"
