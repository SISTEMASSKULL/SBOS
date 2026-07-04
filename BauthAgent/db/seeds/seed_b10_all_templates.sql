-- ============================================================
-- B10 — ROLE TEMPLATES: 66 plantillas base (T19-T66)
-- Seeds para idn_role_template desde BAUTH-CATALOGO-ROLES-EMPRESARIALES.md v2.0
-- GENERADO 2026-06-29 · 6 secciones · Idempotente (ON CONFLICT DO NOTHING)
-- ============================================================

-- BLOQUE 1: Sistémicas (9 plantillas · T19-T27)
INSERT INTO bauth.idn_role_template (role_code, role_name, tier, domain_classification, config, is_active) VALUES
-- T19: SUPERUSUARIO
('TEMPLATE-SYS-SUPERUSUARIO','Super Usuario PAM','SU','{"D1":true,"D2":true,"D3":true,"D8":true,"D9":true}',
 '{"role":{"code":"S001","type":"SUPERUSUARIO","tier":"SU","is_unique":true},"logical_access":{"zones":["*"],"max_records":0},"physical_access":{"all_zones":true,"emergency_override":true},"financial_limits":{"unlimited":true},"temporal_schedule":{"unrestricted":true},"credentials":{"aal":3,"mfa_required":true,"fido2_hw":true,"vault_unseal":"2-of-3"},"compliance_security":{"jit_access":true,"session_recording":true}}'::jsonb,true),
-- T20: PLATAFORMA Admin
('TEMPLATE-SYS-PLATAFORMA','Admin Plataforma','SYS','{"D1":true,"D3":true,"D8":true,"D9":true}',
 '{"role":{"code":"S002","type":"PLATAFORMA","tier":"SYS"},"logical_access":{"zones":["ADMIN"],"scope":"tenant"},"financial_limits":{"daily_limit":"1000000"},"credentials":{"aal":2,"mfa_required":true},"delegation":{"max_duration_h":8},"sod_conflicts":["S003","S004","S005"]}'::jsonb,true),
-- T21: MODULO Admin daemons
('TEMPLATE-SYS-MODULO','Admin Módulo','SYS','{"D1":true,"D7":true,"D8":true}',
 '{"role":{"code":"S006","type":"MODULO","tier":"SYS","daemon":"bauth"},"logical_access":{"zones":["DAEMON_ADMIN"],"scope":"module"},"network":{"mtls_required":true,"rate_limit":1000},"credentials":{"aal":2,"mfa_required":true}}'::jsonb,true),
-- T22: TENANT Admin
('TEMPLATE-SYS-TENANT','Admin Tenant','BIZ_N1','{"D1":true,"D3":true,"D8":true}',
 '{"role":{"code":"S016","type":"TENANT","tier":"BIZ_N1"},"logical_access":{"zones":["TENANT_ADMIN"],"scope":"tenant"},"financial_limits":{"daily_limit":"100000"},"credentials":{"aal":2,"mfa_required":true}}'::jsonb,true),
-- T23-T27: Bootstrap daemons + engines + infra
('TEMPLATE-SYS-BOOTSTRAP-DAEMON','Bootstrap Daemon M2M','M2M','{"D7":true,"D9":true}',
 '{"role":{"code":"S020","type":"M2M","tier":"M2M"},"network":{"mtls_required":true},"credentials":{"aal":2,"token_ttl":"24h"},"temporal_schedule":{"unrestricted":true}}'::jsonb,true),
('TEMPLATE-SYS-BOOTSTRAP-ENGINE','Bootstrap Engine Interno','M2M','{"D1":true,"D7":true}',
 '{"role":{"code":"S022","type":"M2M_ENGINE","tier":"M2M"},"network":{"mtls_required":true,"internal_only":true},"logical_access":{"scope":"internal"}}'::jsonb,true),
('TEMPLATE-SYS-INFRA-SERVICE','Service Account Infra','M2M','{"D7":true}',
 '{"role":{"code":"S039","type":"SERVICE","tier":"M2M"},"network":{"mtls_required":true},"credentials":{"vault_dynamic_secrets":true}}'::jsonb,true),
