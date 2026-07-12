-- ============================================================================
-- bauth_44__gap04_worm_hash_chain.sql — GAP-04: hash-chain SHA-256 en tablas WORM
--
-- Propósito: cerrar el GAP-04 de BAUTH-IDENTITY-GOVERNANCE-GAPS.md — proteger
--   los registros de auditoría contra manipulación mediante encadenamiento
--   criptográfico (cada fila incluye el hash de la anterior).
-- Norma: PCI DSS 4.0 Req 10.3.2 · ISO 27001:2022 A.8.15 · NIST 800-53 AU-9.
-- Alcance (schema bauth — gobernado por bAuth):
--   1. Tabla de cabezas de cadena `aud_chain_head` (puntero al último hash).
--   2. Función-trigger genérica `fn_worm_hash_chain()` (SECURITY DEFINER).
--   3. Columnas prev_hash/entry_hash en las 6 tablas WORM que no las tenían.
--   4. Trigger en las 10 tablas de la cadena (4 que ya tenían columnas + 6).
--   5. REVOKE UPDATE/DELETE en todas (WORM real, patrón de sync_log).
--
-- Diseño (por qué cabeza-de-cadena y no ORDER BY):
--   · O(1) por inserción — sin buscar "la última fila" (imposible de forma
--     uniforme: ses_superuser_context usa UUID v4 no ordenable y las tablas
--     particionadas fragmentarían la búsqueda por partición).
--   · `pg_advisory_xact_lock` por cadena serializa inserciones concurrentes —
--     sin él, dos INSERT simultáneos leerían el mismo prev y bifurcarían la cadena.
--   · El trigger corre BEFORE INSERT: los INSERT existentes del daemon quedan
--     válidos SIN tocar código Rust (hoy no envían entry_hash y la columna es
--     NOT NULL en aud_event — defecto que esta migración sana de raíz).
--   · sha256() es built-in de PostgreSQL (≥11) — sin dependencia de pgcrypto.
--
-- Verificación de la cadena (auditor externo): recorrer las filas siguiendo
--   prev_hash→entry_hash y recomputar sha256(COALESCE(prev,'GENESIS')||'|'||
--   payload_jsonb_sin_campos_de_cadena). La fila adulterada rompe la cadena.
--
-- Estado: PROPUESTA EJECUTABLE — aplicar vía instalador (bosctl) y verificar
--   en VPS (Testeador, suite 7.04). Idempotente (IF NOT EXISTS / OR REPLACE).
-- Autor: bauth-developer · Fecha: 2026-07-11
-- ============================================================================

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- 1. Cabezas de cadena — el puntero al último hash de cada cadena WORM.
--    NO es WORM (es un puntero mutable); solo la función-trigger la escribe.
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bauth.aud_chain_head (
    chain_name  TEXT        PRIMARY KEY,   -- nombre lógico de la cadena (= tabla padre)
    last_hash   TEXT        NOT NULL,      -- entry_hash de la última fila encadenada
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE bauth.aud_chain_head IS
    'GAP-04: cabeza de cada hash-chain WORM. Solo la escribe fn_worm_hash_chain() '
    '(SECURITY DEFINER). PCI DSS 10.3.2. No consultar como fuente de verdad: la '
    'verdad es la cadena en cada tabla; esto es el puntero O(1) de inserción.';

-- Nadie escribe la cabeza directamente — solo la función (SECURITY DEFINER).
REVOKE INSERT, UPDATE, DELETE ON bauth.aud_chain_head FROM PUBLIC;

-- ────────────────────────────────────────────────────────────────────────────
-- 2. Función-trigger genérica del encadenamiento.
--    TG_ARGV[0] = nombre lógico de la cadena (estable aunque la tabla esté
--    particionada: las particiones heredan el trigger del padre con sus args).
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION bauth.fn_worm_hash_chain() RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = bauth, pg_temp
AS $$
DECLARE
    v_chain   TEXT := COALESCE(TG_ARGV[0], TG_TABLE_NAME);
    v_prev    TEXT;
    v_payload TEXT;
BEGIN
    -- Serializa las inserciones de ESTA cadena dentro de la transacción:
    -- evita que dos INSERT concurrentes lean el mismo prev y bifurquen.
    PERFORM pg_advisory_xact_lock(hashtextextended('worm:' || v_chain, 0));

    SELECT last_hash INTO v_prev
      FROM bauth.aud_chain_head
     WHERE chain_name = v_chain;

    -- Payload canónico: la fila completa SIN los campos de la propia cadena.
    -- jsonb ordena las claves → serialización determinista y reproducible.
    v_payload := (to_jsonb(NEW) - 'prev_hash' - 'entry_hash')::text;

    NEW.prev_hash  := v_prev;  -- NULL solo en el génesis de la cadena
    NEW.entry_hash := encode(
        sha256(convert_to(COALESCE(v_prev, 'GENESIS') || '|' || v_payload, 'UTF8')),
        'hex'
    );

    INSERT INTO bauth.aud_chain_head (chain_name, last_hash, updated_at)
    VALUES (v_chain, NEW.entry_hash, now())
    ON CONFLICT (chain_name)
    DO UPDATE SET last_hash = EXCLUDED.last_hash, updated_at = now();

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION bauth.fn_worm_hash_chain() IS
    'GAP-04: encadena cada INSERT WORM — prev_hash = cabeza de la cadena; '
    'entry_hash = sha256(prev|fila_canónica). Advisory lock por cadena. '
    'PCI DSS 10.3.2 · ISO 27001 A.8.15 · NIST 800-53 AU-9.';

-- ────────────────────────────────────────────────────────────────────────────
-- 3. Columnas de cadena en las 6 tablas WORM que NO las tenían.
--    Nullable: las filas históricas quedan NULL (la cadena nace HOY);
--    el trigger llena toda fila nueva. Sin backfill (tablas potencialmente
--    grandes; la integridad retroactiva la da el ancla Merkle D12 donde exista).
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE bauth.sync_log              ADD COLUMN IF NOT EXISTS prev_hash TEXT, ADD COLUMN IF NOT EXISTS entry_hash TEXT;
ALTER TABLE bauth.ses_superuser_context ADD COLUMN IF NOT EXISTS prev_hash TEXT, ADD COLUMN IF NOT EXISTS entry_hash TEXT;
ALTER TABLE bauth.ath_login_attempt     ADD COLUMN IF NOT EXISTS prev_hash TEXT, ADD COLUMN IF NOT EXISTS entry_hash TEXT;
ALTER TABLE bauth.privilege_atom_audit  ADD COLUMN IF NOT EXISTS prev_hash TEXT, ADD COLUMN IF NOT EXISTS entry_hash TEXT;
ALTER TABLE bauth.ath_revocation        ADD COLUMN IF NOT EXISTS prev_hash TEXT, ADD COLUMN IF NOT EXISTS entry_hash TEXT;
ALTER TABLE bauth.aud_policy_change     ADD COLUMN IF NOT EXISTS prev_hash TEXT, ADD COLUMN IF NOT EXISTS entry_hash TEXT;

-- ────────────────────────────────────────────────────────────────────────────
-- 4. Triggers — las 10 cadenas WORM (4 con columnas preexistentes + las 6 nuevas).
--    En particionadas (aud_event, ath_login_attempt, privilege_atom_audit) el
--    trigger BEFORE ROW sobre el padre se propaga a las particiones (PG ≥13);
--    TG_ARGV[0] mantiene UNA cadena lógica por tabla padre.
-- ────────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_worm_chain ON bauth.aud_event;
CREATE TRIGGER trg_worm_chain BEFORE INSERT ON bauth.aud_event
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_worm_hash_chain('aud_event');

DROP TRIGGER IF EXISTS trg_worm_chain ON bauth.bos_rol_template_history;
CREATE TRIGGER trg_worm_chain BEFORE INSERT ON bauth.bos_rol_template_history
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_worm_hash_chain('bos_rol_template_history');

DROP TRIGGER IF EXISTS trg_worm_chain ON bauth.fin_approval;
CREATE TRIGGER trg_worm_chain BEFORE INSERT ON bauth.fin_approval
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_worm_hash_chain('fin_approval');

DROP TRIGGER IF EXISTS trg_worm_chain ON bauth.fin_document_operation;
CREATE TRIGGER trg_worm_chain BEFORE INSERT ON bauth.fin_document_operation
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_worm_hash_chain('fin_document_operation');

DROP TRIGGER IF EXISTS trg_worm_chain ON bauth.sync_log;
CREATE TRIGGER trg_worm_chain BEFORE INSERT ON bauth.sync_log
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_worm_hash_chain('sync_log');

DROP TRIGGER IF EXISTS trg_worm_chain ON bauth.ses_superuser_context;
CREATE TRIGGER trg_worm_chain BEFORE INSERT ON bauth.ses_superuser_context
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_worm_hash_chain('ses_superuser_context');

DROP TRIGGER IF EXISTS trg_worm_chain ON bauth.ath_login_attempt;
CREATE TRIGGER trg_worm_chain BEFORE INSERT ON bauth.ath_login_attempt
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_worm_hash_chain('ath_login_attempt');

DROP TRIGGER IF EXISTS trg_worm_chain ON bauth.privilege_atom_audit;
CREATE TRIGGER trg_worm_chain BEFORE INSERT ON bauth.privilege_atom_audit
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_worm_hash_chain('privilege_atom_audit');

DROP TRIGGER IF EXISTS trg_worm_chain ON bauth.ath_revocation;
CREATE TRIGGER trg_worm_chain BEFORE INSERT ON bauth.ath_revocation
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_worm_hash_chain('ath_revocation');

DROP TRIGGER IF EXISTS trg_worm_chain ON bauth.aud_policy_change;
CREATE TRIGGER trg_worm_chain BEFORE INSERT ON bauth.aud_policy_change
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_worm_hash_chain('aud_policy_change');

-- ────────────────────────────────────────────────────────────────────────────
-- 5. WORM real: REVOKE UPDATE/DELETE (patrón exacto de sync_log — FROM PUBLIC
--    y FROM bauth). Verificado: el daemon NO ejecuta UPDATE sobre ninguna
--    (grep 2026-07-11: 0 coincidencias) — el REVOKE no rompe operación.
--    Nota: ses_context NO entra (las sesiones SÍ se actualizan: state/invalidated_at).
-- ────────────────────────────────────────────────────────────────────────────
REVOKE UPDATE, DELETE ON bauth.aud_event                 FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.bos_rol_template_history  FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.fin_approval              FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.fin_document_operation    FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.ses_superuser_context     FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.ath_login_attempt         FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.privilege_atom_audit      FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.ath_revocation            FROM PUBLIC;
REVOKE UPDATE, DELETE ON bauth.aud_policy_change         FROM PUBLIC;
-- (sync_log ya tiene su REVOKE en sbos_00 — se conserva)

-- ────────────────────────────────────────────────────────────────────────────
-- 6. Comentarios de cumplimiento
-- ────────────────────────────────────────────────────────────────────────────
COMMENT ON COLUMN bauth.sync_log.entry_hash IS
    'GAP-04: sha256(prev|fila). Cadena WORM — PCI DSS 10.3.2. Poblado por trg_worm_chain.';
COMMENT ON COLUMN bauth.ses_superuser_context.entry_hash IS
    'GAP-04: sha256(prev|fila). Todo contexto de superusuario queda encadenado e inmutable.';
COMMENT ON COLUMN bauth.ath_login_attempt.entry_hash IS
    'GAP-04: sha256(prev|fila). Un atacante no puede borrar/alterar sus intentos de login.';
COMMENT ON COLUMN bauth.privilege_atom_audit.entry_hash IS
    'GAP-04: cadena local por fila; complementa (no reemplaza) el ancla Merkle D12 (merkle_batch_id).';
COMMENT ON COLUMN bauth.ath_revocation.entry_hash IS
    'GAP-04: sha256(prev|fila). La revocación de credenciales es evidencia inmutable.';
COMMENT ON COLUMN bauth.aud_policy_change.entry_hash IS
    'GAP-04: sha256(prev|fila). Cambios de política (T-148) encadenados — NIST AU-9.';

COMMIT;

-- ============================================================================
-- Verificación post-aplicación (Testeador — evidencia AA-1, manual 7.04):
--   1) INSERT de prueba en bauth.sync_log → SELECT prev_hash, entry_hash
--      FROM bauth.sync_log ORDER BY created_at DESC LIMIT 2;
--      → entry_hash NO nulo; el 2º INSERT tiene prev_hash = entry_hash del 1º.
--   2) UPDATE bauth.aud_event SET outcome='X' → DEBE fallar (permiso denegado).
--   3) SELECT * FROM bauth.aud_chain_head; → una fila por cadena activa.
-- ============================================================================
