#!/bin/bash
# Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
# Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
# =============================================================================
# BOS-REPAIR-DASHBOARD.sh
# Dashboard de progreso del plan de reparación — ejecutar en VPS DEV
# Uso: bash BOS-REPAIR-DASHBOARD.sh
# Requiere: estar en la raíz del repositorio BOS_V8
# =============================================================================

# Colores
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# Detectar Go — buscar en ubicaciones conocidas si no está en PATH
if ! command -v go &>/dev/null; then
    for _godir in /home/skull/go-dist/go/bin /usr/local/go/bin /usr/local/bin /usr/bin; do
        [ -x "$_godir/go" ] && { export PATH="$PATH:$_godir"; break; }
    done
fi

PLAN_DIR="/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bos/plandeaccion/plandeaccion"
REGISTRO="$PLAN_DIR/REGISTRO-ESTADO.md"
SESSION_LOG="$PLAN_DIR/SESION-LOG.md"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║       BOS-REPAIR — DASHBOARD DE PROGRESO                 ║${RESET}"
echo -e "${BOLD}║       $(date '+%Y-%m-%d %H:%M')  ·  SKULL · SBOS             ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""

# ─── SECCIÓN 1: SALUD DEL REPOSITORIO ────────────────────────────────────────
echo -e "${BOLD}── SALUD DEL REPOSITORIO ──────────────────────────────────${RESET}"

# Build
if go build ./... 2>/dev/null; then
    echo -e "  Build:        ${GREEN}✅ LIMPIO${RESET}"
else
    echo -e "  Build:        ${RED}🔴 ROTO — no ejecutar átomos${RESET}"
fi

# Race detector rápido (3 runs)
RACE_OUT=$(go test -race -count=3 -timeout=2m ./... 2>&1)
if echo "$RACE_OUT" | grep -q "DATA RACE"; then
    echo -e "  Race detector:${RED}🔴 DATA RACE ACTIVA${RESET}"
    echo -e "  ${RED}$(echo "$RACE_OUT" | grep -A2 "DATA RACE" | head -3)${RESET}"
else
    echo -e "  Race detector:${GREEN}✅ LIMPIO (3 runs)${RESET}"
fi

# Último commit
LAST_COMMIT=$(git log --oneline -1 2>/dev/null)
echo -e "  Último commit: ${CYAN}$LAST_COMMIT${RESET}"

# Cambios sin commit
UNCOMMITTED=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNCOMMITTED" -gt 0 ]; then
    echo -e "  Sin commit:   ${YELLOW}⚠️  $UNCOMMITTED archivo(s) modificados${RESET}"
else
    echo -e "  Sin commit:   ${GREEN}✅ Ninguno${RESET}"
fi
echo ""

# ─── SECCIÓN 2: PROGRESO POR FASE ────────────────────────────────────────────
echo -e "${BOLD}── PROGRESO POR FASE ──────────────────────────────────────${RESET}"

if [ ! -f "$REGISTRO" ]; then
    echo -e "  ${RED}❌ REGISTRO-ESTADO.md no encontrado en $PLAN_DIR${RESET}"
else
    # Contar estados por fase leyendo el REGISTRO-ESTADO.md
    declare -A TOTAL DONE INPROG BLOCKED

    while IFS= read -r line; do
        # Detectar qué fase estamos procesando
        if echo "$line" | grep -q "^## FASE"; then
            FASE=$(echo "$line" | grep -o "F[0-9]*" | head -1)
            [ -z "$TOTAL[$FASE]" ] && TOTAL[$FASE]=0
            [ -z "$DONE[$FASE]" ]  && DONE[$FASE]=0
            [ -z "$INPROG[$FASE]" ] && INPROG[$FASE]=0
            [ -z "$BLOCKED[$FASE]" ] && BLOCKED[$FASE]=0
        fi
        # Contar estados en la fase actual
        if echo "$line" | grep -qE "^\| F[0-9]"; then
            [ -n "$FASE" ] && TOTAL[$FASE]=$((${TOTAL[$FASE]:-0} + 1))
            if echo "$line" | grep -q "✅"; then
                DONE[$FASE]=$((${DONE[$FASE]:-0} + 1))
            elif echo "$line" | grep -q "🟡"; then
                INPROG[$FASE]=$((${INPROG[$FASE]:-0} + 1))
            elif echo "$line" | grep -q "⚠️"; then
                BLOCKED[$FASE]=$((${BLOCKED[$FASE]:-0} + 1))
            fi
        fi
    done < "$REGISTRO"

    # Mostrar progreso por fase con barra visual
    GRAND_TOTAL=0; GRAND_DONE=0

    for FASE in F0 F1 F2 F3 F4 F5 F6 F7 F8 F9 F10; do
        T=${TOTAL[$FASE]:-0}
        D=${DONE[$FASE]:-0}
        P=${INPROG[$FASE]:-0}
        B=${BLOCKED[$FASE]:-0}

        [ "$T" -eq 0 ] && continue

        GRAND_TOTAL=$((GRAND_TOTAL + T))
        GRAND_DONE=$((GRAND_DONE + D))

        # Barra de progreso (20 chars)
        PCTS=$((D * 20 / T))
        BAR=""
        for ((i=0; i<20; i++)); do
            [ $i -lt $PCTS ] && BAR="${BAR}█" || BAR="${BAR}░"
        done

        # Color según estado
        if [ "$D" -eq "$T" ]; then
            COLOR=$GREEN
        elif [ "$D" -gt 0 ] || [ "$P" -gt 0 ]; then
            COLOR=$YELLOW
        else
            COLOR=$RESET
        fi

        STATUS_EXTRA=""
        [ "$P" -gt 0 ] && STATUS_EXTRA=" ${YELLOW}[🟡 $P en progreso]${RESET}"
        [ "$B" -gt 0 ] && STATUS_EXTRA="$STATUS_EXTRA ${RED}[⚠️  $B bloqueados]${RESET}"

        printf "  ${COLOR}%-5s${RESET} [${COLOR}%s${RESET}] %2d/%2d${STATUS_EXTRA}\n" \
            "$FASE" "$BAR" "$D" "$T"
    done

    echo ""
    # Total global
    PCT_GLOBAL=$((GRAND_DONE * 100 / (GRAND_TOTAL == 0 ? 1 : GRAND_TOTAL)))
    BAR_TOTAL=""
    PCTS_TOTAL=$((GRAND_DONE * 30 / (GRAND_TOTAL == 0 ? 1 : GRAND_TOTAL)))
    for ((i=0; i<30; i++)); do
        [ $i -lt $PCTS_TOTAL ] && BAR_TOTAL="${BAR_TOTAL}█" || BAR_TOTAL="${BAR_TOTAL}░"
    done
    echo -e "  ${BOLD}TOTAL [${GREEN}${BAR_TOTAL}${RESET}${BOLD}] ${GRAND_DONE}/${GRAND_TOTAL} átomos (${PCT_GLOBAL}%)${RESET}"
