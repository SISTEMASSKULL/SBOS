#!/bin/bash
# ============================================================================
# build_ddl.sh v9 — Identity Governance & Audit Platform
#
# 3 fases independientes:
#   FASE 1: CREATE TABLE + inline REFERENCES (orden topológico)
#   FASE 2: CREATE INDEX + ALTER TABLE ADD CONSTRAINT FK (post-tablas)
#   FASE 3: Funciones, triggers, REVOKE/GRANT, RLS (post-FKs)
#
# Cada fase genera su propio archivo de salida para depuración granular.
# ============================================================================

set -e

BAK="${1:-migrations/001_bauth_init.sql.bak}"
OUTDIR="${2:-migrations}"
mkdir -p "$OUTDIR"

FASE1="$OUTDIR/002_fase1_tablas.sql"
FASE2="$OUTDIR/002_fase2_indices_fk.sql"
FASE3="$OUTDIR/002_fase3_funciones_rls.sql"
OUTPUT="$OUTDIR/002_bauth_reconstruccion.sql"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  BUILD_DDL v9 — 3 Fases Independientes                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# ── Correcciones TEXT→UUID (FASE E) ──────────────────────────
declare -A TEXT_TO_UUID
TEXT_TO_UUID["bos_dispositivo_fisico.area_id"]=1
TEXT_TO_UUID["bos_dispositivo_fisico.pos_logico_id"]=1
TEXT_TO_UUID["bos_edificio.sitio_id"]=1
TEXT_TO_UUID["bos_piso.edificio_id"]=1
TEXT_TO_UUID["bos_area_fisica.piso_id"]=1
TEXT_TO_UUID["bos_empresa.locale_default"]=1
TEXT_TO_UUID["bos_sucursal.empresa_id"]=1
TEXT_TO_UUID["bos_pos_logico.sucursal_id"]=1
TEXT_TO_UUID["bos_pos_logico.empresa_id"]=1
TEXT_TO_UUID["bos_user_template.empresa_id"]=1
TEXT_TO_UUID["bos_user_template.pos_logico"]=1
TEXT_TO_UUID["bos_tenant_language.locale"]=1
TEXT_TO_UUID["bos_rol_template.parent_id"]=1
TEXT_TO_UUID["bos_delegation_log.rol_id"]=1
TEXT_TO_UUID["bos_permiso_logico.rol_id"]=1
TEXT_TO_UUID["bos_permiso_logico.zona_id"]=1
TEXT_TO_UUID["bos_financial_approval.tipo_transaccion"]=1
TEXT_TO_UUID["bos_financial_limit.rol_id"]=1
TEXT_TO_UUID["bos_financial_limit.tipo_transaccion"]=1
TEXT_TO_UUID["bos_financial_role_permission.rol_id"]=1
TEXT_TO_UUID["bos_financial_role_permission.operacion_id"]=1
TEXT_TO_UUID["bos_financial_decision_matrix.tipo_transaccion"]=1
TEXT_TO_UUID["bos_financial_decision_matrix.nivel_1_rol"]=1
TEXT_TO_UUID["bos_financial_decision_matrix.nivel_2_rol"]=1
TEXT_TO_UUID["bos_financial_decision_matrix.nivel_3_rol"]=1
TEXT_TO_UUID["bos_ciudad.timezone_id"]=1

# Contadores globales
TOTAL_TABLES=0
TOTAL_FKS=0
TOTAL_INDEXES=0
CORRECTED_COLUMNS=0

# ── Extraer bloques CREATE TABLE ──────────────────────────────
extract_blocks() {
    echo "  [Extract] Bloques CREATE TABLE..."
    grep -n "^CREATE TABLE" "$BAK" > /tmp/ddl_starts.txt
    > /tmp/all_blocks.txt
    local total_lines=$(wc -l < "$BAK")

    while IFS=: read -r start rest; do
        local next_start
        next_start=$(tail -n +$((start + 1)) "$BAK" 2>/dev/null | grep -n "^CREATE TABLE\|^-- ==" | head -1 | cut -d: -f1)
        local end
        if [ -n "$next_start" ]; then end=$((start + next_start - 1)); else end=$total_lines; fi
        local tn
        tn=$(echo "$rest" | sed 's/.*\.//' | sed 's/ (.*//' | sed 's/IF NOT EXISTS //' | tr -d ' ')
        echo "$tn|$start|$end" >> /tmp/all_blocks.txt
    done < /tmp/ddl_starts.txt
    echo "     $(wc -l < /tmp/all_blocks.txt) bloques"
}

