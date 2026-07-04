-- ============================================================================
-- 003_d00_identidad_organizacional.sql — Dominio D00 Identidad Organizacional
-- ============================================================================
-- Propósito : Crea el Dominio D00 en el catálogo de privilegios del sistema.
--             D00 no es un dominio de acceso (no alinea con OIDC/SAML/OAuth2) —
--             es la base estructural del ctx_id: tenant → bdomain → bsubdomain.
--             Cubre S0 identity, S1 personalInfo y S2 professionalInfo del
--             UserTemplate v6.0 (seed_064_idn_user_template_data.sql).
-- Fuente    : BAUTH-ARQUITECTURA-ATOMICA-FINAL.md §D00 (revisado 2026-06-30)
-- Normas    : SBOS-MODEL-D00 v1.0, ISO 24760-2:2025, SCIM 2.0 RFC 7643
-- Autor     : bauth-developer · 2026-06-30
-- APROBACIÓN REQUERIDA antes de aplicar en producción (ADR-016, feedback DDL)
-- ============================================================================
-- IDEMPOTENCIA: INSERT ... ON CONFLICT DO NOTHING en todos los pasos.
-- NO usa TRUNCATE. Es seguro ejecutar múltiples veces.
-- ============================================================================

BEGIN;
SET lock_timeout = '5s';

-- ============================================================================
-- PASO 1 — Agregar columna is_internal a idn_tenant
-- ============================================================================
-- Distinción interno/externo va en columna boolean, NO en tenant_type_enum.
-- skull es interno (true). Todo tenant externo tendrá is_internal=false.
-- ============================================================================

ALTER TABLE bauth.idn_tenant
  ADD COLUMN IF NOT EXISTS is_internal BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN bauth.idn_tenant.is_internal IS
  'Distingue el tenant interno de SKULL (true) de tenants externos (false). '
  'Primer segmento del ctx_id: interno.tenant.bdomain.bsubdomain (SBOS-049 §5.3).';

-- ============================================================================
-- PASO 2 — Ampliar CHECK de privilege_domain para permitir domain_code=0
-- ============================================================================
-- El CHECK actual es BETWEEN 1 AND 15. D00 necesita domain_code=0.
-- ============================================================================

ALTER TABLE bauth.privilege_domain
  DROP CONSTRAINT IF EXISTS ck_domain_code;

ALTER TABLE bauth.privilege_domain
  ADD CONSTRAINT ck_domain_code CHECK (domain_code BETWEEN 0 AND 15);

-- ============================================================================
-- PASO 3 — Insertar Dominio D00 en privilege_domain
-- ============================================================================

INSERT INTO bauth.privilege_domain (domain_code, domain_name, requires_policy, description)
VALUES (
  0,
  'Identidad Organizacional',
  false,
  'Tipos y atributos de tenant, bDomain, bSubDomain, pos y actor. '
  'Pre-condición estructural del ctx_id (SBOS-049). '
  'Cubre S0/S1/S2 del UserTemplate v6.0. SBOS-MODEL-D00.'
)
ON CONFLICT (domain_code) DO NOTHING;

-- ============================================================================
-- PASO 4 — Insertar aplicación org (app_code=13)
-- ============================================================================
-- Las apps 1-12 son Tryton, Kong, Keycloak, etc. La 13 es Org (identidad).
-- ============================================================================

INSERT INTO bauth.privilege_application (app_code, app_name, app_slug, tenant_id, active)
VALUES (
  13,
  'Org',
  'org',
  COALESCE(
    (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug = 'skull' LIMIT 1),
    '4c697f66-d204-45a5-ac36-c104f07c7046'::uuid
  ),
  true
)
ON CONFLICT (app_code) DO NOTHING;

-- ============================================================================
-- PASO 5 — Insertar 5 grupos de la aplicación org
-- ============================================================================

INSERT INTO bauth.privilege_group (group_code, app_code, group_name)
VALUES
  (1, 13, 'Tenant'),
  (2, 13, 'bDomain'),
  (3, 13, 'bSubDomain'),
  (4, 13, 'Pos'),
  (5, 13, 'Actor')
ON CONFLICT (group_code, app_code) DO NOTHING;

-- ============================================================================
-- PASO 6 — Insertar 13 verbos de identidad (verb_code 51-63)
-- ============================================================================
-- Los verbos 1-50 son verbos de acción/negocio. Los 51-63 son verbos de
-- atributo de identidad, específicos para D00.
-- ============================================================================

