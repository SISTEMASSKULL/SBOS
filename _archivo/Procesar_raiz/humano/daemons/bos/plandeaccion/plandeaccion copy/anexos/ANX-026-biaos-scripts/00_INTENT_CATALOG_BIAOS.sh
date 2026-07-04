#!/usr/bin/env bash
# Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
# Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
# ============================================================================
# 00_INTENT_CATALOG_BIAOS.sh — Catálogo de Handlers de Intenciones
# Proyecto: SBOS — biaos (agente IA soberano del OS)
#
# ANÁLOGO a 00_TASK_CATALOG_SBOS.sh pero para intenciones en lenguaje natural.
#
# Diferencia fundamental:
#   00_TASK_CATALOG_SBOS.sh: funciones que instalan/reparan servicios K8s
#   00_INTENT_CATALOG_BIAOS.sh: funciones que resuelven peticiones en NL
#
# Todas las funciones reciben la misma firma estándar:
#   handler_name intent_text action_id action_entry ctx_id session_id
#
# BI-P3: NUNCA nombra servicios concretos (nextcloud, redis, etc.)
#        Los nombres vienen del action_entry pasado por el engine.
#
# Grupos de funciones:
#   Grupo 1: Clasificación de intención
#   Grupo 2: Match semántico sobre el catálogo
#   Grupo 3: Enriquecimiento con LLM
#   Grupo 4: HITL (presentación y confirmación)
#   Grupo 5: Ejecución (lectura, escritura, destructiva, compensación)
#   Grupo 6: Verificación de resultado
#   Grupo 7: Audit log (BI-P5)
#   Grupo 8: Formato de respuesta al operador
#   Grupo 9: Principios (guardias de dominio, checks)
# ============================================================================

set -euo pipefail

# ── Configuración ────────────────────────────────────────────────────────
readonly BIAOS_CATALOG_VERSION="1.0.0"
readonly BIAOS_OLLAMA_URL="${BIAOS_OLLAMA_URL:-http://localhost:11434}"
readonly BIAOS_EMBED_MODEL="${BIAOS_EMBED_MODEL:-nomic-embed-text}"

# ═══════════════════════════════════════════════════════════════════
# Grupo 1 — Clasificación de intención
# Determina si la petición es lectura (1), escritura (2) o destructiva (3)
# ═══════════════════════════════════════════════════════════════════

biaos_classify_intent() {
    local intent_text="$1"

    # Clasificador rápido basado en vocabulario señalizador
    # No usa el LLM grande — es determinista y rápido (< 1ms)

    local texto_lower
    texto_lower=$(echo "$intent_text" | tr '[:upper:]' '[:lower:]')

    # Señales de acción destructiva (categoría 3)
    local destructive_signals=("drenar" "drain" "mantenimiento del nodo" "mantenimiento del servidor"
                               "maintenance" "suspender tenant" "suspender acceso" "reiniciar namespace"
                               "cordon" "aislar el nodo" "todos los usuarios")
    for signal in "${destructive_signals[@]}"; do
        if echo "$texto_lower" | grep -q "$signal"; then
            echo "3"
            return 0
        fi
    done

    # Señales de escritura (categoría 2)
    local write_signals=("repara" "arregla" "reinicia" "escala" "actualiza" "pausa" "detén"
                         "rollback" "revierte" "invalida" "aplica" "fix" "repair" "restart"
                         "scale" "upgrade" "pause" "undo")
    for signal in "${write_signals[@]}"; do
        if echo "$texto_lower" | grep -q "$signal"; then
            echo "2"
            return 0
        fi
    done

    # Por defecto: lectura (categoría 1)
    echo "1"
}

# ═══════════════════════════════════════════════════════════════════
# Grupo 2 — Match semántico sobre el catálogo
# Implementa BI-P8: dispatch por similitud coseno, no nombre exacto
# ═══════════════════════════════════════════════════════════════════

