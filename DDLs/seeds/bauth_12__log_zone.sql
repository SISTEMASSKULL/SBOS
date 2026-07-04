-- seed_log_zone.sql — 29 áreas organizacionales
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: BAUTH-CATALOGO-ROLES-EMPRESARIALES.md §9
-- Schema actual (pendiente revisar): zona_id TEXT PK, nombre, categoria, ambito, es_critica
-- ═══════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.log_zone RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.log_zone;

INSERT INTO bauth.log_zone (zona_id, nombre, categoria, ambito, es_critica, requiere_segregacion) VALUES
('AREA-DIR','Dirección General','DIRECTIVA','TENANT',true,false),
('AREA-FIN','Gerencia Financiera','FINANCIERA','TENANT',true,true),
('AREA-CONT','Contabilidad','FINANCIERA','TENANT',false,false),
('AREA-TESO','Tesorería','FINANCIERA','TENANT',false,false),
('AREA-COM','Dirección Comercial','COMERCIAL','TENANT',true,false),
('AREA-VENT','Ventas','COMERCIAL','TENANT',false,false),
('AREA-POST','Post-Venta / Servicio al Cliente','COMERCIAL','TENANT',false,false),
('AREA-MKT','Marketing','COMERCIAL','TENANT',false,false),
('AREA-OPER','Operaciones','OPERATIVA','TENANT',true,false),
('AREA-LOG','Logística y Distribución','OPERATIVA','TENANT',false,false),
('AREA-ALM','Almacén','OPERATIVA','TENANT',false,false),
('AREA-IT','Tecnología de la Información','TECNICA','TENANT',true,false),
('AREA-DEV','Desarrollo de Software','TECNICA','TENANT',false,false),
('AREA-SEC-INFO','Seguridad Informática','TECNICA','TENANT',true,false),
('AREA-RRHH','Recursos Humanos','RRHH','TENANT',true,false),
('AREA-SELEC','Selección y Reclutamiento','RRHH','TENANT',false,false),
('AREA-NOM','Nómina y Compensaciones','RRHH','TENANT',false,false),
('AREA-LEGAL','Dirección Legal','DIRECTIVA','TENANT',true,false),
('AREA-COMP','Compras y Proveeduría','OPERATIVA','TENANT',false,false),
('AREA-IMP','Importaciones','COMERCIAL','TENANT',false,false),
('AREA-EXP','Exportaciones','COMERCIAL','TENANT',false,false),
('AREA-PROD','Producción','OPERATIVA','TENANT',true,false),
('AREA-CAL','Control de Calidad','OPERATIVA','TENANT',false,false),
('AREA-MANT','Mantenimiento','TECNICA','TENANT',false,false),
('AREA-SEG','Seguridad Patrimonial','DIRECTIVA','TENANT',true,false),
('AREA-ADM','Administración General','ADMINISTRATIVA','TENANT',false,false),
('AREA-SERV','Servicios Generales','ADMINISTRATIVA','TENANT',false,false),
('AREA-TRANS','Transporte','OPERATIVA','TENANT',false,false),
('AREA-HEALTH','Salud Ocupacional','RRHH','TENANT',false,false);

-- SELECT count(*) FROM bauth.log_zone; -- debe ser 29
