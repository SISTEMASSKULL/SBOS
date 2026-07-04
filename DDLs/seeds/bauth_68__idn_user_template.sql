-- seed_idn_user_template.sql — Template de usuario SCIM 2.0 desde biblioteca
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: SCIM 2.0 RFC 7643 · NIST SP 800-63B-4 · cfg_policy_library
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.idn_user_template RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.idn_user_template;

INSERT INTO bauth.idn_user_template (uuid, username, email, tenant_id, empresa_id, status, template, template_version, ctx_id, created_at, updated_at)
SELECT
  gen_random_uuid(), 'template_default', 'template@sbos.app', '*',
  '4c697f66-d204-45a5-ac36-c104f07c7046',
  'active',
  jsonb_build_object(
    'version', '3.0',
    'name', 'Usuario Estándar SBOS',
    'description', 'Template de usuario con métodos, sesiones y credenciales desde la biblioteca unificada',
    'auth_methods', (SELECT jsonb_agg(DISTINCT section_name) FROM bauth.cfg_policy_library WHERE semantic_type = 'method' AND depth = 1),
    'session_policy', jsonb_build_object(
      'timeout_minutes', 480,
      'idle_minutes', 15,
      'max_concurrent', 3,
      'source_ref', 'authenticationFramework.advancedSessionManagement'
    ),
    'credential_policy', jsonb_build_object(
      'min_length', 12,
      'hibp_check', true,
      'no_complexity_rules', true,
      'no_periodic_rotation', true,
      'mfa_required', true,
      'phishing_resistant_required', true,
      'source_ref', 'nist_sp_800_63b_rev4.password_policy_rev4'
    ),
    'assurance_levels', jsonb_build_object(
      'default', 'AAL1',
      'sensitive', 'AAL2',
      'critical', 'AAL3'
    ),
    'applicable_policies', (SELECT jsonb_agg(json_path) FROM bauth.cfg_policy_library WHERE semantic_type IN ('policy','configuration') AND enforcement = 'mandatory' AND depth <= 2),
    'library_version', '2026-06-25'
  ),
  '3.0',
  'seed-library',
  now(),
  now()
WHERE NOT EXISTS (SELECT 1 FROM bauth.idn_user_template WHERE template->>'name' = 'Usuario Estándar SBOS');
