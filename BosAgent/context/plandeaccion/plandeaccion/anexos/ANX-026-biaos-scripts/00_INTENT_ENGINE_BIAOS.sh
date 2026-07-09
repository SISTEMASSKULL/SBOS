#!/usr/bin/env bash
# Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
# Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
# ============================================================================
# 00_INTENT_ENGINE_BIAOS.sh — Motor Declarativo del Sistema de Intenciones
# Proyecto: SBOS — biaos (agente IA soberano del OS)
#
# ANÁLOGO a 00_YAML_ENGINE_SBOS.sh pero para intenciones en lenguaje natural.
#
# Diferencia fundamental:
#   00_YAML_ENGINE_SBOS.sh: despacha por nombre de tarea (string exacto)
#   00_INTENT_ENGINE_BIAOS.sh: despacha por SCORE DE SIMILITUD SEMÁNTICA
#
# El dispatch nunca usa el nombre de la acción directamente.
# Siempre pasa por biaos_match_action() que usa similitud coseno.
# Esto implementa BI-P8: match semántico, no nombre exacto.
#
# P7 análogo (BI-P7 Absorb/Execute/Release):
#   Absorb:  cargar la entrada del catálogo de la acción matched
#   Execute: ejecutar la fase del lifecycle correspondiente
#   Release: limpiar el contexto de la petición y registrar en audit log
#
# Requiere: yq (parseo YAML), jq (JSON), curl (llamadas RPC al daemon bos)
# Señales propias: __BIAOS__INTENT_START__ ... __BIAOS__INTENT_DONE__
# ============================================================================

set -euo pipefail

readonly BIAOS_INTENT_ENGINE_VERSION="1.0.0"

# ── Señales del protocolo biaos ───────────────────────────────────────────
# DIFERENTES a las señales __SBOS__* — no mezclar nunca
readonly __BIAOS__INTENT_START__="__BIAOS__INTENT_START__"
readonly __BIAOS__INTENT_DONE__="__BIAOS__INTENT_DONE__"
readonly __BIAOS__INTENT_FAIL__="__BIAOS__INTENT_FAIL__"
readonly __BIAOS__MATCH_START__="__BIAOS__MATCH_START__"
readonly __BIAOS__MATCH_OK__="__BIAOS__MATCH_OK__"
readonly __BIAOS__MATCH_NONE__="__BIAOS__MATCH_NONE__"
readonly __BIAOS__HITL_PRESENT__="__BIAOS__HITL_PRESENT__"
readonly __BIAOS__HITL_CONFIRMED__="__BIAOS__HITL_CONFIRMED__"
readonly __BIAOS__HITL_CANCELLED__="__BIAOS__HITL_CANCELLED__"
readonly __BIAOS__EXEC_START__="__BIAOS__EXEC_START__"
readonly __BIAOS__EXEC_OK__="__BIAOS__EXEC_OK__"
readonly __BIAOS__EXEC_FAIL__="__BIAOS__EXEC_FAIL__"
readonly __BIAOS__COMPENSATE_START__="__BIAOS__COMPENSATE_START__"
readonly __BIAOS__COMPENSATE_OK__="__BIAOS__COMPENSATE_OK__"
readonly __BIAOS__DOMAIN_DENIED__="__BIAOS__DOMAIN_DENIED__"

# ── Configuración ────────────────────────────────────────────────────────
readonly BIAOS_ARCHITECTURE_YML="${BIAOS_ARCHITECTURE_YML:-/etc/bos/ai/00_ARCHITECTURE_BIAOS.yml}"
readonly BIAOS_ACTION_CATALOG="${BIAOS_ACTION_CATALOG:-/etc/bos/ai/action_catalog.yml}"
readonly BIAOS_CATALOG_VECTORS="${BIAOS_CATALOG_VECTORS:-/var/lib/bos/ai/catalog-vectors.bin}"
readonly BIAOS_BOS_SOCKET="${BIAOS_BOS_SOCKET:-/run/bos/bos.sock}"
readonly BIAOS_AUDIT_LOG="${BIAOS_AUDIT_LOG:-/var/log/bos/ai-audit.log}"
readonly BIAOS_MIN_SCORE="${BIAOS_MIN_SCORE:-0.65}"   # score mínimo para considerar match válido
readonly BIAOS_TOP_N="${BIAOS_TOP_N:-3}"              # cuántas opciones presentar al operador

# ── Dependencias ─────────────────────────────────────────────────────────
if ! command -v yq &>/dev/null; then
    echo "FATAL: yq es requerido por 00_INTENT_ENGINE_BIAOS.sh"
    exit 99
