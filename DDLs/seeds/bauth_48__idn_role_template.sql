-- seed_idn_role_template.sql — 23 roles base (sistémicos + organizacionales)
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: BAUTH-CATALOGO-ROLES-EMPRESARIALES.md §2-7
-- Schema actual: id TEXT PK, tenant_id, parent_id, type_id, tier, hierarchy_level, status...
-- ═══════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.idn_role_template RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.idn_role_template;

INSERT INTO bauth.idn_role_template (id, tenant_id, parent_id, type_id, tier, hierarchy_level, status, issuer, owner_tenant, loa_required, mfa_required, audit_level, created_by, template, template_version) VALUES

-- ROLES SISTÉMICOS (11)
('ROL-SYS-SUPERUSUARIO',    '*', NULL,                        'TYPE-ADMIN-SISTEMA', 'SU',      1, 'DEFINIDO', 'SBOS-Coordinador', '*', 3, true, 'full', 'seed-library', '{}', '6.0'),
('ROL-SYS-ADMIN-PROYECTO',  '*', 'ROL-SYS-SUPERUSUARIO',      'TYPE-ADMIN-SISTEMA', 'BIZ_N1',  2, 'DEFINIDO', 'SBOS-Coordinador', '*', 3, true, 'full', 'seed-library', '{}', '6.0'),
('ROL-SYS-ADMIN-SEGURIDAD', '*', 'ROL-SYS-SUPERUSUARIO',      'TYPE-ADMIN-SISTEMA', 'BIZ_N1',  2, 'DEFINIDO', 'SBOS-Coordinador', '*', 3, true, 'full', 'seed-library', '{}', '6.0'),
('ROL-SYS-ADMIN-INFRA',     '*', 'ROL-SYS-SUPERUSUARIO',      'TYPE-ADMIN-SISTEMA', 'BIZ_N1',  2, 'DEFINIDO', 'SBOS-Coordinador', '*', 3, true, 'full', 'seed-library', '{}', '6.0'),
('ROL-SYS-ADMIN-BAUTH',     '*', 'ROL-SYS-ADMIN-SEGURIDAD',   'TYPE-ADMIN-SISTEMA', 'BIZ_N2',  3, 'DEFINIDO', 'SBOS-Coordinador', '*', 3, true, 'full', 'seed-library', '{}', '6.0'),
('ROL-SYS-ADMIN-KEYCLOAK',  '*', 'ROL-SYS-ADMIN-SEGURIDAD',   'TYPE-ADMIN-SISTEMA', 'BIZ_N2',  3, 'DEFINIDO', 'SBOS-Coordinador', '*', 3, true, 'full', 'seed-library', '{}', '6.0'),
('ROL-SYS-ADMIN-TENANT',    '*', 'ROL-SYS-ADMIN-BAUTH',       'TYPE-ADMIN-SISTEMA', 'BIZ_N3',  4, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'basic', 'seed-library', '{}', '6.0'),
('ROL-SYS-BOS-DAEMON',      '*', NULL,                        'TYPE-SERVICIO',      'M2M',     5, 'DEFINIDO', 'SBOS-Coordinador', '*', 1, false, 'full', 'seed-library', '{}', '6.0'),
('ROL-SYS-BAUTH-DAEMON',    '*', NULL,                        'TYPE-SERVICIO',      'M2M',     5, 'DEFINIDO', 'SBOS-Coordinador', '*', 1, false, 'full', 'seed-library', '{}', '6.0'),
('ROL-SYS-BKERNEL-DAEMON',  '*', NULL,                        'TYPE-SERVICIO',      'M2M',     5, 'DEFINIDO', 'SBOS-Coordinador', '*', 1, false, 'full', 'seed-library', '{}', '6.0'),
('ROL-SYS-BIEDATA-DAEMON',  '*', NULL,                        'TYPE-SERVICIO',      'M2M',     5, 'DEFINIDO', 'SBOS-Coordinador', '*', 1, false, 'full', 'seed-library', '{}', '6.0'),