fi
echo ""

# ─── SECCIÓN 3: ESTADO DE FASES (señal rápida) ───────────────────────────────
echo -e "${BOLD}── SEÑAL DE RETOMA (estado real del código) ───────────────${RESET}"

check() {
    local label="$1"; local ok="$2"
    if eval "$ok" 2>/dev/null; then
        echo -e "  ${GREEN}✅${RESET} $label"
    else
        echo -e "  ${RED}❌${RESET} $label"
    fi
}

check "F0 — paquetes doc.go" "[ -f internal/audit/doc.go ]"
check "F1 — auditLog extraído" "! grep -q 'func auditLog' cmd/bos/main.go"
check "F2 — gorilla eliminado" "! grep -rq 'gorilla/websocket' cmd/"
check "F3 — install_ui.go ≤500 líneas" "[ \$(wc -l < cmd/bosctl/install_ui.go 2>/dev/null || echo 9999) -le 500 ]"
check "F4 — rbac_provider eliminado" "[ ! -f internal/security/rbac_provider.go ]"
check "F5 — context plane impl." "[ -f internal/context/service.go ]"
check "F6 — sagas consulta" "grep -q 'bos.query.system' internal/server/jsonrpc.go"
check "F7.8 — runbooks" "[ -f docs/runbooks/RB-01-FICHA-DEGRADADA.md ]"
check "F9 — operator soberano" "[ -d internal/scaler ]"
check "F10 — biaos gateway" "[ -f internal/biaos/gateway.go ]"
check "CI/CD pipeline" "[ -f .github/workflows/ci.yml ]"
check "SESION-LOG presente" "[ -f plandeaccion/plandeaccion/SESION-LOG.md ]"
echo ""

# ─── SECCIÓN 4: ÚLTIMA SESIÓN ────────────────────────────────────────────────
echo -e "${BOLD}── ÚLTIMA SESIÓN ──────────────────────────────────────────${RESET}"
if [ -f "$SESSION_LOG" ]; then
    # Mostrar la última entrada de sesión
    LAST_SESSION=$(grep -n "^## SESIÓN" "$SESSION_LOG" | tail -1)
    if [ -n "$LAST_SESSION" ]; then
        LINE_NUM=$(echo "$LAST_SESSION" | cut -d: -f1)
        echo -e "  ${CYAN}$(tail -n +$LINE_NUM "$SESSION_LOG" | head -20)${RESET}"
    else
        echo -e "  ${YELLOW}⚠️  Sin sesiones registradas aún${RESET}"
    fi
else
    echo -e "  ${YELLOW}⚠️  SESION-LOG.md no encontrado — primera sesión${RESET}"
fi
echo ""

# ─── SECCIÓN 5: PRÓXIMO ÁTOMO ────────────────────────────────────────────────
echo -e "${BOLD}── PRÓXIMO ÁTOMO RECOMENDADO ──────────────────────────────${RESET}"
if [ -f "$REGISTRO" ]; then
    # Buscar átomo EN PROGRESO primero
    EN_PROGRESO=$(grep "🟡" "$REGISTRO" | head -1 | awk -F'|' '{print $2, $3}' | tr -d ' ')
    if [ -n "$EN_PROGRESO" ]; then
        echo -e "  ${YELLOW}🟡 RETOMAR:${RESET} $EN_PROGRESO"
    else
        # Buscar primer átomo pendiente
        SIGUIENTE=$(grep "🔴" "$REGISTRO" | head -1 | awk -F'|' '{print $2, $3}' | tr -d ' ')
        echo -e "  ${CYAN}▶ SIGUIENTE:${RESET} $SIGUIENTE"
    fi
fi
echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════${RESET}"
echo ""
