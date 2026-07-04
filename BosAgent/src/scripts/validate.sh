#!/usr/bin/env bash
# Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
# Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
# ============================================================
# scripts/validate.sh — Validación local pre-commit
# Ejecuta exactamente los mismos checks que el pipeline CI.
# Uso: ./scripts/validate.sh [--fast] [--race]
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FAST=false
RACE_ONLY=false
COUNT=10

for arg in "$@"; do
  case $arg in
    --fast)  FAST=true; COUNT=1 ;;
    --race)  RACE_ONLY=true ;;
    --help|-h)
      echo "Uso: $0 [--fast] [--race]"
      echo "  --fast   Usa -count=1 (más rápido, menos confiable para races)"
      echo "  --race   Solo ejecuta race detection"
      exit 0
      ;;
  esac
done

step() { echo -e "\n${BLUE}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }

# Buscar Go y exportar GOROOT/bin al PATH.
# CRÍTICO: go test -coverprofile lanza herramientas internas de Go (covdata, etc.)
# que requieren que $GOROOT/bin esté en PATH — no basta con tener el binario accesible.
GO_BIN=""
if command -v go &> /dev/null; then
  GO_BIN=$(command -v go)
else
  for p in /home/skull/go-dist/go/bin/go /usr/local/go/bin/go /usr/bin/go; do
    if [ -x "$p" ]; then
      GO_BIN=$p
      break
    fi
  done
fi

if [ -z "$GO_BIN" ]; then
  fail "Go no está instalado (buscado en: PATH, /home/skull/go-dist/go/bin, /usr/local/go/bin)"
fi

# Exportar $GOROOT/bin para que los subprocesos de `go test` encuentren covdata y otros tools
GOROOT_BIN="$("$GO_BIN" env GOROOT)/bin"
export PATH="$GOROOT_BIN:$PATH"

GO_VERSION=$(go version | awk '{print $3}')
echo -e "\n${BLUE}SBOS — Validación Local${NC}"
echo -e "Go: $GO_VERSION | Count: $COUNT | $(date)"
echo "════════════════════════════════════════"

START_TIME=$(date +%s)

if [ "$RACE_ONLY" = true ]; then
  step "Race detection (-count=$COUNT)"
  GORACE="halt_on_error=1 log_path=/tmp/race_log" \
    go test -race -count=$COUNT -timeout=5m ./internal/...
  ok "Zero data races"
  exit 0
fi

step "Build"
go build ./... && ok "Build OK"

step "Vet"
go vet ./... && ok "Vet OK"

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

step "Race detection (GORACE=halt_on_error=1, -count=$COUNT)"
[ "$FAST" = true ] && warn "Modo --fast: -count=1. Races intermitentes pueden no detectarse."

# ./internal/... contiene toda la lógica — las races activas están aquí.
# Los cmd/ son entry points sin tests unitarios (no generan coverprofile válido).
GORACE="halt_on_error=1 log_path=/tmp/race_log" \
  go test -race -count=$COUNT -timeout=5m -coverprofile=/tmp/coverage.out ./internal/...
ok "Zero data races"

step "Coverage (threshold: 60% — warning only)"
TOTAL=$(go tool cover -func=/tmp/coverage.out | grep '^total:' | awk '{print $3}' | tr -d '%')
TOTAL_INT=${TOTAL%.*}

echo "Cobertura total: ${TOTAL}%"

go tool cover -func=/tmp/coverage.out | grep -v '^total:' | while IFS= read -r line; do
  PKG=$(echo "$line" | awk '{print $1}')
  PCT=$(echo "$line" | awk '{print $3}' | tr -d '%')
  PCT_INT=${PCT%.*}
  if [ "$PCT_INT" -lt 60 ]; then
    warn "  $PKG: ${PCT}%"
  fi
done

if [ "$TOTAL_INT" -lt 60 ]; then
  warn "Cobertura ${TOTAL}% bajo threshold 60% — WARNING (no bloquea push, corregir en Fase 8)"
else
  ok "Cobertura ${TOTAL}% OK"
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo "════════════════════════════════════════"
echo -e "${GREEN}✅ Todos los checks pasaron en ${ELAPSED}s${NC}"
echo "Listo para: git push"
