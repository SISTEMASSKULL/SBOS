-- seed_ath_method.sql — 40 métodos de autenticación
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: NIST SP 800-63B-4 Final (2025) · FIDO2 Level 3 · OWASP ASVS V2
-- ═══════════════════════════════════════════════════════════════
SET lock_timeout = '5s';
TRUNCATE TABLE bauth.ath_method RESTART IDENTITY CASCADE;
REINDEX TABLE bauth.ath_method;

INSERT INTO bauth.ath_method (method_id, method_name, method_type, category, aal_level, nist_status, applies_to, rfc_ref, kc_implementation, domain_classification) VALUES

-- Single-factor
('PASSWORD','Password','single_factor','password','AAL1','permitted','{web,api}','NIST SP 800-63B-4 §5.1.1','keycloak','{"D1":true,"D2":true,"D9":true}'),
('EMAIL_OTP','Email OTP','single_factor','otp','AAL1','discouraged','{web}','RFC 6238','keycloak','{"D1":true,"D9":true}'),
('SMS_OTP','SMS OTP','deprecated','otp','AAL1','deprecated','{web}','RFC 6238','keycloak','{"D1":true,"D9":true}'),

-- Multi-factor
('TOTP','TOTP Authenticator App','multi_factor','otp','AAL2','permitted','{web,api}','RFC 6238','keycloak','{"D1":true,"D2":true,"D3":true,"D9":true}'),
('HOTP','HOTP Hardware Token','multi_factor','otp','AAL2','permitted','{web,api}','RFC 4226','keycloak','{"D1":true,"D2":true,"D3":true,"D9":true}'),
('EMAIL_OTP_2FA','Email OTP 2FA','multi_factor','otp','AAL2','discouraged','{web}','RFC 6238','keycloak','{"D1":true,"D9":true}'),

-- Phishing-resistant
('WEBAUTHN_PWDLESS','WebAuthn Passkey (Discoverable)','phishing_resistant','cryptographic','AAL2','preferred','{web,api,mobile}','FIDO2 Level 2 · WebAuthn W3C','keycloak','{"D1":true,"D2":true,"D3":true,"D5":true,"D9":true}'),
('WEBAUTHN_2FA','WebAuthn 2FA (Non-Discoverable)','phishing_resistant','cryptographic','AAL2','preferred','{web,api}','FIDO2 Level 1 · WebAuthn W3C','keycloak','{"D1":true,"D2":true,"D9":true}'),
('PASSKEY_SYNCED','Passkey Synced (iCloud/Google)','phishing_resistant','cryptographic','AAL2','permitted','{web,api,mobile}','FIDO2 Level 2','keycloak','{"D1":true,"D2":true,"D3":true,"D5":true,"D9":true}'),
('PASSKEY_DEVICE','Passkey Device-Bound (FIPS)','phishing_resistant','cryptographic','AAL3','preferred','{web,api}','FIDO2 Level 3 · FIPS 140-3','keycloak','{"D1":true,"D2":true,"D3":true,"D5":true,"D9":true,"D12":true}'),
('SMARTCARD_X509','Smart Card X.509 PIV','phishing_resistant','cryptographic','AAL3','preferred','{api,physical}','FIPS 201-3 · NIST SP 800-73-5','keycloak','{"D1":true,"D2":true,"D3":true,"D9":true}'),

-- Federated
('OAUTH2_AUTH_CODE','OAuth 2.1 Authorization Code + PKCE','federated','federated','AAL2','preferred','{web,api}','RFC 6749 · RFC 7636 · OAuth 2.1 BCP','keycloak','{"D1":true,"D7":true,"D9":true}'),
('CLIENT_CREDENTIALS','OAuth 2.1 Client Credentials (M2M)','machine','federated','n/a','preferred','{api}','RFC 6749 · OAuth 2.1 BCP','keycloak','{"D7":true,"D9":true}'),
('OIDC_HYBRID','OpenID Connect Hybrid Flow','federated','federated','AAL2','permitted','{web}','OpenID Connect Core 1.0','keycloak','{"D1":true,"D7":true,"D9":true}'),
('SAML2_POST','SAML 2.0 POST Binding','federated','federated','AAL2','permitted','{web}','SAML 2.0 · OASIS','keycloak','{"D1":true,"D7":true,"D9":true}'),
('CIBA','CIBA Decoupled Auth','federated','out_of_band','AAL2','permitted','{mobile}','OpenID CIBA · FAPI 2.0','keycloak','{"D1":true,"D9":true}'),
('TOKEN_EXCHANGE','Token Exchange (JWT Profile)','federated','federated','AAL2','permitted','{api}','RFC 8693 · RFC 7523','keycloak','{"D7":true,"D9":true}'),

