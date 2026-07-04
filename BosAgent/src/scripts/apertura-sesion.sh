#!/bin/bash
# =============================================================================
# apertura-sesion.sh — Ritual de apertura de sesión BOS-REPAIR
# Ejecutar: bash apertura-sesion.sh
# Desde: cualquier directorio — las rutas están hardcodeadas
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

PLAN_DIR="/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bos/plandeaccion/plandeaccion"
CODE_SRC="/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src"
CODE_ROOT="/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   APERTURA DE SESIÓN — BOS-REPAIR        ║${RESET}"
echo -e "${BOLD}║   $(date '+%Y-%m-%d %H:%M')                    ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"

# ─── PASO 1: NOVEDADES ───────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}1. ÚLTIMAS NOVEDADES (SESION-LOG)${RESET}"
if [ -f "$PLAN_DIR/SESION-LOG.md" ]; then
    tail -50 "$PLAN_DIR/SESION-LOG.md"
else
    echo -e "  ${YELLOW}⚠️  SESION-LOG.md no existe — primera sesión${RESET}"
    echo -e "  Ejecutar F0.0 (snapshot) antes de cualquier otro átomo"
fi

# ─── PASO 2: ÁTOMO EN PROGRESO ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}2. ÁTOMO EN PROGRESO${RESET}"
if grep -q "🟡" "$PLAN_DIR/REGISTRO-ESTADO.md" 2>/dev/null; then
    echo -e "  ${YELLOW}🟡 RETOMAR:${RESET}"
    grep "🟡" "$PLAN_DIR/REGISTRO-ESTADO.md" | head -3
else
    echo -e "  ${GREEN}✅ Ninguno en progreso${RESET}"
    echo -e "  Próximo disponible:"
    grep "🔴" "$PLAN_DIR/REGISTRO-ESTADO.md" 2>/dev/null | head -1 || echo "  (revisar REGISTRO-ESTADO.md)"
fi

# ─── PASO 3: BUILD ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}3. BUILD${RESET}"
cd "$CODE_SRC" 2>/dev/null || { echo -e "  ${RED}❌ No se puede acceder a $CODE_SRC${RESET}"; exit 1; }
if go build ./... 2>/dev/null; then
    echo -e "  ${GREEN}✅ BUILD LIMPIO${RESET}"
else
    echo -e "  ${RED}🔴 BUILD ROTO — resolver antes de cualquier átomo${RESET}"
fi

# ─── PASO 4: RACE DETECTOR ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}4. RACE DETECTOR (rápido — 2 runs)${RESET}"
RACE=$(go test -race -count=2 -timeout=60s ./... 2>&1)
if echo "$RACE" | grep -q "DATA RACE"; then
    echo -e "  ${RED}🔴 DATA RACE ACTIVA${RESET}"
    echo "$RACE" | grep -A3 "DATA RACE" | head -6 | sed 's/^/  /'
else
    echo -e "  ${GREEN}✅ Sin DATA RACE${RESET}"
fi

# ─── PASO 5: SEÑAL DE RETOMA ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}5. SEÑAL DE RETOMA${RESET}"
echo -n "  F0.0 snapshot:  "; [ -d "$CODE_SRC/_snapshots" ] && echo -e "${GREEN}✅${RESET}" || echo -e "${RED}❌ EJECUTAR F0.0 PRIMERO${RESET}"
echo -n "  F0 doc.go:      "; [ -f "$CODE_SRC/internal/audit/doc.go" ] && echo -e "${GREEN}✅${RESET}" || echo -e "${RED}❌${RESET}"
echo -n "  F1 auditLog:    "; grep -q "func auditLog" "$CODE_SRC/cmd/bos/main.go" 2>/dev/null && echo -e "${RED}❌ pendiente${RESET}" || echo -e "${GREEN}✅${RESET}"
echo -n "  F2 gorilla:     "; grep -rq "gorilla/websocket" "$CODE_SRC/cmd/" 2>/dev/null && echo -e "${RED}❌ pendiente${RESET}" || echo -e "${GREEN}✅${RESET}"
echo -n "  F3 install_ui:  "; L=$(wc -l < "$CODE_SRC/cmd/bosctl/install_ui.go" 2>/dev/null || echo 9999); [ "$L" -gt 500 ] && echo -e "${RED}❌ ($L líneas)${RESET}" || echo -e "${GREEN}✅${RESET}"
echo -n "  F4 rbac_prov:   "; [ -f "$CODE_SRC/internal/security/rbac_provider.go" ] && echo -e "${RED}❌ existe${RESET}" || echo -e "${GREEN}✅${RESET}"
echo -n "  F5 ctx plane:   "; [ -f "$CODE_SRC/internal/context/service.go" ] && echo -e "${GREEN}✅${RESET}" || echo -e "${RED}❌${RESET}"
echo -n "  F9 operator:    "; [ -d "$CODE_SRC/internal/scaler" ] && echo -e "${GREEN}✅${RESET}" || echo -e "${RED}❌${RESET}"
echo -n "  F10 biaos:      "; [ -f "$CODE_SRC/internal/biaos/gateway.go" ] && echo -e "${GREEN}✅${RESET}" || echo -e "${RED}❌${RESET}"

# ─── PASO 6: INVENTARIO BOSAGENT/ RAÍZ (solo primera sesión) ─────────────────
if [ ! -d "$CODE_SRC/_snapshots" ]; then
    echo ""
    echo -e "${BOLD}6. INVENTARIO BosAgent/ RAÍZ (primera sesión)${RESET}"
    echo -e "  ${YELLOW}⚠️  F0.0 no ejecutado — explorar antes de empezar:${RESET}"
    echo -e "  ${CYAN}ls -la $CODE_ROOT/${RESET}"
    ls -la "$CODE_ROOT/" 2>/dev/null | sed 's/^/  /' || echo "  No accesible"
fi

# ─── PASO 7: ÚLTIMO COMMIT ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}7. ÚLTIMO COMMIT${RESET}"
git log --oneline -3 2>/dev/null | sed 's/^/  /' || echo "  No disponible"

echo ""
echo -e "${BOLD}──────────────────────────────────────────────${RESET}"
echo -e "${BOLD}APERTURA COMPLETA — registrar inicio en SESION-LOG.md${RESET}"
echo ""
