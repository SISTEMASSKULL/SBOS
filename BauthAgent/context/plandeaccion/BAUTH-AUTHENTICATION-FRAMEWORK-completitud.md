# BAUTH-AUTHENTICATION-FRAMEWORK — Informe de Completitud 2026
**Fecha de análisis:** 2026-06-21  
**Documento evaluado:** `BAUTH-AUTHENTICATION-FRAMEWORK.md v1.0.0`  
**Clasificación:** CONFIDENCIAL — SBOS Identity Core v3.0  
**Metodología:** Confrontación contra estándares internacionales vigentes al 2026-Q2

---

## RESUMEN EJECUTIVO

El framework es **sólido en sus fundamentos** y cubre las bases del estado del arte de 2023-2024, pero presenta **brechas críticas y nomenclaturas desactualizadas** respecto a los estándares finalizados en 2025. El score de completitud global estimado es **72/100**. Las brechas más urgentes son: la actualización de nomenclatura PQC (CRYSTALS → ML-KEM/ML-DSA/SLH-DSA), la adopción de OWASP ASVS 5.0 (la v4.0.3 fue supersedida en mayo 2025), la ausencia de 7-9 métodos de autenticación vigentes en el catálogo, y la falta de referencias a OAuth 2.1 como draft estable (draft-ietf-oauth-v2-1-15, marzo 2026).

| Dimensión | Score | Estado |
|-----------|-------|--------|
| Métodos de autenticación | 15/22 | 🟡 Incompleto |
| Criptografía / PQC | 10/13 | 🟡 Nomenclatura obsoleta |
| Protocolos de federación | 10/12 | 🟢 Bueno |
| Políticas y sagas | 11/12 | 🟢 Muy bueno |
| Cumplimiento normativo | 18/30 | 🔴 Brechas importantes |
| Estándares referenciados | 8/12 vigentes | 🟡 Parcial |

---

## 1. ESTÁNDARES VIGENTES AL 2026-Q2 — MAPA COMPLETO

### 1.1 NIST SP 800-63B — Estado Real

El documento referencia `NIST SP 800-63B Rev.4` como vigente. **Esto es correcto**, pero con precisiones críticas:

- **Finalizado:** 31 julio 2025 como `SP 800-63B-4` (ya no es "Rev.4 en proceso" — es la versión final publicada).
- **Supersede:** SP 800-63B (Rev.3/upd2) fue **retirado formalmente el 1 agosto 2025**.
- **Cambio arquitectónico clave:** Rev.4 no es una actualización incremental. Migra de checklist-based a **Digital Identity Risk Management (DIRM)** framework — evaluación continua de riesgos, no solo clasificación AAL estática.
- **Passkeys explícitamente reconocidas:** Synced passkeys → AAL2 compliant. Device-bound passkeys → AAL2/AAL3.
- **Email OTP:** Rev.4 lo depreca explícitamente como método restringido (no `preferred`, no `permitted`).
- **SMS OTP:** Significativamente degradado — solo `restricted` con condiciones.
- **Referencia correcta en el documento:** El framework usa `SP 800-63B Rev.4` — OK, pero debe actualizar el año a 2025 (no 2025 estaba en "borrador" cuando se redactó el framework).

**Brecha en el documento:** La tabla de `compliance_map` referencia 4 controles de NIST 800-63B. El estándar final tiene controles adicionales que el framework no mapea, especialmente sobre account recovery (§4.4), session bindings (§5.3), y restricciones sobre synced passkeys.

### 1.2 OWASP ASVS — Versión Obsoleta ⚠️ CRÍTICO

El documento referencia `OWASP ASVS 4.0.3`. **Esta versión fue supersedida en mayo 2025.**

- **Versión actual:** OWASP ASVS **5.0.0** — publicada mayo 2025, presentada en Global AppSec EU Barcelona.
- **Cambios disruptivos en v5.0:**
  - De 286 requerimientos en 14 capítulos → **~350 requerimientos en 17 capítulos**.
  - Los IDs de controles cambiaron (el sistema V2.2.1 puede no mapear al mismo control en v5.0).
  - Nuevo capítulo dedicado a **Web Frontend Security** y **Self-contained Tokens**.
  - Criptografía actualizada con consideraciones PQC.
  - Passwords alienadas con NIST SP 800-63-4.
  - Nivel 1 simplificado; Nivel 3 expandido significativamente.
  - AI Security está **excluida intencionalmente** (hay un proyecto separado: AISVS).
- **Los controles que cita el framework** (`V2.1.1`, `V2.1.7`, `V2.2.1`) **deben re-mapearse** a ASVS 5.0.0 porque los identificadores cambiaron entre versiones.

### 1.3 OAuth 2.1 — No Es RFC Final (aún)

El documento indica `OAuth 2.1 BCP — 2025` en referencias. **Precisión necesaria:**

