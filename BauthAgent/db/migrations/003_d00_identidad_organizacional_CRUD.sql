-- ============================================================================
-- 003_d00_identidad_organizacional_CRUD.sql — Dominio D00 Identidad Org (v2 CRUD)
-- ============================================================================
-- Propósito : Crea el Dominio D00 en el catálogo de privilegios del sistema.
--             D00 no es un dominio de acceso (no alinea con OIDC/SAML/OAuth2) —
--             es la base estructural del ctx_id: tenant → bdomain → bsubdomain.
--             Cubre S0 identity, S1 personalInfo y S2 professionalInfo del
--             UserTemplate v6.0.
--
-- VERSIÓN   : v2 CRUD — reemplaza la versión semántica (003_d00_identidad_organizacional.sql)
--             Diferencias con v1 semántica:
--               - PASO 6 eliminado: no se insertan verbos 51-63 (CRUD usa 1-4 existentes)
--               - PASO 7 reemplazado: 120 átomos CRUD (5809-5928) vs 20 semánticos (5809-5828)
--
-- Fuente    : BAUTH-CATALOGO-ATOMOS-D00-CRUD.md v1.1.0 · INFORME-DELTA-DDL-D00.md
-- Normas    : SBOS-MODEL-D00 v1.0, ISO 24760-2:2025, SCIM 2.0 RFC 7643
-- Autor     : bauth-developer · 2026-07-06
--
-- ⚠️  APROBACIÓN REQUERIDA antes de aplicar en producción (ADR-016)
-- ⚠️  Antes de aplicar: confirmar que 003 semántica NO fue ejecutada en el entorno.
--     Si fue ejecutada: ejecutar primero el BLOQUE DE LIMPIEZA al final del archivo.
--
-- ============================================================================
-- IDEMPOTENCIA: INSERT ... ON CONFLICT DO NOTHING en todos los pasos.
-- NO usa TRUNCATE. Es seguro ejecutar múltiples veces en entornos limpios.
-- ============================================================================

BEGIN;
SET lock_timeout = '5s';

-- ============================================================================
-- PASO 1 — Agregar columna is_internal a idn_tenant
-- ============================================================================
-- Distinción interno/externo en columna boolean, no en tenant_type_enum.
-- skull = interno (true). Todo tenant externo → is_internal=false.
-- ============================================================================

ALTER TABLE bauth.idn_tenant
  ADD COLUMN IF NOT EXISTS is_internal BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN bauth.idn_tenant.is_internal IS
  'Distingue el tenant interno de SKULL (true) de tenants externos (false). '
  'Primer segmento del ctx_id: interno.tenant.bdomain.bsubdomain (SBOS-049 §5.3).';

-- ============================================================================
-- PASO 2 — Ampliar CHECK de privilege_domain para permitir domain_code=0
-- ============================================================================
-- El CHECK base es BETWEEN 1 AND 15. D00 necesita domain_code=0.
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
-- Las apps 1-12 son Tryton, Kong, Keycloak, etc. La 13 es Org (identidad D00).
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
-- Los 5 grupos corresponden a las 5 entidades del Modelo Vertical D00:
--   Tenant → bDomain → bSubDomain → Pos → Actor
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
-- PASO 6 — [ELIMINADO en v2 CRUD]
-- ============================================================================
-- La versión semántica (v1) insertaba verbos 51-63 (Tipo, Nombre, NIT, etc.).
-- El enfoque CRUD usa verbos 1-4 (create, update, delete, read) que YA EXISTEN
-- en el seed_privilege_verb.sql. No se necesitan verbos adicionales.
-- ============================================================================

