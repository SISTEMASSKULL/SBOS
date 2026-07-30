# BAUTH-VALIDADORES-POR-METODO.md — Quién Valida Cada Método (Corregido)

**Versión:** 2.0 · **Fecha:** 2026-06-25
**Corrección:** bAuth NO valida métodos de autenticación. bAuth ADMINISTRA y ORQUESTA.
**Pregunta correcta:** ¿Qué aplicación valida en runtime cada método de autenticación?

---

## 0. ROL DE CADA APLICACIÓN — CORRECCIÓN

| Aplicación | Rol REAL | ¿Valida métodos de autenticación? |
|-----------|---------|:---:|
| **bAuth** | **ADMINISTRADOR + ORQUESTADOR.** BitMask engine (átomos), Policy engine (políticas + configs), sync engine (KC+Tryton), context evaluation (12 dominios). | ❌ NO |
| **Keycloak** | **IDENTITY PROVIDER.** Valida credenciales digitales, emite JWT, gestiona sesiones. | ✅ SÍ — 23 métodos digitales |
| **Tryton** | **AUTHORIZATION ENGINE (5 capas).** ir.model.access, ir.rule, ir.model.button, ir.model.field, ir.action.groups. | ✅ SÍ — 5 capas de autorización ERP |
| **bhnexus** | **PHYSICAL ENFORCEMENT POINT.** Lee hardware, ejecuta ALLOW/DENY de bAuth. | ✅ SÍ — 9 tipos de dispositivos físicos |
| **Vault** | **SECRETS MANAGER.** Protege claves criptográficas. Sin Vault, Keycloak no puede firmar JWT ni Kong validar mTLS. | ❌ NO — provee claves, no valida |
| **Kong** | **API GATEWAY.** Valida JWT en cada request, rate limiting, inyección de headers de contexto. | ✅ SÍ — valida acceso a APIs |
| **Besu QBFT** | **BLOCKCHAIN ANCHOR (D12).** Valida Merkle proofs on-chain, DID resolution. | ✅ SÍ — 2 métodos blockchain |
| **Dispositivo** | **LOCAL BIOMETRIC VERIFIER.** Secure Enclave/TPM/TEE del celular/laptop. | ✅ SÍ — biometría local + attestation |

---

## 1. KEYCLOAK — Identity Provider: 23 métodos digitales

Keycloak es el ÚNICO Identity Provider del SBOS. Todo método de autenticación digital
pasa por Keycloak. Nadie más valida passwords, OTPs, WebAuthn ni tokens federados.

| # | Método | Qué valida Keycloak |
|---|--------|---------------------|
| 1 | PASSWORD | Hash Argon2id contra credential table. Aplica password policy (NIST 800-63B-4). |
| 2 | TOTP | OTP contra shared secret (RFC 6238). Ventana ±1 paso. |
| 3 | HOTP | OTP contra contador (RFC 4226). Look-ahead window 5. |
| 4 | EMAIL_OTP | Código 6 dígitos enviado por SMTP. Verifica al recibirlo. |
| 5 | SMS_OTP | Código enviado vía Twilio/SPI. ⚠️ Deprecado NIST Rev.4. |
| 6 | WEBAUTHN_PWDLESS | Firma challenge con clave privada. Verifica con clave pública (FIDO2). |
| 7 | WEBAUTHN_2FA | Igual, como segundo factor. Non-discoverable credential. |
| 8 | PASSKEY_SYNCED | WebAuthn con synced credential (iCloud/Google). KC verifica firma. |
| 9 | PASSKEY_DEVICE | WebAuthn device-bound (FIPS 140-3). KC verifica firma + attestation. |
| 10 | SMARTCARD_X509 | Cadena X.509. KC valida certificado no revocado. |
| 11 | OAUTH2_AUTH_CODE | Authorization Code + PKCE. KC valida client_id + redirect_uri. |
| 12 | CLIENT_CREDENTIALS (M2M) | client_id + client_secret. KC emite access token. |
| 13 | OIDC_HYBRID | OpenID Connect. KC valida ID token + access token. |
| 14 | SAML2_POST | SAML Assertion. KC valida firma XML + condiciones. |
| 15 | CIBA | Decoupled auth. KC envía push al dispositivo, espera confirmación. |
| 16 | TOKEN_EXCHANGE | Intercambia tokens (RFC 8693). KC valida subject_token. |
| 17 | BACKUP_CODES | Hash SHA-256. Un solo uso. KC compara contra 10 hashes. |
| 18 | RECOVERY_EMAIL | Enlace de recuperación. KC verifica email ownership. |
| 19 | STEP_UP_CONDITIONAL | **bAuth evalúa condición** (amount > 5000) → **KC ejecuta auth step-up** (AAL3). |
| 20 | RISK_BASED_AUTH | **bAuth calcula risk score** (ses_ses_risk_policy) → **KC aplica acción** (allow/step_up/deny). |
| 21 | BASIC_AUTH | HTTP Basic. KC valida contra BD. ⚠️ Deprecado. |
| 22 | BEARER_TOKEN_STATIC | Token estático. KC valida en BD. ⚠️ Deprecado. |
| 23 | PUSH_NOTIFICATION | FCM/APNs push. SPI custom en KC. Usuario aprueba en app. |