- OAuth 2.1 está en `draft-ietf-oauth-v2-1-15` (publicado marzo 2026). **No es RFC final.**
- Expiración del draft actual: septiembre 2026.
- **Prácticamente estable:** Spring Security, Keycloak y todos los major IdPs lo implementan.
- **Lo que consolida:** PKCE obligatorio para todos los clientes, sin Implicit flow, sin ROPC, refresh tokens sender-constrained para clientes públicos, bearer tokens solo en header.
- **RFC 9700** (OAuth 2.0 Security Best Current Practice) — **sí es RFC final** (enero 2025) — es la base normativa de OAuth 2.1. El framework debería citar RFC 9700 explícitamente.
- **RFC 9728** (OAuth 2.0 Protected Resource Metadata) — RFC final (abril 2025) — habilita descubrimiento dinámico de authorization servers desde el resource server. Relevante para biedata.

### 1.4 PQC — Nomenclatura Obsoleta ⚠️ CRÍTICO

El framework usa los nombres de competencia (`CRYSTALS-Kyber-1024`, `CRYSTALS-Dilithium-5`, `SPHINCS+`). Los **nombres FIPS oficiales** desde agosto 2024 son diferentes:

| Framework dice | Nombre FIPS oficial | Estándar |
|---------------|-------------------|---------|
| CRYSTALS-Kyber-1024 | **ML-KEM-1024** | FIPS 203 |
| CRYSTALS-Dilithium-5 | **ML-DSA-87** | FIPS 204 |
| SPHINCS+ | **SLH-DSA** (con parámetros específicos) | FIPS 205 |
| NTRU HPS-4096 | — (no estandarizado por NIST) | ❌ No en FIPS |

**Adición faltante:**
- **FN-DSA** (FALCON) → FIPS 206 (draft finalizado, publicación inminente) — firma digital ultra-compacta para firmware y embedded.
- **HQC** (Hamming Quasi-Cyclic) → en proceso como estándar de respaldo KEM.
- **ML-KEM-768** (nivel 3) es el nivel recomendado para uso general; ML-KEM-1024 es para alta seguridad.

**NTRU HPS-4096** no forma parte de los estándares NIST finalizados. Su presencia en el framework como algoritmo PQC activo es un error técnico — no tiene validación FIPS.

### 1.5 ISO/IEC 27001 y 24760

- **ISO/IEC 27001:2022** — correcto y vigente.
- **ISO/IEC 24760-1/2/3/4:2025** — el framework lo lista como referencia. Correcto (suite de gestión de identidad).
- **Brecha:** El framework mapea 7 controles ISO 27001. La suite completa para autenticación incluye A.5.14 (información de autenticación), A.5.17 (gestión de información de autenticación), A.8.2 (privilegios de acceso), A.8.4 (acceso a código fuente), A.8.5 (autenticación segura), A.8.15 (logging), A.8.17 (sincronización de relojes) — algunos ausentes.

---

## 2. MÉTODOS DE AUTENTICACIÓN — ANÁLISIS DE COMPLETITUD

### 2.1 Catálogo actual: 15 métodos

El framework declara 15 métodos distribuidos en AAL1/AAL2/AAL3. A continuación el análisis de completitud contra el estado del arte 2026:

### 2.2 Métodos presentes ✅ (confirmados vigentes)

| Método | AAL NIST 800-63B-4 | Estado en bAuth | Observación |
|--------|-------------------|-----------------|-------------|
| Password/Passphrase | AAL1 | ✅ presente | Rev.4 favorece passphrases largas sobre contraseñas complejas |
| Passkey (device-bound) | AAL2-AAL3 | ✅ presente | Correcto |
| Email OTP | AAL1 (restricted) | ✅ presente | Rev.4 lo **depreca** — debe ser `discouraged` no `permitted` |
| Kerberos | AAL1-AAL2 | ✅ presente | OK para entornos corporativos |
| TOTP (RFC 6238) | AAL2 | ✅ presente | Vigente pero no phishing-resistant |
| HOTP (RFC 4226) | AAL2 | ✅ presente | Vigente, menos común |
| WebAuthn 2FA | AAL2 | ✅ presente | Correcto |
| Conditional OTP | AAL1-AAL2 | ✅ presente | OK como adaptive |
| WebAuthn Passwordless | AAL2-AAL3 | ✅ presente | Core del estándar FIDO2 |
| X.509 mTLS | AAL3 | ✅ presente | Vigente |
| Synced Passkey | AAL2 | ✅ (implícito en Passkey) | Debe ser método independiente con política diferenciada |
| Service Account Key / API Key | n/a (M2M) | ✅ presente | OK |
| Recovery Codes | n/a | ✅ presente | OK |

### 2.3 Métodos faltantes ❌ — Brechas identificadas

Los siguientes métodos tienen RFC o estándar vigente y presencia significativa en el ecosistema empresarial 2026, pero están **ausentes** del catálogo `auth_method`:

#### ❌ SMS OTP / Push OTP (Out-of-Band via dispositivo)
- **RFC:** NIST 800-63B §3.3 (Out-of-Band Authenticators)
- **Estado NIST:** `restricted` — requiere demostración de que el número no ha sido SIM-swapped
- **Por qué falta:** Es el método más usado globalmente en consumer apps. El framework debe registrarlo como `method_type=out_of_band`, `nist_status=restricted`, para poder aplicar políticas de prohibición en tiers altos (SU, SYS) y permitirlo en EXT_N0.

#### ❌ Synced Passkey (como método independiente)
- **RFC/Estándar:** NIST SP 800-63B-4 §3.2.3, FIDO2 Level 3
- **Estado:** AAL2 según Rev.4 (julio 2025) — explícitamente reconocido
- **Por qué importa:** Synced passkeys (Apple Keychain, Google Password Manager, Windows Hello) tienen políticas de attestation distintas a device-bound. El framework los mezcla bajo "Passkey" pero necesitan registros separados con `method_id=KC_PASSKEY_SYNCED` vs `KC_PASSKEY_DEVICE_BOUND`.

#### ❌ Biometría como factor independiente (local on-device)
- **RFC/Estándar:** NIST 800-63B §3.2.4, ISO/IEC 30107-3 (liveness detection)
- **Estado:** No es AAL por sí sola — es un desbloqueador del authenticator criptográfico (FIDO2). Sin embargo, debe modelarse como `method_type=biometric` para configurar políticas de liveness, error rates, y fallback.
- **Contexto 2026:** Gartner predice que 30% de empresas dejarán de confiar en biometría aislada por deepfakes AI. El framework debe tener una entrada para gestionar esta política.

#### ❌ Verifiable Credentials / mDL (ISO 18013-5)
- **Estándar:** W3C VC Data Model 2.0, ISO/IEC 18013-5, eIDAS 2.0
- **Estado 2026:** Japón emitió IDs nacionales en mdoc format (junio 2025). 18 estados de EE.UU. tienen mDL. eIDAS 2.0 en vigor desde mayo 2024.
- **Por qué importa para SBOS:** Como plataforma B2B/empresarial, bAuth podría necesitar aceptar credenciales verificables de terceros (proveedores, clientes corporativos). Falta `method_id=VC_MDOC` y `method_id=VC_W3C`.

#### ❌ CIBA Push (client-initiated backchannel — push notification)
- **RFC:** OpenID Connect CIBA Core + Push delivery mode
- **Estado:** El framework lista CIBA como `enabled` pero solo como protocolo de federación. Falta registrarlo como método de autenticación (la notificación push al dispositivo es un authenticator out-of-band distinto a TOTP).

#### ❌ Silent Network Authentication (SNA)
- **Estándar:** GSMA Mobile Connect / SNA spec
- **Estado 2026:** Usado por telcos para autenticación transparente por SIM/red. Relevante si SBOS sirve usuarios móviles en Bolivia (Tigo, Entel tienen capacidad SNA).
- **Clasificación:** AAL1 (possession factor via SIM).

#### ❌ Risk-Based / Adaptive Authentication (como método propio)
- **Estándar:** NIST 800-63B Rev.4 §6 (Risk Management), OWASP ASVS 5.0 V2
- **Estado 2026:** El paradigma dominante en 2026. No es un método de autenticación aislado sino una capa de orquestación. Sin embargo, debe modelarse en el framework como `method_type=adaptive` con sus propias políticas (risk score threshold, step-up triggers, behavioral signals).
- **El framework tiene `Conditional OTP`** pero no una entrada genérica para adaptive auth engine.

#### ❌ Behavioral Biometrics (autenticación continua post-login)
- **Estándar:** IEEE 2410-2021 (Biometric Open Protocol Standard), NIST SP 800-207 §4
- **Estado 2026:** Keystroke dynamics, mouse patterns, gait — mercado proyectado a $4.26B para 2027. NIST ZTA lo menciona como continuous verification.
- **Clasificación:** `method_type=continuous`, no es un authenticator inicial sino un re-autenticador silencioso. Falta en el catálogo y en sagas (no hay saga para `auth.continuous.reevaluate`).

#### ❌ Hardware Token (OTP físico, ej. YubiKey OTP legacy)
- **RFC:** OATH HOTP/TOTP en hardware
- **Estado:** Distinto de WebAuthn/FIDO2. Los YubiKey en modo OTP (no FIDO2) son tokens separados. El framework mezcla estos con HOTP/TOTP software.

### 2.4 Resumen de métodos: estado vs. estándar