('TEMPLATE-SYS-OBSERVABILIDAD','Observabilidad','BIZ_N3','{"D1":true,"D11":true}',
 '{"role":{"code":"S047","type":"OBSERVABILITY","tier":"BIZ_N3"},"logical_access":{"zones":["METRICS","LOGS"],"read_only":true}}'::jsonb,true),
('TEMPLATE-SYS-M2M','M2M Meta-Plantilla','M2M','{"D7":true}',
 '{"role":{"code":"S050","type":"M2M_META","tier":"M2M"},"network":{"mtls_required":true},"credentials":{"token_ttl":"12h"}}'::jsonb,true)
ON CONFLICT (role_code) DO NOTHING;

-- BLOQUE 2: Internas Prioritarias (12 plantillas · T28-T39)
INSERT INTO bauth.idn_role_template (role_code, role_name, tier, domain_classification, config, is_active) VALUES
('TEMPLATE-GERENTE','Gerente General','BIZ_N5','{"D1":true,"D3":true,"D8":true}',
 '{"role":{"code":"ROL-GERENTE-GENERAL","type":"DIRECCION","tier":"BIZ_N5"},"logical_access":{"scope":"tenant","all_zones":true},"financial_limits":{"daily_limit":"1000000","requires_dual":true}}'::jsonb,true),
('TEMPLATE-SUPERVISOR','Supervisor','BIZ_N3','{"D1":true,"D3":true}',
 '{"role":{"code":"ROL-SUPERVISOR","type":"SUPERVISION","tier":"BIZ_N3"},"logical_access":{"zones":["TIENDA","PLANTA","ALMACEN"]},"financial_limits":{"daily_limit":"100000"},"inheritance":{"parents":["ROL-OPERARIO","ROL-CAJERO"]}}'::jsonb,true),
('TEMPLATE-CONTABLE','Jefe Contabilidad','BIZ_N2','{"D1":true,"D3":true,"D8":true}',
 '{"role":{"code":"ROL-CONTABLE","type":"FINANZAS","tier":"BIZ_N2"},"logical_access":{"zones":["CONTABILIDAD"]},"financial_limits":{"daily_limit":"500000"},"compliance_security":{"sox_compliant":true}}'::jsonb,true),
('TEMPLATE-FACTURACION','Facturador Electrónico','BIZ_N1','{"D1":true,"D3":true,"D12":true}',
 '{"role":{"code":"ROL-FACTURADOR","type":"FACTURACION","tier":"BIZ_N1"},"logical_access":{"zones":["FACTURACION","POS"]},"financial_limits":{"daily_limit":"200000"},"blockchain":{"anchor_required":true},"compliance_security":{"sin_compliance":true}}'::jsonb,true),
('TEMPLATE-CAJERO','Cajero','BIZ_N1','{"D1":true,"D2":true,"D3":true}',
 '{"role":{"code":"ROL-CAJERO","type":"OPERATIVO","tier":"BIZ_N1"},"logical_access":{"zones":["CAJA","VENTAS"]},"physical_access":{"zones":["CAJA"]},"financial_limits":{"daily_limit":"50000"},"credentials":{"aal":1,"mfa_required":false}}'::jsonb,true),
('TEMPLATE-SEGURIDAD','Jefe Seguridad','BIZ_N2','{"D1":true,"D2":true,"D5":true}',
 '{"role":{"code":"ROL-JEFE-SEGURIDAD","type":"SEGURIDAD","tier":"BIZ_N2"},"physical_access":{"all_zones":true,"emergency_override":true},"biometric":{"required":true,"liveness":true},"credentials":{"aal":2,"mfa_required":true}}'::jsonb,true),
('TEMPLATE-ALMACEN','Jefe Almacén','BIZ_N2','{"D1":true,"D2":true}',
 '{"role":{"code":"ROL-JEFE-ALMACEN","type":"LOGISTICA","tier":"BIZ_N2"},"logical_access":{"zones":["ALMACEN","INVENTARIO"]},"physical_access":{"zones":["ALMACEN","DEPOSITO"]}}'::jsonb,true),
