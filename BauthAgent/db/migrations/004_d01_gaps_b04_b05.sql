-- ============================================================================
-- 004_d01_gaps_b04_b05.sql — Dominio D01: GAP-D01-01 (B04) y GAP-D01-02 (B05)
-- ============================================================================
-- Propósito : Cierra los gaps B04 y B05 del dominio D01 (Control de Acceso Lógico).
--             GAP-D01-01 (B04): PIP T-500 para acceso a nivel de campo (field-level).
--             GAP-D01-02 (B05): Contrato de acceso T-201 con WORM parcial.
--             Columna contrato_id en privilege_atom_grant (T-170) para trazabilidad.
-- Normas    : SCIM 2.0 RFC 7643 §4 · ISO 27001:2022 A.9.2.2 · NIST SP 800-53 R5 AC-2
--             PCI DSS 4.0 Req 7.2 · SOX §404 · ISO/IEC 24760-1:2019 §5
-- Fuente    : A.65.03.01.02_COMPLETITUD_D01.md v1.2.0 §6 (B04) y §7 (B05)
-- Autor     : bauth-developer · 2026-07-29
-- APROBACIÓN REQUERIDA antes de aplicar en producción (ADR-016, feedback DDL)
-- ============================================================================
-- IDEMPOTENCIA: CREATE TABLE IF NOT EXISTS · ADD COLUMN IF NOT EXISTS.
-- Es seguro ejecutar múltiples veces.
-- ============================================================================
-- NOTA ARQUITECTÓNICA (DDL canónico):
--   En el DDL canónico (SBOS_db_V2_DDL.sql), T-201 y T-500 están ya en sus
--   CREATE TABLE respectivos, y privilege_atom_grant incluye contrato_id desde
--   su CREATE TABLE. Este archivo es solo para migraciones incrementales en
--   bases de datos creadas antes de esta versión del DDL canónico.
-- ============================================================================

BEGIN;
SET lock_timeout = '5s';

-- ============================================================================
-- PASO 1 — T-500: bauth.idn_registro_atributo_schema (PIP D98-B01 / D01-B04)
-- PIP (Policy Information Point): esquema canónico de atributos de identidad.
-- SCIM 2.0 RFC 7643 §4 · ISO/IEC 24760-1:2019 §5 · NIST SP 800-162 §3.3
-- ============================================================================

CREATE TABLE IF NOT EXISTS bauth.idn_registro_atributo_schema (
    schema_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id       UUID NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    attr_name       TEXT NOT NULL,
    scim_urn        TEXT NULL,
    display_name    JSONB NOT NULL,
    tipo_dato       TEXT NOT NULL DEFAULT 'STRING'
        CONSTRAINT chk_idras_tipo CHECK (tipo_dato IN (
            'STRING','INTEGER','DECIMAL','BOOLEAN','DATE','DATETIME','UUID','JSON','BINARY')),
    requerido       BOOLEAN NOT NULL DEFAULT FALSE,
    multi_valor     BOOLEAN NOT NULL DEFAULT FALSE,
    longitud_max    INTEGER NULL,
    patron_regex    TEXT NULL,
    clasificacion   TEXT NOT NULL DEFAULT 'INTERNAL'
        CONSTRAINT chk_idras_clas CHECK (clasificacion IN (
            'PUBLIC','INTERNAL','CONFIDENTIAL','PII','SENSITIVE_PII')),
    mutabilidad     TEXT NOT NULL DEFAULT 'READ_WRITE'
        CONSTRAINT chk_idras_mut CHECK (mutabilidad IN (
            'READ_ONLY','READ_WRITE','WRITE_ONLY','IMMUTABLE')),
    returned        TEXT NOT NULL DEFAULT 'DEFAULT'
        CONSTRAINT chk_idras_ret CHECK (returned IN ('ALWAYS','NEVER','DEFAULT','REQUEST')),
    display_mask    TEXT NULL,
    estandar_ref    TEXT NULL,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, attr_name)
);

COMMENT ON TABLE bauth.idn_registro_atributo_schema IS
  '[T-500] [D98-B01] [SCIM 2.0 RFC 7643 §4] [ISO/IEC 24760-1:2019 §5] [NIST SP 800-162 §3.3]
   PIP (Policy Information Point): esquema canónico de atributos de identidad.
   Define atributos válidos para idn_identidad_atributo (T-157, D00).
   clasificacion/display_mask: soporte a control de acceso a nivel de campo (GAP-D01-01).
   NULL tenant_id = esquema global del sistema.';

-- ============================================================================
-- PASO 2 — T-201: bauth.idn_acceso_contrato (D01-B05)
-- Contrato de acceso: registro de gobernanza con WORM parcial.
-- ISO 27001:2022 A.9.2.2 · NIST SP 800-53 R5 AC-2 · PCI DSS 4.0 Req 7.2 · SOX §404
-- ============================================================================

