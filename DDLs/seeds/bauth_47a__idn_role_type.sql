-- =============================================================================
-- bauth_47a__idn_role_type.sql
-- Catálogo normativo de tipos de cuenta/rol — bauth.idn_role_type
-- Fuente: NIST SP 800-53 Rev5 AC-2 · ISO 24760-2:2025 · oneM2M TS 0001 · PAM NHI
-- Idempotente: CREATE TABLE IF NOT EXISTS + ON CONFLICT (codigo) DO UPDATE
-- Debe ejecutarse ANTES de bauth_48 (dependencia de FK en idn_role_template.type_id)
-- =============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS bauth.idn_role_type (
    id                  uuid        NOT NULL DEFAULT uuidv7(),
    codigo              text        NOT NULL,
    nombre_es           text        NOT NULL,
    nombre_en           text        NOT NULL,
    descripcion_es      text        NOT NULL,
    norma_ref           text        NOT NULL,
    es_humano           boolean     NOT NULL,
    es_externo          boolean     NOT NULL DEFAULT false,
    riesgo_elevado      boolean     NOT NULL DEFAULT false,
    requiere_expiracion boolean     NOT NULL DEFAULT false,
    activo              boolean     NOT NULL DEFAULT true,
    ctx_id              text        NOT NULL DEFAULT 'bootstrap',
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_idn_role_type        PRIMARY KEY (id),
    CONSTRAINT uq_idn_role_type_codigo UNIQUE (codigo)
);

COMMENT ON TABLE  bauth.idn_role_type IS 'Catálogo normativo de tipos de cuenta — NIST SP 800-53 Rev5 AC-2 · ISO 24760-2:2025 · oneM2M TS 0001';
COMMENT ON COLUMN bauth.idn_role_type.codigo              IS 'Código canónico invariable — clave natural para referencias en seeds y código Rust';
COMMENT ON COLUMN bauth.idn_role_type.es_humano           IS 'true = cuenta de persona física; false = cuenta no humana (NHI, daemon, automatización)';
COMMENT ON COLUMN bauth.idn_role_type.es_externo          IS 'true = identidad cuya entidad proveedora está fuera de la organización';
COMMENT ON COLUMN bauth.idn_role_type.riesgo_elevado      IS 'NIST AC-2: tipo que la organización puede optar por prohibir por riesgo elevado';
COMMENT ON COLUMN bauth.idn_role_type.requiere_expiracion IS 'true = todo rol de este tipo DEBE tener expiry_time definido (AC-2(2))';

