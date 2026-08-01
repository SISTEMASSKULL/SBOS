-- bauth_T335__auth_method.sql — Seed de métodos de autenticación bAuth
-- Fuente: Authentication_Framework.json v3.0.0 + src/CLAUDE.md (18 métodos documentados)
-- Categorías: A=Password/KBA · B=OTP · C=WebAuthn/FIDO2 · D=PKI/Cert · E=Federated · F=M2M
-- Idempotente: ON CONFLICT (code) DO NOTHING
SET lock_timeout = '5s';

-- ─── CATEGORÍA A — Algo que el usuario sabe (password, recovery) ────────────
INSERT INTO bauth.auth_method (code, category, name, description, loa_provided, is_phishing_resistant, is_mfa_component, status, standards, sort_order)
VALUES
    ('password',
     'A',
     '{"es": "Contraseña", "en": "Password"}',
     '{"es": "Autenticación por contraseña con política NIST SP 800-63B Rev.4: Argon2id, screening de brechas, min 8 chars.", "en": "Password authentication with NIST SP 800-63B Rev.4 policy: Argon2id, breach screening, min 8 chars."}',
     'AAL1', false, false, 'IMPLEMENTED',
     ARRAY['NIST SP 800-63B-4 §5.1', 'OWASP ASVS 2.1'], 10),

    ('recovery_codes',
     'A',
     '{"es": "Códigos de recuperación", "en": "Recovery Codes"}',
     '{"es": "Códigos de un solo uso para recuperación de cuenta cuando otros factores no están disponibles. 10 códigos de 8 caracteres aleatorios.", "en": "Single-use codes for account recovery when other factors are unavailable. 10 codes of 8 random chars."}',
     'AAL1', false, true, 'IMPLEMENTED',
     ARRAY['NIST SP 800-63B-4 §5.1.12', 'OWASP ASVS 2.10'], 15),

    ('conditional_otp',
     'A',
     '{"es": "OTP Condicional", "en": "Conditional OTP"}',
     '{"es": "Solicita un segundo factor solo cuando el motor de riesgo detecta comportamiento anómalo (IP desconocida, dispositivo nuevo, horario inusual).", "en": "Requests a second factor only when the risk engine detects anomalous behavior (unknown IP, new device, unusual hours)."}',
     'AAL1', false, true, 'IMPLEMENTED',
     ARRAY['NIST SP 800-63B-4 §7.3', 'NIST SP 800-53 IA-8'], 16)
ON CONFLICT (code) DO NOTHING;

-- ─── CATEGORÍA B — OTP (basado en tiempo o evento) ─────────────────────────
INSERT INTO bauth.auth_method (code, category, name, description, loa_provided, is_phishing_resistant, is_mfa_component, status, standards, sort_order)
VALUES
    ('totp',
     'B',
     '{"es": "TOTP (Tiempo)", "en": "TOTP (Time-based)"}',
     '{"es": "Contraseña de un solo uso basada en tiempo. Ventana de 30s, SHA-1/SHA-256/SHA-512, compatible con Google Authenticator, Authy, etc.", "en": "Time-based one-time password. 30s window, SHA-1/SHA-256/SHA-512, compatible with Google Authenticator, Authy, etc."}',
     'AAL2', false, true, 'IMPLEMENTED',
     ARRAY['RFC 6238', 'NIST SP 800-63B-4 §5.1.4', 'OWASP ASVS 2.8'], 20),

    ('hotp',
     'B',
     '{"es": "HOTP (Contador)", "en": "HOTP (Counter-based)"}',
     '{"es": "Contraseña de un solo uso basada en contador HMAC. Resincronización automática con ventana de 10 pasos.", "en": "Counter-based HMAC one-time password. Auto-resync with window of 10 steps."}',
     'AAL2', false, true, 'IMPLEMENTED',
     ARRAY['RFC 4226', 'NIST SP 800-63B-4 §5.1.4', 'OWASP ASVS 2.8'], 21),

    ('email_otp',
     'B',
     '{"es": "OTP por Correo", "en": "Email OTP"}',
     '{"es": "Código de 6 dígitos enviado por correo electrónico. TTL 10 minutos. Requiere email verificado en la cuenta.", "en": "6-digit code sent by email. TTL 10 minutes. Requires verified email on the account."}',
     'AAL2', false, true, 'IMPLEMENTED',
     ARRAY['NIST SP 800-63B-4 §5.1.3', 'OWASP ASVS 2.5'], 22),

    ('sms_otp',
     'B',
     '{"es": "OTP por SMS (obsoleto)", "en": "SMS OTP (deprecated)"}',
     '{"es": "Código por SMS. DEPRECATED por NIST SP 800-63B-4 §5.1.3 (vulnerabilidad SIM-swapping). Solo disponible para tenants con dispensa explícita.", "en": "SMS code. DEPRECATED per NIST SP 800-63B-4 §5.1.3 (SIM-swapping vulnerability). Only for tenants with explicit waiver."}',
     'AAL1', false, true, 'DEPRECATED',
     ARRAY['NIST SP 800-63B-4 §5.1.3 (deprecated)'], 99)