CREATE TABLE IF NOT EXISTS bauth.idn_acceso_contrato (
    contrato_id          UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id            UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    tipo                 TEXT NOT NULL CONSTRAINT chk_iac_tipo CHECK (tipo IN (
        'ACCESO_ROL','ACCESO_ATOMICO','ACCESO_TEMPORAL','ACCESO_EMERGENCIA','ACCESO_DELEGADO')),
    beneficiario_id      UUID NOT NULL REFERENCES bauth.idn_identidad_entidad(entidad_id) ON DELETE RESTRICT,
    role_id              UUID NULL REFERENCES bauth.idn_roles_rol_hierarchical(id) ON DELETE SET NULL,
    id_atom              UUID NULL REFERENCES bauth.idn_roles_template(id) ON DELETE SET NULL,
    CONSTRAINT chk_iac_subject CHECK (role_id IS NOT NULL OR id_atom IS NOT NULL),
    estado               TEXT NOT NULL DEFAULT 'BORRADOR' CONSTRAINT chk_iac_estado CHECK (estado IN (
        'BORRADOR','ACTIVO','SUSPENDIDO','EXPIRADO','REVOCADO')),
    justificacion_negocio TEXT NOT NULL,
    politica_ref         TEXT NULL,
    solicitante_id       UUID NOT NULL REFERENCES bauth.idn_identidad_entidad(entidad_id) ON DELETE RESTRICT,
    aprobador_id         UUID NOT NULL REFERENCES bauth.idn_identidad_entidad(entidad_id) ON DELETE RESTRICT,
    aprobado_at          TIMESTAMPTZ NULL,
    valid_from           TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until          TIMESTAMPTZ NULL,
    proxima_revision     TIMESTAMPTZ NULL,
    revisor_id           UUID NULL REFERENCES bauth.idn_identidad_entidad(entidad_id) ON DELETE SET NULL,
    version_number       INTEGER NOT NULL DEFAULT 1,
    hash_anterior        TEXT NULL,
    ctx_id               TEXT NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iac_tenant    ON bauth.idn_acceso_contrato(tenant_id, estado);
CREATE INDEX IF NOT EXISTS idx_iac_benefici  ON bauth.idn_acceso_contrato(beneficiario_id, estado);
CREATE INDEX IF NOT EXISTS idx_iac_solicit   ON bauth.idn_acceso_contrato(solicitante_id);
CREATE INDEX IF NOT EXISTS idx_iac_aprobador ON bauth.idn_acceso_contrato(aprobador_id);
CREATE INDEX IF NOT EXISTS idx_iac_valid     ON bauth.idn_acceso_contrato(valid_from, valid_until)
    WHERE estado = 'ACTIVO';
CREATE INDEX IF NOT EXISTS idx_iac_revision  ON bauth.idn_acceso_contrato(proxima_revision)
    WHERE proxima_revision IS NOT NULL AND estado = 'ACTIVO';

COMMENT ON TABLE bauth.idn_acceso_contrato IS
  '[T-201] [D01-B05] [ISO 27001:2022 A.9.2.2] [NIST SP 800-53 R5 AC-2] [PCI DSS 4.0 Req 7.2] [SOX §404]
   Contrato de acceso: registro de gobernanza que documenta QUÉ PASÓ y POR QUÉ se otorgó acceso.
   WORM parcial: trigger trg_iac_protect_active impide modificar campos de gobernanza una vez aprobado.
   FK inversa: privilege_atom_grant.contrato_id (nullable) apunta aquí. No usa array (anti-patrón).
   Sujeto: role_id XOR id_atom — CONSTRAINT chk_iac_subject garantiza al menos uno definido.';

-- Trigger WORM parcial: impide modificar campos de gobernanza una vez estado != BORRADOR
CREATE OR REPLACE FUNCTION bauth.fn_iac_protect_active()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.estado != 'BORRADOR' THEN
        IF (
            NEW.tipo                     IS DISTINCT FROM OLD.tipo
            OR NEW.beneficiario_id       IS DISTINCT FROM OLD.beneficiario_id
            OR NEW.role_id               IS DISTINCT FROM OLD.role_id
            OR NEW.id_atom               IS DISTINCT FROM OLD.id_atom
            OR NEW.justificacion_negocio IS DISTINCT FROM OLD.justificacion_negocio
            OR NEW.politica_ref          IS DISTINCT FROM OLD.politica_ref
            OR NEW.solicitante_id        IS DISTINCT FROM OLD.solicitante_id
            OR NEW.aprobador_id          IS DISTINCT FROM OLD.aprobador_id
            OR NEW.aprobado_at           IS DISTINCT FROM OLD.aprobado_at
            OR NEW.valid_from            IS DISTINCT FROM OLD.valid_from
        ) THEN
            RAISE EXCEPTION
                'WORM: campos de gobernanza de contrato_id=% son inmutables (estado=%)',
                OLD.contrato_id, OLD.estado
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    NEW.version_number := OLD.version_number + 1;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION bauth.fn_iac_protect_active() IS
  '[T-201] [ISO 27001 A.8.15] WORM parcial: bloquea edición de campos de gobernanza una vez
   estado != BORRADOR. Incrementa version_number en cada UPDATE para trazabilidad.';

CREATE OR REPLACE TRIGGER trg_iac_protect_active
    BEFORE UPDATE ON bauth.idn_acceso_contrato
    FOR EACH ROW
    EXECUTE FUNCTION bauth.fn_iac_protect_active();

-- ============================================================================
-- PASO 3 — Columna contrato_id en privilege_atom_grant (T-170)
-- Caso excepcional de ALTER TABLE: tabla ya existente en bases pre-migración.
-- En el DDL canónico (SBOS_db_V2_DDL.sql) esta columna está en el CREATE TABLE.
-- ============================================================================

ALTER TABLE bauth.privilege_atom_grant
    ADD COLUMN IF NOT EXISTS contrato_id UUID NULL
        REFERENCES bauth.idn_acceso_contrato(contrato_id) ON DELETE SET NULL;

COMMENT ON COLUMN bauth.privilege_atom_grant.contrato_id IS
  '[T-201] [D01-B05] [ISO 27001:2022 A.9.2.2] FK opcional al contrato de gobernanza.
   Un grant puede existir sin contrato (retrocompatibilidad). Cuando se crea un acceso
   formal, este campo vincula el grant con su registro de autorización ISO 27001.';

CREATE INDEX IF NOT EXISTS idx_pag_contrato
    ON bauth.privilege_atom_grant(contrato_id)
    WHERE contrato_id IS NOT NULL;

COMMIT;