fi
if ! command -v jq &>/dev/null; then
    echo "FATAL: jq es requerido por 00_INTENT_ENGINE_BIAOS.sh"
    exit 99
fi

# ═══════════════════════════════════════════════════════════════════
# Validación del schema de 00_ARCHITECTURE_BIAOS.yml
# Análogo a yaml_validate_schema() de 00_YAML_ENGINE_SBOS.sh
# ═══════════════════════════════════════════════════════════════════

biaos_validate_schema() {
    local arch_file="${1:-$BIAOS_ARCHITECTURE_YML}"

    if [[ ! -f "$arch_file" ]]; then
        echo "ERROR: Registro de arquitectura biaos no encontrado: $arch_file"
        return 1
    fi

    local errors=0

    for key in version principios lifecycle acciones signals; do
        if ! yq -e ".${key}" "$arch_file" &>/dev/null; then
            echo "ERROR: Clave requerida '${key}' no encontrada en $arch_file"
            errors=$((errors + 1))
        fi
    done

    # El lifecycle debe tener los 3 ciclos principales
    for ciclo in intent_read intent_write intent_destructive; do
        if ! yq -e ".lifecycle.${ciclo}" "$arch_file" &>/dev/null; then
            echo "ERROR: Lifecycle '${ciclo}' requerido no encontrado"
            errors=$((errors + 1))
        fi
    done

    if (( errors > 0 )); then
        echo "Validación de schema FALLÓ: $errors error(s)"
        return 1
    fi

    return 0
}

# ═══════════════════════════════════════════════════════════════════
# Verificación de principios (BI-P1..BI-P12)
# Análogo a yaml_check_principle() de 00_YAML_ENGINE_SBOS.sh
# ═══════════════════════════════════════════════════════════════════

biaos_check_principle() {
    local principle_id="$1"
    local arch_file="${2:-$BIAOS_ARCHITECTURE_YML}"

    local active
    active=$(yq ".principios.${principle_id}.activo" "$arch_file" 2>/dev/null)
    [[ "$active" == "true" ]]
}

biaos_enforce_principle() {
    local principle_id="$1"
    local arch_file="${2:-$BIAOS_ARCHITECTURE_YML}"

    local handler
    handler=$(yq ".principios.${principle_id}.enforce" "$arch_file" 2>/dev/null)

    if [[ -z "$handler" || "$handler" == "null" ]]; then
        echo "WARN: No hay función enforce para $principle_id"
        return 0
    fi

    if ! declare -f "$handler" &>/dev/null; then
        echo "ERROR: Función enforce '$handler' para $principle_id no está cargada"
        return 1
    fi

    "$handler"
}

# ═══════════════════════════════════════════════════════════════════
# Resolución del ciclo de lifecycle por categoría
# Análogo a yaml_get_lifecycle_phases() de 00_YAML_ENGINE_SBOS.sh
# ═══════════════════════════════════════════════════════════════════

biaos_get_lifecycle() {
    local categoria="$1"
    local arch_file="${2:-$BIAOS_ARCHITECTURE_YML}"

    local ciclo
    case "$categoria" in
        1) ciclo="intent_read" ;;
        2) ciclo="intent_write" ;;
        3) ciclo="intent_destructive" ;;
        *)
            echo "ERROR: Categoría desconocida: $categoria"
            return 1
            ;;
    esac

    yq ".lifecycle.${ciclo}[]" "$arch_file" 2>/dev/null
}

biaos_get_phase_handler() {
    local phase="$1"
    local arch_file="${2:-$BIAOS_ARCHITECTURE_YML}"

    yq ".lifecycle.phases.${phase}.handler" "$arch_file" 2>/dev/null
}

biaos_get_phase_timeout() {
    local phase="$1"
    local arch_file="${2:-$BIAOS_ARCHITECTURE_YML}"

    local timeout
    timeout=$(yq ".lifecycle.phases.${phase}.timeout_sec" "$arch_file" 2>/dev/null)
    echo "${timeout:-30}"
}

# ═══════════════════════════════════════════════════════════════════
# Dispatch de intenciones — EL NÚCLEO DEL MOTOR
#
# Diferencia CLAVE vs yaml_dispatch() de 00_YAML_ENGINE_SBOS.sh:
#   yaml_dispatch: recibe un task_name (string exacto) → busca en signals
#   biaos_dispatch: recibe un intent_text (lenguaje natural)
#                   → clasifica → busca por similitud semántica
#                   → ejecuta el lifecycle de la categoría encontrada
#
# BI-P7 Absorb/Execute/Release:
#   Absorb:  cargar la acción matched del catálogo
#   Execute: correr cada fase del lifecycle con su timeout
#   Release: limpiar ctx de la petición, registrar resultado en audit log
# ═══════════════════════════════════════════════════════════════════

