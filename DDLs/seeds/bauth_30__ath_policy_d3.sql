-- seed_ath_policy_d3.sql — Políticas pre-diseñadas D3 Financiero
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: PCI DSS 4.0.1 · SOX §404 · COSO 2013 · NIST SP 800-53 AC-5 · SIN Bolivia RND 102100000011
-- ═══════════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.ath_policy_d3 RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.ath_policy_d3;

INSERT INTO bauth.ath_policy_d3 (policy_code, policy_name, description, standard_ref, config) VALUES

('DUAL_APPROVAL_ABOVE_5000', 'Aprobación dual > 5.000 BOB', 'Transacciones > 5.000 BOB requieren 2 aprobadores distintos. SoD: creador != aprobador.',
 '{SOX §404,COSO 2013 Control Activities,NIST SP 800-53 AC-5}',
 '{"rule":"dual_approval","threshold":5000,"currency":"BOB","approvers_required":2,"sod_check":"creator_neq_approver"}'),

('SOD_CREATOR_APPROVER', 'SoD: Creador ≠ Aprobador', 'Quien crea una transacción financiera no puede aprobarla. SoD estático obligatorio.',
 '{SOX §404,NIST SP 800-53 AC-5,ISACA COBIT 2019}',
 '{"rule":"sod","type":"creator_neq_approver","severity":"CRITICAL","mitigation":"DENY"}'),

('SOD_CASHIER_RECONCILE', 'SoD: Cajero ≠ Conciliador', 'Quien recibe cobros no puede conciliar extractos bancarios. Separación obligatoria.',
 '{SOX §404,COSO 2013 §8}',
 '{"rule":"sod","type":"cashier_neq_reconciler","severity":"CRITICAL","mitigation":"DENY"}'),

('LIMIT_DAILY_10000', 'Límite diario 10.000 BOB', 'Máximo 10.000 BOB en transacciones por día calendario. Agregación por usuario.',
 '{PCI DSS 4.0.1 Req.7,COSO 2013}',
 '{"rule":"daily_limit","amount":10000,"currency":"BOB","aggregation":"SUM_ALL_TRANSACTIONS"}'),

('LIMIT_MONTHLY_50000', 'Límite mensual 50.000 BOB', 'Máximo 50.000 BOB en transacciones por mes calendario.',
 '{PCI DSS 4.0.1 Req.7}',
 '{"rule":"monthly_limit","amount":50000,"currency":"BOB"}'),

('SIN_COMPLIANCE_BOLIVIA', 'Cumplimiento SIN Bolivia', 'Facturación electrónica obligatoria. Dosificación SIN, CAFC, envío en línea. RND 102100000011.',
 '{SIN RND 102100000011,ISO 20022}',
 '{"rule":"sin_compliance","country":"BO","electronic_invoicing":true,"offline_contingency_allowed":true,"offline_max_hours":48}'),

('APPROVAL_CHAIN_3_TIERS', 'Cadena de aprobación 3 niveles', 'N1≤2.000→1aprobador, N2≤10.000→2aprobadores, N3>10.000→3aprobadores con justificación.',
 '{COSO 2013,SOX §404}',
 '{"rule":"approval_chain","levels":[{"tier":1,"amount_up_to":2000,"approvers":1},{"tier":2,"amount_up_to":10000,"approvers":2,"step_up":true},{"tier":3,"amount_up_to":null,"approvers":3,"justification_required":true}]}'),

('TRANSACTION_SCHEDULE_OFFICE', 'Horario de transacciones: oficina', 'Transacciones solo Lun-Vie 08:30-18:00, Sáb 08:30-12:30. Fuera de horario: bloqueado.',
 '{PCI DSS 4.0.1 Req.7}',
 '{"rule":"transaction_schedule","type":"SCHEDULED","days":["MON-FRI","SAT"],"hours":{"MON-FRI":"08:30-18:00","SAT":"08:30-12:30"},"outside":"BLOCKED"}'),

('REQUIRE_SECURE_NETWORK', 'Red segura obligatoria', 'Transacciones financieras solo desde red corporativa. Bloquear VPN, WiFi público, redes móviles.',
 '{PCI DSS 4.0.1 Req.7,NIST SP 800-207 ZTA}',
 '{"rule":"secure_network_required","allowed_zones":["CORPORATE"],"block_remote":true,"block_vpn":false}');

-- SELECT count(*) AS total_d3_policies FROM bauth.ath_policy_d3;
