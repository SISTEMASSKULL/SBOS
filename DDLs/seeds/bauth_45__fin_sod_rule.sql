-- seed_fin_sod_rule.sql — Matriz de conflictos SoD financieros fundamentales
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: SOX §404 · COSO 2013 Control Activities · NIST SP 800-53 AC-5 · ISACA COBIT 2019
-- ═══════════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.fin_sod_rule RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.fin_sod_rule;

INSERT INTO bauth.fin_sod_rule (position_a, position_b, risk_level, action, rationale) VALUES

-- Conflictos financieros fundamentales (SOX §404)
(14, 15, 'ALTO', 'BLOCK',
 'SOX §404 · COSO Control Activities: quien crea transacciones (FINANCIAL_CREATE) no puede aprobarlas (FINANCIAL_APPROVE). NIST SP 800-53 AC-5.'),
(15, 14, 'ALTO', 'BLOCK',
 'SOX §404: par simétrico — quien aprueba no puede crear (dual control forzoso).'),

-- Separación Ventas ↔ Cobranzas
(101, 102, 'ALTO', 'BLOCK',
 'COSO 2013 §7: quien emite facturas de venta no puede registrar cobros de esas mismas facturas. Previene desfalco por facturación falsa + auto-cobro.'),

-- Separación Compras ↔ Pagos
(201, 202, 'ALTO', 'BLOCK',
 'COSO 2013 §8: quien crea órdenes de compra no puede aprobar pagos a proveedores. Previene colusión con proveedores.'),

-- Separación Nómina ↔ RRHH
(301, 302, 'MEDIO', 'COMPENSATE',
 'COSO 2013 §9: quien calcula nómina no debe tener acceso a modificar datos maestros de empleados. Requiere control compensatorio (aprobación dual).'),

-- Separación Auditoría ↔ Operaciones
(401, 101, 'ALTO', 'BLOCK',
 'IIA Standard 1100: quien audita un área no puede tener permisos operativos en esa misma área. Independencia obligatoria de auditoría interna.');

-- SELECT count(*) AS total_reglas_sod FROM bauth.fin_sod_rule;
