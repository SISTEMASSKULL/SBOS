-- seed_zone_application_map.sql — Zonas ↔ Aplicaciones
SET lock_timeout = '5s'; TRUNCATE TABLE bauth.zone_application_map RESTART IDENTITY CASCADE; REINDEX TABLE bauth.zone_application_map;
INSERT INTO bauth.zone_application_map (zone_id, app_code, app_scopes, modules)
SELECT 'AREA-COM', app_code, ARRAY['openid','profile'], ARRAY['sale','party'] FROM bauth.privilege_application WHERE app_slug='tryton'
UNION ALL SELECT 'AREA-OPER', app_code, ARRAY['openid','profile'], ARRAY['sale_pos','account_invoice'] FROM bauth.privilege_application WHERE app_slug='tryton'
UNION ALL SELECT 'AREA-CONT', app_code, ARRAY['openid','profile'], ARRAY['account_invoice'] FROM bauth.privilege_application WHERE app_slug='tryton'
UNION ALL SELECT 'AREA-CONT', app_code, ARRAY['openid','profile'], ARRAY['account'] FROM bauth.privilege_application WHERE app_slug='tryton'
UNION ALL SELECT 'AREA-DIR', app_code, ARRAY['openid','profile'], ARRAY['res','ir'] FROM bauth.privilege_application WHERE app_slug='tryton'
UNION ALL SELECT 'AREA-DIR', app_code, ARRAY['admin'], ARRAY[]::text[] FROM bauth.privilege_application WHERE app_slug='keycloak'
UNION ALL SELECT 'AREA-FIN', app_code, ARRAY['admin'], ARRAY[]::text[] FROM bauth.privilege_application WHERE app_slug='keycloak'
UNION ALL SELECT 'AREA-FIN', app_code, ARRAY['admin'], ARRAY[]::text[] FROM bauth.privilege_application WHERE app_slug='vault'
UNION ALL SELECT 'AREA-DIR', app_code, ARRAY['admin'], ARRAY[]::text[] FROM bauth.privilege_application WHERE app_slug='kong'
ON CONFLICT DO NOTHING;