-- ============================================================================
-- PASO 7 — Insertar 120 átomos CRUD de D00 (atom_position 5809-5928)
-- ============================================================================
-- Justificación del inicio en 5809:
--   seed_privilege_atom.sql genera 5808 átomos dinámicos para apps 1-12, domains 1-12.
--   Fórmula verificada: 48 grupos × 121 combinaciones(domain,verb) = 5808.
--   D00 ocupa el bloque inmediato siguiente: 5809+.
--
-- Fórmulas de masks (MANUAL_DB_DDL.md §4.2 / §4.3):
--   contextual_mask = (domain_code << 8) | (app_code << 12) | (group_code << 21)
--   logical_mask    = (verb_code << 8)
--
-- Con domain_code=0, app_code=13:
--   base = (0 << 8) | (13 << 12) = 0 | 53248 = 53248
--   g1 = 53248 | (1 << 21) = 53248 | 2097152 = 2150400
--   g2 = 53248 | (2 << 21) = 53248 | 4194304 = 4247552
--   g3 = 53248 | (3 << 21) = 53248 | 6291456 = 6344704
--   g4 = 53248 | (4 << 21) = 53248 | 8388608 = 8441856
--   g5 = 53248 | (5 << 21) = 53248 |10485760 =10538496
--
-- logical_mask por verbo CRUD:
--   verb_code=1 (create):  1 << 8 = 256
--   verb_code=2 (update):  2 << 8 = 512
--   verb_code=3 (delete):  3 << 8 = 768
--   verb_code=4 (read):    4 << 8 = 1024
--
-- Nomenclatura de slug: D00.org.{entidad}_{campo}.{VERBO}
-- Fuente: BAUTH-CATALOGO-ATOMOS-D00-CRUD.md
-- ============================================================================

INSERT INTO bauth.privilege_atom
  (atom_code, app_code, group_code, domain_code, verb_code,
   atom_name, atom_slug, atom_position, contextual_mask, logical_mask)
