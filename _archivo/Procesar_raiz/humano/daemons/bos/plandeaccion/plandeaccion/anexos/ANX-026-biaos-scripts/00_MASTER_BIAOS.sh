#!/usr/bin/env bash
# Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
# Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
# ============================================================================
# 00_MASTER_BIAOS.sh — Orquestador del Sistema de Intenciones
# Proyecto: SBOS — biaos (agente IA soberano del OS)
#
# ANÁLOGO a 00_MASTER_INSTALL_SBOS.sh pero para intenciones en lenguaje natural.
#
# Diferencia fundamental con 00_MASTER_INSTALL_SBOS.sh:
#
#   00_MASTER_INSTALL_SBOS.sh:
#     Entrada:  comando explícito (install, repair, update) + ficha_id
#     Dispatch: por nombre de tarea → yaml_dispatch(task_name, ficha_id)
#     Objetivo: gestionar el ciclo de vida de un servicio K8s
#
#   00_MASTER_BIAOS.sh:
#     Entrada:  intención en lenguaje natural + ctx_id del operador
#     Dispatch: por similitud semántica → biaos_dispatch(intent_text, ctx_id)
#     Objetivo: resolver una petición del operador sobre infraestructura OS
#
# BI-P7 Absorb/Execute/Release (análogo al P7 del bos):
#   Absorb:  cargar 00_INTENT_CATALOG_BIAOS.sh + la entrada del catálogo
#   Execute: biaos_dispatch() → classify → match → hitl → execute → verify
#   Release: limpiar contexto de la petición + registrar en audit log
#
# Exit codes (análogos a los del 00_MASTER_INSTALL_SBOS.sh):
#   0  Intención resuelta exitosamente
#   1  Clasificación falló / dominio de negocio / sin match
#   2  Diagnóstico previo falló (BI-P2)
#   3  Ejecución falló (compensación ejecutada)
#   4  Operador canceló (HITL timeout o rechazo explícito)
#   5  Timeout general del ciclo
#   9  Error de sistema (dependencias, configuración)
# ============================================================================

set -euo pipefail

readonly BIAOS_MASTER_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Configuración ────────────────────────────────────────────────────────
readonly BIAOS_AI_DIR="${BIAOS_AI_DIR:-/etc/bos/ai}"
readonly BIAOS_ARCHITECTURE_YML="${BIAOS_ARCHITECTURE_YML:-${BIAOS_AI_DIR}/00_ARCHITECTURE_BIAOS.yml}"
readonly BIAOS_ACTION_CATALOG="${BIAOS_ACTION_CATALOG:-${BIAOS_AI_DIR}/action_catalog.yml}"
readonly BIAOS_CATALOG_VECTORS="${BIAOS_CATALOG_VECTORS:-/var/lib/bos/ai/catalog-vectors.bin}"
readonly BIAOS_AUDIT_LOG="${BIAOS_AUDIT_LOG:-/var/log/bos/ai-audit.log}"
readonly BIAOS_BOS_SOCKET="${BIAOS_BOS_SOCKET:-/run/bos/bos.sock}"
readonly BIAOS_SAGAS_STORE="${BIAOS_SAGAS_STORE:-/var/lib/bos/ai/sagas}"

# ── Uso ──────────────────────────────────────────────────────────────────