**Keycloak cubre: passwords, OTPs, WebAuthn/Passkeys, PKI, OAuth2/OIDC/SAML, CIBA, recovery, deprecated.**

---

## 2. KEYCLOAK NO CUBRE — ¿Quién los valida?

### 2.1 TRYTON — 5 Capas de Autorización ERP

Tryton NO autentica usuarios (eso lo hace Keycloak). Pero Tryton tiene su propio
motor de autorización de 5 capas que valida CADA operación dentro del ERP.

| Capa | Mecanismo | Qué valida Tryton |
|:---:|-----------|-------------------|
| **1** | `ir.model.access` | ¿Puede este usuario/grupo LEER/CREAR/ESCRIBIR/ELIMINAR este modelo? (ej: sale.order) |
| **2** | `ir.rule` (Record Rules) | ¿Qué REGISTROS puede ver? Filtro SQL automático: `[('shop.region','=',user.region)]` |
| **3** | `ir.model.button` (Button Rules) | ¿Puede ejecutar este BOTÓN? Condición PYSON: `amount_total <= 5000` |
| **4** | `ir.model.field` (Field Access) | ¿Qué CAMPOS ve y edita? `margin: read=false, write=false` |
| **5** | `ir.action.groups` (Menu Visibility) | ¿Qué MENÚS y ACCIONES ve en la UI? |

**bAuth provee la configuración.** Tryton la ejecuta en runtime.

### 2.2 bhnexus — 9 Dispositivos Físicos

bhnexus es el ENFORCEMENT POINT para acceso físico. Lee hardware, consulta a bAuth,
ejecuta ALLOW/DENY.

| # | Método físico | Qué hace bhnexus | Quién decide ALLOW/DENY |
|---|--------------|-----------------|----------------------|
| 1 | NFC (DESFIRE/Classic) | Lee tarjeta, envía UID a bAuth | bAuth (zona + horario + anti-passback) |
| 2 | RFID 125KHz (Wiegand) | Lee proximidad, envía facility+card | bAuth |
| 3 | QR Dinámico | Muestra QR, recibe ctx_id firmado del celular | bAuth (firma + TTL + anti-replay) |
| 4 | Huella Dactilar | Lector captura, bhnexus recibe hash | bAuth (compara Argon2id + liveness + zona) |
| 5 | Rostro 3D | Cámara 3D captura, bhnexus envía hash | bAuth (compara Argon2id + liveness active) |
| 6 | Iris | Lector NIR captura, bhnexus envía hash | bAuth (compara Argon2id + liveness combined) |
| 7 | Smartcard X.509 | bhnexus lee certificado | bAuth (valida cadena + zona + LoA) |
| 8 | PIN Pad | bhnexus captura PIN | bAuth (compara hash, siempre combinado) |
| 9 | Cámara + Sensor | ONVIF streaming, detección movimiento | bAuth (alerta + audit_event) |

**bhnexus es el hardware bridge. bAuth es el cerebro que decide.**

### 2.3 BESU QBFT — 2 Métodos Blockchain (D12)