-- Recovery
('BACKUP_CODES','Backup Recovery Codes','recovery','recovery','AAL1','permitted','{web}','OWASP ASVS V2.5.1','keycloak','{"D1":true,"D9":true}'),
('RECOVERY_EMAIL','Email Recovery','recovery','recovery','AAL1','discouraged','{web}','NIST SP 800-63B-4 §4.4','keycloak','{"D1":true,"D9":true}'),

-- Biometric (via WebAuthn platform authenticator)
('TOUCH_ID','Apple Touch ID','phishing_resistant','biometric','AAL2','preferred','{mobile}','FIDO2 Level 2 · WebAuthn W3C','keycloak','{"D1":true,"D2":true,"D5":true,"D9":true}'),
('FACE_ID','Apple Face ID','phishing_resistant','biometric','AAL3','preferred','{mobile}','FIDO2 Level 3 · ISO 30107-3 PAD','keycloak','{"D1":true,"D2":true,"D5":true,"D9":true}'),
('WINDOWS_HELLO','Windows Hello','phishing_resistant','biometric','AAL2','preferred','{desktop}','FIDO2 Level 2 · WebAuthn W3C','keycloak','{"D1":true,"D2":true,"D5":true,"D9":true}'),
('ANDROID_BIOMETRIC','Android Biometric','phishing_resistant','biometric','AAL2','preferred','{mobile}','FIDO2 Level 2 · Android Keystore','keycloak','{"D1":true,"D2":true,"D5":true,"D9":true}'),

-- Hardware tokens
('YUBIKEY_OTP','YubiKey OTP','multi_factor','otp','AAL2','permitted','{desktop}','Yubico OTP · RFC 4226','keycloak','{"D1":true,"D2":true,"D9":true}'),
('YUBIKEY_FIDO2','YubiKey FIDO2','phishing_resistant','cryptographic','AAL3','preferred','{desktop}','FIDO2 Level 3 · FIPS 140-3','keycloak','{"D1":true,"D2":true,"D3":true,"D5":true,"D9":true,"D12":true}'),
('NITROKEY_FIDO2','Nitrokey FIDO2','phishing_resistant','cryptographic','AAL3','preferred','{desktop}','FIDO2 Level 3','keycloak','{"D1":true,"D2":true,"D3":true,"D5":true,"D9":true}'),

-- Out-of-band
('PUSH_NOTIFICATION','Push Notification (Mobile App)','out_of_band','out_of_band','AAL2','permitted','{mobile}','Custom SPI · FCM/APNS','spi_required','{"D1":true,"D5":true,"D9":true}'),
('WHATSAPP_OTP','WhatsApp OTP','out_of_band','out_of_band','AAL1','discouraged','{mobile}','WhatsApp Business API','spi_required','{"D1":true,"D9":true}'),

-- Adaptive / Conditional
('STEP_UP_CONDITIONAL','Step-Up Conditional OTP','adaptive','adaptive','AAL2','permitted','{web,api}','RFC 9470 · NIST SP 800-63B-4 §4.3','keycloak','{"D1":true,"D3":true,"D9":true}'),
('RISK_BASED_AUTH','Risk-Based Authentication','adaptive','adaptive','AAL2','permitted','{web,api}','NIST SP 800-207 · ZTA','custom','{"D1":true,"D7":true,"D8":true,"D9":true}'),

-- Deprecated / Legacy
('BASIC_AUTH','HTTP Basic Authentication','deprecated','password','AAL1','deprecated','{api}','RFC 7617','keycloak','{"D1":true}'),
('BEARER_TOKEN_STATIC','Static Bearer Token','deprecated','cryptographic','AAL1','deprecated','{api}','RFC 6750','keycloak','{"D1":true,"D7":true}');

-- SELECT count(*) AS total_methods FROM bauth.ath_method;