usage() {
    cat <<'HELP'
biaos — Agente IA Soberano del OS SBOS

Uso:
  00_MASTER_BIAOS.sh <subcomando> [opciones]

Subcomandos:
  intent   "<petición en lenguaje natural>" [--ctx-id <ctx_id>]
             Resuelve una petición del operador sobre infraestructura.
             Ejemplo: intent "el sistema está lento"
             Ejemplo: intent "repara nextcloud" --ctx-id ctx-88291

  query    "<petición>" [--ctx-id <ctx_id>]
             Solo lectura — no propone acciones de escritura.
             Ejemplo: query "estado del cluster"

  match    "<petición>"
             Muestra las acciones del catálogo más similares sin ejecutar.
             Útil para depuración del motor ICAP.

  validate
             Valida el schema de 00_ARCHITECTURE_BIAOS.yml y action_catalog.yml.

  status
             Estado del motor de intenciones (vectores cargados, catálogo OK, etc.)

  help
             Muestra este mensaje.

Variables de entorno:
  BIAOS_AI_DIR          Directorio de configuración IA (default: /etc/bos/ai)
  BIAOS_OLLAMA_URL      URL de Ollama para embeddings (default: http://localhost:11434)
  BIAOS_EMBED_MODEL     Modelo de embeddings (default: nomic-embed-text)
  BIAOS_MIN_SCORE       Score mínimo para match válido (default: 0.65)
  BIAOS_TOP_N           Opciones a presentar al operador (default: 3)

Exit codes:
  0  Intención resuelta exitosamente
  1  Sin match / dominio de negocio / clasificación fallida
  2  Diagnóstico previo falló
  3  Ejecución falló (compensación ejecutada si aplica)
  4  Operador canceló la acción
  5  Timeout del ciclo
  9  Error de sistema (falta dependencia o configuración)
HELP
    exit "${1:-1}"
}

# ── Bootstrap de dependencias ────────────────────────────────────────────

biaos_bootstrap_deps() {
    echo "=== biaos: verificando dependencias del motor ==="

    # Dependencias estrictas
    for cmd in curl jq yq; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "ERROR: '$cmd' es requerido por biaos — instalar antes de continuar"
            exit 9
        fi
    done

    # Verificar que el daemon bos está escuchando
    if ! curl -sf --unix-socket "$BIAOS_BOS_SOCKET" http://localhost/health &>/dev/null; then
        echo "WARN: El daemon bos no responde en $BIAOS_BOS_SOCKET"
        echo "      biaos puede operar en modo degradado (fallback sin RPC)"
    fi

    # Verificar que el catálogo existe
    if [[ ! -f "$BIAOS_ACTION_CATALOG" ]]; then
        echo "ERROR: Catálogo de acciones no encontrado: $BIAOS_ACTION_CATALOG"
        exit 9
    fi

    # Verificar que los vectores están precalculados (o calculares si no existen)
    if [[ ! -f "$BIAOS_CATALOG_VECTORS" ]]; then
        echo "WARN: Vectores del catálogo no encontrados — calculando..."
        biaos_precalculate_vectors || {
            echo "WARN: No se pudieron precalcular vectores — usando fallback por aliases"
        }
    fi

    # Crear directorio de sagas si no existe
    mkdir -p "$BIAOS_SAGAS_STORE"
    mkdir -p "$(dirname "$BIAOS_AUDIT_LOG")"
}

biaos_precalculate_vectors() {
    # Pedir al daemon que precalcule los vectores del catálogo
    curl -sf --unix-socket "$BIAOS_BOS_SOCKET" \
        -X POST http://localhost/rpc \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"bos.ai.catalog.init","params":{},"id":1}' \
        &>/dev/null
}

# ── Carga del motor (BI-P7 Absorb) ───────────────────────────────────────

biaos_absorb_engine() {
    # Cargar el engine y el catálogo de handlers
    if [[ -f "${SCRIPT_DIR}/00_INTENT_ENGINE_BIAOS.sh" ]]; then
        # shellcheck source=/dev/null
        source "${SCRIPT_DIR}/00_INTENT_ENGINE_BIAOS.sh"
    elif [[ -f "${BIAOS_AI_DIR}/00_INTENT_ENGINE_BIAOS.sh" ]]; then
        # shellcheck source=/dev/null
        source "${BIAOS_AI_DIR}/00_INTENT_ENGINE_BIAOS.sh"
    else
        echo "ERROR: 00_INTENT_ENGINE_BIAOS.sh no encontrado"
        exit 9
    fi

    if [[ -f "${SCRIPT_DIR}/00_INTENT_CATALOG_BIAOS.sh" ]]; then
        # shellcheck source=/dev/null
        source "${SCRIPT_DIR}/00_INTENT_CATALOG_BIAOS.sh"
    elif [[ -f "${BIAOS_AI_DIR}/00_INTENT_CATALOG_BIAOS.sh" ]]; then
        # shellcheck source=/dev/null
        source "${BIAOS_AI_DIR}/00_INTENT_CATALOG_BIAOS.sh"
    else
        echo "ERROR: 00_INTENT_CATALOG_BIAOS.sh no encontrado"
        exit 9
    fi
}

# ── Limpieza del motor (BI-P7 Release) ───────────────────────────────────

biaos_release_engine() {
    # Limpiar funciones del catálogo para evitar polución entre peticiones
    # Análogo al `unset -f $(compgen -A function | grep '^ficha_')` del bos
    unset -f $(compgen -A function 2>/dev/null | grep '^biaos_') 2>/dev/null || true
    unset BIAOS_CURRENT_ACTION BIAOS_CURRENT_ENTRY BIAOS_CURRENT_DIAGNOSIS \
          BIAOS_LAST_RESULT BIAOS_VERIFY_RESULT 2>/dev/null || true
}

# ── Subcomando: intent ────────────────────────────────────────────────────

cmd_intent() {
    local intent_text=""
    local ctx_id=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ctx-id) ctx_id="$2"; shift 2 ;;
            --ctx-id=*) ctx_id="${1#*=}"; shift ;;
            -*) echo "WARN: Opción desconocida: $1"; shift ;;
            *) intent_text="$1"; shift ;;
        esac
    done

    if [[ -z "$intent_text" ]]; then
        echo "ERROR: Se requiere la petición en lenguaje natural"
        usage 1
    fi

    local session_id
    session_id="biaos-$(date +%s%N | md5sum | head -c 12)"

    biaos_dispatch "$intent_text" "$ctx_id" "$session_id"
    local rc=$?

    # BI-P7 Release: limpiar después de cada petición
    biaos_release_engine

    return $rc
}

