-- seed_privilege_atom.sql — Átomos generados desde TANDA 1
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: combinación P01×P02×P05×P06. Solo combinaciones válidas.
-- Schema real: atom_code, app_code, group_code, domain_code, verb_code,
--   atom_name, atom_slug, atom_position, contextual_mask, logical_mask
-- ═══════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.privilege_atom RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.privilege_atom;

INSERT INTO bauth.privilege_atom (atom_code, app_code, group_code, domain_code, verb_code, atom_name, atom_slug, atom_position, contextual_mask, logical_mask)
SELECT
  row_number() OVER (ORDER BY a.app_code, g.group_code, d.domain_code, v.verb_code) AS atom_code,
  a.app_code, g.group_code, d.domain_code, v.verb_code,
  a.app_name || ' · ' || g.group_name || ' · ' || d.domain_name || ' · ' || v.verb_name AS atom_name,
  LOWER(a.app_slug || '.g' || g.group_code || '.d' || d.domain_code || '.' || v.verb_slug) AS atom_slug,
  row_number() OVER (ORDER BY a.app_code, g.group_code, d.domain_code, v.verb_code) AS atom_position,
  -- MANUAL §4.2: [8 res][4 dom][9 app][11 grupo]
  (d.domain_code::integer << 8) | (a.app_code::integer << 12) | (g.group_code::integer << 21) AS contextual_mask,
  -- MANUAL §4.3: [6 res][2 pol][24 verb]
  (v.verb_code::integer << 8) AS logical_mask
FROM bauth.privilege_application a
JOIN bauth.privilege_group g ON a.app_code = g.app_code
CROSS JOIN bauth.privilege_domain d
CROSS JOIN bauth.privilege_verb v
WHERE (
  v.verb_code BETWEEN 1 AND 4
  OR (v.verb_code IN (9,13,15,16,23,28,29,33,34,35) AND d.domain_code = 3)
  OR (v.verb_code IN (10,11,12,22,24,25,36,37) AND d.domain_code IN (1,3,4))
  OR (v.verb_code IN (38,39,40,41,43,44,46,48,49) AND d.domain_code = 1)
  OR (v.verb_code IN (6,7,17,18,19) AND d.domain_code IN (1,2,3))
  OR (v.verb_code IN (14,42,47,50) AND d.domain_code IN (1,8))
  OR (v.verb_code = 45 AND d.domain_code IN (1,8,11))
  OR (v.verb_code IN (5,31) AND d.domain_code IN (1,3))
);

-- SELECT count(*) FROM bauth.privilege_atom;
