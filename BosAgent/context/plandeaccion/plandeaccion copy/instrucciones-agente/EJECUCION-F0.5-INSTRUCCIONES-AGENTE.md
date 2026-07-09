# INSTRUCCIONES DE EJECUCIÓN — Átomo F0.5
## Pipeline CI/CD con Race Detection
## Para: Agente ejecutor (Claude Code / desarrollador)

**Átomo:** F0.5  
**Requiere previo:** F0.1 (`_legacy/README.md` creado)  
**Duración estimada:** 15 minutos  
**Riesgo:** Bajo — solo agrega archivos nuevos, no modifica código existente  
**Reversión:** `git revert HEAD` elimina los archivos sin efectos secundarios

---

## CONTEXTO — Por qué este átomo existe

El proyecto BosAgent/SBOS tiene una race condition activa (P6/P14) entre
`observer` y `reconciler` que puede corromper el estado de fichas en producción.
Sin un pipeline CI/CD con race detection, esta race puede reintroducirse en
cualquier commit sin que nadie la detecte.

Este átomo instala la red de seguridad que protege todos los átomos siguientes.

---

## PRE-CONDICIONES — Verificar antes de empezar

```bash
# 1. Estás en la raíz del repositorio BosAgent/SBOS
pwd
# debe mostrar algo como: /opt/skull/.../BosAgent/src

# 2. El módulo Go es correcto
head -1 go.mod
# debe mostrar: module bos

# 3. Go 1.25 disponible
go version
# debe mostrar: go version go1.25.x ...

# 4. git está configurado y tienes acceso al remote
git remote -v
# debe mostrar la URL de GitHub del repo

# 5. El directorio .github NO existe aún (o si existe, NO tiene workflows/)
ls .github/ 2>/dev/null || echo "OK — .github no existe todavía"
```

Si alguna pre-condición falla, detener y reportar. No continuar.

---

## PASO 1 — Crear estructura de directorios

```bash
mkdir -p .github/workflows
mkdir -p scripts
mkdir -p docs/ci
```

**Verificar:**
```bash
[ -d .github/workflows ] && echo "✅ .github/workflows" || echo "❌ FALLO"
[ -d scripts ] && echo "✅ scripts" || echo "❌ FALLO"
[ -d docs/ci ] && echo "✅ docs/ci" || echo "❌ FALLO"
```

---

## PASO 2 — Crear `.github/workflows/ci.yml`

Crear el archivo con el siguiente contenido EXACTO
(fuente: anexos/F0.5-pipeline-cicd/ci.yml):

```bash
cat > .github/workflows/ci.yml << 'ENDOFFILE'
# ============================================================
# SBOS / BosAgent — Pipeline CI/CD
# Archivo: .github/workflows/ci.yml
#
# Triggers:
#   - push a main: ejecuta todos los checks, bloquea si fallan
#   - push a cualquier rama: ejecuta todos los checks
#
# Por qué NO usamos Pull Requests como gate:
#   El equipo hace commit directo a main. El pipeline actúa
#   como red de seguridad post-commit. Si algo falla, el
#   commit queda marcado con ❌ en el historial de GitHub
#   y el desarrollador recibe email inmediato.
#
# Para migrar a PR-based workflow en el futuro, cambiar:
#   on: push → on: [push, pull_request]
#   y activar "Branch protection rules" en Settings → Branches
# ============================================================

name: CI

on:
  push:
    branches: ["**"]
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  build:
    name: Build & Lint
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Go 1.25
        uses: actions/setup-go@v5
        with:
          go-version: '1.25'
          cache: true

      - name: Build
        run: go build ./...

      - name: Vet
        run: go vet ./...

      - name: Format check
        run: |
          UNFORMATTED=$(gofmt -l .)
          if [ -n "$UNFORMATTED" ]; then
            echo "❌ Los siguientes archivos necesitan gofmt:"
            echo "$UNFORMATTED"
            echo ""
            echo "Fix: gofmt -w ."
            exit 1
          fi
          echo "✅ Formato correcto"

  race:
    name: Race Detection (HARD GATE)
    runs-on: ubuntu-latest
    timeout-minutes: 20

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Go 1.25
        uses: actions/setup-go@v5
        with:
          go-version: '1.25'
          cache: true

      - name: Race detection
        env:
          GORACE: "halt_on_error=1 log_path=/tmp/race_log"
        run: |
          go test -race -count=10 -timeout=5m -coverprofile=coverage.out ./...
          echo "✅ Zero data races detectadas"

      - name: Upload coverage artifact
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: |
            coverage.out
            /tmp/race_log.*
          retention-days: 7

  coverage:
    name: Coverage (Warning Only)
    runs-on: ubuntu-latest
    needs: race
    if: always()
    timeout-minutes: 5

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Go 1.25
        uses: actions/setup-go@v5
        with:
          go-version: '1.25'
          cache: true

      - name: Download coverage artifact
        uses: actions/download-artifact@v4
        with:
          name: coverage-report
        continue-on-error: true

      - name: Coverage gate (WARNING)
        continue-on-error: true
        run: |
          if [ ! -f coverage.out ]; then
            echo "⚠️  No hay coverage.out disponible (posiblemente race falló)"
            exit 0
          fi

          THRESHOLD=60

          echo "## 📊 Reporte de Cobertura" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
          go tool cover -func=coverage.out | tee -a $GITHUB_STEP_SUMMARY
          echo "\`\`\`" >> $GITHUB_STEP_SUMMARY

          TOTAL=$(go tool cover -func=coverage.out | grep '^total:' | awk '{print $3}' | tr -d '%')

          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Total: ${TOTAL}% (threshold: ${THRESHOLD}%)**" >> $GITHUB_STEP_SUMMARY

          TOTAL_INT=${TOTAL%.*}
          if [ "$TOTAL_INT" -lt "$THRESHOLD" ]; then
            echo "⚠️  WARNING: Cobertura ${TOTAL}% bajo threshold ${THRESHOLD}%"
          else
            echo "✅ Cobertura ${TOTAL}% OK"
          fi

  summary:
    name: Pipeline Status
    runs-on: ubuntu-latest
    needs: [build, race, coverage]
    if: always()
    timeout-minutes: 2

    steps:
      - name: Check results
        run: |
          BUILD="${{ needs.build.result }}"
          RACE="${{ needs.race.result }}"
          COVERAGE="${{ needs.coverage.result }}"

          echo "## Pipeline Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Job | Resultado |" >> $GITHUB_STEP_SUMMARY
          echo "|-----|-----------|" >> $GITHUB_STEP_SUMMARY
          echo "| Build & Lint | $BUILD |" >> $GITHUB_STEP_SUMMARY
          echo "| Race Detection | $RACE |" >> $GITHUB_STEP_SUMMARY
          echo "| Coverage (warning) | $COVERAGE |" >> $GITHUB_STEP_SUMMARY

          if [ "$BUILD" != "success" ] || [ "$RACE" != "success" ]; then
            echo "❌ Pipeline FALLÓ — build: $BUILD, race: $RACE"
            exit 1
          fi

          echo "✅ Pipeline OK"
ENDOFFILE
```