# ── Subcomando: query (solo lectura) ─────────────────────────────────────

cmd_query() {
    local intent_text=""
    local ctx_id=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ctx-id) ctx_id="$2"; shift 2 ;;
            --ctx-id=*) ctx_id="${1#*=}"; shift ;;
            *) intent_text="$1"; shift ;;
        esac
    done

    if [[ -z "$intent_text" ]]; then
        echo "ERROR: Se requiere la petición"
        usage 1
    fi

    local session_id="biaos-query-$(date +%s%N | md5sum | head -c 12)"

    # Forzar categoría 1 (solo lectura) independientemente del classify
    local match_result
    match_result=$(biaos_match_action "$intent_text" "$BIAOS_TOP_N")

    if [[ -z "$match_result" ]]; then
        echo "Sin resultados para: $intent_text"
        return 1
    fi

    # Ejecutar solo la primera acción de lectura del match
    local action_id
    action_id=$(echo "$match_result" | jq -r '.[] | select(.categoria == 1) | .id' | head -1)

    if [[ -z "$action_id" ]]; then
        echo "La petición requiere una acción de escritura. Usa 'intent' para peticiones que modifican el sistema."
        return 1
    fi

    local action_entry
    action_entry=$(biaos_absorb_action "$action_id")

    biaos_execute_read_action "$intent_text" "$action_id" "$action_entry" "$ctx_id" "$session_id"
    biaos_format_response

    biaos_release_engine
}

# ── Subcomando: match (debug del motor ICAP) ─────────────────────────────

cmd_match() {
    local intent_text="$1"

    if [[ -z "$intent_text" ]]; then
        echo "ERROR: Se requiere la petición"
        usage 1
    fi

    echo "Buscando acciones similares a: '$intent_text'"
    echo "Score mínimo: $BIAOS_MIN_SCORE"
    echo ""

    local matches
    matches=$(biaos_match_action "$intent_text" "$BIAOS_TOP_N")

    if [[ -z "$matches" || "$matches" == "[]" ]]; then
        echo "Sin matches con score >= $BIAOS_MIN_SCORE"
        return 1
    fi

    echo "$matches" | jq -r '.[] | "[\(.categoria)] \(.id) (score: \(.score))\n  \(.description)\n"'
}

# ── Subcomando: validate ──────────────────────────────────────────────────