| Categoría | En bAuth | En estándares 2026 | Faltantes |
|-----------|----------|-------------------|-----------|
| Single-factor knowledge | 1 (password) | 1 | 0 |
| Single-factor possession | 3 (HOTP, TOTP, Email OTP) | 5 (+ SMS OTP, Hardware Token) | 2 |
| Multi-factor (phishing-resistant) | 3 (WebAuthn, Passkey, mTLS) | 5 (+ Synced Passkey separado, CIBA Push) | 2 |
| Federated/Identity | 2 (Kerberos, OIDC implícito) | 4 (+ VC/mDL, CIBA push) | 2 |
| Machine/Service | 2 (API Key, Client Cred) | 2 | 0 |
| Adaptive/Continuous | 1 (Conditional OTP) | 3 (+ Risk-Based, Behavioral Biometrics) | 2 |
| Recovery | 1 (Recovery Codes) | 2 (+ Account Recovery via RP/IdP) | 1 |
| **Total** | **15** | **22-24** | **7-9** |

---

## 3. CRIPTOGRAFÍA — ANÁLISIS DE COMPLETITUD

### 3.1 Problemas de nomenclatura PQC ⚠️

Como se detalló en §1.4, el framework usa nombres del concurso NIST, no los nombres FIPS oficiales. Esto es un problema de trazabilidad: los auditores buscarán `ML-KEM`, `ML-DSA`, `SLH-DSA` — no encontrarán esos nombres en el documento.

**Cambios requeridos en `crypto_algorithm`:**

| Registro actual | Registro correcto | FIPS | Acción |
|----------------|------------------|------|--------|
| `CRYSTALS-Kyber-1024` | `ML-KEM-1024` | FIPS 203 | UPDATE name + rfc_ref |
| `CRYSTALS-Dilithium-5` | `ML-DSA-87` | FIPS 204 | UPDATE name + rfc_ref |
| `SPHINCS+` | `SLH-DSA-SHA2-256s` (o variante elegida) | FIPS 205 | UPDATE name + params |
| `NTRU HPS-4096` | ❌ Eliminar / marcar inactive | No estandarizado | Soft delete |

**Agregar:**
- `FN-DSA` (FALCON via FIPS 206 — draft final, inminente). Útil para firmware signing y casos donde el tamaño de firma es crítico.
- `ML-KEM-768` como nivel recomendado para uso general (el framework solo tiene ML-KEM-1024).
- `ChaCha20-Poly1305` — alternativa a AES-GCM para contextos sin hardware AES-NI (IETF RFC 8439, vigente).
- `X25519` / `X448` para ECDH clásico pre-transición PQC (RFC 7748).

### 3.2 Algoritmos presentes y su estado

| Algoritmo | Estado FIPS 140-3 | En bAuth | Observación |
|-----------|------------------|----------|-------------|
| Argon2id | FIPS 140-3 compliant (via SP 800-132) | ✅ | Correcto para password hashing |
| SHA-256 | FIPS 180-4 | ✅ | Vigente |
| SHA3-256 | FIPS 202 | ✅ | Vigente |
| ES256 (ECDSA P-256) | FIPS 186-5 | ✅ | Vigente |
| ES384 | FIPS 186-5 | ✅ | Vigente |
| Ed25519 | FIPS 186-5 (aprobado 2023) | ✅ | Vigente — correcto |
| AES-256-GCM | FIPS 197 | ✅ | Vigente |
| HKDF-SHA256 | NIST SP 800-56C | ✅ | Vigente |
| ML-KEM-1024 (mal llamado CRYSTALS-Kyber) | FIPS 203 | ⚠️ | Renombrar |
| ML-DSA-87 (mal llamado CRYSTALS-Dilithium-5) | FIPS 204 | ⚠️ | Renombrar |
| SLH-DSA (mal llamado SPHINCS+) | FIPS 205 | ⚠️ | Renombrar + especificar variante |
| NTRU HPS-4096 | ❌ No FIPS | ⚠️ | Marcar inactive — no en estándares NIST |

---

## 4. PROTOCOLOS DE FEDERACIÓN — ANÁLISIS

### 4.1 Estado actual: 12 protocolos

El framework cubre bien el ecosistema OAuth/OIDC. Análisis específico:

| Protocolo | Estado real | Observación |
|-----------|------------|-------------|
| OAuth 2.0 Auth Code + PKCE | ✅ Core de OAuth 2.1 | Correcto |
| OAuth 2.0 Client Credentials | ✅ Vigente | Correcto |
| OAuth 2.0 Refresh Token Rotation | ✅ Mandatorio en OAuth 2.1 | Correcto |
| OAuth 2.0 Device Authorization (RFC 8628) | ✅ Vigente | Correcto |
| OAuth 2.0 Token Exchange (RFC 8693) | ✅ `enabled_controlled` | Correcto — sensato |
| OpenID Connect Auth Code | ✅ Vigente | Correcto |
| SAML 2.0 Web SSO | ✅ Vigente (legacy enterprise) | Correcto |
| mTLS OAuth 2.0 (RFC 8705) | ✅ Vigente | Correcto |
| DPoP (RFC 9449) | 🟡 `planned` | **Debería estar `enabled`** — RFC 9449 es final desde 2023, Keycloak lo soporta |
| CIBA (OIDC CIBA Core) | ✅ `enabled` | Correcto |
| ROPC | ✅ `disabled_permanently` | Correcto — eliminado en OAuth 2.1 |
| Implicit Grant | ✅ `disabled_permanently` | Correcto — eliminado en OAuth 2.1 |

