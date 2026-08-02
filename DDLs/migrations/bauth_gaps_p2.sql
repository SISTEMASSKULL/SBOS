-- bauth_gaps_p2.sql
-- Cierra: GAP-OAUTH-02, GAP-OAUTH-03, GAP-OAUTH-04, GAP-FIDO2-01,
--         GAP-GDPR-01, GAP-GDPR-02, GAP-800207-01, GAP-PCI-02, GAP-NIST63B-02
-- Normas: RFC 9396 · FAPI 2.0 · RFC 7591 · WebAuthn L3 · GDPR Art.20/44
--         NIST SP 800-207 · PCI DSS 11.3 · NIST 800-63B §5.2.3
-- Idempotente: ADD COLUMN IF NOT EXISTS + CREATE TABLE IF NOT EXISTS.
-- Autor: bAuth DDL · 2026-08-02

SET lock_timeout = '5s';

-- =============================================================================
-- §1 ALTER TABLE — tablas existentes
-- =============================================================================

-- GAP-OAUTH-03 — JARM (JWT Secured Authorization Response Mode)
-- RFC 9101 / FAPI 2.0 Advanced: la respuesta del authorization endpoint se
-- entrega como JWT firmado, protegiendo contra open redirector y response
-- tampering. jarm_signing_alg define el algoritmo de firma (RS256/ES256/PS256).
ALTER TABLE bauth.fed_client
    ADD COLUMN IF NOT EXISTS jarm_signing_alg     TEXT NULL,
    ADD COLUMN IF NOT EXISTS jarm_encryption_alg  TEXT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_fc_jarm_sign'
          AND conrelid = 'bauth.fed_client'::regclass
    ) THEN
        ALTER TABLE bauth.fed_client
            ADD CONSTRAINT chk_fc_jarm_sign CHECK (
                jarm_signing_alg IS NULL OR
                jarm_signing_alg IN ('RS256','ES256','PS256','RS384','ES384')
            );
    END IF;
END $$;

COMMENT ON COLUMN bauth.fed_client.jarm_signing_alg    IS '[FAPI 2.0 Adv / RFC 9101] Algoritmo de firma del JWT de respuesta de autorización (JARM). NULL = JARM no activo para este cliente. Valores: RS256, ES256, PS256 (FAPI 2.0 obliga ES256 o PS256). El daemon firma la respuesta del authorization endpoint con la clave Vault correspondiente.';
COMMENT ON COLUMN bauth.fed_client.jarm_encryption_alg IS '[FAPI 2.0 Adv / RFC 9101] Algoritmo de cifrado del JARM (JWE). NULL = respuesta firmada pero no cifrada. Valores: RSA-OAEP, ECDH-ES. Requerido cuando el cliente necesita confidencialidad de la respuesta (típico en Open Banking).';

-- GAP-OAUTH-02 — RAR / authorization_details (RFC 9396)
-- Rich Authorization Requests permiten especificar permisos granulares en el
-- authorization request (ej. "pago de X monto en cuenta Y"). El campo en
-- fed_client declara los tipos que el cliente puede solicitar; el campo en
-- fed_token_issued almacena los authorization_details efectivamente otorgados.
ALTER TABLE bauth.fed_client
    ADD COLUMN IF NOT EXISTS authorization_details_types JSONB NULL;

COMMENT ON COLUMN bauth.fed_client.authorization_details_types IS '[RFC 9396] Array JSONB de tipos de authorization_details que este cliente tiene permitido solicitar. Ejemplo: [{"type":"payment_initiation"},{"type":"account_information"}]. NULL = RAR no habilitado para este cliente. El daemon valida que el request solo incluya tipos declarados aquí.';

ALTER TABLE bauth.fed_token_issued
    ADD COLUMN IF NOT EXISTS authorization_details JSONB NULL;

COMMENT ON COLUMN bauth.fed_token_issued.authorization_details IS '[RFC 9396] authorization_details efectivamente otorgados en este token — subset de lo solicitado, tras evaluación del PDP. NULL para tokens emitidos sin RAR. Inmutable tras emisión: refleja la decisión de autorización en el momento de emitir el token.';

