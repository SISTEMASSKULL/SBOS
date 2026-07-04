-- seed_org_sucursal.sql — Sucursal Central bootstrap
SET lock_timeout = '5s'; TRUNCATE TABLE bauth.org_sucursal RESTART IDENTITY CASCADE; REINDEX TABLE bauth.org_sucursal;
INSERT INTO bauth.org_sucursal (sucursal_id, empresa_id, tenant_id, nombre, ciudad, timezone, horario_apertura, horario_cierre, status) VALUES
('skull-central','skull','skull','Oficina Central','La Paz','America/La_Paz','08:00','18:00','ACTIVE');