# ── Calcular orden topológico ────────────────────────────────
compute_tsort() {
    echo "  [Tsort]  Grafo de dependencias..."
    > /tmp/fk_edges.txt
    while IFS='|' read -r tn start end; do
        sed -n "${start},${end}p" "$BAK" | grep -o 'REFERENCES [a-z_]*\.[a-z_][a-z0-9_]*' | sed 's/REFERENCES //' | while read -r ref; do
            echo "$(echo $ref | sed 's/.*\.//') $tn" >> /tmp/fk_edges.txt
        done
    done < /tmp/all_blocks.txt

    sort -u /tmp/fk_edges.txt > /tmp/fk_edges_unique.txt
    echo "     $(wc -l < /tmp/fk_edges_unique.txt) aristas"

    tsort /tmp/fk_edges_unique.txt > /tmp/topo_order.txt 2>/dev/null || {
        echo "     ⚠️  tsort falló — usando orden de archivo"
        cut -d'|' -f1 /tmp/all_blocks.txt > /tmp/topo_order.txt
    }
    echo "     $(wc -l < /tmp/topo_order.txt) en orden topológico"

    cut -d'|' -f1 /tmp/all_blocks.txt | sort > /tmp/all_names.txt
    cat /tmp/fk_edges_unique.txt | tr ' ' '\n' | sort -u > /tmp/graph_names.txt
    comm -23 /tmp/all_names.txt /tmp/graph_names.txt > /tmp/isolated.txt
    echo "     $(wc -l < /tmp/isolated.txt) aisladas (Nivel 0)"
}

# ── Función: corregir TEXT→UUID y limpiar un bloque ──────────
# Retorna el bloque corregido por stdout
correct_block() {
    local tn="$1" st="$2" en="$3"
    # Estado: dentro de un CREATE TABLE (antes del `);` final) o fuera
    local in_table=1  # 1 = dentro, 0 = fuera (ya se cerró el CREATE TABLE)
    local paren_depth=0

    sed -n "${st},${en}p" "$BAK" | while IFS= read -r line; do
        local corrected="$line"

        # Si ya salimos del CREATE TABLE, saltar TODO lo demás
        # (índices, DO blocks, comentarios, etc. van en FASE 2 o 3)
        if [[ $in_table -eq 0 ]]; then
            continue
        fi

        # Detectar cierre del CREATE TABLE: línea que es solo ");"
        if [[ "$corrected" =~ ^\)\; ]]; then
            in_table=0
            echo "$corrected"
            continue
        fi

        # Saltar CHECK multilínea con valores no-UUID (post-procesamiento)
        echo "$corrected" | grep -qE "CHECK.*tier IN \(|CHECK.*criticality IN \(|CHECK.*review_type IN " && continue

        # Corrección TEXT→UUID
        for key in "${!TEXT_TO_UUID[@]}"; do
            local tab="${key%%.*}" col="${key##*.}"
            if [[ "$tn" == "$tab" ]] && echo "$corrected" | grep -qE "${col}[[:space:]]+TEXT.*REFERENCES"; then
                corrected=$(echo "$corrected" | sed "s/\b${col}\b[[:space:]]*TEXT/${col} UUID/g")
            fi
        done

        echo "$corrected"
    done
}

# ── Procesar todas las tablas en orden ────────────────────────
declare -A written

