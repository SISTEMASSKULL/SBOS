-- seed_geo_trust_tier.sql — Tiers de confianza por ubicación (BeyondCorp)
-- IDEMPOTENTE · Fuente: Google BeyondCorp Location Trust Tiers · NIST SP 800-53 PE-3
-- ═══════════════════════════════════════════════════════════════
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.geo_trust_tier RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.geo_trust_tier;

INSERT INTO bauth.geo_trust_tier (tier_code, tier_name, tier_level, allowed_operations, restricted_operations, max_session_seconds, requires_step_up, requires_vpn) VALUES

('HIGH', 'Alta Confianza — Oficina/Sucursal', 1,
 '{READ,WRITE,DELETE,APPROVE,CONFIGURE,EMIT,EXECUTE,FINANCIAL_APPROVE,USER_MANAGEMENT,SYSTEM_CONFIG}',
 '{}',
 28800, false, false),

('MEDIUM', 'Confianza Media — VPN / Remoto Seguro', 2,
 '{READ,WRITE,EXECUTE}',
 '{DELETE,APPROVE,CONFIGURE,FINANCIAL_APPROVE,USER_MANAGEMENT,SYSTEM_CONFIG}',
 14400, true, true),

('LOW', 'Baja Confianza — Red pública / Móvil', 3,
 '{READ}',
 '{WRITE,DELETE,APPROVE,CONFIGURE,EMIT,EXECUTE,FINANCIAL_APPROVE,USER_MANAGEMENT,SYSTEM_CONFIG}',
 3600, true, true);

-- SELECT tier_code, tier_level, max_session_seconds FROM bauth.geo_trust_tier ORDER BY tier_level;