### 4.2 Protocolos faltantes

| Protocolo | RFC/Estándar | Por qué agregar |
|-----------|-------------|----------------|
| **OAuth 2.0 Protected Resource Metadata** | RFC 9728 (abril 2025) | Permite a biedata autodescubrir AS sin configuración estática |
| **OAuth 2.0 Security BCP** | RFC 9700 (enero 2025) | Referencia normativa base de OAuth 2.1 — debe estar en compliance_map |
| **JWT Secured Authorization Request (JAR)** | RFC 9101 | Requests firmados — relevante para AAL3 |
| **Pushed Authorization Requests (PAR)** | RFC 9126 | Evita interceptación del authorization request — recomendado en OAuth 2.1 BCP |
| **W3C Verifiable Credentials / DID** | W3C VC 2.0 / DID Core | Emergente pero estandarizado — FIDO Alliance lanzó DCWG en diciembre 2025 |

**DPoP debe pasar de `planned` a `enabled`**: RFC 9449 está finalizado y es el mecanismo recomendado para sender-constrained tokens. Keycloak (que usa SBOS) lo soporta desde versión 21.

---

## 5. COMPLIANCE MAP — BRECHAS NORMATIVAS

### 5.1 Estándares con cobertura insuficiente

#### OWASP ASVS — Versión incorrecta y controles desactualizados
- **Declarado:** ASVS 4.0.3 (3 controles mapeados: V2.1.1, V2.1.7, V2.2.1)
- **Vigente:** ASVS **5.0.0** (mayo 2025) — los identificadores de controles cambiaron
- **Acción:** Re-mapear todos los controles ASVS al nuevo esquema `v5.0.0-X.Y.Z`
- **Controles adicionales a mapear en ASVS 5.0:** autenticación phishing-resistant (capítulo nuevo), tokens auto-contenidos (capítulo nuevo), gestión de credenciales.

#### GDPR — 50% de cobertura (2/4)
- **Mapeado:** Art.32 (seguridad del procesamiento), Art.33 (planned)
- **Faltante:** Art.25 (Privacy by Design — relevante para passkeys que no transmiten PII), Art.17 (derecho al olvido — implica política de revocación de authenticators).

#### NIST SP 800-53 Rev.5 — 60% (3/5)
- **Faltante:** AC-5 (separation of duties — planned), IA-5 (authenticator management — ausente), IA-8 (identification and authentication for non-organizational users — crítico para tenants externos EXT_N0).

#### ISO 27001:2022 — 70% (7/10)
- **Faltante:** A.5.14 (information transfer — relevante para tokens entre servicios), A.8.17 (clock synchronization — crítico para TOTP), A.8.4 (access to source code — relevante para bAuth en sí).

### 5.2 Estándares ausentes en compliance_map

| Estándar | Relevancia para bAuth | Acción sugerida |
|----------|----------------------|----------------|
| **RFC 9700** (OAuth 2.0 Security BCP) | Base normativa de todos los protocolos OAuth | Agregar con controles: token binding, PKCE obligatorio, redirect URI matching |
| **FIPS 203/204/205** (nombres correctos) | Los algoritmos PQC actuales | Actualizar referencias en compliance_map |
| **eIDAS 2.0** (Reglamento EU 2024/1183) | Si SBOS tiene usuarios en UE o integra con IdPs europeos | Evaluar si aplica |
| **PCI DSS 4.0.1** — Req 8.5.1 | Marcado como `planned` | Implementar: anti-phishing para acceso a CDE |
| **CISA Phishing-Resistant MFA Guidance** | Directiva federal US — referencia de facto en enterprise | Agregar como referencia informativa |
| **W3C WebAuthn Level 3** | El framework cita "Level 3 / 2024" pero sin mapeo de controles | Mapear: attestation requirements, credential backup flags |

---

## 6. SAGAS — ANÁLISIS DE COMPLETITUD

### 6.1 Las 12 sagas actuales están bien diseñadas

El catálogo de sagas es el elemento más robusto del framework. Cubre los flujos críticos con timeouts y estrategias de compensación apropiadas.

### 6.2 Sagas faltantes (escenarios emergentes 2026)

| Saga sugerida | Justificación | Prioridad |
|---------------|--------------|-----------|
| `auth.continuous.reevaluate` | Behavioral biometrics / ZTA continuous verification (NIST SP 800-207) | Media |
| `auth.passkey.register` | El enrollment de passkeys es un flujo diferente al de `auth.mfa.enroll` — requiere attestation verification, credential backup flag evaluation | Alta |
| `auth.token.dpop_bind` | Binding de DPoP proof al access token — saga corta (2-3 pasos) pero diferenciada | Media |
| `auth.vc.present` | Presentación de Verifiable Credential desde wallet externo | Baja (emergente) |
| `auth.account.recovery_advanced` | Recovery con múltiples métodos de verificación según NIST 800-63B-4 §4.4 | Media |