ON CONFLICT (code) DO NOTHING;

-- ─── CATEGORÍA C — WebAuthn / FIDO2 / Passkey (resistente a phishing) ───────
INSERT INTO bauth.auth_method (code, category, name, description, loa_provided, is_phishing_resistant, is_mfa_component, status, standards, sort_order)
VALUES
    ('webauthn_passwordless',
     'C',
     '{"es": "WebAuthn Sin Contraseña", "en": "WebAuthn Passwordless"}',
     '{"es": "Autenticación sin contraseña mediante autenticador FIDO2 (llave de seguridad, TPM, biometría). Vinculado al origen — resistente a phishing.", "en": "Passwordless authentication via FIDO2 authenticator (security key, TPM, biometrics). Origin-bound — phishing-resistant."}',
     'AAL2', true, false, 'IMPLEMENTED',
     ARRAY['FIDO2', 'W3C WebAuthn Level 2', 'NIST SP 800-63B-4 §5.1.7', 'OWASP ASVS 2.9'], 30),

    ('webauthn_2fa',
     'C',
     '{"es": "WebAuthn Segundo Factor", "en": "WebAuthn 2FA"}',
     '{"es": "Autenticador FIDO2 como segundo factor adicional a la contraseña. sign_count verificado contra replay. Exige presencia del usuario.", "en": "FIDO2 authenticator as second factor in addition to password. sign_count verified against replay. Requires user presence."}',
     'AAL2', true, true, 'IMPLEMENTED',
     ARRAY['FIDO2', 'W3C WebAuthn Level 2', 'NIST SP 800-63B-4 §5.1.7', 'OWASP ASVS 2.9'], 31),

    ('passkey',
     'C',
     '{"es": "Passkey (Credencial Descubrible)", "en": "Passkey (Discoverable Credential)"}',
     '{"es": "Passkey sincronizado entre dispositivos (FIDO2 Discoverable Credential). Compatible con iCloud Keychain, Google Password Manager. AAL2 synced, AAL3 con hardware bound.", "en": "Device-synced passkey (FIDO2 Discoverable Credential). Compatible with iCloud Keychain, Google Password Manager. AAL2 synced, AAL3 with hardware bound."}',
     'AAL2', true, false, 'IMPLEMENTED',
     ARRAY['FIDO2 Passkey', 'W3C WebAuthn Level 3', 'CTAP 2.2', 'NIST SP 800-63B-4 §5.1.7'], 32)
ON CONFLICT (code) DO NOTHING;

-- ─── CATEGORÍA D — PKI / Certificado / Kerberos ─────────────────────────────
INSERT INTO bauth.auth_method (code, category, name, description, loa_provided, is_phishing_resistant, is_mfa_component, status, standards, sort_order)
VALUES
    ('x509_mtls',
     'D',
     '{"es": "Certificado X.509 mTLS", "en": "X.509 mTLS Client Certificate"}',
     '{"es": "Autenticación mutua TLS con certificado cliente X.509. Emitido por PKI interna (Vault PKI) o ADSIB Bolivia. Criptográficamente vinculado a la sesión (RFC 8705).", "en": "Mutual TLS authentication with X.509 client certificate. Issued by internal PKI (Vault PKI) or ADSIB Bolivia. Cryptographically bound to session (RFC 8705)."}',
     'AAL3', true, false, 'IMPLEMENTED',
     ARRAY['RFC 5280', 'RFC 8705', 'NIST SP 800-63B-4 §5.1.9', 'ADSIB-FD-POLT-015 v2.3', 'Ley 164 Bolivia'], 40),

    ('kerberos',
     'D',
     '{"es": "Kerberos v5", "en": "Kerberos v5"}',
     '{"es": "Autenticación Kerberos v5 para entornos Active Directory / LDAP. Válido para integración con infraestructura corporativa existente.", "en": "Kerberos v5 authentication for Active Directory / LDAP environments. Valid for integration with existing corporate infrastructure."}',
     'AAL2', false, false, 'PLANNED',
     ARRAY['RFC 4120', 'NIST SP 800-63B-4 §5.1.9'], 41)
ON CONFLICT (code) DO NOTHING;

