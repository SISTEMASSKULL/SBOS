-- fixtures_test_data.sql — synthetic test data for SBOS daemon DB integration tests
-- Purpose: Provides reproducible test data for CI pipelines
-- Used by: PGE Evaluator (Claude) — validates DDL correctness
-- Version: 1.0.0 — 2026-05-12

-- ============================================================================
-- bkernel_db fixtures
-- ============================================================================

-- replication slots for test
INSERT INTO bkernel.replication_state (slot_name, database_name, last_lsn, events_total, status)
VALUES
    ('bkernel_slot',     'tryton',    '0/16B3748',  1523, 'active'),
    ('biedata_slot',     'tryton',    '0/16B3750',   892, 'active'),
    ('bcompass_slot',    'tryton',    '0/16B3740',   445, 'active');

-- entity crossref — employee MDM
INSERT INTO bkernel.entity_crossref (entity_type, source_app, source_table, source_id, target_app, target_table, target_id)
VALUES
    ('employee', 'orangehrm',  'hs_hr_employee',   '42',    'tryton',  'party_party',         '1089'),
    ('employee', 'orangehrm',  'hs_hr_employee',   '42',    'keycloak', 'user_entity',        'abc-123-uuid'),
    ('employee', 'orangehrm',  'hs_hr_employee',   '43',    'tryton',  'party_party',         '1090'),
    ('customer', 'espocrm',    'account',           '201',   'tryton',  'party_party',         '2045'),
    ('customer', 'espocrm',    'account',           '201',   'saleor',  'user_user',           '89');

-- rule execution log — synthetic traces
INSERT INTO bkernel.rule_execution_log (rule_id, event_lsn, source_app, source_table, operation, condition_match, actions_count, duration_ms, status)
VALUES
    ('OHRM-001',   '0/16B0001', 'orangehrm', 'hs_hr_employee',    'INSERT', true,  4,  23, 'success'),
    ('CORE-001',   '0/16B0002', 'orangehrm', 'hs_hr_employee',    'INSERT', true,  5,  31, 'success'),
    ('TRY-023',    '0/16B0003', 'tryton',    'product_product',   'UPDATE', false, 0,   2, 'success'),
    ('CORE-005',   '0/16B0004', 'saleor',    'order_line',        'INSERT', true,  3,  18, 'success'),
    ('SAL-089',    '0/16B0005', 'saleor',    'order_line',        'INSERT', true,  2,  12, 'error');

-- sync log — test sync entries
INSERT INTO bkernel.sync_log (event_id, rule_id, source_app, source_table, target_app, target_table, operation, rows_affected, duration_ms, status)
VALUES
    ('a1000000-0000-0000-0000-000000000001', 'OHRM-001', 'orangehrm', 'hs_hr_employee',  'tryton',  'party_party',  'UPSERT', 1, 15, 'completed'),
    ('a1000000-0000-0000-0000-000000000002', 'OHRM-001', 'orangehrm', 'hs_hr_employee',  'keycloak','user_entity',  'UPSERT', 1, 42, 'completed'),
    ('a1000000-0000-0000-0000-000000000003', 'CORE-005', 'saleor',    'order_line',       'tryton',  'sale_sale',    'UPSERT', 1, 28, 'completed');

-- audit events — ISO 27001
INSERT INTO bkernel.audit_events (event_type, user_id, role_id, source_app, source_table, operation, target_app, iso_control, severity)
VALUES
    ('data_sync',     '00000000-0000-0000-0000-000000000001', 'ADMIN_SKULL',  'orangehrm', 'hs_hr_employee', 'INSERT', 'tryton',   'A.8.15', 'info'),
    ('role_update',   '00000000-0000-0000-0000-000000000001', 'OPERADOR_SBOS', 'bos_core', 'bos_bauth_template', 'UPDATE', 'keycloak', 'A.5.15', 'info'),
    ('drift_detected','00000000-0000-0000-0000-000000000002', 'CAJERO_001',   'bos_core', 'bos_bauth_template', 'UPDATE', 'keycloak', 'A.5.15', 'warning');

-- dead letter queue — test DLQ entries
INSERT INTO bkernel.dead_letter_queue (event_id, rule_id, source_app, source_table, operation, event_data, error_message, retry_count, status)
VALUES
    ('b2000000-0000-0000-0000-000000000001', 'TRY-089', 'tryton', 'account_account', 'UPDATE',
     '{"old": {"id": 5001}, "new": {"id": 5001, "name": "Test"}}',
     'connection refused: target DB unreachable', 1, 'pending'),
    ('b2000000-0000-0000-0000-000000000002', 'SAL-101', 'saleor', 'checkout_line', 'INSERT',
     '{"new": {"id": 882, "quantity": 5}}',
     'duplicate key violation on party_party.email', 2, 'retrying');

-- conflict log
INSERT INTO bkernel.conflict_log (rule_id, source_app_a, source_id_a, source_app_b, source_id_b, conflict_type)
VALUES
    ('MDM-001', 'orangehrm', '42', 'tryton', '1089', 'divergent_name');

-- anomaly events
INSERT INTO bkernel.anomaly_events (anomaly_type, source_app, severity, metric_name, metric_value, threshold_value)
VALUES
    ('throughput_drop', 'tryton', 'warning', 'events_per_min', 450, 1000),
    ('lag_increase',    'bkernel_slot', 'critical', 'lag_bytes', 104857600, 52428800);

-- ============================================================================
-- biedata_db fixtures
-- ============================================================================

INSERT INTO biedata.biedata_circuit_state (external_system, state, failure_count, last_success)
VALUES
    ('SIAT Bolivia',    'closed',     0, now() - interval '1 hour'),
    ('AFIP Argentina',  'closed',     0, now() - interval '2 hours'),
    ('SAT Guatemala',   'half_open',  3, now() - interval '30 minutes');