biaos_dispatch() {
    local intent_text="$1"
    local ctx_id="${2:-}"
    local session_id="${3:-$(date +%s%N | md5sum | head -c 12)}"

    echo "${__BIAOS__INTENT_START__} session=${session_id}"

    # ── BI-P1: Verificar dominio ──────────────────────────────────
    if ! biaos_check_domain "$intent_text"; then
        echo "${__BIAOS__DOMAIN_DENIED__} session=${session_id}"
        biaos_derive_to_bcompass "$intent_text"
        return 1
    fi

    # ── Fase classify: determinar categoría preliminar ────────────
    local categoria
    categoria=$(biaos_classify_intent "$intent_text")

    # ── Fase match: similitud semántica sobre el catálogo ─────────
    echo "${__BIAOS__MATCH_START__} session=${session_id}"
    local match_result
    match_result=$(biaos_match_action "$intent_text" "$BIAOS_TOP_N")

    if [[ -z "$match_result" ]]; then
        echo "${__BIAOS__MATCH_NONE__} session=${session_id} intent='${intent_text}'"
        biaos_format_error_response "No encontré acciones relacionadas con tu petición en mi dominio."
        echo "${__BIAOS__INTENT_FAIL__} session=${session_id}"
        return 1
    fi
    echo "${__BIAOS__MATCH_OK__} session=${session_id}"

    # Extraer la acción con mayor score para el execute
    local action_id
    action_id=$(echo "$match_result" | jq -r '.[0].id')
    local action_categoria
    action_categoria=$(biaos_get_action_field "$action_id" "categoria")

    # ── BI-P7 Absorb: cargar la acción del catálogo ───────────────
    local action_entry
    action_entry=$(biaos_absorb_action "$action_id")

    # ── Ejecutar el lifecycle completo de la categoría ────────────
    local phases
    phases=$(biaos_get_lifecycle "$action_categoria")

    local rc=0
    while IFS= read -r phase; do
        [[ -z "$phase" ]] && continue

        local handler timeout_sec
        handler=$(biaos_get_phase_handler "$phase")
        timeout_sec=$(biaos_get_phase_timeout "$phase")

        # Saltar fases no aplicables (ej: hitl_confirm_2 en cat-2)
        if ! biaos_phase_applies "$phase" "$action_categoria"; then
            continue
        fi

        echo "${__BIAOS__EXEC_START__} phase=${phase} session=${session_id}"

        # Ejecutar con timeout
        if ! timeout "$timeout_sec" bash -c \
            "$handler '$intent_text' '$action_id' '$action_entry' '$ctx_id' '$session_id'"; then
            rc=$?
            local exit_code
            exit_code=$(biaos_get_phase_exit_code_from_arch "$phase")

            echo "${__BIAOS__EXEC_FAIL__} phase=${phase} rc=${rc} session=${session_id}"

            # Decidir si compensar o abortar según el exit_code del phase
            case "$exit_code" in
                0) continue ;;   # 0 = best-effort, continuar aunque falle
                4) # 4 = operador canceló — abort limpio sin compensación
                    biaos_format_response "Acción cancelada por el operador."
                    echo "${__BIAOS__INTENT_DONE__} session=${session_id} outcome=cancelled"
                    biaos_release_context "$session_id" "cancelled"
                    return 0
                    ;;
                *)  # 1,2,3 = fallo real → compensar si aplica
                    biaos_run_compensation "$action_id" "$action_entry" "$ctx_id" "$session_id"
                    echo "${__BIAOS__INTENT_FAIL__} session=${session_id}"
                    biaos_release_context "$session_id" "failed"
                    return "$rc"
                    ;;
            esac
        fi

        echo "${__BIAOS__EXEC_OK__} phase=${phase} session=${session_id}"

    done <<< "$phases"

    # ── BI-P7 Release: limpiar contexto ──────────────────────────
    biaos_release_context "$session_id" "success"
    echo "${__BIAOS__INTENT_DONE__} session=${session_id} outcome=success"
    return 0
}

# ── Absorb de acción (BI-P7) ─────────────────────────────────────────────
# Carga la entrada completa del catálogo para la acción matched.
# Análogo al `source "$ficha_tasks"` de 00_MASTER_INSTALL_SBOS.sh

biaos_absorb_action() {
    local action_id="$1"

    # Extraer la entrada completa del action_catalog.yml como JSON
    yq -o=json ".acciones.${action_id}" "$BIAOS_ACTION_CATALOG" 2>/dev/null \
        || echo "{}"
}

# ── Release de contexto (BI-P7) ──────────────────────────────────────────
# Limpia el contexto de la petición y registra en audit log.
# Análogo al `unset -f $(compgen -A function | grep '^ficha_')` de 00_MASTER

