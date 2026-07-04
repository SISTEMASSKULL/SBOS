-- seed_ath_policy_d7.sql — Políticas D7 Red/API
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: NIST SP 800-207 ZTA · CISA ZTMM v2 · RFC 8705 mTLS · OAuth 2.1 BCP
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.ath_policy_d7 RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.ath_policy_d7;

INSERT INTO bauth.ath_policy_d7 (policy_code, policy_name, description, standard_ref, config) VALUES
('DEVICE_TRUST_MIN_70',         'Trust score mínimo 70',        'Dispositivo requiere score de confianza ≥70.', '{NIST SP 800-207 ZTA,CISA ZTMM v2}', '{"rule":"device_trust","min_score":70,"on_failure":"BLOCK"}'),
('VPN_REQUIRED_REMOTE',         'VPN obligatoria acceso remoto', 'Acceso fuera de red corporativa requiere VPN WireGuard activa con killswitch.', '{NIST SP 800-207 ZTA}', '{"rule":"vpn_required","provider":"WIREGUARD","require_killswitch":true}'),
('MTLS_REQUIRED_M2M',           'mTLS obligatorio M2M',         'Comunicación entre servicios requiere certificados X.509 mutuos con rotación auto.', '{RFC 8705,OAuth 2.1 BCP}', '{"rule":"mtls_required","applies_to":["M2M","SERVICE_ACCOUNT"],"cert_rotation":"automatic"}'),
('CONTINUOUS_VERIFICATION_5MIN','Verificación continua cada 5min','Reevaluar postura del dispositivo cada 300s. Señales de MDM+EDR.', '{NIST SP 800-207,OpenID CAEP 1.0}', '{"rule":"continuous_verification","interval_seconds":300,"signal_sources":["MDM","EDR"]}'),
('ZTNA_DEFAULT_DENY',           'Zero Trust default deny',      'Todo tráfico entre servicios es denegado por defecto. Solo servicios explícitos.', '{NIST SP 800-207,CISA ZTMM v2}', '{"rule":"default_deny","microsegment":true,"explicit_allow":["tryton","keycloak","vault"]}'),
('API_RATE_LIMIT_PER_CLIENT',   'Rate limiting por cliente',    '100 req/s autenticado, 10 req/s no autenticado, bloqueo 60s al exceder.', '{OAuth 2.1 BCP,RFC 6585}', '{"rule":"rate_limit","auth_req_s":100,"unauth_req_s":10,"block_seconds":60}');