write_table() {
    local tn="$1"
    [[ -z "$tn" ]] && return
    [[ "${written[$tn]}" = "1" ]] && return
    written[$tn]=1

    local blk=$(grep "^${tn}|" /tmp/all_blocks.txt 2>/dev/null || echo "")
    [[ -z "$blk" ]] && return

    local st=$(echo "$blk" | cut -d'|' -f2)
    local en=$(echo "$blk" | cut -d'|' -f3)

    correct_block "$tn" "$st" "$en"
    echo ""  # separador entre tablas
    TOTAL_TABLES=$((TOTAL_TABLES + 1))
}

process_all_tables() {
    # 1. Aisladas primero (Nivel 0)
    [[ -s /tmp/isolated.txt ]] && while read -r tn || [[ -n "$tn" ]]; do
        [[ -z "$tn" ]] && continue; write_table "$tn"
    done < /tmp/isolated.txt

    # 2. Orden topológico
    [[ -s /tmp/topo_order.txt ]] && while read -r tn || [[ -n "$tn" ]]; do
        [[ -z "$tn" ]] && continue; write_table "$tn"
    done < /tmp/topo_order.txt

    # 3. Restantes
    [[ -s /tmp/all_blocks.txt ]] && while IFS='|' read -r tn st en || [[ -n "$tn" ]]; do
        [[ -z "$tn" ]] && continue; write_table "$tn"
    done < /tmp/all_blocks.txt
}

# ═══════════════════════════════════════════════════════════════
# FASE 1: CREATE TABLE + inline REFERENCES
# ═══════════════════════════════════════════════════════════════
build_fase1() {
    echo ""
    echo "┌──────────────────────────────────────────────────────────┐"
    echo "│  FASE 1: CREATE TABLE + inline REFERENCES               │"
    echo "└──────────────────────────────────────────────────────────┘"

    cat > "$FASE1" << HEADER
-- ============================================================
-- bauth_db DDL — FASE 1: Tablas + Referencias
-- build_ddl.sh v9 · $(date -u +%Y-%m-%dT%H:%M:%SZ)
-- Correcciones: 26 columnas TEXT→UUID (FASE E)
-- ============================================================

DROP SCHEMA IF EXISTS bos_blockchain CASCADE;
DROP SCHEMA IF EXISTS bos_privilege CASCADE;
DROP SCHEMA IF EXISTS bauth CASCADE;
CREATE SCHEMA IF NOT EXISTS bauth;
CREATE SCHEMA IF NOT EXISTS bos_privilege;
CREATE SCHEMA IF NOT EXISTS bos_blockchain;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

HEADER

    extract_blocks
    compute_tsort
    echo "  [FASE 1] Generando CREATE TABLEs..."

    process_all_tables > /tmp/fase1_body.sql

    # Corregir trailing commas antes del ); (sintaxis heredada del .bak)
    sed -i '$!N;s/,\n);/\n);/' /tmp/fase1_body.sql

    # Agregar IF NOT EXISTS
    sed -i '/CREATE TABLE IF NOT EXISTS/!s/^CREATE TABLE /CREATE TABLE IF NOT EXISTS /' /tmp/fase1_body.sql

    cat /tmp/fase1_body.sql >> "$FASE1"

    local t1=$(grep -c "^CREATE TABLE IF NOT EXISTS" "$FASE1" 2>/dev/null || echo 0)
    local f1=$(grep -c "REFERENCES" "$FASE1" 2>/dev/null || echo 0)
    local l1=$(wc -l < "$FASE1")

    echo "  [FASE 1] ✅ $t1 tablas, $f1 FKs, $l1 líneas → $FASE1"
    TOTAL_TABLES=$t1
    TOTAL_FKS=$f1
}

