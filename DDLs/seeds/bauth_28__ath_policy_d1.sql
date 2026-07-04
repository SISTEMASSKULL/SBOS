-- seed_ath_policy_d1.sql — Políticas pre-diseñadas D1 Lógico
-- Fuente: NIST 800-53 AC-3/5/6 · ANSI INCITS 359-2004 · OASIS XACML 3.0
-- ═══════════════════════════════════════════════════════════════
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.ath_policy_d1 RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.ath_policy_d1;

INSERT INTO bauth.ath_policy_d1 (policy_code, policy_name, description, standard_ref, config) VALUES
('SCOPE_BRANCH', 'Scope: Sucursal', 'Acceso limitado a datos de la sucursal asignada. Record rule automática.',
 '{NIST 800-53 AC-3,ANSI INCITS 359-2004}',
 '{"rule":"scope","level":"BRANCH","auto_record_rule":true}'),
('SCOPE_REGIONAL', 'Scope: Regional', 'Acceso a datos de la región. Incluye sucursales subordinadas.',
 '{NIST 800-53 AC-3}',
 '{"rule":"scope","level":"REGIONAL","auto_record_rule":true}'),
('MAX_RECORDS_200', 'Máximo 200 registros por consulta', 'Limitar resultados de consultas a 200 registros. Prevención de exfiltración masiva.',
 '{NIST 800-53 AC-6}',
 '{"rule":"max_records","value":200}'),
('DATA_CLASS_INTERNAL', 'Clasificación: INTERNAL', 'Acceso a datos PUBLIC + INTERNAL. Sin acceso a CONFIDENTIAL ni RESTRICTED.',
 '{NIST 800-53 AC-3}',
 '{"rule":"data_classification","allowed":["PUBLIC","INTERNAL"],"restricted":["CONFIDENTIAL","RESTRICTED","SECRET"]}'),
('HIDE_FINANCIAL_FIELDS', 'Ocultar campos financieros', 'margin, cost_price, commission_rate ocultos. Solo lectura: credit_limit.',
 '{NIST 800-53 AC-3}',
 '{"rule":"field_restriction","fields":{"margin":"hidden","cost_price":"hidden","commission_rate":"hidden","credit_limit":"readonly"}}'),
('RECORD_RULE_REGION', 'Regla de registro: región', 'Filtro automático por región del usuario en todas las consultas.',
 '{ANSI INCITS 359-2004}',
 '{"rule":"record_filter","type":"region","auto_apply":true}');