-- GAP-FIDO2-01 — uv_required (WebAuthn L3)
-- WebAuthn L3 §16.1 requiere que los RP puedan exigir verificación de usuario
-- (UV) en el autenticador. uv_required=TRUE obliga UV en cada operación;
-- FALSE = UV preferida pero no obligatoria (comportamiento anterior).
ALTER TABLE bauth.auth_credential_fido2
    ADD COLUMN IF NOT EXISTS uv_required BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN bauth.auth_credential_fido2.uv_required IS '[WebAuthn L3 §16.1] TRUE = verificación de usuario obligatoria en el autenticador (PIN, biometría) para cada operación. FALSE = UV preferida pero no requerida. Para operaciones AAL3 (NIST 800-63B), el daemon fuerza uv_required=TRUE. Configurable por credencial, no por usuario.';

-- =============================================================================
-- §2 TABLAS NUEVAS — simples
-- =============================================================================

-- T-572 — GAP-PCI-02 — vul_pentest_record (PCI DSS 11.3)
-- PCI DSS 11.3 exige pruebas de penetración anuales y tras cambios
-- significativos. Esta tabla registra la evidencia forense de cada pentest
-- realizado sobre los componentes de autenticación del ecosistema.
CREATE TABLE IF NOT EXISTS bauth.vul_pentest_record (
    pentest_id                UUID        NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id                 UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    title                     TEXT        NOT NULL,
    scope                     TEXT        NOT NULL,
    performed_by              TEXT        NOT NULL,
    performed_at              DATE        NOT NULL,
    method                    TEXT        NOT NULL CONSTRAINT chk_vpr_method CHECK (
                                              method IN ('BLACKBOX','GREYBOX','WHITEBOX')),
    findings_critical         INT         NOT NULL DEFAULT 0,
    findings_high             INT         NOT NULL DEFAULT 0,
    findings_medium           INT         NOT NULL DEFAULT 0,
    findings_low              INT         NOT NULL DEFAULT 0,
    report_path               TEXT        NULL,
    remediation_status        TEXT        NOT NULL DEFAULT 'OPEN' CONSTRAINT chk_vpr_status CHECK (
                                              remediation_status IN ('OPEN','IN_PROGRESS','CLOSED','ACCEPTED_RISK')),
    remediated_at             DATE        NULL,
    next_pentest_due          DATE        NULL,
    ctx_id                    TEXT        NOT NULL DEFAULT 'system',
    created_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_vpr_tenant    ON bauth.vul_pentest_record (tenant_id, performed_at DESC);
CREATE INDEX IF NOT EXISTS idx_vpr_due       ON bauth.vul_pentest_record (next_pentest_due) WHERE next_pentest_due IS NOT NULL;
COMMENT ON TABLE bauth.vul_pentest_record IS
'VULNERABILIDADES | Registro de pruebas de penetración — PCI DSS 11.3 obliga pentest anual
y tras cambios significativos. Registra evidencia forense: quién, cuándo, alcance, metodología
y conteo de hallazgos por severidad. remediation_status rastrea el cierre de los hallazgos.
next_pentest_due: calculado por el daemon al cerrar el registro anterior.
Norma: PCI DSS 4.0 Req 11.3, ISO 27001:2022 A.8.8. T-572.';

-- T-570 — GAP-GDPR-02 — gdpr_international_transfer (GDPR Art. 44)
-- GDPR Art. 44-49 exige que las transferencias de datos a países fuera del EEE
-- tengan una base jurídica documentada (decisión de adecuación, SCCs, BCRs, etc.).
CREATE TABLE IF NOT EXISTS bauth.gdpr_international_transfer (
    transfer_id      UUID        NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    recipient_country TEXT       NOT NULL,   -- ISO 3166-1 alpha-2 (ej. US, BR, IN)
    recipient_org    TEXT        NOT NULL,
    transfer_basis   TEXT        NOT NULL CONSTRAINT chk_git_basis CHECK (
                                     transfer_basis IN (
                                         'ADEQUACY_DECISION','STANDARD_CONTRACTUAL_CLAUSES',
                                         'BINDING_CORPORATE_RULES','DEROGATION_ART49',
                                         'CERTIFICATION','CODE_OF_CONDUCT'
                                     )),
    data_categories  TEXT[]      NOT NULL DEFAULT '{}',
    purpose          TEXT        NOT NULL,
    started_at       DATE        NOT NULL,
    ended_at         DATE        NULL,
    review_due       DATE        NULL,
    notes            TEXT        NULL,
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_git_tenant  ON bauth.gdpr_international_transfer (tenant_id);
CREATE INDEX IF NOT EXISTS idx_git_country ON bauth.gdpr_international_transfer (recipient_country);
COMMENT ON TABLE bauth.gdpr_international_transfer IS
'PRIVACIDAD | Registro de transferencias internacionales de datos personales.
GDPR Art. 44-49: toda transferencia a un país no adecuado debe tener una base jurídica.
transfer_basis registra el mecanismo legal (SCCs son el más común post-Schrems II).
data_categories: categorías de datos transferidos (ej. {identidad, sesiones, biometría}).
Norma: GDPR Art. 44-49, EDPB Guidelines 05/2021. T-570.';

-- =============================================================================
-- §3 TABLAS NUEVAS — complejas
-- =============================================================================

-- T-567 — GAP-GDPR-01 — gdpr_portability_request (GDPR Art. 20)
-- El derecho de portabilidad permite al sujeto recibir sus datos en formato
-- estructurado y legible por máquina para transferirlos a otro responsable.
CREATE TABLE IF NOT EXISTS bauth.gdpr_portability_request (
    request_id       UUID        NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    subject_id       UUID        NOT NULL REFERENCES bauth.idn_identity_entity(entity_id),
    requested_by     UUID        NULL REFERENCES bauth.idn_identity_entity(entity_id),
    format           TEXT        NOT NULL DEFAULT 'JSON' CONSTRAINT chk_gpr_format CHECK (
                                     format IN ('JSON','CSV','XML')),
    scope            TEXT[]      NOT NULL DEFAULT '{}',
    status           TEXT        NOT NULL DEFAULT 'PENDING' CONSTRAINT chk_gpr_status CHECK (
                                     status IN ('PENDING','PROCESSING','READY','DELIVERED','EXPIRED','FAILED')),
    requested_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at     TIMESTAMPTZ NULL,
    expires_at       TIMESTAMPTZ NULL,
    delivery_method  TEXT        NOT NULL DEFAULT 'DOWNLOAD' CONSTRAINT chk_gpr_delivery CHECK (
                                     delivery_method IN ('DOWNLOAD','EMAIL','API_PUSH')),
    download_token   TEXT        NULL UNIQUE,
    error_message    TEXT        NULL,
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_gpr_subject  ON bauth.gdpr_portability_request (subject_id, requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_gpr_pending  ON bauth.gdpr_portability_request (status) WHERE status IN ('PENDING','PROCESSING');
CREATE INDEX IF NOT EXISTS idx_gpr_token    ON bauth.gdpr_portability_request (download_token) WHERE download_token IS NOT NULL;
COMMENT ON TABLE bauth.gdpr_portability_request IS
'PRIVACIDAD | Solicitudes de portabilidad de datos — GDPR Art. 20. El sujeto tiene derecho
a recibir sus datos en formato estructurado (JSON/CSV/XML) y a transmitirlos a otro
responsable. El daemon procesa la solicitud de forma asíncrona: recopila los datos del
sujeto de todas las tablas bAuth, los empaqueta y genera un download_token de un solo uso.
SLA: 30 días calendario (Art. 12.3). download_token expira en 7 días tras READY.
Norma: GDPR Art. 20, EDPB Guidelines 05/2021. T-567.';

-- T-569 — GAP-OAUTH-04 — fed_dynamic_client_registration (RFC 7591)
-- Permite que aplicaciones se registren dinámicamente como clientes OIDC
-- sin intervención manual del OAUTH_ADMIN. Cada registro genera un
-- registration_access_token para gestionar el registro posteriormente.
CREATE TABLE IF NOT EXISTS bauth.fed_dynamic_client_registration (
    registration_id          UUID        NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    client_id                UUID        NOT NULL UNIQUE REFERENCES bauth.fed_client(client_id) ON DELETE CASCADE,
    tenant_id                UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    registration_access_token TEXT       NOT NULL UNIQUE,
    initial_access_token_ref TEXT        NULL,
    metadata                 JSONB       NOT NULL DEFAULT '{}',
    status                   TEXT        NOT NULL DEFAULT 'ACTIVE' CONSTRAINT chk_fdcr_status CHECK (
                                             status IN ('ACTIVE','EXPIRED','REVOKED')),
    registered_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at               TIMESTAMPTZ NULL,
    ctx_id                   TEXT        NOT NULL DEFAULT 'system',
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_fdcr_tenant ON bauth.fed_dynamic_client_registration (tenant_id);
COMMENT ON TABLE bauth.fed_dynamic_client_registration IS
'FEDERACIÓN OIDC | Registro dinámico de clientes — RFC 7591. Cada fila vincula un client_id
(en fed_client, creado dinámicamente) con su registration_access_token, que permite al
cliente actualizar o eliminar su propio registro sin intervención del OAUTH_ADMIN.
metadata: copia del software_statement JWT y parámetros del registration request original.
initial_access_token_ref: referencia al token de acceso inicial requerido por el servidor
para autorizar el registro (ruta en Vault — el token en sí nunca se almacena en BD).
Norma: RFC 7591 (Dynamic Client Registration), RFC 7592 (Management). T-569.';

-- T-571 — GAP-800207-01 — zta_data_access_policy (NIST SP 800-207)
-- Zero Trust Architecture §3.3: el PEP evalúa acceso a recursos a nivel de dato,
-- no solo a nivel de red. Esta tabla almacena políticas de acceso granulares por
-- tipo de recurso, patrón, LoA mínimo y átomos BitMask requeridos.
CREATE TABLE IF NOT EXISTS bauth.zta_data_access_policy (
    policy_id        UUID        NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    tenant_id        UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    resource_type    TEXT        NOT NULL CONSTRAINT chk_zdap_rtype CHECK (
                                     resource_type IN ('TABLE','API_ENDPOINT','FILE_PATH','QUEUE','STREAM','OBJECT')),
    resource_pattern TEXT        NOT NULL,
    required_loa     TEXT        NOT NULL CONSTRAINT chk_zdap_loa CHECK (
                                     required_loa IN ('AAL1','AAL2','AAL3')),
    required_atoms   TEXT[]      NOT NULL DEFAULT '{}',
    conditions       JSONB       NULL,
    effect           TEXT        NOT NULL DEFAULT 'DENY' CONSTRAINT chk_zdap_effect CHECK (
                                     effect IN ('ALLOW','DENY')),
    priority         INT         NOT NULL DEFAULT 100,
    enabled          BOOLEAN     NOT NULL DEFAULT true,
    ctx_id           TEXT        NOT NULL DEFAULT 'system',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_zdap_tenant   ON bauth.zta_data_access_policy (tenant_id, enabled);
CREATE INDEX IF NOT EXISTS idx_zdap_rtype    ON bauth.zta_data_access_policy (resource_type, priority);
COMMENT ON TABLE bauth.zta_data_access_policy IS
'ZERO TRUST | Políticas de acceso a nivel de dato — NIST SP 800-207 §3.3. Cada fila define
una regla que el PEP de bAuth evalúa al decidir si un sujeto puede acceder a un recurso.
resource_pattern: glob o prefijo del recurso (ej. "/api/v1/users/*", "bauth.idn_user").
required_loa: nivel mínimo de autenticación requerido (AAL1/2/3).
required_atoms: lista de slugs de átomos BitMask que el sujeto debe tener activos.
conditions: filtros adicionales JSONB (geo, temporal, device_posture, risk_score).
priority: menor número = mayor prioridad (evaluado en orden ascendente).
Norma: NIST SP 800-207 §3.3 (Data-Level Access Policy), SBOS-049. T-571.';

-- T-568 — GAP-NIST63B-02 — auth_biometric_template (NIST 800-63B §5.2.3)
-- NIST 800-63B §5.2.3 exige que los datos biométricos se almacenen en un sistema
-- separado del verificador principal. Los templates nunca se guardan en claro —
-- solo el hash SHA-256 y la ruta en Vault donde vive el template cifrado.
CREATE TABLE IF NOT EXISTS bauth.auth_biometric_template (
    template_id       UUID        NOT NULL DEFAULT uuidv7() PRIMARY KEY,
    credential_id     UUID        NOT NULL UNIQUE REFERENCES bauth.auth_credential(credential_id) ON DELETE CASCADE,
    tenant_id         UUID        NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    biometric_type    TEXT        NOT NULL CONSTRAINT chk_abt_type CHECK (
                                      biometric_type IN ('FINGERPRINT','FACE','IRIS','VOICE','VEIN','PALM')),
    template_hash     TEXT        NOT NULL,
    vault_path        TEXT        NOT NULL,
    vault_key_version INT         NOT NULL DEFAULT 1,
    sensor_make       TEXT        NULL,
    sensor_model      TEXT        NULL,
    quality_score     NUMERIC(5,2) NULL CONSTRAINT chk_abt_quality CHECK (
                                      quality_score IS NULL OR
                                      (quality_score >= 0 AND quality_score <= 100)),
    enrolled_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_verified_at  TIMESTAMPTZ NULL,
    revoked_at        TIMESTAMPTZ NULL,
    ctx_id            TEXT        NOT NULL DEFAULT 'system',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_abt_tenant ON bauth.auth_biometric_template (tenant_id);
CREATE INDEX IF NOT EXISTS idx_abt_type   ON bauth.auth_biometric_template (biometric_type);
COMMENT ON TABLE bauth.auth_biometric_template IS
'AUTENTICACIÓN | Templates biométricos — NIST SP 800-63B §5.2.3. Los datos biométricos
se almacenan en un sistema separado del verificador principal (ADR-010). NUNCA se guarda
el template en claro: template_hash es el SHA-256 del template procesado; vault_path apunta
a la ruta en Vault transit donde vive el template cifrado con AES-256-GCM.
Tipos: FINGERPRINT, FACE, IRIS, VOICE, VEIN, PALM. quality_score 0-100 indica la calidad
del template capturado (umbral mínimo configurable en cfg_policy_library).
vault_key_version: permite re-cifrado al rotar la clave sin invalidar templates activos.
Norma: NIST SP 800-63B §5.2.3, ISO/IEC 30107-3 (PAD). T-568.';

-- =============================================================================
-- §4 VERIFICACIÓN
-- =============================================================================

SELECT 'fed_client nuevas columnas' AS check_point,
       COUNT(*) AS encontradas
FROM information_schema.columns
WHERE table_schema = 'bauth'
  AND table_name   = 'fed_client'
  AND column_name  IN ('jarm_signing_alg','jarm_encryption_alg','authorization_details_types');

SELECT 'fed_token_issued nuevas columnas' AS check_point,
       COUNT(*) AS encontradas
FROM information_schema.columns
WHERE table_schema = 'bauth'
  AND table_name   = 'fed_token_issued'
  AND column_name  = 'authorization_details';

SELECT 'auth_credential_fido2 nuevas columnas' AS check_point,
       COUNT(*) AS encontradas
FROM information_schema.columns
WHERE table_schema = 'bauth'
  AND table_name   = 'auth_credential_fido2'
  AND column_name  = 'uv_required';

SELECT 'tablas nuevas T-567..T-572' AS check_point,
       COUNT(*) AS encontradas
FROM information_schema.tables
WHERE table_schema = 'bauth'
  AND table_name IN (
      'gdpr_portability_request',
      'auth_biometric_template',
      'fed_dynamic_client_registration',
      'gdpr_international_transfer',
      'zta_data_access_policy',
      'vul_pentest_record'
  );
