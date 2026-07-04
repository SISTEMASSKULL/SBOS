-- ============================================================
-- SEED 053: Configuración de seguridad
-- Tablas: bos_zona_logica, bos_credential_policy, bos_sod_conflict_matrix
-- IDEMPOTENTE: ON CONFLICT DO NOTHING
-- ============================================================

INSERT INTO bauth.bos_zona_logica (zona_id, nombre, descripcion, categoria, ambito, es_critica, requiere_segregacion, zona_conflicto) VALUES
('VENTAS','Ventas y Facturación','Gestión de ventas, facturas, clientes','COMERCIAL','EMPRESA',true,true,ARRAY['AUDITORIA']),
('CONTABILIDAD','Contabilidad General','Registros contables, balances, cierres','FINANCIERA','EMPRESA',true,true,ARRAY['AUDITORIA']),
('INVENTARIO','Inventario y Almacenes','Control de stock, entradas, salidas','OPERATIVA','SUCURSAL',false,false,NULL),
('COMPRAS','Compras y Proveedores','Órdenes de compra, proveedores, licitaciones','OPERATIVA','EMPRESA',false,true,ARRAY['AUDITORIA','CONTABILIDAD']),
('TESORERIA','Tesorería y Pagos','Gestión de caja, bancos, conciliaciones','FINANCIERA','EMPRESA',true,true,ARRAY['AUDITORIA']),
('RRHH','Recursos Humanos','Personal, nómina, contratación','RRHH','EMPRESA',true,false,NULL),
('NOMINA','Nómina y Sueldos','Cálculo de planillas, AFP, retenciones','RRHH','EMPRESA',true,true,ARRAY['AUDITORIA']),
('TRIBUTARIA','Gestión Tributaria','Impuestos, DDJJ, retenciones SIN','FISCAL','EMPRESA',true,true,ARRAY['AUDITORIA']),
('FACTURACION','Facturación Electrónica','Emisión, dosificación, CUFD, SIN','FISCAL','SUCURSAL',true,true,ARRAY['AUDITORIA']),
('AUDITORIA','Auditoría Interna','Revisión de procesos, cumplimiento, SOX','DIRECTIVA','TENANT',true,false,NULL),
('ADMIN_SISTEMA','Administración del Sistema','Configuración, seguridad, monitoreo','TECNICA','TENANT',true,false,NULL),
('REPORTES','Reportes y Dashboards','Consultas, BI, exportación de datos','ADMINISTRATIVA','EMPRESA',false,false,NULL)
ON CONFLICT DO NOTHING;

-- Verbos — gestionados en bos_privilege.bos_verb (§20.4), no en bauth.bos_verbo (eliminada)

INSERT INTO bauth.bos_credential_policy (policy_id, nombre, credential_type, min_strength_bits, ttl_max_dias, rota_por_tiempo, rota_post_compromiso, rota_post_evento, requiere_breach_screening, historial_retencion) VALUES
('PASSWORDS','Contraseñas de Usuario','PASSWORD',256,NULL,false,true,true,true,10),
('MFA_TOTP','Seeds TOTP','TOTP',256,NULL,false,true,false,false,0),
('WEBAUTHN','Credenciales FIDO2/WebAuthn','WEBAUTHN',256,NULL,false,true,false,false,0),
('M2M_CERTS','Certificados M2M (Daemons)','X509_CERT',256,1,true,true,false,false,0),
('OAUTH_SECRETS','Client Secrets OAuth 2.0','OAUTH_SECRET',256,90,true,true,false,false,3),
('API_KEY','API Keys','API_KEY',256,180,true,true,false,false,3),
('ENCRYPTION_KEY','Claves de Cifrado (AES)','ENCRYPTION_KEY',256,90,true,true,true,false,0),
('SIGNING_KEY','Claves de Firma (EdDSA/ECDSA)','SIGNING_KEY',256,180,true,true,true,false,0)
ON CONFLICT DO NOTHING;

INSERT INTO bauth.bos_financial_document_operation (operacion_id, tipo_documento, verbo, descripcion, afecta_dosificacion, requiere_firma_digital, notifica_sin) VALUES

INSERT INTO bauth.bos_sod_conflict_matrix (bit_a, bit_b, risk_level, action, rationale) VALUES
(14, 15, 'ALTO', 'BLOCK',
 'SOX §404 COSO Control Activities: quien crea transacciones (FINANCIAL_CREATE) no puede aprobarlas (FINANCIAL_APPROVE). NIST SP 800-53 AC-5.'),
(15, 14, 'ALTO', 'BLOCK',
 'SOX §404: par simétrico — quien aprueba no puede crear (dual control).')
ON CONFLICT DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_sod_bits ON bauth.bos_sod_conflict_matrix(bit_a, bit_b);