('TEMPLATE-RRHH','Jefe RRHH','BIZ_N2','{"D1":true,"D8":true}',
 '{"role":{"code":"ROL-JEFE-RRHH","type":"RRHH","tier":"BIZ_N2"},"logical_access":{"zones":["RRHH"],"pii_masked":true},"compliance_security":{"gdpr_art9":true}}'::jsonb,true),
('TEMPLATE-SALUD','Médico','BIZ_N1','{"D1":true,"D5":true,"D6":true}',
 '{"role":{"code":"ROL-MEDICO","type":"SALUD","tier":"BIZ_N1"},"logical_access":{"zones":["CONSULTORIO"],"pii_masked":true},"biometric":{"required":false},"compliance_security":{"gdpr_art9":true}}'::jsonb,true),
('TEMPLATE-DOCENTE','Docente','BIZ_N1','{"D1":true,"D4":true}',
 '{"role":{"code":"ROL-DOCENTE","type":"EDUCACION","tier":"BIZ_N1"},"logical_access":{"zones":["AULA","BIBLIOTECA"]},"temporal_schedule":{"type":"ACADEMICO"}}'::jsonb,true),
('TEMPLATE-TRIBUTARIO','Contador Tributario','BIZ_N2','{"D1":true,"D3":true}',
 '{"role":{"code":"ROL-TRIBUTARIO","type":"FISCAL","tier":"BIZ_N2"},"logical_access":{"zones":["CONTABILIDAD","IMPUESTOS"]},"compliance_security":{"sin_compliance":true,"iva_reports":true}}'::jsonb,true),
('TEMPLATE-COBRANZA','Jefe Facturación-Crédito','BIZ_N2','{"D1":true,"D3":true}',
 '{"role":{"code":"ROL-COBRANZA","type":"FINANZAS","tier":"BIZ_N2"},"logical_access":{"zones":["COBRANZAS","CREDITO"]},"financial_limits":{"daily_limit":"500000"}}'::jsonb,true)
ON CONFLICT (role_code) DO NOTHING;