cmd_validate() {
    echo "Validando 00_ARCHITECTURE_BIAOS.yml..."
    biaos_validate_schema "$BIAOS_ARCHITECTURE_YML" \
        && echo "✅ Schema válido" \
        || { echo "❌ Schema inválido"; exit 1; }

    echo ""
    echo "Validando action_catalog.yml..."
    python3 -c "import yaml; yaml.safe_load(open('$BIAOS_ACTION_CATALOG'))" \
        && echo "✅ Catálogo YAML válido" \
        || { echo "❌ Catálogo YAML inválido"; exit 1; }

    local count
    count=$(yq '.acciones | length' "$BIAOS_ACTION_CATALOG" 2>/dev/null)
    echo ""
    echo "Acciones registradas: $count"
    yq '.acciones | to_entries[] | "\(.value.categoria) \(.key)"' "$BIAOS_ACTION_CATALOG" 2>/dev/null \
        | sort | awk '{
            if ($1=="1") print "  📖 [cat-1] " $2
            if ($1=="2") print "  ✏️  [cat-2] " $2
            if ($1=="3") print "  🔴 [cat-3] " $2
        }'
}

# ── Subcomando: status ────────────────────────────────────────────────────

cmd_status() {
    echo "=== biaos Motor de Intenciones — Estado ==="
    echo ""

    echo -n "Daemon bos:          "
    curl -sf --unix-socket "$BIAOS_BOS_SOCKET" http://localhost/health &>/dev/null \
        && echo "✅ activo" || echo "❌ no responde"

    echo -n "Catálogo de acciones: "
    [[ -f "$BIAOS_ACTION_CATALOG" ]] \
        && echo "✅ $(yq '.acciones | length' "$BIAOS_ACTION_CATALOG") acciones" \
        || echo "❌ no encontrado"

    echo -n "Vectores precalcul.: "
    [[ -f "$BIAOS_CATALOG_VECTORS" ]] \
        && echo "✅ $(ls -lh "$BIAOS_CATALOG_VECTORS" | awk '{print $5}')" \
        || echo "⚠️  no generados (se usará fallback por aliases)"

    echo -n "Ollama (embeddings): "
    curl -sf "${BIAOS_OLLAMA_URL}/api/tags" &>/dev/null \
        && echo "✅ disponible" || echo "⚠️  no disponible (fallback activo)"

    echo -n "Audit log:           "
    [[ -w "$(dirname "$BIAOS_AUDIT_LOG")" ]] \
        && echo "✅ escribible" || echo "❌ sin permisos de escritura"

    echo ""
    echo "Configuración:"
    echo "  BIAOS_AI_DIR:       $BIAOS_AI_DIR"
    echo "  BIAOS_MIN_SCORE:    $BIAOS_MIN_SCORE"
    echo "  BIAOS_TOP_N:        $BIAOS_TOP_N"
    echo "  BIAOS_EMBED_MODEL:  $BIAOS_EMBED_MODEL"
}

# ── Dispatch principal ────────────────────────────────────────────────────

main() {
    local cmd="${1:-}"

    case "$cmd" in
        intent|query|match|validate|status)
            ;;
        -h|--help|help|"")
            usage 0
            ;;
        *)
            echo "ERROR: Subcomando desconocido: $cmd"
            usage 1
            ;;
    esac

    # BI-P7 Absorb: cargar el engine y el catálogo de handlers
    biaos_absorb_engine

    # Validar schema antes de cualquier operación
    if [[ "$cmd" != "validate" && "$cmd" != "status" ]]; then
        biaos_validate_schema "$BIAOS_ARCHITECTURE_YML" &>/dev/null || {
            echo "ERROR: Schema de 00_ARCHITECTURE_BIAOS.yml inválido — ejecutar 'validate' para detalles"
            exit 9
        }
    fi

    # Verificar dependencias
    biaos_bootstrap_deps

    # Ejecutar subcomando
    shift
    case "$cmd" in
        intent)   cmd_intent "$@" ;;
        query)    cmd_query "$@" ;;
        match)    cmd_match "$@" ;;
        validate) cmd_validate ;;
        status)   cmd_status ;;
    esac

    local rc=$?

    # BI-P7 Release ya fue llamado dentro de cmd_intent / cmd_query
    # Para los otros subcomandos, limpiar aquí
    [[ "$cmd" != "intent" && "$cmd" != "query" ]] && biaos_release_engine

    return $rc
}

main "$@"