VALUES

  -- ===========================================================================
  -- MÓDULO: tenant (group_code=1, contextual_mask=2150400)
  -- Campo: type — columna idn_tenant.tenant_type
  -- ===========================================================================
  (5809, 13, 1, 0, 1, 'D00 · Tenant · type · create',
   'D00.org.tenant_type.C',        5809, 2150400,  256),
  (5810, 13, 1, 0, 4, 'D00 · Tenant · type · read',
   'D00.org.tenant_type.R',        5810, 2150400, 1024),
  (5811, 13, 1, 0, 2, 'D00 · Tenant · type · update',
   'D00.org.tenant_type.U',        5811, 2150400,  512),
  (5812, 13, 1, 0, 3, 'D00 · Tenant · type · delete',
   'D00.org.tenant_type.D',        5812, 2150400,  768),

  -- ===========================================================================
  -- MÓDULO: bdomain (group_code=2, contextual_mask=4247552)
  -- Campo: type — columna org_empresa.tipo_bdomain
  -- ===========================================================================
  (5813, 13, 2, 0, 1, 'D00 · bDomain · type · create',
   'D00.org.bdomain_type.C',       5813, 4247552,  256),
  (5814, 13, 2, 0, 4, 'D00 · bDomain · type · read',
   'D00.org.bdomain_type.R',       5814, 4247552, 1024),
  (5815, 13, 2, 0, 2, 'D00 · bDomain · type · update',
   'D00.org.bdomain_type.U',       5815, 4247552,  512),
  (5816, 13, 2, 0, 3, 'D00 · bDomain · type · delete',
   'D00.org.bdomain_type.D',       5816, 4247552,  768),

  -- Campo: nombre — columna org_empresa.nombre
  (5817, 13, 2, 0, 1, 'D00 · bDomain · nombre · create',
   'D00.org.bdomain_nombre.C',     5817, 4247552,  256),
  (5818, 13, 2, 0, 4, 'D00 · bDomain · nombre · read',
   'D00.org.bdomain_nombre.R',     5818, 4247552, 1024),
  (5819, 13, 2, 0, 2, 'D00 · bDomain · nombre · update',
   'D00.org.bdomain_nombre.U',     5819, 4247552,  512),
  (5820, 13, 2, 0, 3, 'D00 · bDomain · nombre · delete',
   'D00.org.bdomain_nombre.D',     5820, 4247552,  768),

  -- Campo: nit — idn_atributo(cat=documento, key=nit) — TAX_XX por país
  (5821, 13, 2, 0, 1, 'D00 · bDomain · nit · create',
   'D00.org.bdomain_nit.C',        5821, 4247552,  256),
  (5822, 13, 2, 0, 4, 'D00 · bDomain · nit · read',
   'D00.org.bdomain_nit.R',        5822, 4247552, 1024),
  (5823, 13, 2, 0, 2, 'D00 · bDomain · nit · update',
   'D00.org.bdomain_nit.U',        5823, 4247552,  512),
  (5824, 13, 2, 0, 3, 'D00 · bDomain · nit · delete',
   'D00.org.bdomain_nit.D',        5824, 4247552,  768),

  -- Campo: email — idn_atributo(cat=contacto, key=email) — RFC 5321
  (5825, 13, 2, 0, 1, 'D00 · bDomain · email · create',
   'D00.org.bdomain_email.C',      5825, 4247552,  256),
  (5826, 13, 2, 0, 4, 'D00 · bDomain · email · read',
   'D00.org.bdomain_email.R',      5826, 4247552, 1024),
  (5827, 13, 2, 0, 2, 'D00 · bDomain · email · update',
   'D00.org.bdomain_email.U',      5827, 4247552,  512),
  (5828, 13, 2, 0, 3, 'D00 · bDomain · email · delete',
   'D00.org.bdomain_email.D',      5828, 4247552,  768),

  -- Campo: telefono — idn_atributo(cat=contacto, key=telefono) — ITU-T E.164
  (5829, 13, 2, 0, 1, 'D00 · bDomain · telefono · create',
   'D00.org.bdomain_telefono.C',   5829, 4247552,  256),
  (5830, 13, 2, 0, 4, 'D00 · bDomain · telefono · read',
   'D00.org.bdomain_telefono.R',   5830, 4247552, 1024),
  (5831, 13, 2, 0, 2, 'D00 · bDomain · telefono · update',
   'D00.org.bdomain_telefono.U',   5831, 4247552,  512),
  (5832, 13, 2, 0, 3, 'D00 · bDomain · telefono · delete',
   'D00.org.bdomain_telefono.D',   5832, 4247552,  768),

  -- Campo: ci (carnet/doc del bDomain persona) — idn_atributo(cat=documento, key=id_doc) — ID_XX
  (5833, 13, 2, 0, 1, 'D00 · bDomain · ci · create',
   'D00.org.bdomain_ci.C',         5833, 4247552,  256),
  (5834, 13, 2, 0, 4, 'D00 · bDomain · ci · read',
   'D00.org.bdomain_ci.R',         5834, 4247552, 1024),
  (5835, 13, 2, 0, 2, 'D00 · bDomain · ci · update',
   'D00.org.bdomain_ci.U',         5835, 4247552,  512),
  (5836, 13, 2, 0, 3, 'D00 · bDomain · ci · delete',
   'D00.org.bdomain_ci.D',         5836, 4247552,  768),

  -- Campo: direccion — idn_atributo(cat=ubicacion, key=direccion) — TEXTO_LIBRE
  (5837, 13, 2, 0, 1, 'D00 · bDomain · direccion · create',
   'D00.org.bdomain_direccion.C',  5837, 4247552,  256),
  (5838, 13, 2, 0, 4, 'D00 · bDomain · direccion · read',
   'D00.org.bdomain_direccion.R',  5838, 4247552, 1024),
  (5839, 13, 2, 0, 2, 'D00 · bDomain · direccion · update',
   'D00.org.bdomain_direccion.U',  5839, 4247552,  512),
  (5840, 13, 2, 0, 3, 'D00 · bDomain · direccion · delete',
   'D00.org.bdomain_direccion.D',  5840, 4247552,  768),

  -- ===========================================================================
  -- MÓDULO: bsubdomain (group_code=3, contextual_mask=6344704)
  -- Campo: type — columna org_sucursal.tipo
  -- ===========================================================================
  (5841, 13, 3, 0, 1, 'D00 · bSubDomain · type · create',
   'D00.org.bsubdomain_type.C',    5841, 6344704,  256),
  (5842, 13, 3, 0, 4, 'D00 · bSubDomain · type · read',
   'D00.org.bsubdomain_type.R',    5842, 6344704, 1024),
  (5843, 13, 3, 0, 2, 'D00 · bSubDomain · type · update',
   'D00.org.bsubdomain_type.U',    5843, 6344704,  512),
  (5844, 13, 3, 0, 3, 'D00 · bSubDomain · type · delete',
   'D00.org.bsubdomain_type.D',    5844, 6344704,  768),

  -- Campo: nombre — columna org_sucursal.nombre
  (5845, 13, 3, 0, 1, 'D00 · bSubDomain · nombre · create',
   'D00.org.bsubdomain_nombre.C',  5845, 6344704,  256),
  (5846, 13, 3, 0, 4, 'D00 · bSubDomain · nombre · read',
   'D00.org.bsubdomain_nombre.R',  5846, 6344704, 1024),
  (5847, 13, 3, 0, 2, 'D00 · bSubDomain · nombre · update',
   'D00.org.bsubdomain_nombre.U',  5847, 6344704,  512),
  (5848, 13, 3, 0, 3, 'D00 · bSubDomain · nombre · delete',
   'D00.org.bsubdomain_nombre.D',  5848, 6344704,  768),

  -- Campo: direccion — idn_atributo(cat=ubicacion, key=direccion) — SCIM 2.0 RFC 7643
  (5849, 13, 3, 0, 1, 'D00 · bSubDomain · direccion · create',
   'D00.org.bsubdomain_direccion.C', 5849, 6344704, 256),
  (5850, 13, 3, 0, 4, 'D00 · bSubDomain · direccion · read',
   'D00.org.bsubdomain_direccion.R', 5850, 6344704, 1024),
  (5851, 13, 3, 0, 2, 'D00 · bSubDomain · direccion · update',
   'D00.org.bsubdomain_direccion.U', 5851, 6344704, 512),
  (5852, 13, 3, 0, 3, 'D00 · bSubDomain · direccion · delete',
   'D00.org.bsubdomain_direccion.D', 5852, 6344704, 768),

  -- ===========================================================================
  -- MÓDULO: pos (group_code=4, contextual_mask=8441856)
  -- Campo: type — columna org_pos_logico.tipo — SBOS-049 §6.1
  -- ===========================================================================
  (5853, 13, 4, 0, 1, 'D00 · Pos · type · create',
   'D00.org.pos_type.C',           5853, 8441856,  256),
  (5854, 13, 4, 0, 4, 'D00 · Pos · type · read',
   'D00.org.pos_type.R',           5854, 8441856, 1024),
  (5855, 13, 4, 0, 2, 'D00 · Pos · type · update',
   'D00.org.pos_type.U',           5855, 8441856,  512),
  (5856, 13, 4, 0, 3, 'D00 · Pos · type · delete',
   'D00.org.pos_type.D',           5856, 8441856,  768),

  -- Campo: nombre — columna org_pos_logico.nombre
  (5857, 13, 4, 0, 1, 'D00 · Pos · nombre · create',
   'D00.org.pos_nombre.C',         5857, 8441856,  256),
  (5858, 13, 4, 0, 4, 'D00 · Pos · nombre · read',
   'D00.org.pos_nombre.R',         5858, 8441856, 1024),
  (5859, 13, 4, 0, 2, 'D00 · Pos · nombre · update',
   'D00.org.pos_nombre.U',         5859, 8441856,  512),
  (5860, 13, 4, 0, 3, 'D00 · Pos · nombre · delete',
   'D00.org.pos_nombre.D',         5860, 8441856,  768),

  -- ===========================================================================
  -- MÓDULO: actor columnas directas (group_code=5, contextual_mask=10538496)
  -- Fuente: idn_user_template — SCIM 2.0 RFC 7643 §4.1 / Enterprise §4.3
  -- ===========================================================================

  -- Campo: type — columna idn_user_template.actor_type
  (5861, 13, 5, 0, 1, 'D00 · Actor · type · create',
   'D00.org.actor_type.C',             5861, 10538496,  256),
  (5862, 13, 5, 0, 4, 'D00 · Actor · type · read',
   'D00.org.actor_type.R',             5862, 10538496, 1024),
  (5863, 13, 5, 0, 2, 'D00 · Actor · type · update',
   'D00.org.actor_type.U',             5863, 10538496,  512),
  (5864, 13, 5, 0, 3, 'D00 · Actor · type · delete',
   'D00.org.actor_type.D',             5864, 10538496,  768),

  -- Campo: employee_type — columna idn_user_template.employee_type
  (5865, 13, 5, 0, 1, 'D00 · Actor · employee_type · create',
   'D00.org.actor_employee_type.C',    5865, 10538496,  256),
  (5866, 13, 5, 0, 4, 'D00 · Actor · employee_type · read',
   'D00.org.actor_employee_type.R',    5866, 10538496, 1024),
  (5867, 13, 5, 0, 2, 'D00 · Actor · employee_type · update',
   'D00.org.actor_employee_type.U',    5867, 10538496,  512),
  (5868, 13, 5, 0, 3, 'D00 · Actor · employee_type · delete',
   'D00.org.actor_employee_type.D',    5868, 10538496,  768),

  -- Campo: gender — columna idn_user_template.gender — SCIM 2.0 RFC 7643 §4.1.2
  (5869, 13, 5, 0, 1, 'D00 · Actor · gender · create',
   'D00.org.actor_gender.C',           5869, 10538496,  256),
  (5870, 13, 5, 0, 4, 'D00 · Actor · gender · read',
   'D00.org.actor_gender.R',           5870, 10538496, 1024),
  (5871, 13, 5, 0, 2, 'D00 · Actor · gender · update',
   'D00.org.actor_gender.U',           5871, 10538496,  512),
  (5872, 13, 5, 0, 3, 'D00 · Actor · gender · delete',
   'D00.org.actor_gender.D',           5872, 10538496,  768),

  -- Campo: marital_status — columna idn_user_template.marital_status — ISO 24760-2:2025 §4.3
  (5873, 13, 5, 0, 1, 'D00 · Actor · marital_status · create',
   'D00.org.actor_marital_status.C',   5873, 10538496,  256),
  (5874, 13, 5, 0, 4, 'D00 · Actor · marital_status · read',
   'D00.org.actor_marital_status.R',   5874, 10538496, 1024),
  (5875, 13, 5, 0, 2, 'D00 · Actor · marital_status · update',
   'D00.org.actor_marital_status.U',   5875, 10538496,  512),
  (5876, 13, 5, 0, 3, 'D00 · Actor · marital_status · delete',
   'D00.org.actor_marital_status.D',   5876, 10538496,  768),

  -- Campo: id_doc_type — columna idn_user_template.id_doc_type — ISO 3166-1 por país
  (5877, 13, 5, 0, 1, 'D00 · Actor · id_doc_type · create',
   'D00.org.actor_id_doc_type.C',      5877, 10538496,  256),
  (5878, 13, 5, 0, 4, 'D00 · Actor · id_doc_type · read',
   'D00.org.actor_id_doc_type.R',      5878, 10538496, 1024),
  (5879, 13, 5, 0, 2, 'D00 · Actor · id_doc_type · update',
   'D00.org.actor_id_doc_type.U',      5879, 10538496,  512),
  (5880, 13, 5, 0, 3, 'D00 · Actor · id_doc_type · delete',
   'D00.org.actor_id_doc_type.D',      5880, 10538496,  768),

  -- Campo: locale — columna idn_user_template.locale — IETF BCP 47
  (5881, 13, 5, 0, 1, 'D00 · Actor · locale · create',
   'D00.org.actor_locale.C',           5881, 10538496,  256),
  (5882, 13, 5, 0, 4, 'D00 · Actor · locale · read',
   'D00.org.actor_locale.R',           5882, 10538496, 1024),
  (5883, 13, 5, 0, 2, 'D00 · Actor · locale · update',
   'D00.org.actor_locale.U',           5883, 10538496,  512),
  (5884, 13, 5, 0, 3, 'D00 · Actor · locale · delete',
   'D00.org.actor_locale.D',           5884, 10538496,  768),

  -- Campo: timezone — columna idn_user_template.timezone — IANA tzdata
  (5885, 13, 5, 0, 1, 'D00 · Actor · timezone · create',
   'D00.org.actor_timezone.C',         5885, 10538496,  256),
  (5886, 13, 5, 0, 4, 'D00 · Actor · timezone · read',
   'D00.org.actor_timezone.R',         5886, 10538496, 1024),
  (5887, 13, 5, 0, 2, 'D00 · Actor · timezone · update',
   'D00.org.actor_timezone.U',         5887, 10538496,  512),
  (5888, 13, 5, 0, 3, 'D00 · Actor · timezone · delete',
   'D00.org.actor_timezone.D',         5888, 10538496,  768),

  -- ===========================================================================
  -- MÓDULO: actor idn_atributo — PERSONAL (group_code=5)
  -- Requiere: tabla idn_atributo (migración 004) para almacenamiento.
  -- Los átomos se registran ahora; la tabla storage se crea en 004.
  -- ===========================================================================

  -- Campo: birth_date — idn_atributo(cat=personal, key=birth_date) — ISO 8601
  (5889, 13, 5, 0, 1, 'D00 · Actor · birth_date · create',
   'D00.org.actor_birth_date.C',       5889, 10538496,  256),
  (5890, 13, 5, 0, 4, 'D00 · Actor · birth_date · read',
   'D00.org.actor_birth_date.R',       5890, 10538496, 1024),
  (5891, 13, 5, 0, 2, 'D00 · Actor · birth_date · update',
   'D00.org.actor_birth_date.U',       5891, 10538496,  512),
  (5892, 13, 5, 0, 3, 'D00 · Actor · birth_date · delete',
   'D00.org.actor_birth_date.D',       5892, 10538496,  768),

  -- Campo: nationality — idn_atributo(cat=personal, key=nationality) — ISO 3166-1 alpha-2
  (5893, 13, 5, 0, 1, 'D00 · Actor · nationality · create',
   'D00.org.actor_nationality.C',      5893, 10538496,  256),
  (5894, 13, 5, 0, 4, 'D00 · Actor · nationality · read',
   'D00.org.actor_nationality.R',      5894, 10538496, 1024),
  (5895, 13, 5, 0, 2, 'D00 · Actor · nationality · update',
   'D00.org.actor_nationality.U',      5895, 10538496,  512),
  (5896, 13, 5, 0, 3, 'D00 · Actor · nationality · delete',
   'D00.org.actor_nationality.D',      5896, 10538496,  768),

  -- Campo: id_doc_number — idn_atributo(cat=documento, key=id_doc) — campo sensible
  (5897, 13, 5, 0, 1, 'D00 · Actor · id_doc_number · create',
   'D00.org.actor_id_doc_number.C',    5897, 10538496,  256),
  (5898, 13, 5, 0, 4, 'D00 · Actor · id_doc_number · read',
   'D00.org.actor_id_doc_number.R',    5898, 10538496, 1024),
  (5899, 13, 5, 0, 2, 'D00 · Actor · id_doc_number · update',
   'D00.org.actor_id_doc_number.U',    5899, 10538496,  512),
  (5900, 13, 5, 0, 3, 'D00 · Actor · id_doc_number · delete',
   'D00.org.actor_id_doc_number.D',    5900, 10538496,  768),

  -- Campo: email (del actor individual) — idn_atributo(cat=contacto, key=email) — RFC 5321
  (5901, 13, 5, 0, 1, 'D00 · Actor · email · create',
   'D00.org.actor_email.C',            5901, 10538496,  256),
  (5902, 13, 5, 0, 4, 'D00 · Actor · email · read',
   'D00.org.actor_email.R',            5902, 10538496, 1024),
  (5903, 13, 5, 0, 2, 'D00 · Actor · email · update',
   'D00.org.actor_email.U',            5903, 10538496,  512),
  (5904, 13, 5, 0, 3, 'D00 · Actor · email · delete',
   'D00.org.actor_email.D',            5904, 10538496,  768),

  -- Campo: telefono (del actor) — idn_atributo(cat=contacto, key=telefono) — ITU-T E.164
  (5905, 13, 5, 0, 1, 'D00 · Actor · telefono · create',
   'D00.org.actor_telefono.C',         5905, 10538496,  256),
  (5906, 13, 5, 0, 4, 'D00 · Actor · telefono · read',
   'D00.org.actor_telefono.R',         5906, 10538496, 1024),
  (5907, 13, 5, 0, 2, 'D00 · Actor · telefono · update',
   'D00.org.actor_telefono.U',         5907, 10538496,  512),
  (5908, 13, 5, 0, 3, 'D00 · Actor · telefono · delete',
   'D00.org.actor_telefono.D',         5908, 10538496,  768),

  -- Campo: direccion (del actor) — idn_atributo(cat=ubicacion, key=direccion)
  (5909, 13, 5, 0, 1, 'D00 · Actor · direccion · create',
   'D00.org.actor_direccion.C',        5909, 10538496,  256),
  (5910, 13, 5, 0, 4, 'D00 · Actor · direccion · read',
   'D00.org.actor_direccion.R',        5910, 10538496, 1024),
  (5911, 13, 5, 0, 2, 'D00 · Actor · direccion · update',
   'D00.org.actor_direccion.U',        5911, 10538496,  512),
  (5912, 13, 5, 0, 3, 'D00 · Actor · direccion · delete',
   'D00.org.actor_direccion.D',        5912, 10538496,  768),

  -- Campo: photo — idn_atributo(cat=personal, key=photo_url) — URL_HTTPS
  (5913, 13, 5, 0, 1, 'D00 · Actor · photo · create',
   'D00.org.actor_photo.C',            5913, 10538496,  256),
  (5914, 13, 5, 0, 4, 'D00 · Actor · photo · read',
   'D00.org.actor_photo.R',            5914, 10538496, 1024),
  (5915, 13, 5, 0, 2, 'D00 · Actor · photo · update',
   'D00.org.actor_photo.U',            5915, 10538496,  512),
  (5916, 13, 5, 0, 3, 'D00 · Actor · photo · delete',
   'D00.org.actor_photo.D',            5916, 10538496,  768),

  -- ===========================================================================
  -- MÓDULO: actor idn_atributo — BIO (group_code=5)
  -- ===========================================================================
  -- Campo: bio — idn_atributo(cat=personal, key=bio) — SCIM 2.0 §4.1
  (5917, 13, 5, 0, 1, 'D00 · Actor · bio · create',
   'D00.org.actor_bio.C',              5917, 10538496,  256),
  (5918, 13, 5, 0, 4, 'D00 · Actor · bio · read',
   'D00.org.actor_bio.R',              5918, 10538496, 1024),
  (5919, 13, 5, 0, 2, 'D00 · Actor · bio · update',
   'D00.org.actor_bio.U',              5919, 10538496,  512),
  (5920, 13, 5, 0, 3, 'D00 · Actor · bio · delete',
   'D00.org.actor_bio.D',              5920, 10538496,  768),

  -- ===========================================================================
  -- MÓDULO: actor idn_atributo — PROFESIONAL (group_code=5)
  -- Fuente: SCIM Enterprise Extension §4.3
  -- ===========================================================================
  -- Campo: department — idn_atributo(cat=profesional, key=departamento)
  (5921, 13, 5, 0, 1, 'D00 · Actor · department · create',
   'D00.org.actor_department.C',       5921, 10538496,  256),
  (5922, 13, 5, 0, 4, 'D00 · Actor · department · read',
   'D00.org.actor_department.R',       5922, 10538496, 1024),
  (5923, 13, 5, 0, 2, 'D00 · Actor · department · update',
   'D00.org.actor_department.U',       5923, 10538496,  512),
  (5924, 13, 5, 0, 3, 'D00 · Actor · department · delete',
   'D00.org.actor_department.D',       5924, 10538496,  768),

  -- Campo: title (cargo profesional) — idn_atributo(cat=profesional, key=cargo)
  (5925, 13, 5, 0, 1, 'D00 · Actor · title · create',
   'D00.org.actor_title.C',            5925, 10538496,  256),
  (5926, 13, 5, 0, 4, 'D00 · Actor · title · read',
   'D00.org.actor_title.R',            5926, 10538496, 1024),
  (5927, 13, 5, 0, 2, 'D00 · Actor · title · update',
   'D00.org.actor_title.U',            5927, 10538496,  512),
  (5928, 13, 5, 0, 3, 'D00 · Actor · title · delete',
   'D00.org.actor_title.D',            5928, 10538496,  768)

