#!/bin/bash
# Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
# Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
# =============================================================================
# BOS-REPAIR-VERIFICAR-CONTINUIDAD.sh
# Verifica que el repositorio está en estado consistente para retomar trabajo
# Uso: bash BOS-REPAIR-VERIFICAR-CONTINUIDAD.sh
# Retorna: 0 si todo está OK, 1 si hay problemas que bloquean el trabajo
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# Detectar Go — buscar en ubicaciones conocidas si no está en PATH
if ! command -v go &>/dev/null; then
    for _godir in /home/skull/go-dist/go/bin /usr/local/go/bin /usr/local/bin /usr/bin; do
        [ -x "$_godir/go" ] && { export PATH="$PATH:$_godir"; break; }
    done
fi

PLAN_DIR="/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bos/plandeaccion/plandeaccion"
BLOQUEANTES=0
ADVERTENCIAS=0

echo ""
echo -e "${BOLD}BOS-REPAIR — VERIFICACIÓN DE CONTINUIDAD${RESET}"
echo -e "$(date '+%Y-%m-%d %H:%M') · $REPO_ROOT"
echo "══════════════════════════════════════════"

ok()   { echo -e "  ${GREEN}✅${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠️ ${RESET} $1"; ADVERTENCIAS=$((ADVERTENCIAS+1)); }
fail() { echo -e "  ${RED}🔴${RESET} $1"; BLOQUEANTES=$((BLOQUEANTES+1)); }

# ─── BLOQUE 1: INTEGRIDAD DEL REPOSITORIO ────────────────────────────────────
echo ""
echo -e "${BOLD}1. INTEGRIDAD DEL REPOSITORIO${RESET}"

# ¿Estamos en el repositorio correcto?
MODULE=$(head -1 go.mod 2>/dev/null | grep -o "module .*" | cut -d' ' -f2)
if [ "$MODULE" = "bos" ]; then
    ok "Módulo Go: $MODULE (correcto)"
else
    fail "Módulo Go incorrecto: '$MODULE' (se esperaba 'bos')"
fi

# Build limpio
if go build ./... 2>/dev/null; then
    ok "go build ./... — limpio"
else
    fail "go build ./... — ROTO. Resolver antes de continuar."
fi

# No hay cambios sin commit que no sean intencionales
WIP_COUNT=$(git status --short 2>/dev/null | grep -v "^?" | wc -l | tr -d ' ')
if [ "$WIP_COUNT" -eq 0 ]; then
    ok "Sin cambios sin commit"
elif [ "$WIP_COUNT" -le 3 ]; then
    warn "$WIP_COUNT archivo(s) modificados sin commit — verificar si son WIP intencional"
    git status --short | grep -v "^?" | head -5 | sed 's/^/     /'
else
    warn "$WIP_COUNT archivos sin commit — posible sesión interrumpida"
    git status --short | grep -v "^?" | head -10 | sed 's/^/     /'
fi

# ─── BLOQUE 2: CONSISTENCIA CON EL REGISTRO-ESTADO ───────────────────────────
echo ""
echo -e "${BOLD}2. CONSISTENCIA CÓDIGO ↔ REGISTRO-ESTADO${RESET}"

REGISTRO="$PLAN_DIR/REGISTRO-ESTADO.md"
if [ ! -f "$REGISTRO" ]; then
    fail "REGISTRO-ESTADO.md no encontrado en $PLAN_DIR"
else
    ok "REGISTRO-ESTADO.md presente"

    # Verificar que el estado del código coincide con el registro
    # F0 — si doc.go existe, F0 debería ser ✅
    F0_REAL=$([ -f internal/audit/doc.go ] && echo "completo" || echo "pendiente")
    F0_REG=$(grep "F0.1" "$REGISTRO" | grep -o "✅\|🔴\|🟡" | head -1)
    if [ "$F0_REAL" = "completo" ] && [ "$F0_REG" = "🔴" ]; then
        warn "F0 parece completo en código pero REGISTRO-ESTADO dice 🔴 — actualizar"
    elif [ "$F0_REAL" = "pendiente" ] && [ "$F0_REG" = "✅" ]; then
        warn "F0 marcado ✅ en REGISTRO pero doc.go no existe — inconsistencia"
    else
        ok "F0: código y registro consistentes ($F0_REAL)"
    fi

    # F1 — auditLog
    F1_REAL=$(grep -q "func auditLog" cmd/bos/main.go 2>/dev/null && echo "pendiente" || echo "completo")
    F1_REG=$(grep "F1.1" "$REGISTRO" | grep -o "✅\|🔴\|🟡" | head -1)
    if [ "$F1_REAL" = "completo" ] && [ "$F1_REG" = "🔴" ]; then
        warn "F1.1 parece completo en código pero REGISTRO dice 🔴"
    else
        ok "F1: código y registro consistentes ($F1_REAL)"
    fi

    # Detectar átomo EN PROGRESO sin señal de retoma en el código
    EN_PROG=$(grep "🟡" "$REGISTRO" | awk -F'|' '{print $2}' | tr -d ' ' | head -3)
    if [ -n "$EN_PROG" ]; then
        warn "Átomo(s) EN PROGRESO detectados: $EN_PROG"
        echo "     → Leer SESION-LOG.md para saber dónde continuar"
    fi