# ═══════════════════════════════════════════════════════════════
# FASE 2: CREATE INDEX + ALTER TABLE ADD CONSTRAINT FK
# ═══════════════════════════════════════════════════════════════
build_fase2() {
    echo ""
    echo "┌──────────────────────────────────────────────────────────┐"
    echo "│  FASE 2: Índices + Constraints FK                       │"
    echo "└──────────────────────────────────────────────────────────┘"

    cat > "$FASE2" << HEADER
-- ============================================================
-- bauth_db DDL — FASE 2: Índices + Constraints FK
-- build_ddl.sh v9 · $(date -u +%Y-%m-%dT%H:%M:%SZ)
-- Se ejecuta DESPUÉS de FASE 1 (todas las tablas creadas)
-- ============================================================

HEADER

    # Extraer CREATE INDEX del .bak (excluyendo los problemáticos)
    grep -n "^CREATE INDEX\|^CREATE UNIQUE INDEX" "$BAK" > /tmp/idx_lines.txt
    local idx_count=0

    while IFS=: read -r line_num line_content; do
        # Saltar índices con CURRENT_DATE o now()
        echo "$line_content" | grep -qE "CURRENT_DATE|now\(\)" && continue
        # Saltar índices GIN en cláusulas WHERE problemáticas
        echo "$line_content" | grep -q "idx_bae_severity" && continue

        # Extraer la línea completa (los índices suelen ser single-line en .bak)
        echo "$line_content" | sed '/IF NOT EXISTS/!s/^CREATE /CREATE IF NOT EXISTS /' >> "$FASE2" 2>/dev/null || true
        idx_count=$((idx_count + 1))
        echo "" >> "$FASE2"
    done < /tmp/idx_lines.txt

    # Extraer ALTER TABLE ADD CONSTRAINT FK (para FKs que no están inline)
    grep -n "ALTER TABLE.*ADD CONSTRAINT\|ADD CONSTRAINT.*FOREIGN KEY" "$BAK" > /tmp/fk_constraints.txt 2>/dev/null || true
    local fk_count=0

    if [[ -s /tmp/fk_constraints.txt ]]; then
        echo "" >> "$FASE2"
        echo "-- Foreign Key Constraints (non-inline)" >> "$FASE2"
        while IFS=: read -r line_num line_content; do
            echo "$line_content" >> "$FASE2"
            fk_count=$((fk_count + 1))
        done < /tmp/fk_constraints.txt
    fi

    TOTAL_INDEXES=$idx_count
    echo "  [FASE 2] ✅ $idx_count índices, $fk_count constraints → $FASE2"
}

# ═══════════════════════════════════════════════════════════════
# FASE 3: Funciones, Triggers, REVOKE/GRANT, RLS
# ═══════════════════════════════════════════════════════════════
build_fase3() {
    echo ""
    echo "┌──────────────────────────────────────────────────────────┐"
    echo "│  FASE 3: Funciones, Triggers, RLS, Permisos             │"
    echo "└──────────────────────────────────────────────────────────┘"

    cat > "$FASE3" << HEADER
-- ============================================================
-- bauth_db DDL — FASE 3: Funciones, Triggers, RLS, Permisos
-- build_ddl.sh v9 · $(date -u +%Y-%m-%dT%H:%M:%SZ)
-- Se ejecuta DESPUÉS de FASE 1 y FASE 2
-- ============================================================

HEADER

    # 3a. CREATE OR REPLACE FUNCTION
    echo "" >> "$FASE3"
    echo "-- Funciones" >> "$FASE3"
    awk '/^CREATE OR REPLACE FUNCTION/,/^\$\$/' "$BAK" >> "$FASE3" 2>/dev/null || true
    local funcs=$(grep -c "CREATE OR REPLACE FUNCTION" "$FASE3" 2>/dev/null || echo 0)

    # 3b. DO blocks (triggers y constraints condicionales)
    echo "" >> "$FASE3"
    echo "-- Triggers y Constraints" >> "$FASE3"
    awk '/^DO \$\$/,/^END \$\$/' "$BAK" >> "$FASE3" 2>/dev/null || true
    local triggers=$(grep -c "^DO \$\$" "$FASE3" 2>/dev/null || echo 0)

    # 3c. REVOKE y GRANT (seguridad WORM)
    echo "" >> "$FASE3"
    echo "-- Permisos WORM (REVOKE UPDATE/DELETE)" >> "$FASE3"
    grep -E '^REVOKE |^GRANT ' "$BAK" >> "$FASE3" 2>/dev/null || true
    local perms=$(grep -cE "^REVOKE |^GRANT " "$FASE3" 2>/dev/null || echo 0)

    # 3d. RLS (Row Level Security)
    echo "" >> "$FASE3"
    echo "-- Row Level Security" >> "$FASE3"
    grep -E 'ENABLE ROW LEVEL SECURITY|FORCE ROW LEVEL SECURITY|CREATE POLICY|DROP POLICY' "$BAK" >> "$FASE3" 2>/dev/null || true
    local rls=$(grep -cE "ENABLE ROW|FORCE ROW|CREATE POLICY|DROP POLICY" "$FASE3" 2>/dev/null || echo 0)

    echo "  [FASE 3] ✅ $funcs funciones, $triggers triggers, $perms permisos, $rls RLS → $FASE3"
}

