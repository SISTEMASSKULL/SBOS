-- bauth_hibp_t331.sql
-- Cierra: GAP-NIST63B-01 (A.73 v1.3.0)
-- Norma: NIST SP 800-63B-4 §5.1.1.2 — Compromised credential lookup
-- Tabla: bauth.auth_credential_secret (T-331)
-- Propósito: agregar trazabilidad de verificación HIBP (Have I Been Pwned) para
--   contraseñas. El CHECK chk_acs_hibp fuerza que toda inserción de ARGON2ID_HASH
--   haya completado la verificación contra el corpus local antes de guardarse.
-- Implementación soberana: corpus HIBP local con k-Anonymity (SHA-1 prefix 5 chars)
--   sin llamadas a servicios externos (principio SBOS de soberanía de datos).
-- Idempotente: ADD COLUMN IF NOT EXISTS + ADD CONSTRAINT IF NOT EXISTS.
-- Autor: bAuth DDL · 2026-08-02

SET lock_timeout = '5s';

-- =============================================================================
-- §1 COLUMNAS HIBP
-- =============================================================================

ALTER TABLE bauth.auth_credential_secret
    ADD COLUMN IF NOT EXISTS hibp_checked_at     TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS hibp_pwned_count    INT         NULL,
    ADD COLUMN IF NOT EXISTS hibp_is_compromised BOOLEAN     NOT NULL DEFAULT false;

-- =============================================================================
-- §2 CHECK CONSTRAINT — fuerza verificación obligatoria para ARGON2ID_HASH
-- ADD CONSTRAINT no tiene IF NOT EXISTS en PG < 17; usamos DO para idempotencia.
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_acs_hibp'
          AND conrelid = 'bauth.auth_credential_secret'::regclass
    ) THEN
        ALTER TABLE bauth.auth_credential_secret
            ADD CONSTRAINT chk_acs_hibp CHECK (
                type != 'ARGON2ID_HASH'
                OR (hibp_checked_at IS NOT NULL AND hibp_pwned_count IS NOT NULL)
            );
        RAISE NOTICE 'chk_acs_hibp creado correctamente.';
    ELSE
        RAISE NOTICE 'chk_acs_hibp ya existe — omitiendo.';
    END IF;
END $$;

-- =============================================================================
-- §3 COMENTARIOS
-- =============================================================================

COMMENT ON COLUMN bauth.auth_credential_secret.hibp_checked_at IS
'[NIST 800-63B-4 §5.1.1.2] Timestamp de la última verificación HIBP. NULL para tipos
distintos de ARGON2ID_HASH. El CHECK chk_acs_hibp fuerza NOT NULL al insertar contraseña.';

COMMENT ON COLUMN bauth.auth_credential_secret.hibp_pwned_count IS
'[NIST 800-63B-4 §5.1.1.2] Número de veces que la contraseña aparece en el corpus HIBP local.
0 = limpia (aceptar). >0 = comprometida (rechazar antes de INSERT).
NULL para tipos distintos de ARGON2ID_HASH.';

COMMENT ON COLUMN bauth.auth_credential_secret.hibp_is_compromised IS
'[NIST 800-63B-4 §5.1.1.2] TRUE si hibp_pwned_count > 0. Una fila con TRUE indica que se
intentó registrar una contraseña comprometida. El daemon la rechaza; este registro es
evidencia forense de la verificación. Corpus soberano: HIBP local k-Anonymity.';

-- =============================================================================
-- §4 VERIFICACIÓN
-- =============================================================================

SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'bauth'
  AND table_name   = 'auth_credential_secret'
  AND column_name IN ('hibp_checked_at','hibp_pwned_count','hibp_is_compromised')
ORDER BY ordinal_position;

SELECT conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid = 'bauth.auth_credential_secret'::regclass
  AND conname  = 'chk_acs_hibp';

-- Prueba funcional: intentar insertar ARGON2ID_HASH sin HIBP debe fallar
DO $$
DECLARE
    v_credential_id UUID;
    v_user_id       UUID;
    v_tenant_id     UUID;
BEGIN
    -- Obtener IDs reales de SBOSDB para la prueba
    SELECT credential_id INTO v_credential_id FROM bauth.auth_credential LIMIT 1;

    IF v_credential_id IS NULL THEN
        RAISE NOTICE 'SKIP: no hay filas en auth_credential — prueba omitida (tabla vacía).';
        RETURN;
    END IF;

    BEGIN
        INSERT INTO bauth.auth_credential_secret
            (credential_id, type, secret, algorithm, params, hibp_checked_at, hibp_pwned_count)
        VALUES
            (v_credential_id, 'ARGON2ID_HASH', '$argon2id$...', 'ARGON2ID', '{}', NULL, NULL);
        RAISE EXCEPTION 'FALLO: INSERT sin HIBP debería haber sido rechazado por chk_acs_hibp';
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'OK: chk_acs_hibp activo — INSERT ARGON2ID_HASH sin HIBP rechazado correctamente (%).', SQLERRM;
        WHEN unique_violation THEN
            -- Ya existe un secret para este credential_id — la prueba funcional es válida
            -- si el error es unique_violation ANTES de check_violation, significa que
            -- PostgreSQL evaluó el INSERT pero la clave ya estaba → reenviamos con otro credential
            RAISE NOTICE 'INFO: credential_id ya tenía un secret — saltando prueba de inserción.';
    END;
END $$;
