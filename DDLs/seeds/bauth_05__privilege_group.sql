-- seed_privilege_group.sql — 48 grupos funcionales por aplicación
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: Odoo res.groups + Tryton modules + Manual D1 §2.1b
-- Schema real: group_code SMALLINT, app_code SMALLINT, group_name VARCHAR(128)
-- PK: (app_code, group_code)
-- ═══════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.privilege_group RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.privilege_group;

INSERT INTO bauth.privilege_group (app_code, group_code, group_name) VALUES
-- Tryton (app=1) — 10 grupos
(1, 1,  'Contabilidad'),
(1, 2,  'Inventario'),
(1, 3,  'Ventas'),
(1, 4,  'Compras'),
(1, 5,  'Gestión de Tiempo'),
(1, 6,  'Proyectos'),
(1, 7,  'Administración'),
(1, 8,  'Punto de Venta'),
(1, 9,  'Calendario'),
(1, 10, 'Marketing'),
-- Keycloak (app=2) — 5 grupos
(2, 1, 'Administrador de Realm'),
(2, 2, 'Administrador de Clientes'),
(2, 3, 'Administrador de Usuarios'),
(2, 4, 'Proveedor de Identidad'),
(2, 5, 'Auditor'),
-- Kong (app=3) — 4 grupos
(3, 1, 'Administrador'),
(3, 2, 'Desarrollador'),
(3, 3, 'Consumidor'),
(3, 4, 'Monitor'),
-- Vault (app=4) — 4 grupos
(4, 1, 'Administrador'),
(4, 2, 'Operador'),
(4, 3, 'Auditor'),
(4, 4, 'App Role'),
-- Cal.com (app=5) — 3 grupos
(5, 1, 'Administrador de Calendario'),
(5, 2, 'Usuario de Calendario'),
(5, 3, 'Visualizador de Agenda'),
-- Mattermost (app=6) — 3 grupos
(6, 1, 'Administrador de Canal'),
(6, 2, 'Usuario'),
(6, 3, 'Auditor'),
-- Novu (app=7) — 3 grupos
(7, 1, 'Administrador de Workflows'),
(7, 2, 'Gestor de Suscriptores'),
(7, 3, 'Visualizador'),
-- Grafana (app=8) — 3 grupos
(8, 1, 'Editor'),
(8, 2, 'Viewer'),
(8, 3, 'Admin'),
-- Prometheus (app=9) — 3 grupos
(9, 1, 'Administrador'),
(9, 2, 'Operador'),
(9, 3, 'Viewer'),
-- Besu QBFT (app=10) — 3 grupos
(10, 1, 'Validador'),
(10, 2, 'Usuario RPC'),
(10, 3, 'Auditor'),
-- MinIO (app=11) — 3 grupos
(11, 1, 'Administrador'),
(11, 2, 'Lectura/Escritura'),
(11, 3, 'Solo Lectura'),
-- PostgreSQL (app=12) — 4 grupos
(12, 1, 'Superusuario'),
(12, 2, 'Lectura/Escritura'),
(12, 3, 'Solo Lectura'),
(12, 4, 'Replicador');

-- SELECT count(*) FROM bauth.privilege_group; -- debe ser 48
