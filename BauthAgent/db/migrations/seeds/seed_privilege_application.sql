-- seed_privilege_application.sql — 12 aplicaciones base SBOS
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: BosAgent/src/servers/*/manifest.yml (31 fichas, 12 apps)
-- Schema real: app_code SMALLINT PK, app_name, app_slug, tenant_id UUID, active, registered_at
-- NOTA: tenant_id usa un UUID fijo para bootstrap. Al registrar un tenant real, se actualiza.
-- ═══════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.privilege_application RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.privilege_application;

-- UUID fijo para tenant del sistema (bootstrap). Se actualiza al crear el tenant real.
INSERT INTO bauth.privilege_application (app_code, app_name, app_slug, tenant_id, active, registered_at) VALUES
  (1,  'Tryton','tryton',      COALESCE((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), '4c697f66-d204-45a5-ac36-c104f07c7046'::uuid), true, now()),
  (2,  'Keycloak','keycloak',  COALESCE((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), '4c697f66-d204-45a5-ac36-c104f07c7046'::uuid), true, now()),
  (3,  'Kong','kong',          COALESCE((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), '4c697f66-d204-45a5-ac36-c104f07c7046'::uuid), true, now()),
  (4,  'Vault','vault',        COALESCE((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), '4c697f66-d204-45a5-ac36-c104f07c7046'::uuid), true, now()),
  (5,  'Cal.com','calcom',     COALESCE((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), '4c697f66-d204-45a5-ac36-c104f07c7046'::uuid), true, now()),
  (6,  'Mattermost','mattermost',COALESCE((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), '4c697f66-d204-45a5-ac36-c104f07c7046'::uuid), true, now()),
  (7,  'Novu','novu',          COALESCE((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), '4c697f66-d204-45a5-ac36-c104f07c7046'::uuid), true, now()),
  (8,  'Grafana','grafana',    COALESCE((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), '4c697f66-d204-45a5-ac36-c104f07c7046'::uuid), true, now()),
  (9,  'Prometheus','prometheus',COALESCE((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), '4c697f66-d204-45a5-ac36-c104f07c7046'::uuid), true, now()),
  (10, 'Besu QBFT','besu',     COALESCE((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), '4c697f66-d204-45a5-ac36-c104f07c7046'::uuid), true, now()),
  (11, 'MinIO','minio',        COALESCE((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), '4c697f66-d204-45a5-ac36-c104f07c7046'::uuid), true, now()),
  (12, 'PostgreSQL','postgresql',COALESCE((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), '4c697f66-d204-45a5-ac36-c104f07c7046'::uuid), true, now());

-- SELECT count(*) FROM bauth.privilege_application; -- debe ser 12
