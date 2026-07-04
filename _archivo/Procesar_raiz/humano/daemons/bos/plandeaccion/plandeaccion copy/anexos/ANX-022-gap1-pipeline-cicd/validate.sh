#!/usr/bin/env bash
# Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
# Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
# ============================================================
# scripts/validate.sh — Validación local pre-commit
#
# Ejecuta exactamente los mismos checks que el pipeline CI.
# Usar antes de cada `git push` para evitar sorpresas.
#
# Uso:
#   ./scripts/validate.sh          # todos los checks
#   ./scripts/validate.sh --fast   # sin -count=10 (más rápido)
#   ./scripts/validate.sh --race   # solo race detection
#
# Por qué existe:
#   El CI corre post-push. Este script permite detectar
#   races y problemas ANTES de que el commit llegue al repo.
#   El feedback loop es segundos vs minutos.
# ============================================================

set -euo pipefail

# ── Colores ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ── Flags ──────────────────────────────────────────────────
FAST=false
RACE_ONLY=false
COUNT=10

for arg in "$@"; do
  case $arg in
    --fast)   FAST=true; COUNT=1 ;;
    --race)   RACE_ONLY=true ;;
    --help|-h)
      echo "Uso: $0 [--fast] [--race]"
      echo "  --fast   Usa -count=1 en vez de -count=10 (más rápido, menos confiable)"
      echo "  --race   Solo ejecuta race detection"
      exit 0
      ;;
  esac
done

# ── Helpers ────────────────────────────────────────────────
step() { echo -e "\n${BLUE}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }

# ── Verificar Go disponible ────────────────────────────────
if ! command -v go &> /dev/null; then
  fail "Go no está instalado o no está en PATH"
fi

GO_VERSION=$(go version | awk '{print $3}')
echo -e "\n${BLUE}SBOS — Validación Local${NC}"
echo -e "Go: $GO_VERSION | Count: $COUNT | $(date)"
echo "════════════════════════════════════════"

START_TIME=$(date +%s)

# ── RACE ONLY mode ─────────────────────────────────────────
if [ "$RACE_ONLY" = true ]; then
  step "Race detection (-count=$COUNT)"
  GORACE="halt_on_error=1 log_path=/tmp/race_log" \
    go test -race -count=$COUNT -timeout=5m ./...
  ok "Zero data races"
  exit 0
fi

# ── CHECK 1: Build ─────────────────────────────────────────
step "Build"
go build ./... && ok "Build OK"

# ── CHECK 2: Vet ───────────────────────────────────────────
step "Vet"
go vet ./... && ok "Vet OK"

# ── CHECK 3: Format ────────────────────────────────────────
step "Format (gofmt)"
UNFORMATTED=$(gofmt -l .)
if [ -n "$UNFORMATTED" ]; then
  echo "Archivos sin formatear:"
  echo "$UNFORMATTED"
  echo ""
  read -r -p "¿Aplicar gofmt automáticamente? [s/N] " response
  if [[ "$response" =~ ^[sS]$ ]]; then
    gofmt -w .
    ok "Formato aplicado"
  else
    fail "Formato incorrecto — ejecuta: gofmt -w ."
  fi
else
  ok "Formato correcto"
fi

# ── CHECK 4: Race detection ────────────────────────────────
step "Race detection (GORACE=halt_on_error=1, -count=$COUNT)"
if [ "$FAST" = true ]; then
  warn "Modo --fast: usando -count=1. Las races intermitentes pueden no detectarse."
fi

GORACE="halt_on_error=1 log_path=/tmp/race_log" \
  go test -race -count=$COUNT -timeout=5m -coverprofile=/tmp/coverage.out ./...
ok "Zero data races"

# ── CHECK 5: Coverage (warning) ────────────────────────────
step "Coverage (threshold: 60% — warning only)"
TOTAL=$(go tool cover -func=/tmp/coverage.out | grep '^total:' | awk '{print $3}' | tr -d '%')

echo "Cobertura total: ${TOTAL}%"

# Muestra paquetes bajo threshold
go tool cover -func=/tmp/coverage.out | grep -v '^total:' | while IFS= read -r line; do
  PKG=$(echo "$line" | awk '{print $1}')
  PCT=$(echo "$line" | awk '{print $3}' | tr -d '%')
  if (( $(echo "$PCT < 60" | bc -l) )); then
    warn "  $PKG: ${PCT}%"
  fi
done

if (( $(echo "$TOTAL < 60" | bc -l) )); then
  warn "Cobertura ${TOTAL}% bajo threshold 60% — WARNING (no bloquea push)"
else
  ok "Cobertura ${TOTAL}% OK"
fi

# ── Resumen ────────────────────────────────────────────────
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo "════════════════════════════════════════"
echo -e "${GREEN}✅ Todos los checks pasaron en ${ELAPSED}s${NC}"
echo "Listo para: git push"