-- ─── CATEGORÍA E — Federación / SSO ─────────────────────────────────────────
INSERT INTO bauth.auth_method (code, category, name, description, loa_provided, is_phishing_resistant, is_mfa_component, status, standards, sort_order)
VALUES
    ('social_brokering',
     'E',
     '{"es": "Brokering Social (IdP externo)", "en": "Social Brokering (External IdP)"}',
     '{"es": "Autenticación delegada a un proveedor de identidad externo (Google, Microsoft, GitHub, Apple). El LoA depende del LoA del IdP externo — máximo AAL1 por defecto salvo acuerdo de confianza.", "en": "Authentication delegated to an external identity provider (Google, Microsoft, GitHub, Apple). LoA depends on external IdP LoA — AAL1 max by default unless trust agreement."}',
     'AAL1', false, false, 'IMPLEMENTED',
     ARRAY['OAuth 2.0 RFC 6749', 'OpenID Connect Core 1.0', 'NIST SP 800-63C-4'], 50),

    ('saml2',
     'E',
     '{"es": "SAML 2.0 Federado", "en": "SAML 2.0 Federated"}',
     '{"es": "Autenticación federada mediante SAML 2.0 (SSO empresarial). bAuth actúa como SP. El LoA se infiere del AuthnContextClassRef del assertion SAML.", "en": "Federated authentication via SAML 2.0 (enterprise SSO). bAuth acts as SP. LoA inferred from SAML assertion AuthnContextClassRef."}',
     'AAL2', false, false, 'IMPLEMENTED',
     ARRAY['SAML 2.0 OASIS', 'NIST SP 800-63C-4', 'eIDAS 2.0'], 51)
ON CONFLICT (code) DO NOTHING;

-- ─── CATEGORÍA F — Máquina / M2M ─────────────────────────────────────────────
INSERT INTO bauth.auth_method (code, category, name, description, loa_provided, is_phishing_resistant, is_mfa_component, status, standards, sort_order)
VALUES
    ('client_credentials',
     'F',
     '{"es": "Client Credentials (M2M)", "en": "Client Credentials (M2M)"}',
     '{"es": "OAuth 2.0 Client Credentials para machine-to-machine. El cliente se autentica con client_id + client_secret. Secreto almacenado en Vault, rotado automáticamente.", "en": "OAuth 2.0 Client Credentials for machine-to-machine. Client authenticates with client_id + client_secret. Secret stored in Vault, auto-rotated."}',
     'AAL1', false, false, 'IMPLEMENTED',
     ARRAY['OAuth 2.0 RFC 6749 §4.4', 'RFC 7521', 'NIST SP 800-63B-4'], 60),

    ('token_exchange',
     'F',
     '{"es": "Intercambio de Token (RFC 8693)", "en": "Token Exchange (RFC 8693)"}',
     '{"es": "OAuth 2.0 Token Exchange para delegar o impersonar identidades entre servicios internos. Requiere grant_type=urn:ietf:params:oauth:grant-type:token-exchange.", "en": "OAuth 2.0 Token Exchange for delegating or impersonating identities between internal services. Requires grant_type=urn:ietf:params:oauth:grant-type:token-exchange."}',
     'AAL1', false, false, 'IMPLEMENTED',
     ARRAY['RFC 8693', 'NIST SP 800-63B-4'], 61),

    ('ciba',
     'F',
     '{"es": "CIBA (Backchannel Authentication)", "en": "CIBA (Client-Initiated Backchannel Authentication)"}',
     '{"es": "Autenticación iniciada por cliente en canal de retorno (FAPI 2.0). El cliente solicita la autenticación y el usuario la aprueba en su dispositivo sin redireccionamiento.", "en": "Client-initiated backchannel authentication (FAPI 2.0). Client requests auth and user approves on their device without redirect."}',
     'AAL2', false, false, 'PLANNED',
     ARRAY['OpenID CIBA 1.0', 'FAPI 2.0', 'NIST SP 800-63B-4'], 62),

    ('device_auth',
     'F',
     '{"es": "Device Authorization Grant (RFC 8628)", "en": "Device Authorization Grant (RFC 8628)"}',
     '{"es": "OAuth 2.0 Device Authorization Grant para dispositivos sin navegador (TV, CLI, IoT). El usuario ingresa el user_code en otro dispositivo con navegador.", "en": "OAuth 2.0 Device Authorization Grant for browserless devices (TV, CLI, IoT). User enters user_code on another device with a browser."}',
     'AAL1', false, false, 'IMPLEMENTED',
     ARRAY['RFC 8628', 'OAuth 2.0 RFC 6749', 'NIST SP 800-63B-4'], 63)
ON CONFLICT (code) DO NOTHING;

SELECT 'T335__auth_method: ' || COUNT(*) || ' métodos cargados' AS resultado
FROM bauth.auth_method;