INSERT INTO bauth.privilege_verb (verb_code, verb_name, verb_slug)
VALUES
  (51, 'Tipo',           'type'),
  (52, 'Nombre',         'nombre'),
  (53, 'NIT',            'nit'),
  (54, 'Email',          'email'),
  (55, 'Teléfono',       'telefono'),
  (56, 'Carnet',         'ci'),
  (57, 'Dirección',      'direccion'),
  (58, 'Tipo empleo',    'employee_type'),
  (59, 'Género',         'gender'),
  (60, 'Estado civil',   'marital_status'),
  (61, 'Tipo documento', 'id_doc_type'),
  (62, 'Locale',         'locale'),
  (63, 'Zona horaria',   'timezone')
ON CONFLICT (verb_code) DO NOTHING;

-- ============================================================================
-- PASO 7 — Insertar 20 átomos de D00 (atom_position 5809-5828)
-- ============================================================================
-- Fórmulas (MANUAL_DB_DDL.md §4.2 / §4.3):
--   contextual_mask = (domain_code << 8) | (app_code << 12) | (group_code << 21)
--   logical_mask    = (verb_code << 8)
--
-- domain_code=0, app_code=13 → base = (0<<8)|(13<<12) = 53248
--   g1: 53248 | (1<<21) = 53248 | 2097152 = 2150400
--   g2: 53248 | (2<<21) = 53248 | 4194304 = 4247552
--   g3: 53248 | (3<<21) = 53248 | 6291456 = 6344704
--   g4: 53248 | (4<<21) = 53248 | 8388608 = 8441856
--   g5: 53248 | (5<<21) = 53248 |10485760 =10538496
-- ============================================================================

INSERT INTO bauth.privilege_atom
  (atom_code, app_code, group_code, domain_code, verb_code,
   atom_name, atom_slug, atom_position, contextual_mask, logical_mask)
VALUES
  -- Grupo 1: Tenant
  (5809, 13, 1, 0, 51,
   'Org · Tenant     · Identidad Org · Tipo',
   'org.g1.d0.type',        5809, 2150400,  13056),

  -- Grupo 2: bDomain
  (5810, 13, 2, 0, 51,
   'Org · bDomain    · Identidad Org · Tipo',
   'org.g2.d0.type',        5810, 4247552,  13056),
  (5811, 13, 2, 0, 52,
   'Org · bDomain    · Identidad Org · Nombre',
   'org.g2.d0.nombre',      5811, 4247552,  13312),
  (5812, 13, 2, 0, 53,
   'Org · bDomain    · Identidad Org · NIT',
   'org.g2.d0.nit',         5812, 4247552,  13568),
  (5813, 13, 2, 0, 54,
   'Org · bDomain    · Identidad Org · Email',
   'org.g2.d0.email',       5813, 4247552,  13824),
  (5814, 13, 2, 0, 55,
   'Org · bDomain    · Identidad Org · Teléfono',
   'org.g2.d0.telefono',    5814, 4247552,  14080),
  (5815, 13, 2, 0, 56,
   'Org · bDomain    · Identidad Org · Carnet',
   'org.g2.d0.ci',          5815, 4247552,  14336),
  (5816, 13, 2, 0, 57,
   'Org · bDomain    · Identidad Org · Dirección',
   'org.g2.d0.direccion',   5816, 4247552,  14592),

  -- Grupo 3: bSubDomain
  (5817, 13, 3, 0, 51,
   'Org · bSubDomain · Identidad Org · Tipo',
   'org.g3.d0.type',        5817, 6344704,  13056),
  (5818, 13, 3, 0, 52,
   'Org · bSubDomain · Identidad Org · Nombre',
   'org.g3.d0.nombre',      5818, 6344704,  13312),
  (5819, 13, 3, 0, 57,
   'Org · bSubDomain · Identidad Org · Dirección',
   'org.g3.d0.direccion',   5819, 6344704,  14592),

  -- Grupo 4: Pos
  (5820, 13, 4, 0, 51,
   'Org · Pos        · Identidad Org · Tipo',
   'org.g4.d0.type',        5820, 8441856,  13056),
  (5821, 13, 4, 0, 52,
   'Org · Pos        · Identidad Org · Nombre',
   'org.g4.d0.nombre',      5821, 8441856,  13312),

  -- Grupo 5: Actor
  (5822, 13, 5, 0, 51,
   'Org · Actor      · Identidad Org · Tipo',
   'org.g5.d0.type',         5822, 10538496, 13056),
  (5823, 13, 5, 0, 58,
   'Org · Actor      · Identidad Org · Tipo empleo',
   'org.g5.d0.employee_type',5823, 10538496, 14848),
  (5824, 13, 5, 0, 59,
   'Org · Actor      · Identidad Org · Género',
   'org.g5.d0.gender',       5824, 10538496, 15104),
  (5825, 13, 5, 0, 60,
   'Org · Actor      · Identidad Org · Estado civil',
   'org.g5.d0.marital_status',5825,10538496, 15360),
  (5826, 13, 5, 0, 61,
   'Org · Actor      · Identidad Org · Tipo documento',
   'org.g5.d0.id_doc_type',  5826, 10538496, 15616),
  (5827, 13, 5, 0, 62,
   'Org · Actor      · Identidad Org · Locale',
   'org.g5.d0.locale',       5827, 10538496, 15872),
  (5828, 13, 5, 0, 63,
   'Org · Actor      · Identidad Org · Zona horaria',
   'org.g5.d0.timezone',     5828, 10538496, 16128)