| # | Método | Qué valida Besu |
|---|--------|----------------|
| 1 | MERKLE_ANCHOR | Smart contract en Arbitrum L2 almacena Merkle root. Besu ejecuta el contrato. Terceros verifican proof sin acceso a la BD. |
| 2 | DID | Smart contract EIP-725 (Identity) + EIP-735 (Claims). Besu resuelve el DID Document on-chain y valida que la firma corresponde al controller. |

### 2.4 DISPOSITIVO DEL USUARIO — 6 Verificaciones Locales

Estas verificaciones ocurren EN el dispositivo. El servidor solo recibe el resultado.

| # | Verificación | Dónde | Qué hace |
|---|-------------|-------|---------|
| 1 | TOUCH_ID | Secure Enclave (Apple) | Captura huella, compara localmente, desbloquea clave privada |
| 2 | FACE_ID | Secure Enclave + Neural Engine | Captura rostro 3D, compara localmente, desbloquea clave |
| 3 | WINDOWS_HELLO | TPM 2.0 (Microsoft) | Captura huella/rostro, compara en TPM, desbloquea clave |
| 4 | ANDROID_BIOMETRIC | TEE (Android) | Captura huella/rostro, compara en Trusted Execution Environment |
| 5 | PLAY_INTEGRITY | Google Play Services | Evalúa integridad → emite token → **bAuth verifica token server-side** |
| 6 | APP_ATTEST | Apple Secure Enclave | Genera attestation → **bAuth verifica cadena X.509 server-side** |

### 2.5 KONG — 6 Validaciones de API Gateway

| # | Validación | Qué hace Kong |
|---|-----------|--------------|
| 1 | JWT Signature | Verifica firma del token contra clave pública de Keycloak |
| 2 | JWT Expiry | Rechaza tokens con exp vencido |
| 3 | Rate Limiting | 100 req/s por IP. 429 con Retry-After |
| 4 | OIDC | Redirige a Keycloak si no hay token. Valida aud, iss, exp |
| 5 | ACL | Verifica consumer (rol/grupo) tiene acceso a la ruta |
| 6 | mTLS | Exige certificado de cliente para rutas de daemon. Valida contra CA de Vault |

---

## 3. MATRIZ FINAL: CADA MÉTODO TIENE SU VALIDADOR