biaos_release_context() {
    local session_id="$1"
    local outcome="$2"

    # Registrar en audit log (BI-P5 — siempre, incluso si canceló)
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"ts\":\"$ts\",\"session_id\":\"$session_id\",\"event\":\"INTENT_RELEASE\",\"outcome\":\"$outcome\"}" \
        >> "$BIAOS_AUDIT_LOG" 2>/dev/null || true

    # Limpiar variables de contexto de la sesión actual
    unset BIAOS_CURRENT_ACTION BIAOS_CURRENT_ENTRY BIAOS_CURRENT_DIAGNOSIS 2>/dev/null || true
}

# ── Compensación (BI-P6) ─────────────────────────────────────────────────

biaos_run_compensation() {
    local action_id="$1"
    local action_entry="$2"
    local ctx_id="$3"
    local session_id="$4"

    local compensacion
    compensacion=$(echo "$action_entry" | jq -r '.compensacion // empty' 2>/dev/null)

    # Si no hay compensación declarada o es "ninguna*" → no compensar
    if [[ -z "$compensacion" || "$compensacion" == null || "$compensacion" == ninguna* ]]; then
        return 0
    fi

    echo "${__BIAOS__COMPENSATE_START__} action=${action_id} compensacion=${compensacion} session=${session_id}"

    biaos_audit_before_execute "" "compensacion_${action_id}" "" "$ctx_id" "$session_id" \
        2>/dev/null || true

    # Llamar al método de compensación vía RPC
    biaos_call_rpc "$compensacion" "{}" "$ctx_id" "$session_id" || true

    echo "${__BIAOS__COMPENSATE_OK__} action=${action_id} session=${session_id}"
}

# ── Llamada RPC al daemon bos ────────────────────────────────────────────
# Toda comunicación con el daemon pasa por aquí (BI-P9 — sin comandos directos)

biaos_call_rpc() {
    local method="$1"
    local params="$2"
    local ctx_id="${3:-}"
    local session_id="${4:-}"

    local payload
    payload=$(jq -n \
        --arg method "$method" \
        --argjson params "$params" \
        --arg ctx_id "$ctx_id" \
        --arg session_id "$session_id" \
        '{
            jsonrpc: "2.0",
            method: $method,
            params: ($params + {ctx_id: $ctx_id, session_id: $session_id}),
            id: 1
        }')

    # Llamar al daemon bos vía Unix socket (no SSH, no HTTP externo)
    curl -sf --unix-socket "$BIAOS_BOS_SOCKET" \
        -X POST http://localhost/rpc \
        -H "Content-Type: application/json" \
        -d "$payload" 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════
# Resolución del registro de acciones
# Análogo a yaml_ficha_exists / yaml_get_ficha_field en 00_YAML_ENGINE_SBOS.sh
# ═══════════════════════════════════════════════════════════════════

biaos_action_exists() {
    local action_id="$1"
    local arch_file="${2:-$BIAOS_ARCHITECTURE_YML}"

    yq -e ".acciones[\"${action_id}\"]" "$arch_file" &>/dev/null
}

biaos_get_action_field() {
    local action_id="$1"
    local field="$2"
    local arch_file="${3:-$BIAOS_ARCHITECTURE_YML}"

    yq ".acciones.${action_id}.${field}" "$arch_file" 2>/dev/null
}

biaos_list_actions() {
    local arch_file="${1:-$BIAOS_ARCHITECTURE_YML}"
    yq '.acciones | keys[]' "$arch_file" 2>/dev/null
}

biaos_list_actions_by_categoria() {
    local categoria="$1"
    local arch_file="${2:-$BIAOS_ARCHITECTURE_YML}"

    yq ".acciones | to_entries[] | select(.value.categoria == ${categoria}) | .key" \
        "$arch_file" 2>/dev/null
}

# ── Helpers internos ─────────────────────────────────────────────────────

biaos_phase_applies() {
    local phase="$1"
    local categoria="$2"

    # hitl_confirm_2 solo aplica en categoría 3
    [[ "$phase" == "hitl_confirm_2" && "$categoria" != "3" ]] && return 1
    # diagnose solo aplica en cat 2 y 3
    [[ "$phase" == "diagnose" && "$categoria" == "1" ]] && return 1
    return 0
}

biaos_get_phase_exit_code_from_arch() {
    local phase="$1"
    local arch_file="${2:-$BIAOS_ARCHITECTURE_YML}"

    local code
    code=$(yq ".lifecycle.phases.${phase}.exit_code" "$arch_file" 2>/dev/null)
    echo "${code:-3}"
}