-- BLOQUE 3: Internas Secundarias (13 plantillas · T40-T52)
INSERT INTO bauth.idn_role_template (role_code, role_name, tier, domain_classification, config, is_active) VALUES
('TEMPLATE-OPERARIO','Operario','BIZ_N4','{"D1":true,"D2":true}','{"role":{"code":"ROL-OPERARIO","type":"OPERATIVO","tier":"BIZ_N4"},"logical_access":{"zones":["TIENDA","PLANTA"]},"physical_access":{"zones":["TIENDA","PLANTA"]},"credentials":{"aal":1}}'::jsonb,true),
('TEMPLATE-BANCO','Cajero Banco','BIZ_N1','{"D1":true,"D3":true}','{"role":{"code":"ROL-CAJERO-BANCO","type":"BANCA","tier":"BIZ_N1"},"logical_access":{"zones":["CAJA_BANCO"]},"financial_limits":{"daily_limit":"200000"},"credentials":{"aal":2,"mfa_required":true}}'::jsonb,true),
('TEMPLATE-HOTEL','Recepcionista Hotel','BIZ_N4','{"D1":true,"D2":true}','{"role":{"code":"ROL-RECEPCIONISTA","type":"HOTELERIA","tier":"BIZ_N4"},"logical_access":{"zones":["RECEPCION"]},"physical_access":{"zones":["RECEPCION","HABITACIONES"]}}'::jsonb,true),
('TEMPLATE-CONSTRUCCION','Maestro Obra','BIZ_N4','{"D1":true,"D2":true}','{"role":{"code":"ROL-MAESTRO-OBRA","type":"CONSTRUCCION","tier":"BIZ_N4"},"logical_access":{"zones":["OBRA"]},"physical_access":{"zones":["OBRA","ALMACEN_MATERIALES"]}}'::jsonb,true),
('TEMPLATE-IT','Soporte IT','BIZ_N3','{"D1":true,"D7":true}','{"role":{"code":"ROL-SOPORTE-IT","type":"TECNOLOGIA","tier":"BIZ_N3"},"logical_access":{"zones":["IT"],"scope":"empresa"},"network":{"vpn_required":false}}'::jsonb,true),
('TEMPLATE-DIRECTOR','Director','BIZ_N5','{"D1":true,"D3":true,"D8":true}','{"role":{"code":"ROL-DIRECTOR","type":"DIRECCION","tier":"BIZ_N5"},"logical_access":{"scope":"tenant","all_zones":true},"financial_limits":{"daily_limit":"5000000"}}'::jsonb,true),
('TEMPLATE-AUDITOR','Auditor Interno','BIZ_N2','{"D1":true,"D3":true,"D11":true}','{"role":{"code":"ROL-AUDITOR","type":"AUDITORIA","tier":"BIZ_N2"},"logical_access":{"read_only":true,"scope":"tenant"},"compliance_security":{"audit_trail":true,"iso_27001":true}}'::jsonb,true),
('TEMPLATE-PRODUCCION','Jefe Producción','BIZ_N2','{"D1":true,"D2":true}','{"role":{"code":"ROL-JEFE-PRODUCCION","type":"PRODUCCION","tier":"BIZ_N2"},"logical_access":{"zones":["PRODUCCION"]},"physical_access":{"zones":["PLANTA"]}}'::jsonb,true),
('TEMPLATE-LOGISTICA','Jefe Logística','BIZ_N2','{"D1":true,"D2":true}','{"role":{"code":"ROL-JEFE-LOGISTICA","type":"LOGISTICA","tier":"BIZ_N2"},"logical_access":{"zones":["LOGISTICA","DESPACHO"]},"physical_access":{"zones":["CENTRO_DISTRIBUCION"]}}'::jsonb,true),
('TEMPLATE-MANTENIMIENTO','Técnico Mantenimiento','BIZ_N4','{"D1":true,"D2":true}','{"role":{"code":"ROL-MANTENIMIENTO","type":"MANTENIMIENTO","tier":"BIZ_N4"},"logical_access":{"zones":["MANTENIMIENTO"]},"physical_access":{"zones":["INSTALACIONES"]}}'::jsonb,true),
('TEMPLATE-VENTAS','Vendedor','BIZ_N4','{"D1":true}','{"role":{"code":"ROL-VENDEDOR","type":"VENTAS","tier":"BIZ_N4"},"logical_access":{"zones":["VENTAS","PISO"]}}'::jsonb,true),
('TEMPLATE-COMPRAS','Jefe Compras','BIZ_N2','{"D1":true,"D3":true}','{"role":{"code":"ROL-JEFE-COMPRAS","type":"COMPRAS","tier":"BIZ_N2"},"logical_access":{"zones":["COMPRAS","PROVEEDORES"]},"financial_limits":{"daily_limit":"500000"}}'::jsonb,true),
('TEMPLATE-RURAL','Capataz Rural','BIZ_N4','{"D1":true,"D6":true}','{"role":{"code":"ROL-CAPATAZ","type":"RURAL","tier":"BIZ_N4"},"logical_access":{"zones":["CAMPO","ESTANCIA"]},"geospatial":{"country_allow":["BO"],"jurisdiction":"RURAL"}}'::jsonb,true)
ON CONFLICT (role_code) DO NOTHING;

