-- seed_privilege_verb.sql — 50 verbos (Fast-Path + Business Actions)
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: SAP ACTVT (31 códigos) + Odoo + Dynamics + ServiceNow + NetSuite + Tryton
-- Schema real: verb_code SMALLINT PK, verb_name VARCHAR(32) UNIQUE, verb_slug VARCHAR(32)
-- ═══════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.privilege_verb RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.privilege_verb;

INSERT INTO bauth.privilege_verb (verb_code, verb_name, verb_slug) VALUES
-- CRUD Base — Fast-Path (1-4)
(1,  'create',   'nuevo'),
(2,  'update',   'editar'),
(3,  'delete',   'eliminar'),
(4,  'read',     'ver'),
-- SAP ACTVT Business Actions (5-29)
(5,  'print',    'imprimir'),
(6,  'lock',     'bloquear'),
(7,  'unlock',   'desbloquear'),
(8,  'check',    'verificar'),
(9,  'post',     'contabilizar'),
(10, 'release',  'liberar'),
(11, 'undo_release','deshacer_liberar'),
(12, 'complete', 'completar'),
(13, 'reverse',  'reversar'),
(14, 'execute',  'ejecutar'),
(15, 'approve',  'aprobar'),
(16, 'reject',   'rechazar'),
(17, 'block_entity','bloquear_entidad'),
(18, 'unblock_entity','desbloquear_entidad'),
(19, 'archive',  'archivar'),
(20, 'copy',     'copiar'),
(21, 'save',     'guardar'),
(22, 'submit',   'enviar'),
(23, 'transfer', 'transferir'),
(24, 'close',    'cerrar'),
(25, 'reopen',   'reabrir'),
(26, 'display_totals','ver_totales'),
(27, 'display_items','ver_partidas'),
(28, 'settle_rule','liquidar_regla'),
(29, 'settle_params','param_liq'),
-- Tryton + Dynamics + ServiceNow Extended (30-46)
(30, 'duplicate','duplicar'),
(31, 'export',   'exportar'),
(32, 'import',   'importar'),
(33, 'reconcile','conciliar'),
(34, 'validate', 'validar'),
(35, 'void',     'anular'),
(36, 'draft',    'borrador'),
(37, 'confirm',  'confirmar'),
(38, 'assign',   'asignar'),
(39, 'share',    'compartir'),
(40, 'append',   'anexar'),
(41, 'append_to','ser_anexado'),
(42, 'schedule', 'programar'),
(43, 'delegate', 'delegar'),
(44, 'impersonate','suplantar'),
(45, 'notify',   'notificar'),
(46, 'configure','configurar'),
-- Ejecución especial (47-50)
(47, 'schedule_task','programar_tarea'),
(48, 'delegate_access','delegar_acceso'),
(49, 'impersonate_user','suplantar_usuario'),
(50, 'emergency_access','acceso_emergencia');

-- SELECT count(*) FROM bauth.privilege_verb; -- debe ser 50