INSERT INTO biedata.biedata_audit_log (box_id, box_type, trigger_type, external_system, status, rows_processed, rows_failed, duration_ms)
VALUES
    ('export_facturas_siat',  'export', 'schedule', 'SIAT Bolivia',   'completed',              45,  0, 3200),
    ('import_clientes_excel', 'import', 'file_watch','Excel Upload',   'completed_with_errors',   87,  3, 5400),
    ('export_nomina_csv',     'export', 'manual',    'Banco Nacional', 'completed',              120,  0, 1800);

INSERT INTO biedata.biedata_dlq (job_id, box_id, external_system, phase, row_data, error_message, retry_count, status)
VALUES
    ('c3000000-0000-0000-0000-000000000001', 'import_clientes_excel', 'Excel Upload', 'transform',
     '{"row": 15, "razon_social": "Empresa Test", "correo": "malformado"}',
     'email regex validation failed', 0, 'pending');

-- ============================================================================
-- bauth_db fixtures
-- ============================================================================

INSERT INTO bauth.bauth_sync_log (template_type, template_id, action, kc_status, tryton_status, privilege_mask, duration_ms)
VALUES
    ('role_template', 'ADMIN_SKULL',   'create_role', 'synced', 'synced', 18446744073709551615, 245),
    ('role_template', 'OPERADOR_SBOS', 'create_role', 'synced', 'synced', 511,                   178),
    ('role_template', 'CAJERO_001',    'update_role', 'synced', 'synced', 101,                    89);

INSERT INTO bauth.bauth_drift_history (template_id, drift_type, expected_value, actual_value, severity, corrected)
VALUES
    ('CAJERO_001', 'missing_composite_role', '{"role": "CAJERO_001"}', '{}', 'high', true);

INSERT INTO bauth.bauth_delegations (delegated_to, delegated_from, role_template, reason, bitmask_effective, valid_from, valid_until, status)
VALUES
    ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001',
     'OPERADOR_SBOS', 'Vacaciones — cobertura temporal', 255,
     now() - interval '1 day', now() + interval '6 days', 'active');

INSERT INTO bauth.bauth_access_log (user_id, username, node_id, input_type, domain_logical, domain_physical, domain_financial, loa_level, result, bitmask, latency_ms)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'ivan.villanueva', 'Admin-01', 'webauthn', true, true, true, 4, 'GRANTED', 18446744073709551615, 12),
    ('00000000-0000-0000-0000-000000000003', 'test.operator',   'Ventas-01', 'otp',     true, true, false, 1, 'GRANTED', 511,                     8),
    ('00000000-0000-0000-0000-000000000004', 'test.cajero',    'Tienda-01', 'qr',       true, true, false, 1, 'DENIED',  101,                     3);

-- ============================================================================
-- bcompass_db fixtures
-- ============================================================================

INSERT INTO bcompass.bcompass_route_log (route_id, route_type, user_id, governance_level, model_used, prompt_tokens, completion_tokens, confidence, latency_ms, status)
VALUES
    ('RPT-001', 'sales_forecast',  '00000000-0000-0000-0000-000000000001', 2, 'qwen3:14b',      450, 320, 0.87, 4200, 'completed'),
    ('QA-002',  'qa',              '00000000-0000-0000-0000-000000000003', 1, 'deepseek-r1:8b',  180, 520, 0.92, 6800, 'completed'),
    ('PLAN-005','inventory_analysis','00000000-0000-0000-0000-000000000003', 3, 'qwen3:14b',     890, 750, 0.81, 12300, 'requires_approval');

INSERT INTO bcompass.bcompass_feedback (route_log_id, user_id, rating, useful, comment)
VALUES
    (1, '00000000-0000-0000-0000-000000000001', 5, true,  'Excelente precisión en forecast Q3'),
    (2, '00000000-0000-0000-0000-000000000003', 4, true,  'Buena respuesta, faltó contexto de inventario');

INSERT INTO bcompass.bcompass_proposals (route_id, route_log_id, proposal_type, title, proposal_data, confidence, impact, governance_level, status)
VALUES
    ('PLAN-005', 3, 'inventory_alert', 'Reorden urgente: Stock bajo en categoría A',
     '{"products": ["SKU-001", "SKU-045"], "current_stock": 12, "reorder_point": 50, "suggested_qty": 200}',
     0.88, 'high', 3, 'pending');

-- ============================================================================
-- bos_db fixtures
-- ============================================================================

INSERT INTO bos.bos_operation_log (operation_type, ficha_name, product_name, category, criticality, phase, status, duration_ms, operator)
VALUES
    ('install',     'tryton',        'Tryton ERP',     2, true,  'install',  'completed',  45000,  'ivan.villanueva'),
    ('install',     'keycloak',      'Keycloak IAM',   3, true,  'install',  'completed',  32000,  'ivan.villanueva'),
    ('repair',      'kong',          'Kong Gateway',   2, false, 'repair',   'completed',   1200,  'juan.perez'),
    ('update',      'grafana',       'Grafana',        1, false, 'configure','completed',   3500,  'juan.perez'),
    ('health_check','--',            'System',         1, false, 'verify',   'completed',    150,  'bos.service');

INSERT INTO bos.bos_health_snapshot (fichas_total, fichas_healthy, fichas_degraded, k8s_nodes, k8s_nodes_ready, k8s_pods_total, k8s_pods_running, pg_connections, overall_status)
VALUES
    (34, 32, 2, 5, 5, 147, 145, 28, 'degraded'),
    (34, 33, 1, 5, 5, 147, 146, 25, 'degraded'),
    (34, 34, 0, 5, 5, 147, 147, 22, 'healthy');