biaos_match_action() {
    local intent_text="$1"
    local top_n="${2:-$BIAOS_TOP_N}"

    # Llamar al ICAP Engine en Go (internal/biaos/icap/) vía RPC
    # El engine Go tiene los vectores pre-calculados en memoria
    local result
    result=$(biaos_call_rpc "bos.ai.icap.match" \
        "{\"intent\": $(echo "$intent_text" | jq -R .), \"top_n\": $top_n}" \
        "" "" 2>/dev/null)

    if [[ -z "$result" ]]; then
        # Fallback: match por aliases directamente sobre el catálogo YAML
        biaos_match_action_fallback "$intent_text" "$top_n"
        return
    fi

    echo "$result" | jq -r '.result // .result.matches // empty'
}

biaos_match_action_fallback() {
    # Fallback cuando el daemon Go no está disponible.
    # Busca en los aliases del action_catalog.yml mediante grep.
    # Menos preciso que la similitud coseno pero funciona offline.
    local intent_text="$1"
    local top_n="${2:-3}"

    local texto_lower
    texto_lower=$(echo "$intent_text" | tr '[:upper:]' '[:lower:]')

    local matches="[]"
    local count=0

    # Leer las acciones del catálogo
    while IFS= read -r action_id; do
        [[ "$count" -ge "$top_n" ]] && break
        [[ -z "$action_id" ]] && continue

        # Buscar en el embedding_texto de la acción
        local embed_text
        embed_text=$(yq ".acciones.${action_id}.embedding_texto" "$BIAOS_ACTION_CATALOG" 2>/dev/null \
            | tr '[:upper:]' '[:lower:]')

        # Buscar en aliases
        local aliases
        aliases=$(yq ".acciones.${action_id}.aliases[]?" "$BIAOS_ACTION_CATALOG" 2>/dev/null \
            | tr '[:upper:]' '[:lower:]')

        local combined="${embed_text} ${aliases}"

        # Scoring simple: contar palabras del intent que aparecen en la acción
        local score=0
        for word in $texto_lower; do
            [[ ${#word} -lt 3 ]] && continue  # ignorar palabras muy cortas
            if echo "$combined" | grep -q "$word"; then
                score=$((score + 1))
            fi
        done

        if [[ $score -gt 0 ]]; then
            local description
            description=$(yq ".acciones.${action_id}.description" "$BIAOS_ACTION_CATALOG" 2>/dev/null)
            local categoria
            categoria=$(yq ".acciones.${action_id}.categoria" "$BIAOS_ACTION_CATALOG" 2>/dev/null)

            matches=$(echo "$matches" | jq \
                --arg id "$action_id" \
                --arg desc "$description" \
                --argjson score "$score" \
                --argjson cat "$categoria" \
                '. + [{"id": $id, "description": $desc, "score": $score, "categoria": $cat}]')
            count=$((count + 1))
        fi
    done < <(yq '.acciones | keys[]' "$BIAOS_ACTION_CATALOG" 2>/dev/null)

    # Ordenar por score descendente
    echo "$matches" | jq 'sort_by(-.score)'
}

# ═══════════════════════════════════════════════════════════════════
# Grupo 3 — Enriquecimiento con LLM
# Añade contexto específico a las opciones antes de presentarlas al operador
# ═══════════════════════════════════════════════════════════════════

biaos_enrich_with_llm() {
    local intent_text="$1"
    local action_id="$2"
    local action_entry="$3"
    local ctx_id="$4"
    local session_id="$5"

    # Enriquecimiento: pedir al LLM que contextualice el riesgo y parámetros
    # para ESTA petición específica (no el riesgo genérico del catálogo)

    local riesgo_base
    riesgo_base=$(echo "$action_entry" | jq -r '.riesgo // "Consulta los detalles antes de confirmar."')

    local descripcion
    descripcion=$(echo "$action_entry" | jq -r '.description // ""')

    # Llamar al LLM vía gateway biaos (bos.ai.ask)
    # Si el LLM no está disponible, usar los valores base del catálogo
    local enriched
    enriched=$(biaos_call_rpc "bos.ai.enrich_action" \
        "{\"intent\": $(echo "$intent_text" | jq -R .),
          \"action_id\": $(echo "$action_id" | jq -R .),
          \"base_risk\": $(echo "$riesgo_base" | jq -R .),
          \"ctx_id\": $(echo "$ctx_id" | jq -R .)}" \
        "$ctx_id" "$session_id" 2>/dev/null) || true

    if [[ -z "$enriched" ]]; then
        # Sin LLM disponible: usar valores base del catálogo
        echo "$action_entry"
        return 0
    fi

    # Combinar el entry original con el enriquecimiento del LLM
    echo "$action_entry" | jq \
        --argjson enriched "$enriched" \
        '. + {riesgo_contextual: $enriched.riesgo_contextual, params_sugeridos: $enriched.params_sugeridos}'
}

# ═══════════════════════════════════════════════════════════════════
# Grupo 4 — HITL (Human-in-the-Loop)
# Presentación de opciones y espera de confirmación del operador
# ═══════════════════════════════════════════════════════════════════

biaos_present_options() {
    local intent_text="$1"
    local action_id="$2"
    local action_entry="$3"
    local ctx_id="$4"
    local session_id="$5"

    local matches
    matches=$(biaos_match_action "$intent_text" "$BIAOS_TOP_N")

    echo "${__BIAOS__HITL_PRESENT__} session=${session_id}"

    # Enviar las opciones al daemon bos para que las muestre en bosctl
    biaos_call_rpc "bos.ai.hitl.present" \
        "{\"session_id\": $(echo "$session_id" | jq -R .),
          \"intent\": $(echo "$intent_text" | jq -R .),
          \"matches\": $matches,
          \"ctx_id\": $(echo "$ctx_id" | jq -R .)}" \
        "$ctx_id" "$session_id" 2>/dev/null || {
            # Fallback: presentar en stdout si el socket no está disponible
            echo ""
            echo "Encontré acciones relacionadas con tu petición:"
            echo "$matches" | jq -r '.[] | "  [\(.categoria)] \(.id) — \(.description)"'
            echo ""
        }
}

biaos_wait_confirmation() {
    local intent_text="$1"
    local action_id="$2"
    local action_entry="$3"
    local ctx_id="$4"
    local session_id="$5"

    # Esperar respuesta del operador vía bosctl (el daemon la pasa por RPC)
    local timeout_sec
    timeout_sec=$(biaos_get_phase_timeout "hitl_confirm")

    local confirmation
    confirmation=$(timeout "$timeout_sec" \
        biaos_call_rpc "bos.ai.hitl.wait" \
        "{\"session_id\": $(echo "$session_id" | jq -R .), \"timeout_sec\": $timeout_sec}" \
        "$ctx_id" "$session_id" 2>/dev/null) || {
            echo "TIMEOUT: El operador no respondió en ${timeout_sec}s"
            return 4  # exit_code 4 = cancelado
        }

    local confirmed
    confirmed=$(echo "$confirmation" | jq -r '.confirmed // false' 2>/dev/null)

    if [[ "$confirmed" != "true" ]]; then
        echo "${__BIAOS__HITL_CANCELLED__} session=${session_id}"
        return 4
    fi

    # Guardar la acción seleccionada por el operador
    local selected_action
    selected_action=$(echo "$confirmation" | jq -r '.selected_action // empty')
    export BIAOS_CURRENT_ACTION="${selected_action:-$action_id}"

    echo "${__BIAOS__HITL_CONFIRMED__} action=${BIAOS_CURRENT_ACTION} session=${session_id}"
}

biaos_wait_confirmation_first() {
    # Primera confirmación para acciones cat-3
    biaos_wait_confirmation "$@"
}

biaos_wait_confirmation_second() {
    local intent_text="$1"
    local action_id="$2"
    local action_entry="$3"
    local ctx_id="$4"
    local session_id="$5"

    # Segunda confirmación: requiere frase exacta según el catálogo
    local frase_requerida
    frase_requerida=$(echo "$action_entry" | jq -r '.frase_confirmacion // "CONFIRMO"')

    local confirmation
    confirmation=$(biaos_call_rpc "bos.ai.hitl.wait_phrase" \
        "{\"session_id\": $(echo "$session_id" | jq -R .),
          \"required_phrase\": $(echo "$frase_requerida" | jq -R .),
          \"timeout_sec\": 300}" \
        "$ctx_id" "$session_id" 2>/dev/null) || return 4

    local confirmed
    confirmed=$(echo "$confirmation" | jq -r '.confirmed // false' 2>/dev/null)
    [[ "$confirmed" == "true" ]] || return 4

    echo "${__BIAOS__HITL_CONFIRMED__} second_confirm=true action=${action_id} session=${session_id}"
}

# ═══════════════════════════════════════════════════════════════════
# Grupo 5 — Ejecución por categoría
# Ejecuta la acción matched llamando al daemon bos vía RPC
# BI-P9: NUNCA genera comandos — solo llama métodos del catálogo
# ═══════════════════════════════════════════════════════════════════

biaos_execute_read_action() {
    local intent_text="$1"
    local action_id="$2"
    local action_entry="$3"
    local ctx_id="$4"
    local session_id="$5"

    local rpc_method
    rpc_method=$(echo "$action_entry" | jq -r '.rpc_method // empty')

    if [[ -z "$rpc_method" ]]; then
        echo "ERROR: Acción de lectura sin rpc_method: $action_id"
        return 1
    fi

    # Extraer params de la acción (si el operador los especificó)
    local params
    params=$(biaos_extract_params_from_intent "$intent_text" "$action_entry")

    # Ejecutar vía RPC (BI-P9: el catálogo define qué se ejecuta)
    local result
    result=$(biaos_call_rpc "$rpc_method" "$params" "$ctx_id" "$session_id")

    # Guardar resultado para la fase format_response
    export BIAOS_LAST_RESULT="$result"
}

biaos_execute_write_action() {
    local intent_text="$1"
    local action_id="${BIAOS_CURRENT_ACTION:-$2}"  # usar la selección del operador si existe
    local action_entry="$3"
    local ctx_id="$4"
    local session_id="$5"

    # Re-cargar el entry de la acción seleccionada por el operador (puede diferir del match inicial)
    if [[ "${BIAOS_CURRENT_ACTION:-}" != "$2" ]]; then
        action_entry=$(biaos_absorb_action "$BIAOS_CURRENT_ACTION")
    fi

    local saga_id rpc_method
    saga_id=$(echo "$action_entry" | jq -r '.saga_id // empty')
    rpc_method=$(echo "$action_entry" | jq -r '.rpc_method // empty')

    local params
    params=$(biaos_extract_params_from_intent "$intent_text" "$action_entry")

    if [[ -n "$saga_id" && "$saga_id" != "null" ]]; then
        # Ejecutar como saga (multi-paso con compensación)
        biaos_call_rpc "bos.ai.saga.execute" \
            "{\"saga_id\": $(echo "$saga_id" | jq -R .),
              \"params\": $params,
              \"ctx_id\": $(echo "$ctx_id" | jq -R .),
              \"session_id\": $(echo "$session_id" | jq -R .)}" \
            "$ctx_id" "$session_id"
    elif [[ -n "$rpc_method" && "$rpc_method" != "null" ]]; then
        # Ejecutar como llamada RPC directa
        biaos_call_rpc "$rpc_method" "$params" "$ctx_id" "$session_id"
    else
        echo "ERROR: Acción $action_id sin saga_id ni rpc_method"
        return 1
    fi
}

biaos_execute_destructive_action() {
    # Las acciones destructivas van por el mismo camino que escritura
    # La diferencia es que requirieron HITL doble (ya validado en las fases previas)
    biaos_execute_write_action "$@"
}

biaos_execute_compensation() {
    local intent_text="$1"
    local action_id="$2"
    local action_entry="$3"
    local ctx_id="$4"
    local session_id="$5"

    local compensacion
    compensacion=$(echo "$action_entry" | jq -r '.compensacion // empty')

    [[ -z "$compensacion" || "$compensacion" == "null" || "$compensacion" == ninguna* ]] && return 0

    biaos_call_rpc "$compensacion" "{}" "$ctx_id" "$session_id" || true
}

biaos_run_diagnosis() {
    local intent_text="$1"
    local action_id="$2"
    local action_entry="$3"
    local ctx_id="$4"
    local session_id="$5"

    # Diagnóstico previo obligatorio (BI-P2)
    # Determinar qué saga de consulta aplica para esta acción
    local diag_method="bos.query.repair"  # default

    # Si la acción es sobre VDI: usar bos.query.vdi
    local cat_yaml
    cat_yaml=$(echo "$action_entry" | jq -r '.rpc_method // .saga_id // ""')
    if echo "$cat_yaml" | grep -q "vdi\|fedora\|guacamole\|nextcloud"; then
        diag_method="bos.query.vdi"
    fi

    local diagnosis
    diagnosis=$(biaos_call_rpc "$diag_method" "{}" "$ctx_id" "$session_id" 2>/dev/null) || true

    # Guardar diagnóstico para la fase enrich y format_response
    export BIAOS_CURRENT_DIAGNOSIS="${diagnosis:-{}}"
}

# ═══════════════════════════════════════════════════════════════════
# Grupo 6 — Verificación de resultado
# ═══════════════════════════════════════════════════════════════════

biaos_verify_result() {
    local intent_text="$1"
    local action_id="${BIAOS_CURRENT_ACTION:-$2}"
    local action_entry="$3"
    local ctx_id="$4"
    local session_id="$5"

    # Verificar mediante probe si aplica
    local ficha_id
    ficha_id=$(echo "${BIAOS_LAST_RESULT:-{}}" | jq -r '.ficha_id // empty' 2>/dev/null)

    if [[ -n "$ficha_id" ]]; then
        local probe_result
        probe_result=$(biaos_call_rpc "bos.ficha.probe" \
            "{\"ficha_id\": $(echo "$ficha_id" | jq -R .)}" \
            "$ctx_id" "$session_id" 2>/dev/null) || true

        export BIAOS_VERIFY_RESULT="${probe_result:-{}}"
    fi
}

# ═══════════════════════════════════════════════════════════════════
# Grupo 7 — Audit log (BI-P5: antes y después de ejecutar)
# ═══════════════════════════════════════════════════════════════════

biaos_audit_before_execute() {
    local intent_text="$1"
    local action_id="$2"
    local action_entry="$3"
    local ctx_id="$4"
    local session_id="$5"

    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local traceparent
    traceparent=$(biaos_call_rpc "bos.ctx.get" \
        "{\"ctx_id\": $(echo "$ctx_id" | jq -R .)}" \
        "$ctx_id" "$session_id" 2>/dev/null \
        | jq -r '.traceparent // "00-000-000-00"' 2>/dev/null) || traceparent="unknown"

    # Registro en audit log con traceparent W3C (BI-P11)
    printf '%s\n' "{
        \"ts\": \"$ts\",
        \"event\": \"BIAOS_EXEC_PRE\",
        \"session_id\": \"$session_id\",
        \"action_id\": \"$action_id\",
        \"ctx_id\": \"$ctx_id\",
        \"traceparent\": \"$traceparent\",
        \"intent\": $(echo "$intent_text" | jq -R .)
    }" >> "$BIAOS_AUDIT_LOG" 2>/dev/null || true
}

biaos_audit_after_execute() {
    local intent_text="$1"
    local action_id="${BIAOS_CURRENT_ACTION:-$2}"
    local action_entry="$3"
    local ctx_id="$4"
    local session_id="$5"

    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    printf '%s\n' "{
        \"ts\": \"$ts\",
        \"event\": \"BIAOS_EXEC_POST\",
        \"session_id\": \"$session_id\",
        \"action_id\": \"$action_id\",
        \"ctx_id\": \"$ctx_id\",
        \"outcome\": \"success\",
        \"result\": ${BIAOS_LAST_RESULT:-{}}
    }" >> "$BIAOS_AUDIT_LOG" 2>/dev/null || true
}

biaos_audit_compensation() {
    local intent_text="$1"
    local action_id="$2"
    local action_entry="$3"
    local ctx_id="$4"
    local session_id="$5"

    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    printf '%s\n' "{
        \"ts\": \"$ts\",
        \"event\": \"BIAOS_COMPENSATE\",
        \"session_id\": \"$session_id\",
        \"action_id\": \"$action_id\",
        \"ctx_id\": \"$ctx_id\"
    }" >> "$BIAOS_AUDIT_LOG" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════
# Grupo 8 — Formato de respuesta al operador
# ═══════════════════════════════════════════════════════════════════

biaos_format_response() {
    local message="${1:-}"
    local action_id="${BIAOS_CURRENT_ACTION:-}"
    local result="${BIAOS_LAST_RESULT:-{}}"
    local verify="${BIAOS_VERIFY_RESULT:-{}}"

    if [[ -n "$message" ]]; then
        echo "$message"
        return 0
    fi

    # Enviar resultado formateado al daemon bos para que lo muestre en bosctl
    biaos_call_rpc "bos.ai.response.send" \
        "{\"action_id\": $(echo "$action_id" | jq -R .),
          \"result\": $result,
          \"verify\": $verify}" \
        "" "" 2>/dev/null || {
            # Fallback: output directo
            echo "✅ Acción completada: $action_id"
            echo "$result" | jq '.' 2>/dev/null || true
        }
}

biaos_format_error_response() {
    local error_message="$1"

    echo "❌ $error_message"

    biaos_call_rpc "bos.ai.response.error" \
        "{\"message\": $(echo "$error_message" | jq -R .)}" \
        "" "" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════
# Grupo 9 — Principios y guardias (BI-P1, BI-P2, BI-P9)
# ═══════════════════════════════════════════════════════════════════

biaos_check_domain() {
    local intent_text="$1"

    local texto_lower
    texto_lower=$(echo "$intent_text" | tr '[:upper:]' '[:lower:]')

    # Dominio de negocio bloqueado (BI-P1)
    local business_signals=("factura" "venta" "empleado" "inventario" "nomina" "nómina"
                            "saleor" "tryton" "orangehrm" "biedata" "compra" "orden de venta"
                            "cliente" "proveedor" "catalogo de productos" "catálogo de productos")
    for signal in "${business_signals[@]}"; do
        if echo "$texto_lower" | grep -q "$signal"; then
            return 1  # dominio de negocio → denegar
        fi
    done

    return 0  # dominio OS → permitir
}

biaos_derive_to_bcompass() {
    local intent_text="$1"

    echo "Esa consulta corresponde a bCompass (agente de negocio)."
    echo "biaos solo gestiona infraestructura: Ubuntu, Kubernetes y fichas de servicio."

    biaos_call_rpc "bos.ai.derive" \
        "{\"intent\": $(echo "$intent_text" | jq -R .),
          \"target_agent\": \"bCompass\"}" \
        "" "" 2>/dev/null || true
}

biaos_check_diagnose_first() {
    # BI-P2: verificar que hay un diagnóstico en el contexto actual
    # antes de proponer una acción de escritura
    [[ -n "${BIAOS_CURRENT_DIAGNOSIS:-}" && "${BIAOS_CURRENT_DIAGNOSIS}" != "{}" ]]
}

# ── Helper: extracción de parámetros de la intención ─────────────────────
# Extrae parámetros nombrados del texto de la intención (ej: "repara nextcloud")

biaos_extract_params_from_intent() {
    local intent_text="$1"
    local action_entry="$2"

    # Pedir al daemon que extraiga los parámetros via NLP
    local extracted
    extracted=$(biaos_call_rpc "bos.ai.params.extract" \
        "{\"intent\": $(echo "$intent_text" | jq -R .),
          \"expected_params\": $(echo "$action_entry" | jq '.params_requeridos // []')}" \
        "" "" 2>/dev/null) || extracted="{}"

    echo "${extracted:-{}}"
}