| # | Método | Categoría | ¿Quién lo valida en runtime? |
|---|--------|-----------|------------------------------|
| 1 | PASSWORD | Digital | **Keycloak** — hash Argon2id |
| 2 | TOTP | Digital | **Keycloak** — RFC 6238 |
| 3 | HOTP | Digital | **Keycloak** — RFC 4226 |
| 4 | EMAIL_OTP / SMS_OTP | Digital | **Keycloak** — código 6 dígitos |
| 5 | WEBAUTHN_PWDLESS | Digital | **Keycloak** — FIDO2 signature |
| 6 | WEBAUTHN_2FA | Digital | **Keycloak** — FIDO2 signature |
| 7 | PASSKEY_SYNCED | Digital | **Keycloak** — FIDO2 + sync |
| 8 | PASSKEY_DEVICE | Digital | **Keycloak** — FIDO2 device-bound |
| 9 | SMARTCARD_X509 | Digital | **Keycloak** — X.509 chain |
| 10 | OAUTH2_AUTH_CODE | Digital | **Keycloak** — OAuth 2.1 + PKCE |
| 11 | CLIENT_CREDENTIALS | Digital (M2M) | **Keycloak** — client_id + secret |
| 12 | OIDC_HYBRID | Digital | **Keycloak** — OpenID Connect |
| 13 | SAML2_POST | Digital | **Keycloak** — SAML assertion |
| 14 | CIBA | Digital | **Keycloak** — decoupled push |
| 15 | TOKEN_EXCHANGE | Digital | **Keycloak** — RFC 8693 |
| 16 | BACKUP_CODES | Digital | **Keycloak** — SHA-256 hash |
| 17 | RECOVERY_EMAIL | Digital | **Keycloak** — email verification |
| 18 | STEP_UP_CONDITIONAL | Digital | **bAuth** (evalúa condición) + **Keycloak** (ejecuta auth) |
| 19 | RISK_BASED_AUTH | Digital | **bAuth** (calcula risk) + **Keycloak** (aplica acción) |
| 20 | BASIC_AUTH | Digital (deprecated) | **Keycloak** — HTTP Basic |
| 21 | BEARER_TOKEN_STATIC | Digital (deprecated) | **Keycloak** — DB lookup |
| 22 | PUSH_NOTIFICATION | Digital | **Keycloak** — custom SPI |
| 23 | QR_DYNAMIC | Físico | **bhnexus** (lee QR) + **bAuth** (decide ALLOW/DENY) |
| 24 | NFC_MIFARE_DESFIRE | Físico | **bhnexus** (lee tarjeta) + **bAuth** (decide) |
| 25 | NFC_MIFARE_CLASSIC | Físico (legacy) | **bhnexus** + **bAuth** |
| 26 | RFID_125KHZ | Físico (legacy) | **bhnexus** + **bAuth** |
| 27 | FINGERPRINT_HASH | Físico (biométrico) | **bhnexus** (captura) + **bAuth** (compara Argon2id) |
| 28 | FACE_HASH | Físico (biométrico) | **bhnexus** + **bAuth** |
| 29 | IRIS_HASH | Físico (biométrico) | **bhnexus** + **bAuth** |
| 30 | SMARTCARD_X509 (físico) | Físico (PKI) | **bhnexus** + **bAuth** |
| 31 | PIN_PAD | Físico | **bhnexus** + **bAuth** |
| 32 | TOUCH_ID / FACE_ID | Biométrico local | **Dispositivo** — Secure Enclave |
| 33 | WINDOWS_HELLO / ANDROID_BIO | Biométrico local | **Dispositivo** — TPM / TEE |
| 34 | PLAY_INTEGRITY | Attestation | **Google Play** → **bAuth** (server-side verification) |
| 35 | APP_ATTEST | Attestation | **Apple** → **bAuth** (server-side verification) |
| 36 | MERKLE_ANCHOR | Blockchain D12 | **Besu QBFT** — smart contract + proof |
| 37 | DID | Blockchain D12 | **Besu QBFT** — EIP-725/735 |
| 38 | TRYTON MODEL ACCESS | ERP — Capa 1 | **Tryton** — ir.model.access |
| 39 | TRYTON RECORD RULES | ERP — Capa 2 | **Tryton** — ir.rule (domain PYSON) |
| 40 | TRYTON BUTTON RULES | ERP — Capa 3 | **Tryton** — ir.model.button |
| 41 | TRYTON FIELD ACCESS | ERP — Capa 4 | **Tryton** — ir.model.field |
| 42 | TRYTON MENU VISIBILITY | ERP — Capa 5 | **Tryton** — ir.action.groups |
| 43 | KONG JWT VALIDATION | API Gateway | **Kong** — JWT plugin |
| 44 | KONG RATE LIMIT | API Gateway | **Kong** — rate limiting plugin |
| 45 | KONG mTLS | API Gateway | **Kong** — mTLS plugin |

---

## 4. RESUMEN: 45 MÉTODOS — 7 VALIDADORES

| Validador | ¿Cuántos métodos? | Rol |
|-----------|:---:|------|
| **Keycloak** | 22 | Identity Provider — autenticación digital |
| **bAuth** | 11 (como decisor) + 2 (step_up, risk) | **NO valida métodos. ADMINISTRA y DECIDE.** El enforcement lo ejecutan bhnexus, Tryton y Kong. |
| **bhnexus** | 9 | Physical Enforcement Point — ejecuta ALLOW/DENY |
| **Tryton** | 5 | ERP Authorization Engine — 5 capas nativas |
| **Kong** | 3 | API Gateway — JWT, rate limit, mTLS |
| **Besu QBFT** | 2 | Blockchain Anchor — Merkle, DID |
| **Dispositivo** | 4 | Local Biometric Verifier — Secure Enclave/TPM/TEE |

**bAuth NO valida métodos de autenticación.**
**bAuth ADMINISTRA la configuración, ORQUESTA la sincronización, y DECIDE autorización.**
**Los validadores reales son: Keycloak (digital), Tryton (ERP), bhnexus (físico), Besu (blockchain), Kong (API), Dispositivo (biometría local).**

---

*Documento v2.0 corregido 2026-06-25. 45 métodos. 7 validadores reales. bAuth = administrador, no validador.*
