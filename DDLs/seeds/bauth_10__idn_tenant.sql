-- seed_idn_tenant.sql — Tenant bootstrap del sistema
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- ⚠️ DATOS DE PLANTILLA — El humano corregirá con información real
-- ═══════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.idn_tenant RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.idn_tenant;

INSERT INTO bauth.idn_tenant (
    tenant_slug, tenant_name, tenant_type, status, provisioning_status,
    country, data_retention_days,
    realm_kc, realm_kc_ext, namespace_k8s,
    isolation_level, mfa_required, password_policy,
    session_ttl_max, token_ttl_seconds, rate_limit_rps,
    plan_tier, subscription_status, audit_level,
    legal_contact_email
) VALUES (
    'skull',
    'Sistemas SKULL',
    'HIGH_SENSITIVITY',
    'ACTIVE',
    'COMPLETED',
    'BO',
    2555,
    'tenant-skull',
    'tenant-skull-ext',
    'sbos-skull',
    'SCHEMA_PER_TENANT',
    false,
    'length(12)_argon2id_t3_m64',
    28800,
    3600,
    100,
    'ENTERPRISE',
    'ACTIVE',
    'full',
    'admin@sksistemas.com'
);

-- SELECT tenant_id, tenant_slug, tenant_name FROM bauth.idn_tenant;
