-- seed_fin_decision_matrix.sql — Matriz de decisión financiera (3 niveles)
-- IDEMPOTENTE: DELETE + INSERT con IDs fijos
-- Estándar: SOX §404 · COSO Control Activities · NIST SP 800-53 AC-3
-- Modelo de aprobación jerárquica para transacciones financieras.
-- ═══════════════════════════════════════════════════════════
SET lock_timeout = '5s';

-- Emitir Factura: Cajero hasta Bs 5,000, Contador hasta Bs 50,000, Supervisor hasta Bs 500,000
INSERT INTO bauth.fin_decision_matrix (
    decision_id, tenant_id, empresa_id, nombre, tipo_transaccion, moneda,
    nivel_1_rol, nivel_1_monto_max, nivel_1_puede_delegar,
    nivel_2_rol, nivel_2_monto_max, nivel_2_puede_delegar,
    nivel_3_rol, nivel_3_monto_max,
    requiere_comite, requiere_evidencia_adjunta, tiempo_max_aprobacion_horas,
    escala_automatica, is_active, ctx_id
) VALUES (
    '00000000-0000-0000-0000-000000000301',
    '019f01e8-2e33-7734-a756-63d31a003a75',
    '019f01e8-2e33-7734-a756-63d31a003a75',
    'Emitir Factura — Matriz de Aprobación',
    'FAC_EMITIR',
    'BOB',
    'test-cajero',        5000.00,    false,   -- Cajero: hasta Bs 5,000
    'test-contador',     50000.00,    true,    -- Contador: hasta Bs 50,000, puede delegar
    'test-supervisor',  500000.00,             -- Supervisor: hasta Bs 500,000
    FALSE, TRUE, 48,     -- Sin comité, requiere evidencia, 48h max
    TRUE, TRUE, 'seed'
) ON CONFLICT (decision_id) DO UPDATE SET
    nivel_1_rol = EXCLUDED.nivel_1_rol,
    nivel_1_monto_max = EXCLUDED.nivel_1_monto_max,
    nivel_2_rol = EXCLUDED.nivel_2_rol,
    nivel_2_monto_max = EXCLUDED.nivel_2_monto_max,
    nivel_3_rol = EXCLUDED.nivel_3_rol,
    nivel_3_monto_max = EXCLUDED.nivel_3_monto_max,
    updated_at = NOW();

-- Aprobar Pago: requiere Contador como nivel 1, Supervisor como nivel 2
INSERT INTO bauth.fin_decision_matrix (
    decision_id, tenant_id, empresa_id, nombre, tipo_transaccion, moneda,
    nivel_1_rol, nivel_1_monto_max, nivel_1_puede_delegar,
    nivel_2_rol, nivel_2_monto_max, nivel_2_puede_delegar,
    nivel_3_rol, nivel_3_monto_max,
    requiere_comite, requiere_evidencia_adjunta, tiempo_max_aprobacion_horas,
    escala_automatica, is_active, ctx_id
) VALUES (
    '00000000-0000-0000-0000-000000000302',
    '019f01e8-2e33-7734-a756-63d31a003a75',
    '019f01e8-2e33-7734-a756-63d31a003a75',
    'Aprobar Pago — Matriz de Decisión',
    'PAGO_APROBAR',
    'BOB',
    'test-contador',    100000.00,   false,   -- Contador: hasta Bs 100,000
    'test-supervisor', 1000000.00,   false,   -- Supervisor: hasta Bs 1,000,000
    NULL,              NULL,                  -- Sin nivel 3
    TRUE,  TRUE, 24,    -- Requiere comité, evidencia, 24h max
    TRUE, TRUE, 'seed'
) ON CONFLICT (decision_id) DO UPDATE SET
    nivel_1_rol = EXCLUDED.nivel_1_rol,
    nivel_1_monto_max = EXCLUDED.nivel_1_monto_max,
    nivel_2_rol = EXCLUDED.nivel_2_rol,
    nivel_2_monto_max = EXCLUDED.nivel_2_monto_max,
    nivel_3_rol = EXCLUDED.nivel_3_rol,
    nivel_3_monto_max = EXCLUDED.nivel_3_monto_max,
    updated_at = NOW();

-- Anular Factura: solo Supervisor (crítico)
INSERT INTO bauth.fin_decision_matrix (
    decision_id, tenant_id, empresa_id, nombre, tipo_transaccion, moneda,
    nivel_1_rol, nivel_1_monto_max, nivel_1_puede_delegar,
    nivel_2_rol, nivel_2_monto_max, nivel_2_puede_delegar,
    nivel_3_rol, nivel_3_monto_max,
    requiere_comite, requiere_evidencia_adjunta, tiempo_max_aprobacion_horas,
    escala_automatica, is_active, ctx_id
) VALUES (
    '00000000-0000-0000-0000-000000000303',
    '019f01e8-2e33-7734-a756-63d31a003a75',
    '019f01e8-2e33-7734-a756-63d31a003a75',
    'Anular Factura — Solo Supervisor',
    'FAC_ANULAR',
    'BOB',
    'test-supervisor', 100000.00,   false,   -- Solo Supervisor puede anular
    NULL,              NULL,        false,
    NULL,              NULL,
    FALSE, TRUE, 4,     -- Sin comité, evidencia obligatoria, 4h max (urgente)
    FALSE, TRUE, 'seed' -- Sin escala automática (crítico)
) ON CONFLICT (decision_id) DO UPDATE SET
    nivel_1_rol = EXCLUDED.nivel_1_rol,
    nivel_1_monto_max = EXCLUDED.nivel_1_monto_max,
    nivel_2_rol = EXCLUDED.nivel_2_rol,
    nivel_2_monto_max = EXCLUDED.nivel_2_monto_max,
    nivel_3_rol = EXCLUDED.nivel_3_rol,
    nivel_3_monto_max = EXCLUDED.nivel_3_monto_max,
    updated_at = NOW();
