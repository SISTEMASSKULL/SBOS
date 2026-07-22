-- =============================================================
-- T016__idn_tenant.sql
-- Seed: tenant bootstrap — skull (Sistemas SKULL · Bolivia)
-- Tabla: bauth.idn_tenant  (T-016, DDL V2)
-- Idempotente: ON CONFLICT (tenant_slug) DO NOTHING
-- Fuente: bauth_10__idn_tenant.sql (legacy) + estructura V2
-- Generado: 2026-07-22
-- =============================================================

BEGIN;

INSERT INTO bauth.idn_tenant (
    tenant_slug,
    tenant_name,
    tenant_type,
    is_internal,
    status,
    provisioning_status,
    country,
    legal_name,
    tax_id,
    legal_contact_email,
    data_retention_days,
    vault_path,
    isolation_level,
    mfa_required,
    password_policy,
    session_ttl_max,
    token_ttl_seconds,
    rate_limit_rps,
    plan_tier,
    subscription_status,
    audit_level
) VALUES (
    'skull',
    'Sistemas SKULL',
    'HIGH_SENSITIVITY',
    true,
    'ACTIVE',
    'COMPLETED',
    'BO',
    'Sistemas SKULL S.R.L.',
    '1234567890',
    'admin@sksistemas.com',
    2555,
    'secret/bauth/skull',
    'SCHEMA_PER_TENANT',
    false,
    'length(12)_argon2id_t3_m64',
    28800,
    3600,
    100,
    'ENTERPRISE',
    'ACTIVE',
    'full'
)
ON CONFLICT (tenant_slug) DO NOTHING;

COMMIT;