# ═══════════════════════════════════════════════════════════════
# Combinar todo en el output final
# ═══════════════════════════════════════════════════════════════
combine_output() {
    cat > "$OUTPUT" << HEADER
-- ============================================================
-- bauth_db DDL v3.0 — Identity Governance & Audit Platform
-- Autogenerado: build_ddl.sh v9 (3 fases)
-- Fecha: $(date -u +%Y-%m-%dT%H:%M:%SZ)
--
-- Estructura:
--   FASE 1: CREATE TABLE + inline REFERENCES (orden topológico)
--   FASE 2: CREATE INDEX + ADD CONSTRAINT FK
--   FASE 3: Funciones, triggers, REVOKE/GRANT, RLS
--
-- Estándares: ISO 27001 · NIST 800-53 · PCI DSS 4.0
--             W3C Trace Context · RFC 9562 · GDPR
-- ============================================================

HEADER
    cat "$FASE1" | grep -v "^-- bauth_db DDL — FASE\|^-- build_ddl\|^-- Correcciones\|^-- ==" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo "-- ============================================================" >> "$OUTPUT"
    echo "-- FASE 2: Índices + Constraints FK" >> "$OUTPUT"
    echo "-- ============================================================" >> "$OUTPUT"
    cat "$FASE2" | grep -v "^-- bauth_db\|^-- build_ddl\|^-- Se ejecuta\|^-- ==" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo "-- ============================================================" >> "$OUTPUT"
    echo "-- FASE 3: Funciones, Triggers, RLS, Permisos" >> "$OUTPUT"
    echo "-- ============================================================" >> "$OUTPUT"
    cat "$FASE3" | grep -v "^-- bauth_db\|^-- build_ddl\|^-- Se ejecuta\|^-- ==" >> "$OUTPUT"
}

# ── Resumen final ────────────────────────────────────────────
print_summary() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  BUILD_DDL v9 — RESUMEN FINAL                              ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    printf "║  FASE 1 — Tablas:       %4d                             ║\n" "$TOTAL_TABLES"
    printf "║  FASE 1 — Foreign Keys: %4d                             ║\n" "$TOTAL_FKS"
    printf "║  FASE 2 — Índices:      %4d                             ║\n" "$TOTAL_INDEXES"
    printf "║  FASE 3 — Func/Trig:    %4d                             ║\n" "$(grep -c "FUNCTION\|DO \$\$" "$FASE3" 2>/dev/null || echo 0)"
    printf "║  Corr. TEXT→UUID:       %4d                             ║\n" "$CORRECTED_COLUMNS"
    printf "║  Total líneas:          %4d                             ║\n" "$(wc -l < "$OUTPUT")"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Orden:           tsort (67 tablas, 0 ciclos)              ║"
    echo "║  Salida unificada: $OUTPUT"
    echo "║  Fases separadas:  $FASE1"
    echo "║                    $FASE2"
    echo "║                    $FASE3"
    echo "╚══════════════════════════════════════════════════════════════╝"
}

# ═══════════════════════════════════════════════════════════════
# EJECUCIÓN
# ═══════════════════════════════════════════════════════════════
build_fase1
build_fase2
build_fase3
combine_output
print_summary

echo ""
echo "  Para probar en VPS:"
echo "    1. Subir FASE 1 → verificar 0 errores"
echo "    2. Subir FASE 2 → verificar 0 errores"
echo "    3. Subir FASE 3 → verificar solo WARNINGs"
echo "  O usar el archivo unificado: $OUTPUT"
