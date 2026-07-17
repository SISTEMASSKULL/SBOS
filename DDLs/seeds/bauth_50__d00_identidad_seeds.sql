-- ============================================================================
-- bauth_50__d00_identidad_seeds.sql — Seeds del Dominio D00
-- ============================================================================
-- Propósito : Poblar el Dominio D00 en el catálogo de privilegios:
--             dominio 0, app org (13), 5 grupos, 13 verbos, 20 átomos.
--             Datos originalmente en bauth_10__d00_identidad_organizacional.sql
--             (PASOS 3-8), movidos aquí por ORQUESTA-050.
-- Fuente    : BAUTH-ARQUITECTURA-ATOMICA-FINAL.md §D00
--             bauth_10__d00_identidad_organizacional.sql (PASOS 3-8)
-- Autor     : bauth-developer · 2026-07-14
-- ============================================================================
-- IDEMPOTENCIA: INSERT ... ON CONFLICT DO NOTHING en todos los pasos.
-- NO usa TRUNCATE. Es seguro ejecutar múltiples veces.
-- ============================================================================

BEGIN;
SET lock_timeout = '5s';

-- ============================================================================
-- PASO 1 — Insertar Dominio D00 (domain_code=0)
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
-- PASO 2 — Insertar aplicación org (app_code=13)
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
-- PASO 3 — Insertar 5 grupos de la aplicación org
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
-- PASO 4 — Insertar 13 verbos de identidad (verb_code 51-63)
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
-- PASO 5 — Insertar 20 átomos D00 (atom_position 5809-5828)
-- ============================================================================

INSERT INTO bauth.privilege_atom
  (atom_code, app_code, group_code, domain_code, verb_code,
   atom_name, atom_slug, atom_position, contextual_mask, logical_mask)
VALUES
  -- Grupo 1: Tenant (g1)
  (5809, 13, 1, 0, 51,
   'Org · Tenant     · Identidad Org · Tipo',
   'org.g1.d0.type',        5809, 2150400,  13056),

  -- Grupo 2: bDomain (g2)
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

  -- Grupo 3: bSubDomain (g3)
  (5817, 13, 3, 0, 51,
   'Org · bSubDomain · Identidad Org · Tipo',
   'org.g3.d0.type',        5817, 6344704,  13056),
  (5818, 13, 3, 0, 52,
   'Org · bSubDomain · Identidad Org · Nombre',
   'org.g3.d0.nombre',      5818, 6344704,  13312),
  (5819, 13, 3, 0, 57,
   'Org · bSubDomain · Identidad Org · Dirección',
   'org.g3.d0.direccion',   5819, 6344704,  14592),

  -- Grupo 4: Pos (g4)
  (5820, 13, 4, 0, 51,
   'Org · Pos        · Identidad Org · Tipo',
   'org.g4.d0.type',        5820, 8441856,  13056),
  (5821, 13, 4, 0, 52,
   'Org · Pos        · Identidad Org · Nombre',
   'org.g4.d0.nombre',      5821, 8441856,  13312),

  -- Grupo 5: Actor (g5)
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

COMMIT;
