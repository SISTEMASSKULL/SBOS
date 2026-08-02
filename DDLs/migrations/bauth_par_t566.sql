-- bauth_par_t566.sql
-- Cierra: GAP-OAUTH-01 (A.73 v1.4.0)
-- Norma: RFC 9126 (PAR) · FAPI 2.0 Advanced Security Profile §4.3.1.1
-- Propósito: implementar soporte DDL para Pushed Authorization Requests.
--   El cliente empuja los parámetros de autorización al endpoint PAR y recibe
--   un request_uri opaco de un solo uso (TTL 60-600s). FAPI 2.0 Advanced
--   exige PAR para todos los flujos de autorización de alta seguridad.
-- Cambios:
--   (1) ALTER TABLE bauth.fed_client: +par_required BOOLEAN
--   (2) CREATE TABLE bauth.fed_par_request (T-566)
-- Idempotente: ADD COLUMN IF NOT EXISTS + CREATE TABLE IF NOT EXISTS.
-- Autor: bAuth DDL · 2026-08-02

SET lock_timeout = '5s';

-- =============================================================================
-- §1 COLUMNA par_required EN fed_client
-- =============================================================================

ALTER TABLE bauth.fed_client
    ADD COLUMN IF NOT EXISTS par_required BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN bauth.fed_client.par_required IS
'[RFC 9126] TRUE = este cliente SOLO acepta flujos PAR; el daemon rechaza
authorization requests directos al /oauth/authorize sin request_uri previo.
Obligatorio activar para fapi_profile IN (ADVANCED, FAPI2). Default FALSE
para compatibilidad con clientes existentes que no usan PAR.';

-- =============================================================================
-- §2 TABLA fed_par_request (T-566)
-- =============================================================================

CREATE TABLE IF NOT EXISTS bauth.fed_par_request (
    par_id                UUID        NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    request_uri           TEXT        NOT NULL UNIQUE,
    client_id             UUID        NOT NULL REFERENCES bauth.fed_client(client_id) ON DELETE CASCADE,
    tenant_id             UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    request_payload       JSONB       NOT NULL,
    code_challenge        TEXT        NULL,
    code_challenge_method TEXT        NOT NULL DEFAULT 'S256'
                              CONSTRAINT chk_fpar_method CHECK (code_challenge_method IN ('S256','plain')),
    used                  BOOLEAN     NOT NULL DEFAULT false,
    used_at               TIMESTAMPTZ NULL,
    expires_at            TIMESTAMPTZ NOT NULL,
    ctx_id                TEXT        NOT NULL DEFAULT 'system',
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_fpar_used_at CHECK (used = false OR used_at IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_fpar_expires ON bauth.fed_par_request (expires_at) WHERE used = false;
CREATE INDEX IF NOT EXISTS idx_fpar_client  ON bauth.fed_par_request (client_id, created_at DESC);

COMMENT ON TABLE bauth.fed_par_request IS
'FEDERACIÓN OIDC | Pushed Authorization Requests — RFC 9126. El cliente envía los parámetros
de autorización al endpoint PAR y recibe un request_uri opaco de un solo uso (TTL 60-600s).
FAPI 2.0 Advanced exige PAR para todos los flujos de autorización de alta seguridad.
used+used_at: un solo uso (chk_fpar_used_at fuerza used_at cuando used=true).
Limpieza: job diario elimina filas con expires_at < now(); idx_fpar_expires optimiza.
Estándar: RFC 9126 (PAR), FAPI 2.0 Advanced Security Profile §4.3.1.1. T-566.';

COMMENT ON COLUMN bauth.fed_par_request.request_uri IS
'[RFC 9126 §2.2] URN opaco de un solo uso: "urn:ietf:params:oauth:request_uri:<random>".
Generado por el daemon Rust con 128 bits de entropía. UNIQUE constraint garantiza unicidad.
El authorization endpoint acepta este valor en el parámetro "request_uri" del GET/POST.';

COMMENT ON COLUMN bauth.fed_par_request.request_payload IS
'Parámetros completos del authorization request en JSONB: response_type, client_id,
redirect_uri, scope, state, nonce, code_challenge, code_challenge_method, etc.
El daemon los valida al recibir el PAR request y los almacena aquí para recuperarlos
cuando el authorization endpoint recibe el request_uri.';

COMMENT ON COLUMN bauth.fed_par_request.expires_at IS
'[RFC 9126 §2.1] TTL del request_uri. El servidor DEBE asignar TTL entre 5 y 600 segundos.
bAuth usa 300s por defecto (configurable en cfg_policy_library). Después de expires_at,
el authorization endpoint rechaza el request_uri con error "invalid_request_uri".';

COMMENT ON COLUMN bauth.fed_par_request.used IS
'TRUE = el request_uri fue consumido por el authorization endpoint. Un solo uso:
el daemon marca used=true y registra used_at al aceptar el request_uri.
Cualquier intento posterior con el mismo request_uri → error "invalid_request_uri".';

-- =============================================================================
-- §3 VERIFICACIÓN
-- =============================================================================

-- Confirmar columna par_required en fed_client
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema = 'bauth'
  AND table_name   = 'fed_client'
  AND column_name  = 'par_required';

-- Confirmar tabla y estructura fed_par_request
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'bauth'
  AND table_name   = 'fed_par_request'
ORDER BY ordinal_position;

-- Confirmar constraints
SELECT conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid = 'bauth.fed_par_request'::regclass
  AND conname IN ('chk_fpar_method','chk_fpar_used_at');

-- Confirmar índices
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'bauth'
  AND tablename  = 'fed_par_request';

-- Prueba funcional: INSERT válido (S256, not used, expires en 5 min)
DO $$
DECLARE
    v_client_id UUID;
    v_tenant_id UUID;
BEGIN
    SELECT client_id INTO v_client_id FROM bauth.fed_client LIMIT 1;
    SELECT tenant_id INTO v_tenant_id FROM bauth.idn_tenant  LIMIT 1;

    IF v_client_id IS NULL OR v_tenant_id IS NULL THEN
        RAISE NOTICE 'SKIP: no hay filas en fed_client o idn_tenant — prueba omitida.';
        RETURN;
    END IF;

    INSERT INTO bauth.fed_par_request
        (request_uri, client_id, tenant_id, request_payload, code_challenge, expires_at)
    VALUES (
        'urn:ietf:params:oauth:request_uri:test-' || gen_random_uuid()::text,
        v_client_id, v_tenant_id,
        '{"response_type":"code","scope":"openid profile"}'::jsonb,
        'abc123_test_challenge',
        now() + interval '5 minutes'
    );
    RAISE NOTICE 'OK: INSERT en fed_par_request exitoso.';

    -- Limpiar fila de prueba
    DELETE FROM bauth.fed_par_request WHERE request_uri LIKE 'urn:ietf:params:oauth:request_uri:test-%';
    RAISE NOTICE 'OK: fila de prueba eliminada.';
END $$;
