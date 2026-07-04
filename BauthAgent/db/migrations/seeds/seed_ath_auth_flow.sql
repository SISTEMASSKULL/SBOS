-- seed_ath_auth_flow.sql — 8 flujos compuestos de autenticación + métodos asociados
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: NIST SP 800-63B-4 AAL1-3 · RFC 9470 Step-Up · FIDO2 Multi-Factor Ceremony
-- ═══════════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bauth.ath_auth_flow_method RESTART IDENTITY CASCADE;
TRUNCATE TABLE bauth.ath_auth_flow RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.ath_auth_flow_method;
REINDEX TABLE bauth.ath_auth_flow;

-- 8 flujos de autenticación
INSERT INTO bauth.ath_auth_flow (flow_code, flow_name, min_loa, description) VALUES
('unauthenticated',       'Acceso sin autenticación',         0, 'Acceso público sin credenciales. Solo magic link o recursos públicos.'),
('standard_login',        'Login estándar (AAL2)',            2, 'Password + segundo factor (TOTP/WebAuthn). LoA 2. Uso diario.'),
('elevated_login',        'Login elevado (AAL3)',             3, 'Password + Passkey phishing-resistant. LoA 3. Operaciones sensibles.'),
('hardware_protected',    'Hardware Device-Bound (AAL3+)',    3, 'Passkey device-bound FIPS 140-3. LoA 3+. Máxima seguridad.'),
('financial_high_value',  'Transacción financiera alto valor',3, 'Tres factores: Passkey + TOTP fresco. Step-up desde standard_login.'),
('system_config_change',  'Cambio de configuración del sistema',3,'Passkey device-bound exclusivo. Reautenticación obligatoria.'),
('m2m_service_account',   'Machine-to-Machine (M2M)',         0, 'OAuth 2.1 Client Credentials + PKCE. Sin usuario humano.'),
('decoupled_external',    'Autenticación desacoplada externa',2, 'CIBA decoupled. Usuario aprueba en app móvil sin compartir credenciales.');

-- Métodos × flujo
INSERT INTO bauth.ath_auth_flow_method (flow_id, method_id, sort_order, is_required, description)
SELECT f.flow_id, 'EMAIL_OTP',       1, true,  'Magic link de un solo uso, TTL 5 minutos'
FROM bauth.ath_auth_flow f WHERE f.flow_code = 'unauthenticated';

INSERT INTO bauth.ath_auth_flow_method (flow_id, method_id, sort_order, is_required, description)
SELECT f.flow_id, 'PASSWORD',         1, true,  'Primer factor: lo que el usuario SABE'
FROM bauth.ath_auth_flow f WHERE f.flow_code = 'standard_login'
UNION ALL SELECT f.flow_id, 'TOTP',   2, true,  'Segundo factor: lo que el usuario TIENE'
FROM bauth.ath_auth_flow f WHERE f.flow_code = 'standard_login';

INSERT INTO bauth.ath_auth_flow_method (flow_id, method_id, sort_order, is_required, description)
SELECT f.flow_id, 'PASSWORD',              1, true,  'Primer factor'
FROM bauth.ath_auth_flow f WHERE f.flow_code = 'elevated_login'
UNION ALL SELECT f.flow_id, 'WEBAUTHN_PWDLESS', 2, true, 'Passkey phishing-resistant'
FROM bauth.ath_auth_flow f WHERE f.flow_code = 'elevated_login';

INSERT INTO bauth.ath_auth_flow_method (flow_id, method_id, sort_order, is_required, description)
SELECT f.flow_id, 'PASSKEY_DEVICE',     1, true,  'Passkey device-bound FIPS 140-3'
FROM bauth.ath_auth_flow f WHERE f.flow_code = 'hardware_protected'
UNION ALL SELECT f.flow_id, 'TOTP',     2, true,  'Factor adicional fresco'
FROM bauth.ath_auth_flow f WHERE f.flow_code = 'hardware_protected';

INSERT INTO bauth.ath_auth_flow_method (flow_id, method_id, sort_order, is_required, description)
SELECT f.flow_id, 'WEBAUTHN_PWDLESS',   1, true,  'Passkey phishing-resistant'
FROM bauth.ath_auth_flow f WHERE f.flow_code = 'financial_high_value'
UNION ALL SELECT f.flow_id, 'TOTP',     2, true,  'TOTP fresco como tercer factor'
FROM bauth.ath_auth_flow f WHERE f.flow_code = 'financial_high_value';

INSERT INTO bauth.ath_auth_flow_method (flow_id, method_id, sort_order, is_required, description)
SELECT f.flow_id, 'PASSKEY_DEVICE',     1, true,  'Solo Passkey device-bound'
FROM bauth.ath_auth_flow f WHERE f.flow_code = 'system_config_change';

INSERT INTO bauth.ath_auth_flow_method (flow_id, method_id, sort_order, is_required, description)
SELECT f.flow_id, 'CLIENT_CREDENTIALS',          1, true,  'Client Credentials + PKCE'
FROM bauth.ath_auth_flow f WHERE f.flow_code = 'm2m_service_account';

INSERT INTO bauth.ath_auth_flow_method (flow_id, method_id, sort_order, is_required, description)
SELECT f.flow_id, 'CIBA',     1, true,  'Aprobación en app móvil'
FROM bauth.ath_auth_flow f WHERE f.flow_code = 'decoupled_external';

-- SELECT f.flow_code, m.method_id, afm.sort_order, afm.is_required
-- FROM bauth.ath_auth_flow f
-- JOIN bauth.ath_auth_flow_method afm ON afm.flow_id = f.flow_id
-- JOIN bauth.ath__method m ON m.method_id = afm.method_id
-- ORDER BY f.flow_code, afm.sort_order;
