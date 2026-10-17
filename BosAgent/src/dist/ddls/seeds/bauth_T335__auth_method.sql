-- bauth_T335__auth_method.sql — Catálogo canónico de 47 métodos de autenticación bAuth
-- Fuente: 2.02_MANUAL-METODOS-ESTADO-INDUSTRIA-v1.0.md v1.1.0 (2026-07-12) — SSOT
-- Taxonomía NIST SP 800-63B-4:
--   A = Conocimiento (algo que sabes)  · B = Posesión (algo que tienes)
--   C = Inherencia (algo que eres)     · D = Federación e identidad externa
--   E = Flujos especiales y contexto   · F = Identidad descentralizada y emergente
-- Reemplaza: versión anterior con 18 métodos (era Keycloak — taxonomía incorrecta)
-- Idempotente: ON CONFLICT (code) DO UPDATE SET — seguro de ejecutar múltiples veces
SET lock_timeout = '5s';

-- ─────────────────────────────────────────────────────────────────────────────
-- CATEGORÍA A — Conocimiento (algo que el usuario sabe)          (#1 al #5)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO bauth.auth_method
    (code, category, name, description, loa_provided, is_phishing_resistant, is_mfa_component, status, standards, sort_order)
VALUES
    ('password',
     'A',
     '{"es": "Contraseña + Argon2id", "en": "Password + Argon2id"}',
     '{"es": "Contraseña con política NIST SP 800-63B Rev.4: Argon2id (m=19456 KB, t=2, p=1), mínimo 8 chars, screening HIBP obligatorio. Factor único — AAL1.", "en": "Password with NIST SP 800-63B Rev.4 policy: Argon2id, min 8 chars, mandatory HIBP screening. Single factor — AAL1."}',
     'AAL1', false, false, 'IMPLEMENTED',
     ARRAY['NIST SP 800-63B-4 §5.1.1', 'RFC 9106 (Argon2)', 'OWASP ASVS 2.1'], 100),

    ('pin_numeric',
     'A',
     '{"es": "PIN numérico", "en": "Numeric PIN"}',
     '{"es": "PIN de 6–8 dígitos para contextos móviles o terminales físicos. Requiere bloqueo tras 3–5 intentos fallidos y cooldown exponencial. Segundo factor.", "en": "6–8 digit PIN for mobile or physical terminal contexts. Lockout after 3–5 failed attempts with exponential cooldown. Second factor."}',
     'AAL1', false, true, 'PLANNED',
     ARRAY['NIST SP 800-63B-4 §5.1.1', 'OWASP ASVS 2.4'], 110),

    ('pattern_swipe',
     'A',
     '{"es": "Patrón gráfico (swipe)", "en": "Graphical Pattern (swipe)"}',
     '{"es": "Patrón de conexión de puntos en grilla 3×3 o 4×4. Seguridad baja — susceptible a shoulder surfing y grabación de pantalla. Solo con dispensa explícita del tenant.", "en": "Dot-connection pattern on 3×3 or 4×4 grid. Low security — susceptible to shoulder surfing and screen recording. Only with explicit tenant waiver."}',
     'AAL1', false, true, 'PLANNED',
     ARRAY['NIST SP 800-63B-4 §5.1.1 (restricted)'], 120),

    ('recovery_codes',
     'A',
     '{"es": "Códigos de recuperación", "en": "Recovery Codes"}',
     '{"es": "10 códigos de un solo uso (8 caracteres aleatorios diceware) para recuperación de cuenta cuando otros factores no están disponibles. Almacenados hasheados con Argon2id. Solo para emergencias.", "en": "10 single-use codes (8 random diceware chars) for account recovery. Stored hashed with Argon2id. Emergency use only."}',
     'AAL1', false, true, 'IMPLEMENTED',
     ARRAY['NIST SP 800-63B-4 §5.1.12', 'OWASP ASVS 2.10'], 130),

    ('security_questions',
     'A',
     '{"es": "Preguntas de seguridad (PROHIBIDO)", "en": "Security Questions (PROHIBITED)"}',
     '{"es": "ELIMINADO por NIST SP 800-63B-4 (agosto 2024) §5.1.1. Las respuestas son predecibles, adivinables mediante OSINT y reutilizables. bAuth no implementa este método. Ningún tenant puede activarlo.", "en": "ELIMINATED by NIST SP 800-63B-4 (August 2024) §5.1.1. Answers are predictable, guessable via OSINT and reusable. bAuth does not implement this method."}',
     'AAL1', false, false, 'REMOVED',
     ARRAY['NIST SP 800-63B-4 — ELIMINADO §5.1.1'], 199)

ON CONFLICT (code) DO UPDATE SET
    name        = EXCLUDED.name,
    description = EXCLUDED.description,
    status      = EXCLUDED.status,
    standards   = EXCLUDED.standards,
    sort_order  = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────────────────────────────────────
-- CATEGORÍA B — Posesión (algo que el usuario tiene)            (#6 al #20)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO bauth.auth_method
    (code, category, name, description, loa_provided, is_phishing_resistant, is_mfa_component, status, standards, sort_order)
VALUES
    ('totp',
     'B',
     '{"es": "TOTP — Contraseña de un solo uso basada en tiempo", "en": "TOTP — Time-based One-Time Password"}',
     '{"es": "Código de 6 dígitos cada 30 segundos (SHA-1/SHA-256/SHA-512). Compatible con Google Authenticator, Authy, 1Password. AAL2 como segundo factor.", "en": "6-digit code every 30 seconds (SHA-1/SHA-256/SHA-512). Compatible with Google Authenticator, Authy, 1Password. AAL2 as second factor."}',
     'AAL2', false, true, 'IMPLEMENTED',
     ARRAY['RFC 6238', 'NIST SP 800-63B-4 §5.1.4', 'OATH TOTP', 'OWASP ASVS 2.8'], 200),

    ('hotp',
     'B',
     '{"es": "HOTP — Contraseña de un solo uso basada en contador", "en": "HOTP — Counter-based One-Time Password"}',
     '{"es": "Código HMAC basado en contador incremental. Resincronización automática con ventana de 10 pasos. Compatible con hardware tokens (YubiKey OTP mode).", "en": "HMAC code based on incremental counter. Auto-resync with 10-step window. Compatible with hardware tokens (YubiKey OTP mode)."}',
     'AAL2', false, true, 'IMPLEMENTED',
     ARRAY['RFC 4226', 'NIST SP 800-63B-4 §5.1.4', 'OATH HOTP', 'OWASP ASVS 2.8'], 210),

    ('passkey',
     'B',
     '{"es": "WebAuthn / Passkey sincrónico", "en": "WebAuthn / Synced Passkey"}',
     '{"es": "Credencial FIDO2 descubrible sincronizada entre dispositivos (iCloud Keychain, Google Password Manager, 1Password). Origin-bound — resistente a phishing. AAL2 para synced; AAL3 con hardware-bound. Incluye modalidades passwordless y 2FA.", "en": "FIDO2 discoverable credential synced across devices (iCloud Keychain, Google Password Manager, 1Password). Origin-bound — phishing-resistant. AAL2 for synced; AAL3 with hardware-bound."}',
     'AAL2', true, false, 'IMPLEMENTED',
     ARRAY['W3C WebAuthn Level 3', 'FIDO2 Passkey', 'CTAP 2.2', 'NIST SP 800-63B-4 §5.1.7'], 220),

    ('fido2_security_key',
     'B',
     '{"es": "FIDO2 Llave de seguridad (hardware-bound)", "en": "FIDO2 Security Key (hardware-bound)"}',
     '{"es": "Autenticador FIDO2 con clave privada no exportable almacenada en chip seguro (YubiKey, Titan Key, NitroKey). sign_count verificado contra clonación. AAL2 con UV, AAL3 con PIN + UV.", "en": "FIDO2 authenticator with non-exportable private key in secure chip (YubiKey, Titan Key, NitroKey). sign_count verified against cloning. AAL2 with UV, AAL3 with PIN + UV."}',
     'AAL3', true, false, 'IMPLEMENTED',
     ARRAY['W3C WebAuthn Level 3', 'FIDO2', 'CTAP 2.2', 'NIST SP 800-63B-4 §5.1.7', 'FIPS 140-3'], 230),

    ('email_otp',
     'B',
     '{"es": "OTP por correo electrónico", "en": "Email OTP"}',
     '{"es": "Código de 6 dígitos enviado al correo verificado. TTL 10 minutos. Método restricted según NIST (requiere análisis de riesgo en AAL2). Usado como segundo factor o para usuarios EXT_N0.", "en": "6-digit code sent to verified email. TTL 10 minutes. Restricted per NIST (risk analysis required at AAL2). Used as second factor or for EXT_N0 users."}',
     'AAL1', false, true, 'IMPLEMENTED',
     ARRAY['NIST SP 800-63B-4 §5.1.3 (restricted)', 'OWASP ASVS 2.5'], 240),

    ('sms_otp',
     'B',
     '{"es": "OTP por SMS (deprecado — restricted)", "en": "SMS OTP (deprecated — restricted)"}',
     '{"es": "Código por SMS. DEPRECATED en NIST SP 800-63B-4 §5.1.3.3 por vulnerabilidad a SIM-swapping, SS7 hijacking y ataques de portabilidad. Solo disponible para tenants EXT_N0 con dispensa documentada y análisis de riesgo formal.", "en": "SMS code. DEPRECATED in NIST SP 800-63B-4 §5.1.3.3 due to SIM-swapping, SS7 hijacking and number portability attacks. Only for EXT_N0 tenants with documented waiver and formal risk analysis."}',
     'AAL1', false, true, 'DEPRECATED',
     ARRAY['NIST SP 800-63B-4 §5.1.3.3 (deprecated)', 'GSMA FS.11'], 249),

    ('push_challenge',
     'B',
     '{"es": "Push Challenge Ed25519 (autenticación móvil)", "en": "Ed25519 Push Challenge (mobile auth)"}',
     '{"es": "Challenge de 32 bytes firmado con Ed25519 por la app móvil bAuth. La clave privada no sale del dispositivo. Number matching implementado (00-99) contra push fatigue attacks. bNotify entrega el challenge. TTL 120 segundos.", "en": "32-byte challenge signed with Ed25519 by the bAuth mobile app. Private key never leaves device. Number matching implemented (00-99) against push fatigue. bNotify delivers the challenge. TTL 120 seconds."}',
     'AAL2', false, true, 'IMPLEMENTED',
     ARRAY['NIST SP 800-63B-4 §5.1.4 (Out-of-Band)', 'Ed25519 RFC 8032', 'OWASP ASVS 2.7'], 250),

    ('smartcard_piv',
     'B',
     '{"es": "Smart Card / PIV (FIPS 201)", "en": "Smart Card / PIV (FIPS 201)"}',
     '{"es": "Certificado PKI en tarjeta inteligente según FIPS 201-3 (PIV). mTLS valida el cert a nivel TLS; gap actual: sin validación PKIX completa (CRL/OCSP en tiempo real) ni verificación de PIN del titular. Prioritario para sector público boliviano.", "en": "PKI certificate on smart card per FIPS 201-3 (PIV). mTLS validates cert at TLS level; current gap: no full PKIX validation (real-time CRL/OCSP) or PIN verification."}',
     'AAL3', true, false, 'PLANNED',
     ARRAY['FIPS 201-3', 'NIST SP 800-73-4', 'RFC 5280 (PKIX)', 'NIST SP 800-63B-4 §5.1.9'], 260),

    ('hardware_otp_token',
     'B',
     '{"es": "Hardware OTP Token (OATH TOTP/HOTP físico)", "en": "Hardware OTP Token (OATH TOTP/HOTP physical)"}',
     '{"es": "Token físico OATH (YubiKey OATH, Feitian c200/c300, Safenet, Vasco). El secreto se carga en fábrica. Gap: el enrolamiento por serial de token no está implementado — bAuth necesita soporte YKOATH y enrolamiento sin QR.", "en": "Physical OATH token (YubiKey OATH, Feitian c200/c300, Safenet, Vasco). Secret loaded at factory. Gap: serial-based enrollment not implemented — bAuth needs YKOATH support without QR scan."}',
     'AAL2', false, true, 'PLANNED',
     ARRAY['OATH TOTP RFC 6238', 'OATH HOTP RFC 4226', 'OATH OCRA RFC 6287', 'NIST SP 800-63B-4 §5.1.4'], 270),

    ('magic_link',
     'B',
     '{"es": "Magic Link (URL de un solo uso)", "en": "Magic Link (single-use URL)"}',
     '{"es": "URL de un solo uso enviada por email con token aleatorio de 32 bytes y TTL 10 minutos. Mínima fricción para usuarios B2C (EXT_N0) que no tienen app de autenticación. Cada clic invalida el link.", "en": "Single-use URL sent by email with 32-byte random token, TTL 10 min. Minimal friction for B2C users (EXT_N0) without auth app. Each click invalidates the link."}',
     'AAL1', false, false, 'PLANNED',
     ARRAY['NIST SP 800-63B-4 §3.1.4 (OOB)', 'OWASP ASVS 2.3'], 280),

    ('qr_code_challenge',
     'B',
     '{"es": "QR Code Challenge (login web)", "en": "QR Code Challenge (web login)"}',
     '{"es": "El navegador PC genera un QR con challenge. La app bAuth en móvil escanea y firma con Ed25519. El servidor valida la firma y aprueba la sesión PC — sin escribir contraseña. Patrón usado por Telegram, WeChat, WhatsApp Web.", "en": "PC browser generates QR with challenge. bAuth mobile app scans and signs with Ed25519. Server validates signature and approves PC session — no password typing."}',
     'AAL2', false, false, 'PLANNED',
     ARRAY['NIST SP 800-63B-4 §5.1.4 (OOB)', 'Ed25519 RFC 8032'], 290),

    ('nfc_rfid',
     'B',
     '{"es": "NFC / RFID tap", "en": "NFC / RFID tap"}',
     '{"es": "Tag NFC/RFID cifrado con AES-256-GCM para autenticación. bhnexus ya lee tags para acceso físico (D2). Gap para login web: requiere app bAuth con NFC y challenge signing Ed25519.", "en": "NFC/RFID tag encrypted with AES-256-GCM for authentication. bhnexus already reads tags for physical access (D2). Gap for web login: requires bAuth app with NFC and Ed25519 challenge signing."}',
     'AAL2', false, false, 'PLANNED',
     ARRAY['ISO 14443', 'ISO 15693', 'NFC Forum Tag Types', 'FIDO CTAP 2.2'], 300),

    ('ble_proximity',
     'B',
     '{"es": "Bluetooth Low Energy (BLE) — proximidad", "en": "Bluetooth Low Energy (BLE) proximity"}',
     '{"es": "Autenticación por proximidad BLE. El dispositivo móvil con bAuth emite un beacon cifrado. El PC/lector valida la presencia del dispositivo autorizado en rango (<3m). Sin interacción del usuario.", "en": "BLE proximity authentication. Mobile device with bAuth emits encrypted beacon. PC/reader validates presence of authorized device within range (<3m). No user interaction."}',
     'AAL2', false, false, 'PLANNED',
     ARRAY['Bluetooth Core Spec 5.4', 'FIDO CTAP 2.2 (BLE transport)', 'NIST SP 800-63B-4 §5.1.4'], 310),

    ('wearable_auth',
     'B',
     '{"es": "Autenticación por wearable (smartwatch)", "en": "Wearable authentication (smartwatch)"}',
     '{"es": "El smartwatch (Apple Watch, Wear OS, Galaxy Watch) actúa como segundo factor mediante challenge Ed25519 o NFC tap. Requiere que el wearable esté desbloqueado (on-wrist detection).", "en": "Smartwatch (Apple Watch, Wear OS, Galaxy Watch) acts as second factor via Ed25519 challenge or NFC tap. Requires wearable to be unlocked (on-wrist detection)."}',
     'AAL2', false, true, 'PLANNED',
     ARRAY['FIDO CTAP 2.2', 'Ed25519 RFC 8032'], 320),

    ('x509_mtls',
     'B',
     '{"es": "Certificado X.509 — mTLS (RFC 8705)", "en": "X.509 Certificate — mTLS (RFC 8705)"}',
     '{"es": "Autenticación mutua TLS con certificado cliente X.509. CN + SHA-256 fingerprint verificados en tiempo constante. Emitido por PKI interna (Vault PKI) o ADSIB Bolivia (Ley 164). Criptográficamente vinculado a la sesión TLS 1.3 (RFC 8705). AAL3.", "en": "Mutual TLS with X.509 client certificate. CN + SHA-256 fingerprint verified in constant time. Issued by internal PKI (Vault PKI) or ADSIB Bolivia (Law 164). Cryptographically bound to TLS 1.3 session (RFC 8705). AAL3."}',
     'AAL3', true, false, 'IMPLEMENTED',
     ARRAY['RFC 5280 (PKIX)', 'RFC 8705 (mTLS binding)', 'NIST SP 800-63B-4 §5.1.9', 'TLS 1.3 RFC 8446', 'ADSIB-FD-POLT-015 v2.3', 'Ley 164 Bolivia'], 330)

ON CONFLICT (code) DO UPDATE SET
    name        = EXCLUDED.name,
    description = EXCLUDED.description,
    status      = EXCLUDED.status,
    standards   = EXCLUDED.standards,
    sort_order  = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────────────────────────────────────
-- CATEGORÍA C — Inherencia (algo que el usuario es)             (#21 al #28)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO bauth.auth_method
    (code, category, name, description, loa_provided, is_phishing_resistant, is_mfa_component, status, standards, sort_order)
VALUES
    ('fingerprint',
     'C',
     '{"es": "Huella digital (fingerprint)", "en": "Fingerprint biometric"}',
     '{"es": "bAuth almacena SHA-256 del template biométrico; la validación ocurre en bhnexus (hardware). El raw biométrico nunca llega al servidor. Gap: no existe fingerprint.rs como AuthMethod independiente — se procesa como precondición NFC/OSDP. Sin liveness detection (ISO 30107-3 PAD).", "en": "bAuth stores SHA-256 of biometric template; validation occurs in bhnexus (hardware). Raw biometric never reaches server. Gap: no fingerprint.rs as independent AuthMethod — processed as NFC/OSDP precondition. No liveness detection."}',
     'AAL2', false, true, 'PLANNED',
     ARRAY['NIST SP 800-63B-4 §5.2.3', 'ISO/IEC 30107-3:2023 (PAD)', 'GDPR Art. 9'], 400),

    ('face_recognition',
     'C',
     '{"es": "Reconocimiento facial", "en": "Face recognition"}',
     '{"es": "Procesamiento NO en bAuth Core (principio de no almacenar biométricos en servidor central). bAuth actúa como orquestador: delega verificación al motor biométrico (edge/proveedor) y recibe solo el resultado (match: bool, score: float, liveness: bool). GDPR Art. 9 exige consentimiento explícito.", "en": "Processing NOT in bAuth Core (no-biometric-in-central-server principle). bAuth acts as orchestrator: delegates to biometric engine (edge/provider) and receives only result (match: bool, score: float, liveness: bool). GDPR Art. 9 requires explicit consent."}',
     'AAL2', false, false, 'PLANNED',
     ARRAY['ISO/IEC 19794-5:2011', 'NIST FRVT', 'GDPR Art. 9', 'eIDAS 2.0 §12'], 410),

    ('iris_scan',
     'C',
     '{"es": "Escaneo de iris / retina", "en": "Iris / retina scan"}',
     '{"es": "Biometría ocular de alta precisión. AAL3 por la naturaleza única y no modificable del iris. Requiere hardware especializado (scanner óptico). Mismo principio de orquestación que reconocimiento facial — el template nunca llega a bAuth.", "en": "High-precision ocular biometrics. AAL3 due to unique and non-modifiable nature of iris. Requires specialized hardware (optical scanner). Same orchestration principle as face recognition."}',
     'AAL3', false, false, 'PLANNED',
     ARRAY['ISO/IEC 19794-6 (iris)', 'NIST SP 800-76-2', 'NIST SP 800-63B-4 §5.2.3'], 420),

    ('voice_recognition',
     'C',
     '{"es": "Reconocimiento de voz", "en": "Voice recognition"}',
     '{"es": "Biometría de voz — patrón acústico del usuario. Sensible a ruido ambiental, enfermedad y envejecimiento. Se usa combinado con frase de paso específica para minimizar replay attacks. Solo como factor adicional.", "en": "Voice biometrics — user acoustic pattern. Sensitive to ambient noise, illness and aging. Used combined with specific passphrase to minimize replay attacks. Only as additional factor."}',
     'AAL2', false, true, 'PLANNED',
     ARRAY['NIST SP 800-63B-4 §5.2.3', 'ISO/IEC 19794-13 (voice)'], 430),

    ('palm_vein',
     'C',
     '{"es": "Escáner de vena palmar (palm vein)", "en": "Palm vein scanner"}',
     '{"es": "Patrón de venas de la palma mediante luz infrarroja. Alta precisión, anti-spoof natural (las venas son subcutáneas). Usado en banca japonesa y sistemas de alta seguridad. Require scanner IR dedicado.", "en": "Palm vein pattern via infrared light. High accuracy, natural anti-spoof (veins are subcutaneous). Used in Japanese banking and high-security systems. Requires dedicated IR scanner."}',
     'AAL3', false, false, 'PLANNED',
     ARRAY['Fujitsu PalmSecure standard', 'NIST SP 800-63B-4 §5.2.3'], 440),

    ('behavioral_keystroke',
     'C',
     '{"es": "Biometría conductual — dinámica de teclado (keystroke dynamics)", "en": "Behavioral biometrics — keystroke dynamics"}',
     '{"es": "Análisis del patrón de tecleo: tiempo entre pulsaciones, duración de cada tecla, velocidad. El modelo ML aprende el patrón del usuario. Se usa como factor adicional silencioso en autenticación continua.", "en": "Keystroke pattern analysis: inter-key timing, key duration, speed. ML model learns user pattern. Used as silent additional factor in continuous authentication."}',
     'AAL2', false, true, 'PLANNED',
     ARRAY['IEEE 11377740', 'NIST SP 800-63B-4 §5.2.3', 'GDPR Art. 9'], 450),

    ('behavioral_mouse',
     'C',
     '{"es": "Biometría conductual — dinámica de ratón / touchpad", "en": "Behavioral biometrics — mouse / touchpad dynamics"}',
     '{"es": "Análisis de movimientos del ratón y touchpad: aceleración, curvas, velocidad de clic. Complementa keystroke dynamics. Invisible para el usuario — se activa en background durante la sesión.", "en": "Mouse and touchpad movement analysis: acceleration, curves, click speed. Complements keystroke dynamics. Invisible to user — activates in background during session."}',
     'AAL2', false, true, 'PLANNED',
     ARRAY['IEEE 11377740', 'NIST SP 800-63B-4 §5.2.3'], 460),

    ('behavioral_continuous',
     'C',
     '{"es": "Biometría conductual continua (AI/ML)", "en": "Continuous behavioral biometrics (AI/ML)"}',
     '{"es": "Modelo AI/ML que evalúa continuamente el comportamiento del usuario durante toda la sesión (keystroke + mouse + scroll + ritmo de trabajo). Si el score cae bajo umbral → step-up o terminación de sesión. Alineado con Zero Trust NIST 800-207.", "en": "AI/ML model that continuously evaluates user behavior during the entire session. If score drops below threshold → step-up or session termination. Aligned with Zero Trust NIST 800-207."}',
     'AAL2', false, true, 'PLANNED',
     ARRAY['NIST SP 800-207 §3.2', 'IEEE 11377740', 'NIST SP 800-63B-4 §5.2.3', 'GDPR Art. 9'], 470)

ON CONFLICT (code) DO UPDATE SET
    name        = EXCLUDED.name,
    description = EXCLUDED.description,
    status      = EXCLUDED.status,
    standards   = EXCLUDED.standards,
    sort_order  = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────────────────────────────────────
-- CATEGORÍA D — Federación e identidad externa                  (#29 al #34)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO bauth.auth_method
    (code, category, name, description, loa_provided, is_phishing_resistant, is_mfa_component, status, standards, sort_order)
VALUES
    ('saml2',
     'D',
     '{"es": "SAML 2.0 Federado (SP)", "en": "SAML 2.0 Federated (SP)"}',
     '{"es": "Autenticación federada SAML 2.0. bAuth actúa como Service Provider. El LoA se infiere del AuthnContextClassRef del assertion. Integración con IdP corporativos (AD FS, Shibboleth, PingFederate).", "en": "SAML 2.0 federated authentication. bAuth acts as Service Provider. LoA inferred from AuthnContextClassRef. Integration with corporate IdPs (AD FS, Shibboleth, PingFederate)."}',
     'AAL2', false, false, 'IMPLEMENTED',
     ARRAY['SAML 2.0 OASIS', 'NIST SP 800-63C-4', 'eIDAS 2.0'], 500),

    ('oidc_social',
     'D',
     '{"es": "OIDC Social Login — brokering de IdP externo", "en": "OIDC Social Login — external IdP brokering"}',
     '{"es": "Autenticación delegada a IdP externo (Google, Apple, GitHub, Microsoft, LinkedIn). El LoA depende del IdP — máximo AAL1 sin acuerdo de trust formal. bAuth actúa como SP OIDC. Solo para tenants EXT_N0.", "en": "Authentication delegated to external IdP (Google, Apple, GitHub, Microsoft, LinkedIn). LoA depends on IdP — AAL1 max without formal trust agreement. bAuth acts as OIDC SP. Only for EXT_N0 tenants."}',
     'AAL1', false, false, 'PLANNED',
     ARRAY['OpenID Connect Core 1.0', 'OAuth 2.0 RFC 6749', 'NIST SP 800-63C-4'], 510),

    ('kerberos_spnego',
     'D',
     '{"es": "Kerberos v5 / SPNEGO (SSO corporativo)", "en": "Kerberos v5 / SPNEGO (corporate SSO)"}',
     '{"es": "Autenticación Kerberos v5 para entornos Active Directory / LDAP. SPNEGO permite negociación automática. SSO transparente en redes corporativas Windows. Requiere integración con KDC (Key Distribution Center).", "en": "Kerberos v5 authentication for Active Directory / LDAP environments. SPNEGO allows automatic negotiation. Transparent SSO on Windows corporate networks. Requires KDC integration."}',
     'AAL2', false, false, 'PLANNED',
     ARRAY['RFC 4120 (Kerberos)', 'RFC 4178 (SPNEGO)', 'NIST SP 800-63B-4 §5.1.9'], 520),

    ('ldap',
     'D',
     '{"es": "LDAP — autenticación directa (bind)", "en": "LDAP — direct authentication (bind)"}',
     '{"es": "Autenticación directa contra directorio LDAP (OpenLDAP, Active Directory) mediante operación bind. Requiere conexión LDAPS (TLS). Usado para migración de sistemas legacy que no soportan OIDC/SAML.", "en": "Direct authentication against LDAP directory (OpenLDAP, Active Directory) via bind operation. Requires LDAPS (TLS). Used for migrating legacy systems that do not support OIDC/SAML."}',
     'AAL1', false, false, 'PLANNED',
     ARRAY['RFC 4511 (LDAPv3)', 'RFC 4513 (LDAP Auth)', 'NIST SP 800-63B-4'], 530),

    ('wia',
     'D',
     '{"es": "Windows Integrated Authentication (WIA / NTLM / Negotiate)", "en": "Windows Integrated Authentication (WIA / NTLM / Negotiate)"}',
     '{"es": "Autenticación integrada Windows usando credenciales del sistema operativo (NTLM o Kerberos según disponibilidad). Transparente para el usuario en intranet corporativa. Solo para tenants en dominio Windows.", "en": "Windows integrated authentication using OS credentials (NTLM or Kerberos as available). Transparent for users on corporate intranet. Only for tenants on Windows domain."}',
     'AAL2', false, false, 'PLANNED',
     ARRAY['NTLM MS-NLMP', 'RFC 4178 (SPNEGO)', 'NIST SP 800-63B-4'], 540),

    ('scim',
     'D',
     '{"es": "SCIM 2.0 — Provisioning con autenticación delegada", "en": "SCIM 2.0 — Provisioning with delegated authentication"}',
     '{"es": "SCIM 2.0 (RFC 7644) para sincronización bidireccional de identidades entre bAuth y directorios externos (AD, HR systems). La autenticación de la operación SCIM usa Bearer token OAuth 2.0 emitido por bAuth. El proceso provisioning en sí no es un método de autenticación de usuario final.", "en": "SCIM 2.0 (RFC 7644) for bidirectional identity sync between bAuth and external directories (AD, HR systems). SCIM operation authentication uses OAuth 2.0 Bearer token issued by bAuth."}',
     'AAL1', false, false, 'IMPLEMENTED',
     ARRAY['RFC 7644 (SCIM 2.0)', 'RFC 7643 (SCIM Schema)', 'OAuth 2.0 RFC 6749'], 550)

ON CONFLICT (code) DO UPDATE SET
    name        = EXCLUDED.name,
    description = EXCLUDED.description,
    status      = EXCLUDED.status,
    standards   = EXCLUDED.standards,
    sort_order  = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────────────────────────────────────
-- CATEGORÍA E — Flujos especiales y contexto                    (#35 al #43)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO bauth.auth_method
    (code, category, name, description, loa_provided, is_phishing_resistant, is_mfa_component, status, standards, sort_order)
VALUES
    ('ciba',
     'E',
     '{"es": "CIBA — Autenticación en canal de retorno iniciada por cliente", "en": "CIBA — Client-Initiated Backchannel Authentication"}',
     '{"es": "El cliente (back-end) solicita autenticación del usuario sin redireccionamiento. El usuario aprueba en su dispositivo mediante push challenge. Definido en OpenID CIBA 1.0 y FAPI 2.0. Usado en banca (PSD2), call centers y flujos desacoplados.", "en": "Client (back-end) requests user authentication without redirect. User approves on their device via push challenge. Defined in OpenID CIBA 1.0 and FAPI 2.0. Used in banking (PSD2), call centers and decoupled flows."}',
     'AAL2', false, false, 'PLANNED',
     ARRAY['OpenID CIBA 1.0', 'FAPI 2.0 Security Profile', 'NIST SP 800-63B-4'], 600),

    ('step_up',
     'E',
     '{"es": "Step-Up Authentication — elevación de LoA (RFC 9470)", "en": "Step-Up Authentication — LoA elevation (RFC 9470)"}',
     '{"es": "Mecanismo para elevar el nivel de aseguramiento durante una sesión activa. Cuando un recurso requiere AAL3 y la sesión es AAL2, bAuth fuerza re-autenticación con método de mayor garantía. ses_session_log.step_up_valid_until registra la ventana temporal (TTL configurable).", "en": "Mechanism to elevate assurance level during an active session. When a resource requires AAL3 and session is AAL2, bAuth forces re-authentication with higher assurance method. step_up_valid_until records the temporal window."}',
     'AAL3', false, false, 'IMPLEMENTED',
     ARRAY['RFC 9470 (Step-Up)', 'OpenID Connect Core 1.0 §3.1.2.1', 'NIST SP 800-63B-4 §7.3'], 610),

    ('device_auth_grant',
     'E',
     '{"es": "Device Authorization Grant — dispositivos sin navegador (RFC 8628)", "en": "Device Authorization Grant — browserless devices (RFC 8628)"}',
     '{"es": "OAuth 2.0 Device Authorization Grant para dispositivos sin navegador (Smart TV, CLI, IoT, Arduino). El dispositivo obtiene un user_code y device_code. El usuario lo ingresa en otro dispositivo con navegador. Polling del dispositivo hasta aprobación.", "en": "OAuth 2.0 Device Authorization Grant for browserless devices (Smart TV, CLI, IoT, Arduino). Device gets user_code and device_code. User enters it on another device with browser. Device polls until approved."}',
     'AAL1', false, false, 'PLANNED',
     ARRAY['RFC 8628 (Device Grant)', 'OAuth 2.0 RFC 6749', 'NIST SP 800-63B-4'], 620),

    ('token_exchange',
     'E',
     '{"es": "Token Exchange — delegación e impersonación (RFC 8693)", "en": "Token Exchange — delegation and impersonation (RFC 8693)"}',
     '{"es": "OAuth 2.0 Token Exchange para delegar o impersonar identidades entre servicios internos SBOS. grant_type=urn:ietf:params:oauth:grant-type:token-exchange. Usado por daemons que necesitan actuar en nombre de un usuario o en su propio nombre con scope reducido.", "en": "OAuth 2.0 Token Exchange for delegating or impersonating identities between SBOS internal services. Used by daemons acting on behalf of a user or in their own name with reduced scope."}',
     'AAL1', false, false, 'PLANNED',
     ARRAY['RFC 8693 (Token Exchange)', 'OAuth 2.0 RFC 6749', 'NIST SP 800-63B-4'], 630),

    ('dpop',
     'E',
     '{"es": "DPoP — Prueba de posesión de clave (RFC 9449)", "en": "DPoP — Demonstration of Proof of Possession (RFC 9449)"}',
     '{"es": "Mecanismo de binding criptográfico que vincula un token OAuth 2.0 a la clave privada del cliente. Cada request lleva un DPoP proof JWT firmado con la clave privada. Previene replay de tokens robados. fed_token_issued.dpop_jkt almacena el thumbprint de la clave.", "en": "Cryptographic binding mechanism that ties an OAuth 2.0 token to the client private key. Each request carries a DPoP proof JWT signed with private key. Prevents replay of stolen tokens. dpop_jkt stores the key thumbprint."}',
     'AAL2', true, false, 'PLANNED',
     ARRAY['RFC 9449 (DPoP)', 'FAPI 2.0 Security Profile', 'NIST SP 800-63B-4'], 640),

    ('risk_based',
     'E',
     '{"es": "Autenticación adaptativa / Risk-based (contextual)", "en": "Adaptive / Risk-based authentication (contextual)"}',
     '{"es": "El motor de riesgo (ses_risk_policy T-180) evalúa IP, dispositivo, horario, geolocalización y comportamiento. Si el score supera el umbral → solicita segundo factor o eleva a step-up. Si el score es bajo → permite flujo sin fricción. Subcaso: OTP condicional (solo en detección de anomalía).", "en": "Risk engine (ses_risk_policy T-180) evaluates IP, device, time, geolocation and behavior. High score → requests second factor or step-up. Low score → frictionless flow. Subcase: conditional OTP (only on anomaly detection)."}',
     'AAL2', false, false, 'PLANNED',
     ARRAY['NIST SP 800-63B-4 §7.3', 'NIST SP 800-53 IA-8', 'NIST SP 800-207 §3.2'], 650),

    ('continuous_auth',
     'E',
     '{"es": "Autenticación continua de sesión (Zero Trust)", "en": "Continuous session authentication (Zero Trust)"}',
     '{"es": "Evaluación periódica de la sesión activa usando señales de contexto (CAEP/SSF): cambio de IP, cambio de dispositivo, anomalía de comportamiento, revocación de credencial. Si la confianza cae → step-up o terminación de sesión. Pilar del modelo Zero Trust.", "en": "Periodic evaluation of active session using context signals (CAEP/SSF): IP change, device change, behavioral anomaly, credential revocation. Trust degradation → step-up or session termination. Zero Trust pillar."}',
     'AAL2', false, false, 'PLANNED',
     ARRAY['NIST SP 800-207 §3.2', 'OpenID CAEP 1.0', 'RFC 8935/8936 (SSF)', 'NIST SP 800-63B-4 §7'], 660),

    ('liveness_detection',
     'E',
     '{"es": "Detección de liveness (IA anti-spoof)", "en": "Liveness detection (AI anti-spoof)"}',
     '{"es": "Verificación de que el biométrico proviene de una persona viva (no foto, video o máscara). Componente ortogonal a los métodos biométricos. Se activa antes de fingerprint, face_recognition e iris_scan. ISO 30107-3 PAD Nivel 1 obligatorio para AAL2, Nivel 2 para AAL3.", "en": "Verification that biometric comes from a live person (not photo, video or mask). Orthogonal component to biometric methods. Activates before fingerprint, face_recognition and iris_scan. ISO 30107-3 PAD Level 1 required for AAL2, Level 2 for AAL3."}',
     'AAL2', false, false, 'PLANNED',
     ARRAY['ISO/IEC 30107-3:2023 (PAD)', 'NIST SP 800-63B-4 §5.2.3', 'FIDO Biometric Requirements'], 670),

    ('silent_ambient',
     'E',
     '{"es": "Autenticación silenciosa / ambiente (BLE+NFC geofencing)", "en": "Silent / ambient authentication (BLE+NFC geofencing)"}',
     '{"es": "Autenticación sin interacción del usuario basada en presencia de dispositivo autorizado en zona geofenced (BLE o NFC). Nivel mínimo de garantía — se usa solo para recursos de bajo riesgo o como señal de contexto en autenticación adaptativa.", "en": "User-interaction-free authentication based on authorized device presence in geofenced zone (BLE or NFC). Minimum assurance level — used only for low-risk resources or as context signal in adaptive authentication."}',
     'AAL1', false, false, 'PLANNED',
     ARRAY['NIST SP 800-207 §3.2', 'Bluetooth Core Spec 5.4', 'NIST SP 800-63B-4'], 680)

ON CONFLICT (code) DO UPDATE SET
    name        = EXCLUDED.name,
    description = EXCLUDED.description,
    status      = EXCLUDED.status,
    standards   = EXCLUDED.standards,
    sort_order  = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────────────────────────────────────
-- CATEGORÍA F — Identidad descentralizada y emergente           (#44 al #47)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO bauth.auth_method
    (code, category, name, description, loa_provided, is_phishing_resistant, is_mfa_component, status, standards, sort_order)
VALUES
    ('did_vc',
     'F',
     '{"es": "W3C DID + Verifiable Credentials", "en": "W3C DID + Verifiable Credentials"}',
     '{"es": "Autenticación mediante identidad descentralizada (DID) y presentación de Credenciales Verificables (VC) firmadas. El usuario controla su wallet de identidad — no hay repositorio central. Compatible con eIDAS 2.0. bAuth actúa como Verifier de VCs.", "en": "Authentication via Decentralized Identifier (DID) and signed Verifiable Credential (VC) presentation. User controls their identity wallet — no central repository. Compatible with eIDAS 2.0. bAuth acts as VC Verifier."}',
     'AAL2', true, false, 'PLANNED',
     ARRAY['W3C DID Core 1.0', 'W3C VC Data Model 2.0', 'OpenID4VP', 'eIDAS 2.0 ARF'], 700),

    ('eidas_wallet',
     'F',
     '{"es": "eIDAS 2.0 Wallet — EUDIW", "en": "eIDAS 2.0 Wallet — EUDIW"}',
     '{"es": "European Union Digital Identity Wallet (eIDAS 2.0 Art. 5a). Todos los estados UE deben desplegar wallets antes de fin 2026. bAuth actúa como Relying Party: acepta presentaciones de VC del EUDIW usando el protocolo OpenID4VP. Para clientes europeos de SBOS.", "en": "European Union Digital Identity Wallet (eIDAS 2.0 Art. 5a). All EU states must deploy wallets by end 2026. bAuth acts as Relying Party: accepts EUDIW VC presentations using OpenID4VP protocol. For European SBOS clients."}',
     'AAL2', true, false, 'PLANNED',
     ARRAY['eIDAS 2.0 Regulation', 'OpenID4VP', 'W3C VC Data Model 2.0', 'ISO/IEC 18013-5 (mDL)'], 710),

    ('blockchain_did',
     'F',
     '{"es": "Blockchain Identity — DID:ethr / DID:key", "en": "Blockchain Identity — DID:ethr / DID:key"}',
     '{"es": "Identidad auto-soberana anclada en blockchain (Ethereum, Hyperledger). La clave pública es pública y verificable on-chain. ECDSA o Ed25519 para firma. En SBOS el dominio blockchain es Besu (cliente Hyperledger) — bAuth ya consulta a Besu para ECDSA.", "en": "Self-sovereign identity anchored on blockchain (Ethereum, Hyperledger). Public key is public and verifiable on-chain. ECDSA or Ed25519 for signing. In SBOS the blockchain domain is Besu (Hyperledger client) — bAuth already consults Besu for ECDSA."}',
     'AAL2', true, false, 'PLANNED',
     ARRAY['W3C DID Core 1.0', 'did:ethr method', 'EIP-1056', 'Hyperledger Besu'], 720),

    ('post_quantum',
     'F',
     '{"es": "Criptografía post-cuántica — ML-KEM / ML-DSA (FIPS 203/204)", "en": "Post-quantum cryptography — ML-KEM / ML-DSA (FIPS 203/204)"}',
     '{"es": "Preparación para la era post-cuántica. ML-KEM (FIPS 203 — intercambio de claves) y ML-DSA (FIPS 204 — firma digital) reemplazan RSA y ECDSA ante ataques de computación cuántica. harvest-now-decrypt-later ya es amenaza real. bAuth debe migrar PKI a algoritmos híbridos (clásico + PQC).", "en": "Post-quantum era preparation. ML-KEM (FIPS 203 — key encapsulation) and ML-DSA (FIPS 204 — digital signature) replace RSA and ECDSA against quantum computing attacks. Harvest-now-decrypt-later is already a real threat."}',
     'AAL3', true, false, 'PLANNED',
     ARRAY['FIPS 203 (ML-KEM)', 'FIPS 204 (ML-DSA)', 'NIST SP 800-208', 'NIST IR 8413', 'CNSA 2.0'], 730)

ON CONFLICT (code) DO UPDATE SET
    name        = EXCLUDED.name,
    description = EXCLUDED.description,
    status      = EXCLUDED.status,
    standards   = EXCLUDED.standards,
    sort_order  = EXCLUDED.sort_order;

-- ─────────────────────────────────────────────────────────────────────────────
-- Verificación final
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
    category,
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE status = 'IMPLEMENTED') AS implementados,
    COUNT(*) FILTER (WHERE status = 'PLANNED')     AS planificados,
    COUNT(*) FILTER (WHERE status = 'DEPRECATED')  AS deprecados,
    COUNT(*) FILTER (WHERE status = 'REMOVED')     AS eliminados
FROM bauth.auth_method
GROUP BY category
ORDER BY category;

SELECT
    'TOTAL auth_method: ' || COUNT(*) ||
    ' — IMPLEMENTED: ' || COUNT(*) FILTER (WHERE status = 'IMPLEMENTED') ||
    ' — PLANNED: '     || COUNT(*) FILTER (WHERE status = 'PLANNED') ||
    ' — DEPRECATED: '  || COUNT(*) FILTER (WHERE status = 'DEPRECATED') ||
    ' — REMOVED: '     || COUNT(*) FILTER (WHERE status = 'REMOVED')
    AS resumen
FROM bauth.auth_method;
