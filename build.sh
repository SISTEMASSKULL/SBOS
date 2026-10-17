#!/usr/bin/env bash
# build.sh — Compila los binarios de BOS y los coloca en BosAgent/src/dist/
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/BosAgent/src" && pwd)"
GO="${GO_BIN:-/home/skull/sdk/go/bin/go}"
echo "Compilando BOS desde $SRC..."
export CGO_ENABLED=0
cd "$SRC"
"$GO" build -o dist/bos    ./cmd/bos/   && echo "✓ dist/bos    ($(du -sh dist/bos    | cut -f1))"
"$GO" build -o dist/bosctl ./cmd/bosctl/ && echo "✓ dist/bosctl ($(du -sh dist/bosctl | cut -f1))"
echo ""
echo "Binarios listos en BosAgent/src/dist/"
