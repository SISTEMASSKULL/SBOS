-- seed_fin_transaction_type.sql — 20 tipos de transacción financiera
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: ISO 20022 + SIN Bolivia RND 102100000011
-- Schema real: type_id UUID PK, tenant_id, code, name, category, risk_level, controls JSONB
-- ═══════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.fin_transaction_type RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.fin_transaction_type;

DO $$
DECLARE
  tid UUID;
BEGIN
  SELECT tenant_id INTO tid FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1;

  INSERT INTO bauth.fin_transaction_type (tenant_id, code, name, category, risk_level, controls) VALUES
  (tid, 'FAC_EMITIR',    'Emitir Factura',              'VENTAS',     'ALTO',    '{"requires_dual_control":true,"requires_evidence":true,"affects_ledger":true,"notifies_sin":true}'),
  (tid, 'FAC_ANULAR',    'Anular Factura',             'VENTAS',     'CRITICO', '{"requires_dual_control":true,"requires_evidence":true,"affects_ledger":true,"notifies_sin":true}'),
  (tid, 'NC_EMITIR',     'Emitir Nota de Crédito',     'VENTAS',     'ALTO',    '{"requires_dual_control":true,"requires_evidence":true,"affects_ledger":true,"notifies_sin":true}'),
  (tid, 'ND_EMITIR',     'Emitir Nota de Débito',      'VENTAS',     'ALTO',    '{"requires_dual_control":true,"requires_evidence":true,"affects_ledger":true,"notifies_sin":true}'),
  (tid, 'PAGO_APROBAR',  'Aprobar Pago',               'PAGOS',      'ALTO',    '{"requires_dual_control":true,"requires_evidence":true,"affects_ledger":true,"notifies_sin":false}'),
  (tid, 'PAGO_EJECUTAR', 'Ejecutar Pago',              'PAGOS',      'CRITICO', '{"requires_dual_control":true,"requires_evidence":true,"affects_ledger":true,"notifies_sin":false}'),
  (tid, 'COBRO_REGISTRAR','Registrar Cobro',           'COBROS',     'MEDIO',   '{"requires_dual_control":false,"requires_evidence":true,"affects_ledger":true,"notifies_sin":false}'),
  (tid, 'NOMINA_PROCESAR','Procesar Nómina',           'NOMINA',     'CRITICO', '{"requires_dual_control":true,"requires_evidence":true,"affects_ledger":true,"notifies_sin":false}'),
  (tid, 'INV_ENTRADA',   'Entrada de Inventario',      'INVENTARIO', 'MEDIO',   '{"requires_dual_control":false,"requires_evidence":true,"affects_ledger":true,"notifies_sin":false}'),
  (tid, 'INV_SALIDA',    'Salida de Inventario',       'INVENTARIO', 'MEDIO',   '{"requires_dual_control":false,"requires_evidence":true,"affects_ledger":true,"notifies_sin":false}'),
  (tid, 'IMP_DECLARAR',  'Declarar Importación',       'IMPORTACION','ALTO',    '{"requires_dual_control":true,"requires_evidence":true,"affects_ledger":true,"notifies_sin":true}'),
  (tid, 'EXP_DECLARAR',  'Declarar Exportación',       'EXPORTACION','ALTO',    '{"requires_dual_control":true,"requires_evidence":true,"affects_ledger":true,"notifies_sin":true}'),
  (tid, 'BANCO_CONCILIAR','Conciliar Extracto Bancario','BANCARIO',   'ALTO',    '{"requires_dual_control":false,"requires_evidence":true,"affects_ledger":true,"notifies_sin":false}'),
  (tid, 'ACT_FIJO_REG',  'Registrar Activo Fijo',      'ACTIVOS_FIJOS','MEDIO', '{"requires_dual_control":false,"requires_evidence":true,"affects_ledger":true,"notifies_sin":false}'),
  (tid, 'ACT_FIJO_DEP',  'Depreciar Activo Fijo',      'ACTIVOS_FIJOS','MEDIO', '{"requires_dual_control":false,"requires_evidence":false,"affects_ledger":true,"notifies_sin":false}'),
  (tid, 'TRIB_DECLARAR', 'Declarar Impuesto',          'TRIBUTARIO', 'CRITICO', '{"requires_dual_control":true,"requires_evidence":true,"affects_ledger":true,"notifies_sin":true}'),
  (tid, 'COMPRA_APROBAR','Aprobar Orden de Compra',    'COMPRAS',    'ALTO',    '{"requires_dual_control":true,"requires_evidence":true,"affects_ledger":true,"notifies_sin":false}'),
  (tid, 'CAJA_ABRIR',    'Abrir Caja',                 'VENTAS',     'ALTO',    '{"requires_dual_control":false,"requires_evidence":true,"affects_ledger":true,"notifies_sin":false}'),
  (tid, 'CAJA_CERRAR',   'Cerrar Caja',                'VENTAS',     'ALTO',    '{"requires_dual_control":false,"requires_evidence":true,"affects_ledger":true,"notifies_sin":false}'),
  (tid, 'CAJA_ARQUEO',   'Arqueo de Caja',             'VENTAS',     'ALTO',    '{"requires_dual_control":false,"requires_evidence":true,"affects_ledger":true,"notifies_sin":false}');
END $$;

-- SELECT count(*) FROM bauth.fin_transaction_type; -- 20
