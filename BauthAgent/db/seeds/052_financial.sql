-- ============================================================
-- SEED 052: Dominio financiero
-- Tablas: bos_financial_tipo_transaccion, bos_financial_document_operation
-- IDEMPOTENTE: ON CONFLICT DO NOTHING
-- ============================================================

INSERT INTO bauth.bos_financial_tipo_transaccion (tipo_id, nombre, categoria, riesgo, requiere_dual_control, requiere_evidencia, notificacion_sin) VALUES
('FAC_EMITIR','Emitir Factura','VENTAS','MEDIO',false,true,true),
('FAC_ANULAR','Anular Factura','VENTAS','ALTO',true,true,true),
('NC_EMITIR','Emitir Nota de Crédito','VENTAS','ALTO',true,true,true),
('ND_EMITIR','Emitir Nota de Débito','COBROS','ALTO',true,true,true),
('PAGO_CREAR','Crear Pago','PAGOS','MEDIO',false,true,false),
('PAGO_APROBAR','Aprobar Pago','PAGOS','ALTO',true,true,false),
('PAGO_EJECUTAR','Ejecutar Transferencia Bancaria','BANCARIO','CRITICO',true,true,false),
('COBRO_REGISTRAR','Registrar Cobro','COBROS','MEDIO',false,false,false),
('COBRO_CONCILIAR','Conciliar Cobro Bancario','BANCARIO','ALTO',false,true,false),
('ASIENTO_CREAR','Crear Asiento Contable','TRIBUTARIO','MEDIO',false,true,false),
('ASIENTO_APROBAR','Aprobar Asiento Contable','TRIBUTARIO','ALTO',true,true,false),
('ASIENTO_CERRAR','Cerrar Período Contable','TRIBUTARIO','CRITICO',true,true,false),
('NOMINA_PROCESAR','Procesar Nómina','NOMINA','CRITICO',true,true,false),
('INV_AJUSTAR','Ajustar Inventario','INVENTARIO','ALTO',true,true,false),
('ACTIVO_BAJA','Dar de Baja Activo Fijo','ACTIVOS_FIJOS','ALTO',true,true,false),
('IMP_CREAR','Crear Declaración de Importación','IMPORTACION','ALTO',true,true,true),
('EXP_CREAR','Crear Factura de Exportación','EXPORTACION','ALTO',true,true,true)
ON CONFLICT DO NOTHING;

-- Operaciones sobre documentos financieros

INSERT INTO bauth.bos_financial_document_operation (operacion_id, tipo_documento, verbo, descripcion, afecta_dosificacion, requiere_firma_digital, notifica_sin) VALUES
('FAC_CREATE','FACTURA','CREATE','Emitir nueva factura',true,true,true),
('FAC_READ','FACTURA','READ','Consultar factura',false,false,false),
('FAC_ANULAR','FACTURA','ANULAR','Anular factura (no libera número)',false,true,true),
('FAC_REIMPRIMIR','FACTURA','REIMPRIMIR','Reimprimir representación gráfica',false,false,false),
('NC_CREATE','NOTA_CREDITO','CREATE','Emitir nota de crédito',true,true,true),
('ND_CREATE','NOTA_DEBITO','CREATE','Emitir nota de débito',true,true,true),
('PAGO_CREATE','PAGO','CREATE','Crear orden de pago',false,false,false),
('PAGO_APROBAR','PAGO','APROBAR','Aprobar orden de pago',false,false,false),
('PAGO_EJECUTAR','PAGO','EXECUTE','Ejecutar transferencia bancaria',false,true,false),
('ASIENTO_CREATE','ASIENTO','CREATE','Crear asiento contable',false,false,false),
('ASIENTO_APROBAR','ASIENTO','APROBAR','Aprobar asiento contable',false,false,false),
('ASIENTO_CERRAR','ASIENTO','CERRAR','Cerrar período contable',false,false,false),
('ASIENTO_REABRIR','ASIENTO','REABRIR','Reabrir período cerrado (requiere auditoría)',false,true,false)
ON CONFLICT DO NOTHING;

-- ============================================================
