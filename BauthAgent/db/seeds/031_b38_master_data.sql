-- B38 Seed v2 — Columnas corregidas según esquema real

-- T01: SeedPaises
INSERT INTO bauth.bos_pais (codice_iso, nombre, gentilicio, activo) VALUES
('BO','Bolivia','Boliviano/a',true),
('AR','Argentina','Argentino/a',true),
('BR','Brasil','Brasileño/a',true),
('CL','Chile','Chileno/a',true),
('CO','Colombia','Colombiano/a',true),
('EC','Ecuador','Ecuatoriano/a',true),
('PE','Perú','Peruano/a',true),
('PY','Paraguay','Paraguayo/a',true),
('UY','Uruguay','Uruguayo/a',true),
('MX','México','Mexicano/a',true),
('US','Estados Unidos','Estadounidense',false),
('ES','España','Español/a',false)
ON CONFLICT (codice_iso) DO NOTHING;

-- T02: SeedCiudades
INSERT INTO bauth.bos_ciudad (nombre, pais_iso, activo) VALUES
('La Paz','BO',true),('Santa Cruz de la Sierra','BO',true),('Cochabamba','BO',true),
('El Alto','BO',true),('Sucre','BO',true),('Tarija','BO',true),
('Potosí','BO',true),('Oruro','BO',true),('Trinidad','BO',true),
('Cobija','BO',true),('Sacaba','BO',true),('Quillacollo','BO',true),
('Montero','BO',true),('Riberalta','BO',true),('Yacuiba','BO',true),
('Villazón','BO',true),('Bermejo','BO',true),('Camiri','BO',true),
('Villamontes','BO',true),('Uyuni','BO',true)
ON CONFLICT DO NOTHING;

-- T03: SeedMonedas
INSERT INTO bauth.bos_moneda (codice_iso, nombre, simbolo, activo) VALUES
('BOB','Boliviano','Bs.',true),('USD','Dólar','$',true),('EUR','Euro','€',true),
('ARS','Peso Argentino','AR$',true),('BRL','Real','R$',true),('CLP','Peso Chileno','CLP$',true),
('COP','Peso Colombiano','COL$',true),('PEN','Sol','S/',true),('PYG','Guaraní','₲',true),
('UYU','Peso Uruguayo','$U',true),('USDT','Tether USD','USDT',true)
ON CONFLICT (codice_iso) DO NOTHING;

-- T04: SeedIdiomas
INSERT INTO bauth.bos_idioma (codigo, nombre, activo) VALUES
('ES','Español',true),('EN','Inglés',true),('PT','Portugués',true),
('QU','Quechua',true),('AY','Aymara',true),('GN','Guaraní',true)
ON CONFLICT (codigo) DO NOTHING;

-- T07: SeedCredentialPolicies
INSERT INTO bauth.bos_credential_policy (tier, min_length, require_mfa, mfa_methods, password_ttl_days) VALUES
('SU',20,true,'["FIDO2","WebAuthn"]',365),
('SYS',15,true,'["TOTP","FIDO2","WebAuthn"]',365),
('BIZ_N3_N5',12,true,'["TOTP","WebAuthn_2FA"]',365),
('BIZ_N1_N2',10,false,'["TOTP"]',365),
('EXT_N0',8,false,'["Passkey","Email_OTP"]',365),
('M2M',0,false,'["mTLS"]',30)
ON CONFLICT DO NOTHING;

-- T08: SeedSoDMatrix
INSERT INTO bauth.bos_sod_conflict_matrix (role_a, role_b, severity, description) VALUES
('FINANCIAL_CREATE','FINANCIAL_APPROVE','HIGH','Quien crea documentos financieros no puede aprobarlos'),
('CAJERO','AUDITOR_INVENTARIO','HIGH','Cajero no puede auditar inventario'),
('DESARROLLADOR','REVISOR_CODIGO','MEDIUM','Quien desarrolla no puede revisar su propio código'),
('COMPRADOR','APROBADOR_PAGO','HIGH','Quien compra no puede aprobar el pago'),
('ADMIN_SEGURIDAD','ADMIN_TENANT','MEDIUM','Admin de seguridad no puede administrar tenants'),
('ENCARGADO_FACTURACION','REVISOR_FISCAL','HIGH','Quien factura no puede revisar fiscalmente'),
('SUPERVISOR_COBRANZA','COBRADOR','HIGH','Supervisor de cobranza no puede ser cobrador')
ON CONFLICT DO NOTHING;

-- T09: SeedTiposTransaccion
INSERT INTO bauth.bos_financial_tipo_transaccion (tipo_id, nombre, descripcion, activo) VALUES
('PAGO','Pago a Proveedor','Pago de facturas y servicios',true),
('TRANSFERENCIA','Transferencia','Transferencia entre cuentas',true),
('REEMBOLSO','Reembolso','Reembolso de gastos',true),
('ANTICIPO','Anticipo','Anticipo a empleados',true),
('LIQUIDACION','Liquidación','Liquidación de sueldos',true),
('AJUSTE','Ajuste Contable','Ajuste por diferencia',true),
('COMISION','Comisión','Comisión bancaria',true),
('NC','Nota de Crédito','Nota de crédito fiscal',true),
('ND','Nota de Débito','Nota de débito fiscal',true)
ON CONFLICT (tipo_id) DO NOTHING;

-- T10: Tenant SKULL
INSERT INTO bauth.bos_tenant (tenant_id, nombre, country, realm_kc, namespace_k8s, admin_email, plan_tier, isolation_level, mfa_required, audit_level, data_residency, encryption_at_rest) VALUES
('4c697f66-d204-45a5-ac36-c104f07c7046','SKULL','BO','skull','sbos-system','admin@skull.com.bo','ENTERPRISE','dedicated',true,'full','BO',true)
ON CONFLICT (tenant_id) DO NOTHING;

INSERT INTO bauth.bos_tenant_config (tenant_id, default_language, default_timezone, default_currency) VALUES
('4c697f66-d204-45a5-ac36-c104f07c7046','ES','America/La_Paz','BOB')
ON CONFLICT (tenant_id) DO NOTHING;

SELECT 'T01' as t, count(*)::text FROM bauth.bos_pais
UNION ALL SELECT 'T02', count(*)::text FROM bauth.bos_ciudad
UNION ALL SELECT 'T03', count(*)::text FROM bauth.bos_moneda
UNION ALL SELECT 'T04', count(*)::text FROM bauth.bos_idioma
UNION ALL SELECT 'T07', count(*)::text FROM bauth.bos_credential_policy
UNION ALL SELECT 'T08', count(*)::text FROM bauth.bos_sod_conflict_matrix
UNION ALL SELECT 'T09', count(*)::text FROM bauth.bos_financial_tipo_transaccion
UNION ALL SELECT 'T10a', count(*)::text FROM bauth.bos_tenant
UNION ALL SELECT 'T10b', count(*)::text FROM bauth.bos_tenant_config;