**Verificar que el archivo se creó correctamente:**
```bash
[ -f .github/workflows/ci.yml ] && echo "✅ ci.yml creado"
grep "halt_on_error=1" .github/workflows/ci.yml && echo "✅ GORACE configurado"
grep "count=10" .github/workflows/ci.yml && echo "✅ count=10 presente"
grep "continue-on-error: true" .github/workflows/ci.yml && echo "✅ coverage es warning"
wc -l .github/workflows/ci.yml
echo "(debe ser ~150 líneas)"
```

---

## PASO 3 — Crear `scripts/validate.sh`

```bash
cat > scripts/validate.sh << 'ENDOFFILE'
#!/usr/bin/env bash
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

if ! command -v go &> /dev/null; then
  fail "Go no está instalado o no está en PATH"
fi

GO_VERSION=$(go version | awk '{print $3}')
echo -e "\n${BLUE}SBOS — Validación Local${NC}"
echo -e "Go: $GO_VERSION | Count: $COUNT | $(date)"
echo "════════════════════════════════════════"

START_TIME=$(date +%s)

if [ "$RACE_ONLY" = true ]; then
  step "Race detection (-count=$COUNT)"
  GORACE="halt_on_error=1 log_path=/tmp/race_log" \
    go test -race -count=$COUNT -timeout=5m ./...
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

GORACE="halt_on_error=1 log_path=/tmp/race_log" \
  go test -race -count=$COUNT -timeout=5m -coverprofile=/tmp/coverage.out ./...
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
  warn "Cobertura ${TOTAL}% bajo threshold 60% — WARNING (no bloquea push)"
else
  ok "Cobertura ${TOTAL}% OK"
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo "════════════════════════════════════════"
echo -e "${GREEN}✅ Todos los checks pasaron en ${ELAPSED}s${NC}"
echo "Listo para: git push"
ENDOFFILE

chmod +x scripts/validate.sh
```

**Verificar:**
```bash
[ -f scripts/validate.sh ] && echo "✅ validate.sh creado"
[ -x scripts/validate.sh ] && echo "✅ ejecutable"
head -3 scripts/validate.sh | grep "bash" && echo "✅ shebang correcto"
```

---

## PASO 4 — Crear `docs/ci/F0.5-activacion-branch-protection.md`

```bash
# Copiar desde anexos (el archivo ya existe en el proyecto)
# Si estás en el mismo sistema donde están los outputs:
cp /mnt/user-data/outputs/anexos/F0.5-pipeline-cicd/F0.5-activacion-branch-protection.md \
   docs/ci/F0.5-activacion-branch-protection.md

# Si no tienes acceso al path anterior, el contenido completo
# está en: anexos/F0.5-pipeline-cicd/F0.5-activacion-branch-protection.md
```

---

## PASO 5 — Verificación local antes del commit