-- ALTA DIRECCIÓN (8)
('ROL-ORG-CEO',     '*', NULL,                 'TYPE-DIRECCION',       'BIZ_N1', 1, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'full', 'seed-library', '{}', '6.0'),
('ROL-ORG-CFO',     '*', 'ROL-ORG-CEO',        'TYPE-DIRECCION',       'BIZ_N1', 2, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'full', 'seed-library', '{}', '6.0'),
('ROL-ORG-COO',     '*', 'ROL-ORG-CEO',        'TYPE-DIRECCION',       'BIZ_N1', 2, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'full', 'seed-library', '{}', '6.0'),
('ROL-ORG-CTO',     '*', 'ROL-ORG-CEO',        'TYPE-DIRECCION',       'BIZ_N1', 2, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'full', 'seed-library', '{}', '6.0'),
('ROL-ORG-CHRO',    '*', 'ROL-ORG-CEO',        'TYPE-DIRECCION',       'BIZ_N1', 2, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'basic', 'seed-library', '{}', '6.0'),
('ROL-ORG-CCO',     '*', 'ROL-ORG-CEO',        'TYPE-DIRECCION',       'BIZ_N1', 2, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'basic', 'seed-library', '{}', '6.0'),
('ROL-ORG-DIR-IT',  '*', 'ROL-ORG-CTO',        'TYPE-DIRECCION',       'BIZ_N2', 3, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'basic', 'seed-library', '{}', '6.0'),
('ROL-ORG-DIR-FIN', '*', 'ROL-ORG-CFO',        'TYPE-DIRECCION',       'BIZ_N2', 3, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'basic', 'seed-library', '{}', '6.0'),

-- GERENCIA Y OPERATIVOS (10)
('ROL-ORG-GER-VENT',    '*', 'ROL-ORG-CCO',         'TYPE-GERENCIA-MEDIA', 'BIZ_N3', 4, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'basic', 'seed-library', '{}', '6.0'),
('ROL-ORG-GER-RRHH',    '*', 'ROL-ORG-CHRO',        'TYPE-GERENCIA-MEDIA', 'BIZ_N3', 4, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'basic', 'seed-library', '{}', '6.0'),
('ROL-ORG-GER-IT',      '*', 'ROL-ORG-DIR-IT',      'TYPE-GERENCIA-MEDIA', 'BIZ_N3', 4, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'basic', 'seed-library', '{}', '6.0'),
('ROL-ORG-CONT-SENIOR', '*', 'ROL-ORG-DIR-FIN',     'TYPE-OPERATIVO',      'BIZ_N4', 5, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'basic', 'seed-library', '{}', '6.0'),
('ROL-ORG-VEND-SENIOR', '*', 'ROL-ORG-GER-VENT',    'TYPE-OPERATIVO',      'BIZ_N4', 5, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'basic', 'seed-library', '{}', '6.0'),
('ROL-ORG-VEND-JUNIOR', '*', 'ROL-ORG-VEND-SENIOR', 'TYPE-OPERATIVO',      'BIZ_N4', 5, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'basic', 'seed-library', '{}', '6.0'),
('ROL-ORG-CAJ',         '*', 'ROL-ORG-GER-VENT',    'TYPE-OPERATIVO',      'BIZ_N4', 5, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'basic', 'seed-library', '{}', '6.0'),
('ROL-ORG-TEC-SIST',    '*', 'ROL-ORG-GER-IT',      'TYPE-TECNICO',        'BIZ_N4', 5, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'basic', 'seed-library', '{}', '6.0'),
('ROL-ORG-CHOFER-EJEC', '*', NULL,                  'TYPE-OPERATIVO',      'BIZ_N5', 7, 'DEFINIDO', 'SBOS-Coordinador', '*', 2, true, 'basic', 'seed-library', '{}', '6.0'),
('ROL-ORG-LIMPIEZA',    '*', NULL,                  'TYPE-OPERATIVO',      'BIZ_N5', 7, 'DEFINIDO', 'SBOS-Coordinador', '*', 1, false, 'none', 'seed-library', '{}', '6.0'),

-- EXTERNOS (2)
('ROL-EXT-CLIENTE',   '*', NULL, 'TYPE-OPERATIVO', 'EXT_N0',    7, 'DEFINIDO', 'SBOS-Coordinador', '*', 1, false, 'none', 'seed-library', '{}', '6.0'),
('ROL-EXT-VISITANTE', '*', NULL, 'TYPE-OPERATIVO', 'VISITANTE', 7, 'DEFINIDO', 'SBOS-Coordinador', '*', 1, false, 'basic', 'seed-library', '{}', '6.0');

-- SELECT count(*) FROM bauth.idn_role_template; -- 31