INSERT INTO bauth.idn_role_type (
    codigo, nombre_es, nombre_en, descripcion_es, norma_ref,
    es_humano, es_externo, riesgo_elevado, requiere_expiracion
) VALUES
(
    'INDIVIDUAL',
    'Usuario Individual Interno',
    'Individual Internal User',
    'Cuenta personal de un empleado, colaborador o contratista interno. Una persona, una cuenta, trazabilidad individual completa. Ciclo de vida ligado al contrato laboral.',
    'NIST SP 800-53 Rev5 AC-2 "individual" · ISO 24760-2:2025 §4 human entity · ANSI INCITS 359-2012(R2022) §3.1',
    true, false, false, false
),
(
    'EXTERNAL',
    'Identidad Externa',
    'External Identity',
    'Usuario humano externo a la organización: cliente B2C, proveedor B2B, partner comercial, empleador doméstico. Identidad verificada pero perteneciente a otro dominio o tenant.',
    'NIST SP 800-53 Rev5 AC-2 "individual" externo · ISO 24760-2:2025 external party · oneM2M TS 0001 roleType "EXT" · RFC 7643 SCIM userType "External"',
    true, true, false, false
),
(
    'GUEST',
    'Visitante / Acceso Limitado',
    'Guest / Limited Access',
    'Acceso externo con privilegios mínimos. Puede ser anónimo o con verificación básica. NIST AC-2 lo clasifica como de riesgo elevado por la dificultad de trazabilidad. Expiración obligatoria.',
    'NIST SP 800-53 Rev5 AC-2 "guest" · AC-2 Rev5 "anonymous" · Microsoft Entra ID B2B Guest · NIST AC-2 tipo de riesgo elevado',
    true, true, true, true
),
(
    'GROUP',
    'Cuenta Compartida / Grupal',
    'Shared / Group Account',
    'Cuenta usada por múltiples personas: equipo de turno, departamento, guardia compartida. AC-2 la clasifica como riesgo elevado porque dificulta la trazabilidad individual y el no repudio.',
    'NIST SP 800-53 Rev5 AC-2 "group" + "shared" · AC-2(9) Restrictions on Use of Shared and Group Accounts · ISO 27001:2022 A.5.16',
    false, false, true, false
),
(
    'SYSTEM',
    'Proceso de Sistema / Daemon',
    'System Process / Daemon',
    'Identidad de un proceso del sistema operativo o daemon systemd. No accesible por humanos directamente. Ejemplos SBOS: bauth.service, bkernel.service, biedata.service.',
    'NIST SP 800-53 Rev5 AC-2 "system" · oneM2M TS 0001 roleType "SYS" · NIST SP 800-53 AC-3 Access Enforcement',
    false, false, false, false
),
(
    'SERVICE',
    'Cuenta de Servicio / Integración',
    'Service Account / Integration',
    'Service account de una aplicación o integración con credenciales gestionadas explícitamente (secreto rotado periódicamente, certificado X.509). Distinguida de M2M por requerir gestión activa de credenciales.',
    'NIST SP 800-53 Rev5 AC-2 "service" · CyberArk/BeyondTrust PAM service account · Microsoft Entra Service Principal · NIST SP 800-53 AC-2(6)',
    false, false, false, false
),
(
    'M2M',
    'Máquina a Máquina / NHI',
    'Machine-to-Machine / Non-Human Identity',
    'Identidad no humana para automatización: API clients, CI/CD pipelines, agentes IA, RPA, scripts de integración. El mercado PAM los designa NHI (Non-Human Identity, ratio 80:1 vs humanos). Autenticación por mTLS o client_credentials (RFC 6749 §4.4).',
    'oneM2M TS 0001 roleType "M2M" · PAM NHI — Non-Human Identity (BeyondTrust/CyberArk 2025) · NIST SP 800-53 Rev5 AC-2 "service" automatizado · OAuth 2.0 client_credentials RFC 6749 §4.4',
    false, false, false, false
),
(
    'EMERGENCY',
    'Break-Glass / Emergencia',
    'Emergency / Break-Glass',
    'Cuenta de emergencia (firecall). Se activa en crisis sin pasar por el flujo normal de aprobación. AC-2 exige desactivación o remoción inmediata al cesar la emergencia. Auditoría obligatoria de cada activación. Expiración automática obligatoria.',
    'NIST SP 800-53 Rev5 AC-2 "emergency" · AC-2(2) Automated Temporary and Emergency Account Management · NIST AC-2 tipo de riesgo elevado',
    true, false, true, true
),
(
    'TEMPORARY',
    'Acceso Temporal con Expiración',
    'Temporary Access',
    'Acceso con fecha de expiración explícita y obligatoria. Para contratos temporales, proyectos acotados, acceso de proveedor durante mantenimiento, pasantes. AC-2(2) exige remoción automática al vencer la fecha.',
    'NIST SP 800-53 Rev5 AC-2 "temporary" · AC-2(2) Automatic Removal of Temporary Accounts · NIST AC-2 tipo de riesgo elevado',
    true, false, true, true
),
(
    'DEVELOPER',
    'Cuenta de Desarrollo / Debug',
    'Developer / Debug Account',
    'Cuenta con privilegios especiales de desarrollo: acceso a staging, entornos de prueba, herramientas de diagnóstico. Separada de INDIVIDUAL por sus permisos ampliados. Restringida a entornos no productivos.',
    'NIST SP 800-53 Rev5 AC-2 "developer" · NIST SP 800-53 CM-11 User-Installed Software · ISO 27001:2022 A.8.25 Secure Development Lifecycle',
    true, false, false, false
)
ON CONFLICT (codigo) DO UPDATE SET
    nombre_es           = EXCLUDED.nombre_es,
    nombre_en           = EXCLUDED.nombre_en,
    descripcion_es      = EXCLUDED.descripcion_es,
    norma_ref           = EXCLUDED.norma_ref,
    es_humano           = EXCLUDED.es_humano,
    es_externo          = EXCLUDED.es_externo,
    riesgo_elevado      = EXCLUDED.riesgo_elevado,
    requiere_expiracion = EXCLUDED.requiere_expiracion,
    updated_at          = now();

COMMIT;