-- BLOQUE 4: Externas (14 plantillas · T53-T66)
INSERT INTO bauth.idn_role_template (role_code, role_name, tier, domain_classification, config, is_active) VALUES
('TEMPLATE-CLIENTE-MINORISTA','Cliente Minorista','EXT_N0','{"D1":true}','{"role":{"code":"E035","type":"CLIENTE","tier":"EXT_N0"},"logical_access":{"zones":["ECOMMERCE"],"scope":"self"},"credentials":{"aal":1}}'::jsonb,true),
('TEMPLATE-CLIENTE-MAYORISTA','Cliente Mayorista','EXT_N0','{"D1":true,"D3":true}','{"role":{"code":"E041","type":"CLIENTE","tier":"EXT_N0"},"logical_access":{"zones":["PORTAL_MAYORISTA"],"scope":"self"},"financial_limits":{"credit_limit":"500000"}}'::jsonb,true),
('TEMPLATE-PROVEEDOR','Proveedor','EXT_N0','{"D1":true}','{"role":{"code":"E045","type":"PROVEEDOR","tier":"EXT_N0"},"logical_access":{"zones":["PORTAL_PROVEEDORES"],"scope":"self"}}'::jsonb,true),
('TEMPLATE-ALUMNO','Alumno','EXT_N0','{"D1":true}','{"role":{"code":"E103","type":"ALUMNO","tier":"EXT_N0"},"logical_access":{"zones":["AULA_VIRTUAL"],"scope":"self"},"temporal_schedule":{"type":"ACADEMICO"}}'::jsonb,true),
('TEMPLATE-TUTOR-EDUCATIVO','Tutor','EXT_N0','{"D1":true}','{"role":{"code":"E109","type":"TUTOR","tier":"EXT_N0"},"logical_access":{"zones":["PORTAL_TUTORES"],"scope":"self"}}'::jsonb,true),
('TEMPLATE-PACIENTE','Paciente','EXT_N0','{"D1":true,"D5":true}','{"role":{"code":"E112","type":"PACIENTE","tier":"EXT_N0"},"logical_access":{"zones":["PORTAL_PACIENTE"],"scope":"self","pii_masked":true},"compliance_security":{"gdpr_art9":true}}'::jsonb,true),
('TEMPLATE-ASEGURADO-SALUD','Asegurado Salud','EXT_N0','{"D1":true}','{"role":{"code":"E116","type":"ASEGURADO","tier":"EXT_N0"},"logical_access":{"zones":["PORTAL_SALUD"],"scope":"self"}}'::jsonb,true),
('TEMPLATE-CIUDADANO','Ciudadano','EXT_N0','{"D1":true}','{"role":{"code":"E097","type":"CIUDADANO","tier":"EXT_N0"},"logical_access":{"zones":["PORTAL_CIUDADANO"],"scope":"self"}}'::jsonb,true),
('TEMPLATE-VISITANTE','Visitante','VISITANTE','{"D2":true,"D4":true}','{"role":{"code":"E140","type":"VISITANTE","tier":"VISITANTE"},"physical_access":{"zones":["RECEPCION"],"escort_required":true},"temporal_schedule":{"max_duration_h":8},"credentials":{"aal":1,"temporary":true}}'::jsonb,true),
('TEMPLATE-HUESPED','Huésped','EXT_N0','{"D1":true,"D2":true}','{"role":{"code":"E058","type":"HUESPED","tier":"EXT_N0"},"physical_access":{"zones":["HABITACION","AREAS_COMUNES"]},"temporal_schedule":{"max_duration_d":30}}'::jsonb,true),
('TEMPLATE-PASAJERO','Pasajero','EXT_N0','{"D1":true,"D6":true}','{"role":{"code":"E051","type":"PASAJERO","tier":"EXT_N0"},"logical_access":{"zones":["RESERVAS"],"scope":"self"},"geospatial":{"country_allow":["*"]}}'::jsonb,true),
('TEMPLATE-CUENTAHABIENTE','Cuentahabiente','EXT_N0','{"D1":true,"D3":true}','{"role":{"code":"E070","type":"BANCA","tier":"EXT_N0"},"logical_access":{"zones":["BANCA_ONLINE"],"scope":"self"},"financial_limits":{"daily_limit":"50000"}}'::jsonb,true),
('TEMPLATE-ASEGURADO','Asegurado','EXT_N0','{"D1":true}','{"role":{"code":"E071","type":"ASEGURADO","tier":"EXT_N0"},"logical_access":{"zones":["PORTAL_SEGUROS"],"scope":"self"}}'::jsonb,true),
('TEMPLATE-USUARIO-SERVICIOS','Usuario Servicios','EXT_N0','{"D1":true}','{"role":{"code":"E020","type":"SUSCRIPTOR","tier":"EXT_N0"},"logical_access":{"zones":["PORTAL_SERVICIOS"],"scope":"self"}}'::jsonb,true)
ON CONFLICT (role_code) DO NOTHING;

-- Verificación final
DO $$ BEGIN RAISE NOTICE 'B10: 48 templates insertados (idempotente). Total en idn_role_template: %', (SELECT count(*) FROM bauth.idn_role_template WHERE is_active=true); END $$;