```bash
# Verificar que la estructura es correcta
echo "=== Estructura de archivos ==="
find .github/ scripts/ docs/ci/ -type f | sort

echo ""
echo "=== Contenido crítico de ci.yml ==="
echo "GORACE:"
grep "halt_on_error" .github/workflows/ci.yml

echo "count:"
grep "\-count=" .github/workflows/ci.yml

echo "timeout:"
grep "\-timeout=" .github/workflows/ci.yml

echo "coverage warning:"
grep "continue-on-error" .github/workflows/ci.yml

echo ""
echo "=== Prueba rápida de validate.sh ==="
./scripts/validate.sh --fast
echo ""
echo "(si pasó: el entorno local está bien configurado)"
```

**Si `./scripts/validate.sh --fast` falla:**
- Error de compilación → hay código roto en el repo antes de este átomo. Reportar, no continuar.
- DATA RACE → la race P6/P14 ya está presente. Documentar el hallazgo. El átomo F1.5 la resuelve.
- Formato incorrecto → responder `s` para que validate.sh aplique gofmt automáticamente.

---

## PASO 6 — Commit y push

```bash
git add .github/workflows/ci.yml
git add scripts/validate.sh
git add docs/ci/F0.5-activacion-branch-protection.md

# Verificar qué se está commiteando
git status
git diff --cached --stat

# Commit con mensaje estructurado del plan
git commit -m "[F0.5] feat: pipeline CI/CD — race detection HARD GATE, cobertura warning

GAP 1 del BOS-REPAIR-PLAN-MAESTRO-v3 cerrado.

Archivos:
  .github/workflows/ci.yml        — 4 jobs: build, race (HARD GATE), coverage (warning), summary
  scripts/validate.sh             — validación local pre-commit, espejo exacto del CI
  docs/ci/F0.5-activacion-branch-protection.md — guía de branch protection en 3 fases

Configuración crítica:
  GORACE=halt_on_error=1          — proceso muere al primer DATA RACE
  -count=10 -timeout=5m           — detecta races intermitentes
  coverage: continue-on-error     — warning hasta que Fase 8 tenga tests completos

Informe de Cierre: INFORME-CIERRE-F0.5-CI-CD.md
Anexo: anexos/F0.5-pipeline-cicd/"

git push origin main
```

---

## PASO 7 — Verificar que el pipeline corrió en GitHub

```
1. Abrir: https://github.com/<ORG>/BosAgent/actions
   (reemplazar <ORG> con la organización de SKULL)

2. Debe aparecer el workflow "CI" con el commit "[F0.5] feat: pipeline CI/CD..."

3. Esperar a que completen los 4 jobs. Resultado esperado:
   ✅ Build & Lint       — build + vet + format: verde
   ✅ Race Detection     — -race -count=10: verde (cero races en código actual)
   ⚠️  Coverage (Warning) — posiblemente amarillo (sin tests en cmd/ aún)
   ✅ Pipeline Status    — verde si build y race pasaron

4. Si algún job falla:
   - Build falla → hay un error de compilación en el repo. Revisar el log.
   - Race falla con DATA RACE → la race P6/P14 está activa. Ver átomo F1.5.
   - Race falla con timeout → reducir -count=10 a -count=5 temporalmente.
```

---

## PASO 8 — Actualizar `_legacy/README.md`

Agregar esta entrada a la tabla del índice en `_legacy/README.md`:

```markdown
| No aplica (nuevo) | F0.5 | Infraestructura CI/CD | 2026-06-07 | No existía pipeline — sin esto las races como P6/P14 podían reintroducirse en cualquier commit sin detección | INFORME-CIERRE-F0.5-CI-CD.md |
```

---

## CRITERIO DE ÉXITO — El átomo F0.5 está COMPLETO cuando:

```bash
# Todos estos deben ser verdad:
[ -f .github/workflows/ci.yml ] && echo "✅ ci.yml existe"
[ -f scripts/validate.sh ] && echo "✅ validate.sh existe"
[ -x scripts/validate.sh ] && echo "✅ validate.sh ejecutable"
grep -q "halt_on_error=1" .github/workflows/ci.yml && echo "✅ GORACE configurado"
grep -q "count=10" .github/workflows/ci.yml && echo "✅ count=10"

# Y en GitHub Actions:
echo "✅ Pipeline 'CI' corrió y build + race están verdes"
echo "   URL: https://github.com/<ORG>/BosAgent/actions"
```

**Cuando todos estén verdes:** marcar F0.5 como ✅ en el registro de estado del plan maestro.

---

## SEÑAL DE RETOMA

Si el trabajo fue interrumpido, verificar con:

```bash
# ¿Dónde quedó?
[ -f .github/workflows/ci.yml ] && echo "Paso 2 completo" || echo "Empezar en Paso 1"
[ -f scripts/validate.sh ] && echo "Paso 3 completo"
git log --oneline -3 | grep "F0.5" && echo "Commit hecho — verificar GitHub Actions"
```

---

*Instrucciones de ejecución F0.5 · BOS-REPAIR · SKULL · SBOS · 07 de Junio 2026*  
*Fuente: INFORME-CIERRE-F0.5-CI-CD.md + anexos/F0.5-pipeline-cicd/*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