ON CONFLICT (app_code, atom_slug) DO NOTHING;

-- ============================================================================
-- PASO 8 — Tenant externo de ejemplo (DEPO srl)
-- ============================================================================
-- Primer tenant externo del sistema. is_internal=false.
-- ⚠️ Ajustar legal_name, tax_id, realm_kc con datos reales antes de producción.
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
-- -- debe retornar 120

-- SELECT atom_position, atom_slug
-- FROM bauth.privilege_atom WHERE domain_code = 0 ORDER BY atom_position;
-- -- debe retornar 120 filas, posiciones 5809-5928

-- SELECT count(*) FROM bauth.privilege_verb;
-- -- debe retornar 50 (NO 63 — verbos semánticos no se insertan en v2 CRUD)

-- SELECT tenant_slug, tenant_name, is_internal
-- FROM bauth.idn_tenant ORDER BY is_internal DESC;
-- -- skull: is_internal=true, depo-srl: is_internal=false

-- ============================================================================
-- NOTA SOBRE SEEDS
-- ============================================================================
-- Los seeds seed_privilege_domain.sql, seed_privilege_application.sql,
-- seed_privilege_group.sql y seed_privilege_atom.sql usan TRUNCATE CASCADE.
-- Si se re-ejecutan DESPUÉS de esta migración, borrarán los datos de D00.
--
-- Para hacerlos idempotentes con D00, actualizar (FASE 0.S grupo D):
--   1. seed_privilege_domain.sql     → agregar D00 (domain_code=0) en el INSERT
--   2. seed_privilege_application.sql → agregar app_code=13 'Org'
--   3. seed_privilege_group.sql       → agregar 5 grupos app_code=13
--   4. seed_privilege_atom.sql        → agregar INSERT estático 120 átomos D00 al final
--
-- Estos cambios se detallan en INFORME-DELTA-DDL-D00.md §5.
-- Requieren aprobación separada (ADR-016).
-- ============================================================================

-- ============================================================================
-- BLOQUE DE LIMPIEZA — usar SOLO si la versión semántica (v1) ya fue ejecutada
-- ============================================================================
-- Si 003_d00_identidad_organizacional.sql (v1 semántica) ya fue aplicada:
-- ejecutar este bloque ANTES del BEGIN principal para limpiar los datos semánticos.
--
-- DELETE FROM bauth.privilege_atom
--   WHERE app_code = 13 AND domain_code = 0 AND verb_code BETWEEN 51 AND 63;
-- DELETE FROM bauth.privilege_verb
--   WHERE verb_code BETWEEN 51 AND 63;
-- ============================================================================
