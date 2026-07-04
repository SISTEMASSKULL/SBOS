-- ================================================================
-- run_all_seeds.sql — Ejecución ordenada de 49 seeds en producción
-- Uso: psql -U postgres -d skSBOS_db -f run_all_seeds.sql
-- IDEMPOTENTE: cada seed usa TRUNCATE o ON CONFLICT.
-- Ejecutable N veces con resultado idéntico.
-- ================================================================
SET lock_timeout = '5s';
SET client_min_messages = WARNING;

-- ═══════════════════════════════════════════════════════════
-- FASE 0: Catálogos globales (sin dependencias)
-- ═══════════════════════════════════════════════════════════
\echo 'FASE 0: Catálogos globales'
\ir seed_global_country.sql
\ir seed_global_language.sql
\ir seed_geo_timezone.sql

-- ═══════════════════════════════════════════════════════════
-- FASE 1: Sistema de privilegios (base para átomos)
-- ═══════════════════════════════════════════════════════════
\echo 'FASE 1: Sistema de privilegios'
\ir seed_privilege_domain.sql
\ir seed_privilege_verb.sql
\ir seed_privilege_application.sql
\ir seed_privilege_group.sql
\ir seed_privilege_atom.sql
\ir seed_privilege_atom_policy.sql
\ir seed_privilege_role.sql
\ir seed_privilege_role_atom.sql

-- ═══════════════════════════════════════════════════════════
-- FASE 2: Tenant y configuración base
-- ═══════════════════════════════════════════════════════════
\echo 'FASE 2: Tenant y configuración base'
\ir seed_idn_tenant.sql
\ir seed_idn_tier_policy.sql
\ir seed_log_zone.sql
\ir seed_geo_trust_tier.sql

-- ═══════════════════════════════════════════════════════════
-- FASE 3: Catálogos de autenticación (sin dependencias entre sí)
-- ═══════════════════════════════════════════════════════════
\echo 'FASE 3: Catálogos de autenticación'
\ir seed_ath_method.sql
\ir seed_ath_federation_protocol.sql
\ir seed_ath_config_d1.sql
\ir seed_ath_config_d2.sql
\ir seed_ath_config_d3.sql
\ir seed_ath_config_d4.sql
\ir seed_ath_config_d5.sql
\ir seed_ath_config_d6.sql
\ir seed_ath_config_d7.sql
\ir seed_ath_config_d8.sql
\ir seed_ath_config_d9.sql
\ir seed_ath_config_d10.sql
\ir seed_ath_config_d11.sql
\ir seed_ath_config_d12.sql

-- ═══════════════════════════════════════════════════════════
-- FASE 4: Políticas por dominio D1-D12
-- ═══════════════════════════════════════════════════════════
\echo 'FASE 4: Políticas por dominio D1-D12'
\ir seed_ath_policy_d1.sql
\ir seed_ath_policy_d2.sql
\ir seed_ath_policy_d3.sql
\ir seed_ath_policy_d4.sql
\ir seed_ath_policy_d5.sql
\ir seed_ath_policy_d6.sql
\ir seed_ath_policy_d7.sql
\ir seed_ath_policy_d8.sql
\ir seed_ath_policy_d9.sql
\ir seed_ath_policy_d10.sql
\ir seed_ath_policy_d11.sql
\ir seed_ath_policy_d12.sql

-- ═══════════════════════════════════════════════════════════
-- FASE 5: Flujos y reglas (dependen de ath_method)
-- ═══════════════════════════════════════════════════════════
\echo 'FASE 5: Flujos y reglas de autenticación'
\ir seed_ath_auth_flow.sql
\ir seed_ath_step_up_rule.sql
\ir seed_validation_rules.sql
\ir seed_framework_sync.sql

-- ═══════════════════════════════════════════════════════════
-- FASE 6: Financiero, Calendario, Geo
-- ═══════════════════════════════════════════════════════════
\echo 'FASE 6: Financiero, Calendario, Geo'
\ir seed_fin_transaction_type.sql
\ir seed_fin_sod_rule.sql
\ir seed_fin_limit.sql
\ir seed_fin_decision_matrix.sql
\ir seed_cal_calendar.sql
\ir seed_cal_schedule.sql
\ir seed_cal_holiday_complete.sql

-- ═══════════════════════════════════════════════════════════
-- FASE 7: Roles (dependen de tenant, log_zone, policies)
-- ═══════════════════════════════════════════════════════════
\echo 'FASE 7: Roles y templates'
\ir seed_idn_role_template.sql
\ir seed_idn_role_template_data.sql
\ir seed_idn_role_d1.sql
\ir seed_idn_role_d2.sql
\ir seed_idn_role_d3.sql
\ir seed_idn_role_d4.sql
\ir seed_idn_role_d5.sql
\ir seed_idn_role_d6.sql
\ir seed_idn_role_d7.sql
\ir seed_idn_role_d8.sql
\ir seed_idn_role_d9.sql
\ir seed_idn_role_d10.sql
\ir seed_idn_role_d11.sql
\ir seed_idn_role_d12.sql
\ir seed_idn_role_closure.sql

-- ═══════════════════════════════════════════════════════════
-- FASE 8: Menús contextuales (dependen de tenant)
-- ═══════════════════════════════════════════════════════════
\echo 'FASE 8: Menús'
\ir seed_menu_context.sql
\ir seed_menu_item.sql

-- ═══════════════════════════════════════════════════════════
-- FASE 9: Organización y apps
-- ═══════════════════════════════════════════════════════════
\echo 'FASE 9: Organización y apps'
\ir seed_org_empresa.sql
\ir seed_org_sucursal.sql
\ir seed_mobile_app_config.sql
\ir seed_zone_application_map.sql

-- ═══════════════════════════════════════════════════════════
-- FASE 10: Framework unificado (depende de todo lo anterior)
-- ═══════════════════════════════════════════════════════════
\echo 'FASE 10: Framework unificado'
\ir 061_ath_credential_policy.sql
\ir 062_idn_user_template.sql
\ir 063_aud_compliance_map.sql
\ir 064_idn_user_template_data.sql
\ir seed_idn_user_template_v6.sql
\ir seed_test_users.sql

-- ═══════════════════════════════════════════════════════════
-- FASE 11: Compliance QA System (independiente, idempotente)
-- ═══════════════════════════════════════════════════════════
\echo 'FASE 11: Compliance QA System'
\ir seed_compliance_qa.sql

-- ═══════════════════════════════════════════════════════════
-- FASE 12: Métodos de Autenticación Nativos (independiente, idempotente)
-- ═══════════════════════════════════════════════════════════
\echo 'FASE 12: Auth Methods Nativos'
\ir seed_auth_method_native.sql

\echo '=== 54 seeds ejecutados ==='