fi

# ─── BLOQUE 3: CONTINUIDAD DEL SESION-LOG ────────────────────────────────────
echo ""
echo -e "${BOLD}3. CONTINUIDAD DEL SESION-LOG${RESET}"

SESSION_LOG="$PLAN_DIR/SESION-LOG.md"
if [ ! -f "$SESSION_LOG" ]; then
    warn "SESION-LOG.md no existe — crear antes de la primera sesión real"
else
    ok "SESION-LOG.md presente"

    # ¿Hay una sesión abierta sin cierre?
    LAST_APERTURA=$(grep -c "### Apertura" "$SESSION_LOG" 2>/dev/null || echo 0)
    LAST_CIERRE=$(grep -c "### Cierre" "$SESSION_LOG" 2>/dev/null || echo 0)
    if [ "$LAST_APERTURA" -gt "$LAST_CIERRE" ]; then
        warn "Sesión abierta sin cierre detectada ($LAST_APERTURA aperturas, $LAST_CIERRE cierres)"
        echo "     → Revisar el log y cerrar la sesión anterior antes de abrir una nueva"
    else
        ok "Todas las sesiones tienen apertura y cierre ($LAST_APERTURA sesiones)"
    fi

    # Mostrar la nota de la última sesión
    LAST_NOTA=$(grep "Notas críticas" "$SESSION_LOG" | tail -1 | cut -d: -f2- | tr -d ' ')
    if [ -n "$LAST_NOTA" ] && [ "$LAST_NOTA" != "ninguna" ]; then
        warn "Nota de la última sesión: $LAST_NOTA"
    fi
fi

# ─── BLOQUE 4: RACE DETECTOR ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}4. RACE DETECTOR (rápido — 2 runs)${RESET}"

RACE_OUT=$(go test -race -count=2 -timeout=90s ./... 2>&1)
if echo "$RACE_OUT" | grep -q "DATA RACE"; then
    fail "DATA RACE detectada"
    echo "$RACE_OUT" | grep -A 5 "DATA RACE" | head -10 | sed 's/^/     /'
    echo "     → Ver RB-02-DATA-RACE-DETECTADA.md para protocolo de resolución"
else
    ok "Sin DATA RACE en 2 runs"
fi

# ─── BLOQUE 5: INFRAESTRUCTURA DEL PLAN ──────────────────────────────────────
echo ""
echo -e "${BOLD}5. INFRAESTRUCTURA DEL PLAN${RESET}"

[ -f "$PLAN_DIR/MAPA-NAVEGACION.md" ] \
    && ok "MAPA-NAVEGACION.md" \
    || fail "MAPA-NAVEGACION.md no encontrado en $PLAN_DIR"

[ -f "$PLAN_DIR/BOS-REPAIR-PLAN-MAESTRO-v3.md" ] \
    && ok "BOS-REPAIR-PLAN-MAESTRO-v3.md" \
    || fail "BOS-REPAIR-PLAN-MAESTRO-v3.md no encontrado"

[ -f "$PLAN_DIR/PROTOCOLO-SESION-AGENTE.md" ] \
    && ok "PROTOCOLO-SESION-AGENTE.md" \
    || warn "PROTOCOLO-SESION-AGENTE.md no encontrado — agregar a plandeaccion/plandeaccion/"

[ -f "$PLAN_DIR/GESTION-RIESGOS-OPERATIVOS.md" ] \
    && ok "GESTION-RIESGOS-OPERATIVOS.md" \
    || warn "GESTION-RIESGOS-OPERATIVOS.md no encontrado — agregar a plandeaccion/plandeaccion/"

[ -f ".github/workflows/ci.yml" ] \
    && ok "Pipeline CI/CD (.github/workflows/ci.yml)" \
    || warn "ci.yml no encontrado — F0.5 pendiente"

# ─── RESUMEN FINAL ────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
echo -e "${BOLD}RESUMEN${RESET}"
if [ "$BLOQUEANTES" -eq 0 ] && [ "$ADVERTENCIAS" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✅ TODO OK — repositorio en estado consistente${RESET}"
    echo -e "  ${GREEN}Listo para abrir sesión y ejecutar el próximo átomo${RESET}"
    exit 0
elif [ "$BLOQUEANTES" -eq 0 ]; then
    echo -e "  ${YELLOW}${BOLD}⚠️  $ADVERTENCIAS advertencia(s) — revisar antes de continuar${RESET}"
    echo -e "  ${YELLOW}El trabajo puede continuar pero verificar los puntos marcados${RESET}"
    exit 0
else
    echo -e "  ${RED}${BOLD}🔴 $BLOQUEANTES problema(s) bloqueante(s) + $ADVERTENCIAS advertencia(s)${RESET}"
    echo -e "  ${RED}Resolver los bloqueantes antes de ejecutar cualquier átomo${RESET}"
    exit 1
fi