ON CONFLICT (app_code, atom_slug) DO NOTHING;

-- ============================================================================
-- PASO 8 — Tenant externo de ejemplo (DEPO srl)
-- ============================================================================
-- El primer tenant externo del sistema. is_internal=false.
-- ⚠️ El humano deberá ajustar legal_name, tax_id, realm_kc, etc. con datos reales.
-- ============================================================================

INSERT INTO bauth.idn_tenant (
  tenant_slug, tenant_name, tenant_type, status, provisioning_status,
  country, data_retention_days,
  realm_kc, realm_kc_ext, namespace_k8s,
  isolation_level, mfa_required, password_policy,
  session_ttl_max, token_ttl_seconds, rate_limit_rps,
  plan_tier, subscription_status, audit_level,
  legal_name, tax_id, legal_contact_email,
  is_internal
) VALUES (
  'depo-srl',
  'DEPO srl',
  'STANDARD',
  'PENDING_VERIFICATION',
  'PENDING',
  'BO',
  2555,
  'tenant-depo-srl',
  'tenant-depo-srl-ext',
  'sbos-depo-srl',
  'SCHEMA_PER_TENANT',
  false,
  'length(12)_argon2id_t3_m64',
  28800,
  3600,
  100,
  'BASIC',
  'TRIAL',
  'basic',
  'DEPO srl',
  '12345678',
  'admin@depo.com.bo',
  false
)
ON CONFLICT (tenant_slug) DO NOTHING;

COMMIT;

-- ============================================================================
-- VERIFICACIÓN (ejecutar por separado para confirmar el resultado)
-- ============================================================================
-- SELECT domain_code, domain_name FROM bauth.privilege_domain ORDER BY domain_code;
-- -- debe retornar 13 filas: D00 + D1-D12

-- SELECT count(*) FROM bauth.privilege_atom WHERE domain_code = 0;
-- -- debe retornar 20

-- SELECT atom_position, atom_slug, atom_name
-- FROM bauth.privilege_atom WHERE domain_code = 0 ORDER BY atom_position;

-- SELECT tenant_slug, tenant_name, is_internal
-- FROM bauth.idn_tenant ORDER BY is_internal DESC;
-- -- skull: is_internal=true, depo-srl: is_internal=false

-- ============================================================================
-- NOTA SOBRE LOS SEEDS EXISTENTES
-- ============================================================================
-- Los seeds seed_privilege_domain.sql, seed_privilege_verb.sql y
-- seed_privilege_atom.sql usan TRUNCATE CASCADE. Si se re-ejecutan DESPUÉS
-- de esta migration, borrarán los datos de D00.
-- Para hacerlos idempotentes con D00, actualizar:
--   1. seed_privilege_domain.sql → agregar D00 en el INSERT
--   2. seed_privilege_verb.sql   → agregar verbos 51-63 en el INSERT
--   3. seed_privilege_atom.sql   → agregar al WHERE:
--        OR (v.verb_code BETWEEN 51 AND 63 AND d.domain_code = 0)
-- Estos cambios requieren aprobación separada (ADR-016).
-- ============================================================================