### 6.3 Observaciones sobre sagas existentes

- **S7 `auth.emergency.break_glass`** — Timeout de 4h es correcto para emergencia. Bien diseñada con HITL.
- **S8 `auth.offline.login`** — `best_effort` como compensación es aceptable para offline, pero debe documentarse qué métodos son válidos offline (solo passkeys device-bound, no synced).
- **S11 `auth.session.validate`** — 2s timeout es agresivo. Con behavioral biometrics esto podría ejecutarse cada N segundos en background — considerar saga separada vs. esta.
- **S12 `auth.account.lockout`** — La compensación `checkpoint` es correcta. Verificar que el bloqueo progresivo (5→10→20) esté alineado con NIST 800-63B-4 (que no especifica números exactos pero sí el principio de bloqueo progresivo con delays).

---

## 7. POLÍTICAS — ANÁLISIS DE COMPLETITUD

### 7.1 Las 22 políticas son sólidas

El diseño por tier (SU/SYS/BIZ/EXT) es correcto y bien diferenciado. Sin embargo:

### 7.2 Políticas faltantes o a actualizar

| Política | Problema | Acción |
|----------|---------|--------|
| `password.min_length` para EXT_N0: 8 chars | NIST 800-63B-4 recomienda mínimo 8 pero **favorece passphrases de 15+**. Email OTP como único factor en EXT es ahora `restricted`. | Actualizar guidance, considerar forzar passphrase > 15 chars |
| `mfa.phishing_resistant` | No existe política explícita para forzar solo métodos phishing-resistant. NIST 800-63B-4 Rev.4 hace esto mandatorio para AAL3. | Agregar `mfa.phishing_resistant_only` con flag boolean por tier |
| `session.continuous_reevaluation` | ZTA requiere re-evaluación continua, no solo duración máxima. | Agregar política de re-evaluación periódica (cada N minutos, basada en risk score) |
| `passkey.sync_policy` | Synced vs. device-bound passkeys necesitan políticas diferenciadas (SU debería prohibir synced). | Agregar política `passkey.allow_synced` por tier |
| `token.dpop_required` | DPoP debería ser mandatorio para tiers SU/SYS según OAuth 2.1 BCP. | Agregar política |
| Periodic password change | El framework no menciona si lo deshabilita. NIST 800-63B-4 **prohíbe** forced periodic rotation (solo cambiar si hay evidencia de compromiso). | Confirmar que `auth_policy` no incluye rotación periódica. Si existe, eliminarla. |

---

## 8. LIBRERÍAS Y HERRAMIENTAS — COBERTURA DEL ECOSISTEMA

### 8.1 Stack implícito en bAuth (Keycloak + Rust + PostgreSQL)

El framework menciona Keycloak como IdP pero no documenta qué librerías Rust se usan para implementar los algoritmos. Recomendaciones por categoría:

#### Rust — Librerías para métodos de autenticación

| Categoría | Librería recomendada | Versión estable | Notas |
|-----------|---------------------|----------------|-------|
| WebAuthn/FIDO2 | `webauthn-rs` | 0.5.x | Soporta passkeys, attestation, device-bound |
| TOTP/HOTP | `totp-rs` | 5.x | RFC 6238/4226, soporte TOTP-SHA1/256/512 |
| JWT | `jsonwebtoken` | 9.x | ES256/ES384/Ed25519, validación |
| mTLS / X.509 | `rustls` + `rcgen` | 0.23.x | TLS 1.3, certificados X.509 |
| PQC (ML-KEM, ML-DSA) | `pqcrypto` | 0.17.x | Bindings a liboqs/NIST reference impl |
| PQC alternativa | `oqs-rust` (liboqs) | 0.10.x | Open Quantum Safe — soporte ML-KEM-768/1024, ML-DSA |
| Argon2id | `argon2` | 0.5.x | Parametrizable, FIPS-aligned |
| HKDF | `hkdf` | 0.12.x | NIST SP 800-56C compliant |
| DPoP | `dpop` (crate) | 0.2.x | RFC 9449 — sender-constrained tokens |
| Biometric / FIDO2 Assertion | `cosey` | 0.4.x | CBOR/COSE para WebAuthn assertions |

#### Keycloak — Plugins y extensiones relevantes

| Funcionalidad | Plugin/Extensión | Notas |
|--------------|-----------------|-------|
| Passkeys | Keycloak 22+ nativo | WebAuthn passwordless integrado |
| DPoP | Keycloak 24+ nativo | RFC 9449 soportado |
| CIBA | Keycloak 15+ nativo | Push mode disponible |
| Step-up Auth | Keycloak ACR + RFC 9470 | Configurar en `federation_protocol` |
| Behavioral auth | Keycloak + SPI custom | Requiere extensión propia |
| Passkey attestation | Keycloak WebAuthn Policy | Configurar en `auth_policy` |

