#!/bin/bash
# =============================================================================
# cierre-sesion.sh — Ritual de cierre de sesión BOS-REPAIR
# Uso: bash cierre-sesion.sh F1.5 completo
#      bash cierre-sesion.sh F3.2 progreso
#      bash cierre-sesion.sh F4.4 bloqueado
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ATOMO="${1:-UNKNOWN}"
ESTADO="${2:-progreso}"  # completo | progreso | bloqueado

PLAN_DIR="/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bos/plandeaccion/plandeaccion"
CODE_SRC="/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   CIERRE DE SESIÓN — BOS-REPAIR          ║${RESET}"
echo -e "${BOLD}║   Átomo: $ATOMO | Estado: $ESTADO${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"

cd "$CODE_SRC" 2>/dev/null || { echo -e "${RED}❌ No se puede acceder a $CODE_SRC${RESET}"; exit 1; }

# ─── DOD UNIVERSAL ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}DOD UNIVERSAL${RESET}"
go build ./... && echo -e "  ${GREEN}✅ BUILD${RESET}"  || echo -e "  ${RED}❌ BUILD FALLA${RESET}"
go vet ./...   && echo -e "  ${GREEN}✅ VET${RESET}"    || echo -e "  ${RED}❌ VET FALLA${RESET}"
FMT=$(gofmt -l . | wc -l | tr -d ' ')
[ "$FMT" -eq 0 ] && echo -e "  ${GREEN}✅ FORMAT${RESET}" || echo -e "  ${YELLOW}⚠️  FORMAT — ejecutar: gofmt -w .${RESET}"
go test -race -count=10 ./... 2>&1 | tail -5
echo ""

# ─── CAMBIOS PENDIENTES ───────────────────────────────────────────────────────
echo -e "${BOLD}CAMBIOS SIN COMMIT${RESET}"
git status --short | sed 's/^/  /' || echo "  Ninguno"

# ─── CHECKLIST ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}CHECKLIST DE CIERRE${RESET}"
echo -e "  ${CYAN}[ ]${RESET} Actualizar REGISTRO-ESTADO.md — marcar $ATOMO como $ESTADO"
if [ "$ESTADO" = "completo" ]; then
    echo -e "  ${CYAN}[ ]${RESET} Crear INFORME-CIERRE-$ATOMO.md en $PLAN_DIR/informes-cierre/"
fi
echo -e "  ${CYAN}[ ]${RESET} Commit semántico: git commit -m '[$ATOMO] tipo: descripcion'"
echo -e "  ${CYAN}[ ]${RESET} git push origin main"
echo -e "  ${CYAN}[ ]${RESET} Verificar pipeline en GitHub Actions"
echo -e "  ${CYAN}[ ]${RESET} Registrar cierre en $PLAN_DIR/SESION-LOG.md"
echo ""
echo -e "  ${YELLOW}Formato commit: [$ATOMO] tipo: descripcion_breve${RESET}"
echo -e "  ${YELLOW}Tipos: feat | fix | refactor | docs | chore | test${RESET}"

echo ""
echo -e "${BOLD}──────────────────────────────────────────────${RESET}"
echo -e "${BOLD}Sesión cerrada. Actualizar SESION-LOG.md antes de salir.${RESET}"
echo ""
