-- ============================================================================
-- bauth_47b__role_status_enum.sql — ENUM de ciclo de vida de roles RBAC
-- IDEMPOTENTE: guard IS NOT EXISTS para ENUM · ALTER solo si columna es text
-- Prerequisito: bauth_47a__idn_role_type.sql (schema bauth debe existir)
-- Norma: NIST SP 800-53 AC-2(j) — deshabilitar cuentas cuando ya no necesarias
-- Se ejecuta ANTES de bauth_48 (garantizado por orden alfabético 47b < 48)
-- ============================================================================
-- Migración de valores anteriores (en español → normativo inglés):
--   DEFINIDO    → ACTIVE    (roles de producción: activos por defecto)
--   DESARROLLADO → DRAFT    (en desarrollo, aún no revisados)
--   REVISADO    → REVIEW    (en revisión formal)
--   AUTORIZADO  → ACTIVE    (aprobados = activos)
--   PUBLICADO   → ACTIVE    (publicados = activos)
--   DEPRECADO   → DEPRECATED
--   RETIRADO    → ARCHIVED
-- ============================================================================

SET lock_timeout = '10s';
BEGIN;

-- ═══ Crear ENUM bauth.role_status_type si no existe ═══
-- 6 estados normalizados según NIST AC-2(j) + ISO 27001 A.5.18
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_type t
        JOIN   pg_namespace n ON t.typnamespace = n.oid
        WHERE  t.typname  = 'role_status_type'
          AND  n.nspname  = 'bauth'
    ) THEN
        CREATE TYPE bauth.role_status_type AS ENUM (
            'DRAFT',        -- definido, pendiente aprobación: no asignable
            'REVIEW',       -- en revisión formal (role_owner + aprobador): no asignable
            'ACTIVE',       -- en producción: asignable, sincronizado KC + Tryton
            'SUSPENDED',    -- congelado temporalmente: usuarios existentes bloqueados en KC
            'DEPRECATED',   -- obsoleto: no asignable a nuevos; existentes hasta remoción manual
            'ARCHIVED'      -- cerrado definitivamente: sin usuarios; eliminado de KC y Tryton
        );
    END IF;
END;
$$;

-- ═══ Migrar columna status: text → role_status_type ═══
-- Guard: solo ejecuta si la columna sigue siendo text (primera ejecución)
-- En re-ejecuciones el tipo ya es role_status_type y el bloque es no-op
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   information_schema.columns
        WHERE  table_schema = 'bauth'
          AND  table_name   = 'idn_role_template'
          AND  column_name  = 'status'
          AND  data_type    = 'text'
    ) THEN
        -- 1. Eliminar DEFAULT text — PostgreSQL no puede castear default 'DEFINIDO'::text al ENUM
        ALTER TABLE bauth.idn_role_template ALTER COLUMN status DROP DEFAULT;

        -- 2. Eliminar CHECK constraint anterior — sus valores son reemplazados por el ENUM
        ALTER TABLE bauth.idn_role_template DROP CONSTRAINT IF EXISTS chk_brt_status;

        -- 3. Mapear valores anteriores (español) → estados normativos (inglés)
        UPDATE bauth.idn_role_template SET status = 'ACTIVE'     WHERE status IN ('DEFINIDO', 'AUTORIZADO', 'PUBLICADO');
        UPDATE bauth.idn_role_template SET status = 'DRAFT'      WHERE status = 'DESARROLLADO';
        UPDATE bauth.idn_role_template SET status = 'REVIEW'     WHERE status = 'REVISADO';
        UPDATE bauth.idn_role_template SET status = 'DEPRECATED' WHERE status = 'DEPRECADO';
        UPDATE bauth.idn_role_template SET status = 'ARCHIVED'   WHERE status = 'RETIRADO';

        -- 4. Cambiar tipo de columna (USING convierte text → enum)
        ALTER TABLE bauth.idn_role_template
            ALTER COLUMN status TYPE bauth.role_status_type
                USING status::bauth.role_status_type;

        -- 5. Fijar default normativo
        ALTER TABLE bauth.idn_role_template
            ALTER COLUMN status SET DEFAULT 'ACTIVE'::bauth.role_status_type;
    END IF;
END;
$$;

COMMIT;

-- ═══ Verificación post-ejecución ═══
SELECT 'tipo columna status' AS metrica,
       data_type || ' (' || udt_name || ')' AS valor
FROM   information_schema.columns
WHERE  table_schema = 'bauth'
  AND  table_name   = 'idn_role_template'
  AND  column_name  = 'status';

SELECT 'distribución status' AS metrica,
       status::text || ' → ' || COUNT(*)::text AS valor
FROM   bauth.idn_role_template
GROUP  BY status
ORDER  BY status;

SELECT 'constraint chk_brt_status eliminado' AS metrica,
       CASE WHEN COUNT(*) = 0 THEN 'SÍ ✓' ELSE 'NO — aún existe' END AS valor
FROM   pg_constraint
WHERE  conrelid = 'bauth.idn_role_template'::regclass
  AND  conname  = 'chk_brt_status';