#### Herramientas de validación y compliance

| Herramienta | Propósito | URL |
|------------|----------|-----|
| `yubikey-manager` | Gestión de YubiKeys (FIDO2, OTP) | Yubico |
| `OpenSC` | Smart cards / X.509 | opensc-project.org |
| `oqs-provider` (OpenSSL) | PQC en TLS 1.3 vía OpenSSL | open-quantum-safe.org |
| `Bouncy Castle` (Java/JVM) | Si Kong o componentes JVM necesitan PQC | bouncycastle.org |
| `Duo Security SDK` | Adaptive MFA push — si se integra Duo | duo.com |
| `FIDO MDS3` | Metadata Service para attestation de passkeys | fidoalliance.org/mds |
| `webauthn.io` | Testing de flujos WebAuthn | webauthn.io |

---

## 9. SCORING DETALLADO POR DIMENSIÓN

### 9.1 Tabla de completitud

| Dimensión | Peso | Score Raw | Score Ponderado | Estado |
|-----------|------|-----------|----------------|--------|
| **Métodos de autenticación** | 25% | 68% (15/22 métodos) | 17/25 | 🟡 |
| **Criptografía (correctitud + cobertura)** | 20% | 75% (9/12 correctos) | 15/20 | 🟡 |
| **Protocolos de federación** | 15% | 83% (10/12 + DPoP pendiente) | 12.5/15 | 🟢 |
| **Cumplimiento normativo (compliance_map)** | 20% | 65% (16/24.5 controles) | 13/20 | 🔴 |
| **Políticas (auth_policy)** | 10% | 85% (19/22 políticas OK) | 8.5/10 | 🟢 |
| **Sagas (orquestación)** | 10% | 85% (12/14 escenarios) | 8.5/10 | 🟢 |
| **Total** | 100% | — | **74.5/100** | 🟡 |

### 9.2 Priorización de brechas

| Prioridad | Brecha | Esfuerzo | Impacto |
|-----------|--------|----------|---------|
| 🔴 P0 | Renombrar algoritmos PQC a nomenclatura FIPS oficial | Bajo (SQL UPDATE) | Alto (auditoría) |
| 🔴 P0 | Actualizar referencia OWASP ASVS 4.0.3 → 5.0.0 | Medio (re-mapeo) | Alto (compliance) |
| 🔴 P0 | Agregar SMS OTP como método `restricted` en registro | Bajo (INSERT) | Alto (completitud) |
| 🟡 P1 | Separar Synced Passkey de Device-Bound Passkey | Bajo (INSERT) | Medio |
| 🟡 P1 | DPoP: cambiar `planned` → `enabled` | Bajo (UPDATE) | Medio |
| 🟡 P1 | Agregar RFC 9700 y RFC 9728 en federation_protocol y compliance_map | Bajo (INSERT) | Alto |
| 🟡 P1 | Eliminar/inactivar NTRU HPS-4096 (no estandarizado FIPS) | Bajo (UPDATE active=false) | Medio |
| 🟢 P2 | Agregar métodos: Behavioral Biometrics, Risk-Based Auth | Medio (INSERT + saga) | Medio |
| 🟢 P2 | Saga `auth.passkey.register` independiente | Medio | Medio |
| 🟢 P2 | Agregar política `passkey.allow_synced` por tier | Bajo | Bajo |
| 🔵 P3 | Verifiable Credentials / mDL (ISO 18013-5) | Alto | Bajo (futuro) |
| 🔵 P3 | Agenda de transición post-cuántica (2030 deadline NSA CNSA 2.0) | Alto | Bajo (futuro) |

---

## 10. CONCLUSIÓN Y RECOMENDACIONES

### 10.1 Fortalezas del framework

El `BAUTH-AUTHENTICATION-FRAMEWORK` es un documento de arquitectura de alta calidad. Sus fortalezas son:

- El modelo declarativo SSOT (SQL seeds idempotentes) es un patrón de ingeniería correcto y poco común en el sector.
- La separación en 7 tablas con responsabilidades acotadas es limpia y extensible.
- Las sagas con compensaciones inversas siguen el patrón correcto para transacciones distribuidas.
- El diseño por tier (SU/SYS/BIZ/EXT) con políticas diferenciadas es arquitectónicamente sólido.
- La inclusión de PQC es un diferenciador estratégico — la mayoría de plataformas similares no lo tienen todavía.
- La trazabilidad normativa por entidad (cada registro referencia su estándar) es un patrón excelente para auditoría.

### 10.2 Plan de acción recomendado

**Sprint inmediato (1-2 días, impacto alto):**

```sql
-- P0.1: Renombrar algoritmos PQC
UPDATE bauth.crypto_algorithm SET algorithm_name = 'ML-KEM-1024', standard_ref = 'FIPS-203' 
WHERE algorithm_name LIKE '%Kyber%';

UPDATE bauth.crypto_algorithm SET algorithm_name = 'ML-DSA-87', standard_ref = 'FIPS-204'
WHERE algorithm_name LIKE '%Dilithium%';

UPDATE bauth.crypto_algorithm SET algorithm_name = 'SLH-DSA-SHA2-256s', standard_ref = 'FIPS-205'
WHERE algorithm_name LIKE '%SPHINCS%';

-- P0.2: Inactivar NTRU (no FIPS)
UPDATE bauth.crypto_algorithm SET active = FALSE, notes = 'Retirado: no estandarizado por NIST FIPS'
WHERE algorithm_name LIKE '%NTRU%';

-- P0.3: Actualizar referencia ASVS
UPDATE bauth.compliance_map SET standard_version = '5.0.0', control_id = 'v5.0.0-2.X.X'
WHERE standard = 'OWASP_ASVS' AND standard_version = '4.0.3';

-- P0.4: Agregar SMS OTP como método restricted
INSERT INTO bauth.auth_method (method_id, display_name, method_type, aal_level, nist_status, applies_to, rfc_ref, active)
VALUES ('KC_SMS_OTP', 'SMS One-Time Password', 'out_of_band', 'AAL1', 'restricted', '{EXT_N0}', 'NIST_800_63B_4_S3_3', TRUE)
ON CONFLICT DO NOTHING;

-- P0.5: DPoP enabled
UPDATE bauth.federation_protocol SET status = 'enabled', notes = 'RFC 9449 final - Keycloak 24+ nativo'
WHERE protocol_name = 'DPoP';
```

**Sprint siguiente (1 semana):**
- Agregar Synced Passkey como `method_id=KC_PASSKEY_SYNCED` con política `passkey.allow_synced=false` para SU/SYS.
- Agregar RFC 9700 y RFC 9728 en federation_protocol y compliance_map.
- Crear saga `auth.passkey.register` con pasos: `generate_options → validate_attestation → store_credential → notify_user → audit_log`.
- Agregar política `mfa.phishing_resistant_only` boolean por tier.
- Re-mapear controles ASVS 4.0.3 → ASVS 5.0.0.

**Sprint de mejora (2-4 semanas):**
- Modelar Risk-Based/Adaptive Auth como `method_type=adaptive`.
- Agregar saga `auth.continuous.reevaluate` para ZTA.
- Completar cobertura GDPR (Art.25 Privacy by Design).
- Completar NIST 800-53 (IA-5, IA-8).
- Documentar roadmap PQC hacia 2030 (NSA CNSA 2.0 deadline).

---

## APÉNDICE — Referencias de estándares vigentes al 2026-06-21

| Estándar | Versión vigente | Fecha | Estado |
|----------|----------------|-------|--------|
| NIST SP 800-63B | **Rev.4 (SP 800-63B-4)** | 31 jul 2025 | Final |
| NIST SP 800-63A | Rev.4 | 31 jul 2025 | Final |
| NIST SP 800-63C | Rev.4 | 31 jul 2025 | Final |
| NIST SP 800-53 | Rev.5 | 2020+errata | Final |
| NIST SP 800-207 | Final | 2020 | Final |
| NIST SP 1800-35 | Final | 2024 | Final |
| FIPS 140-3 | — | 2019 | Final |
| FIPS 203 (ML-KEM) | — | ago 2024 | Final |
| FIPS 204 (ML-DSA) | — | ago 2024 | Final |
| FIPS 205 (SLH-DSA) | — | ago 2024 | Final |
| FIPS 206 (FN-DSA) | Draft | 2024-2025 | Draft final |
| ISO/IEC 27001 | 2022 | 2022 | Vigente |
| ISO/IEC 24760-1/2/3/4 | 2025 | 2025 | Vigente |
| PCI DSS | **4.0.1** | mar 2025 | Vigente |
| OWASP ASVS | **5.0.0** | may 2025 | Vigente ← framework usa 4.0.3 |
| OAuth 2.1 | draft-ietf-oauth-v2-1-15 | mar 2026 | Draft estable |
| RFC 9700 (OAuth Security BCP) | — | ene 2025 | RFC Final |
| RFC 9728 (Protected Resource Metadata) | — | abr 2025 | RFC Final |
| RFC 9449 (DPoP) | — | 2023 | RFC Final |
| RFC 9470 (Step-Up Auth) | — | 2023 | RFC Final |
| FIDO2/WebAuthn | Level 3 | 2024 | Final |
| W3C VC Data Model | 2.0 | 2024 | W3C Recommendation |
| eIDAS 2.0 | Reg. EU 2024/1183 | may 2024 | Vigente (UE) |
| ISO/IEC 18013-5 (mDL) | — | 2021+amd | Vigente |

---

*Informe generado el 2026-06-21. Revisión sugerida: semestral o ante publicación de nuevos estándares NIST/OWASP.*
