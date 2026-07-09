# BAUTH — Dossier de Certificación Externa
## OpenID Foundation · FIDO Alliance · ISO 27001 · Kantara NIST 800-63

**Versión:** 1.0 · **Fecha:** 2026-06-29 · **Autor:** agente-bauth  
**Propósito:** Documentar el estado de preparación de bAuth para certificación externa con organismos internacionales.  
**Referencias:** `BAUTH-QUALITY-ASSURANCE-SYSTEM.md` v4.0 · `BAUTH-RECONCILIACION-METODOS-AUTENTICACION.md` v5.0

---

## 1. RESUMEN EJECUTIVO

bAuth Identity Core v3.0 está **técnicamente listo** para iniciar procesos de certificación externa. Este documento detalla:

1. Qué certificaciones aplican
2. Estado de preparación para cada una
3. Documentación requerida
4. Evidencia disponible
5. Gaps remanentes
6. Plan de ejecución

**332 tests unitarios · 105 handlers JSON-RPC · 0% dependencia Keycloak · Compliance QA System operativo**

---

## 2. CERTIFICACIONES OBJETIVO

| Certificación | Organismo | Costo Est. (USD) | Tiempo Est. | Prioridad |
|--------------|-----------|:---:|:---:|:---:|
| **OIDC Provider** | OpenID Foundation | $5K-$15K | 3-6 meses | 🔴 Fase 1 |
| **FIDO2 Authenticator** | FIDO Alliance | $15K-$50K | 6-12 meses | 🟠 Fase 2 |
| **ISO 27001:2022** | IBNORCA (Bolivia) | Variable | 6-12 meses | 🟡 Fase 3 |
| **NIST 800-63 Trust Mark** | Kantara Initiative | $20K-$60K | 6-18 meses | 🟢 Fase 4 |

---

## 3. OPENID FOUNDATION — OIDC Provider Certification

### 3.1 Perfil Objetivo: Basic OP

| Requisito | Estado | Evidencia |
|-----------|:---:|------|
| Authorization Code Flow | ✅ | `oidc_provider.rs` — `handle_authorization_code` |
| PKCE S256 | ✅ | `verify_pkce()` — SHA256 challenge verification |
| Discovery (`/.well-known/openid-configuration`) | ✅ | `bauth.oidc.discovery` — handler operativo en VPS |
| JWKS endpoint | ✅ | `token_jwks.rs` — Ed25519, RFC 8037 |
| ID Token (JWT) | ✅ | `jwt_signer.rs` — EdDSA Ed25519 |
| `sub`, `iss`, `aud`, `exp`, `iat` claims | ✅ | Claims estándar en token |
| `nonce` claim | ✅ | Soportado en authorization code flow |
| Token Endpoint | ✅ | `bauth.oidc.token` — client_credentials + auth_code + refresh |
| UserInfo Endpoint | ✅ | `bauth.oidc.userinfo` — lookup en idn_user_template |
| Token Introspection (RFC 7662) | ✅ | `bauth.oidc.introspect` |

### 3.2 Evidencia para OpenID Foundation

| Documento | Estado | Ubicación |
|-----------|:---:|------|
| Resultados Conformance Suite | 🔄 Pendiente ejecutar | https://openid.net/certification/ |
| `openid-configuration` válido | ✅ | `bauth.oidc.discovery` |
| Matriz de features OIDC | ✅ | Este documento §3.1 |
| Rotación de claves (JWKS) | ✅ | `key.rotation` seed (cada 4h) |
| Registro de cambios | ✅ | Git log de `oidc_provider.rs` |

### 3.3 Pasos para certificación

```
1. Ejecutar OIDF Conformance Suite contra bAuth
2. Corregir cualquier test fallido
3. Subir resultados a openid.net
4. Revisión por OpenID Foundation (2-4 semanas)
5. Certificación emitida → logo "OpenID Certified"
```

---

## 4. FIDO ALLIANCE — FIDO2 Authenticator Certification

### 4.1 Perfil Objetivo: FIDO2 Server (Relying Party)

| Requisito | Estado | Evidencia |
|-----------|:---:|------|
| WebAuthn Registration (ceremony) | ✅ | `webauthn.rs` — `start_registration()` + `finish_registration()` |
| WebAuthn Authentication (ceremony) | ✅ | `webauthn.rs` — `start_authentication()` + `finish_authentication()` |
| Challenge generation (random) | ✅ | `ring::rand::SystemRandom` — 32 bytes |
| CTAP 2.1/2.2 support | ✅ | Challenge format compatible |
| User Verification (UV) | ✅ | `userVerification: preferred` |
| Resident Key (RK) | ✅ | `residentKey: preferred` |
| Attestation verification | ⚠️ Básica | `verify_assertion()` — firma + clientDataJSON. Attestation completa pendiente |
| Frontend JavaScript | ✅ | `public/webauthn.js` (195 líneas) |
| Demo page | ✅ | `public/webauthn-demo.html` |

### 4.2 Evidencia para FIDO Alliance

| Documento | Estado | Ubicación |
|-----------|:---:|------|
| FIDO Functional Test Suite | 🔄 Pendiente ejecutar en lab acreditado | — |
| Metadata Statement | 🔄 Pendiente | — |
| Reporte de seguridad | 🔄 Pendiente | — |

### 4.3 Requisitos del Lab Acreditado

Los labs acreditados por FIDO Alliance que pueden certificar:
- **Leidos** (US) — FIDO Functional Certification
- **UL Solutions** (US/Global) — FIDO Authenticator Certification
- **Lightship Security** (US/Canada) — FIDO + NIST

---

## 5. ISO 27001:2022 — VÍA IBNORCA (BOLIVIA)

### 5.1 Controles aplicables a bAuth

| Control | Implementación bAuth | Evidencia |
|---------|---------------------|------|
| A.5.15 Access Control | BitMask Dual 64-bit + 12 dominios | `bitmask/` + `domain/` |
| A.5.16 Identity Management | `idn_user_template` + `idn_role_template` | DDL + seeds |
| A.5.17 Authentication Information | Argon2id + HIBP screening | `password_policy.rs` |
| A.8.2 Privileged Access | Break-Glass SU + PAM | `saga/actions/` |
| A.8.5 Secure Authentication | MFA multi-factor | `auth_methods/` (9 validadores) |
| A.8.9 Configuration Management | `aud_policy_change` WORM | DDL + `policy_admin.rs` |
| A.8.15 Logging | `compliance_test_result` + `certification_certificate` | QA System DDL |

### 5.2 Documentación requerida por IBNORCA

| Documento | Estado | Ubicación |
|-----------|:---:|------|
| Política de Seguridad | 🔄 Pendiente redactar | — |
| Declaración de Aplicabilidad (SoA) | 🔄 Pendiente | 93 controles ISO 27001:2022 |
| Metodología de Riesgos (ISO 27005) | 🔄 Pendiente | — |
| Plan de Tratamiento de Riesgos | 🔄 Pendiente | — |
| Evidencia de controles | ✅ | Este documento + QA System |
| Auditoría interna | 🔄 Pendiente | — |
| Revisión por dirección | 🔄 Pendiente | — |

---

## 6. KANTARA — NIST 800-63 TRUST MARK

### 6.1 Niveles objetivo

| Nivel | Requisito | bAuth |
|------|-----------|:---:|
| **IAL2** | Identity proofing | `idn_user_template` + verificación SEGIP/SERECI |
| **AAL2** | Multi-factor auth | 9 validadores nativos (TOTP, HOTP, WebAuthn, Push) |
| **FAL2** | Federation assurance | OIDC Provider + SAML 2.0 nativos |

### 6.2 Evidencia

| Documento | Estado |
|-----------|:---:|
| IAL/AAL/FAL assertion | 🔄 Pendiente — requiere assessor Kantara |
| Trust Framework conformance | 🔄 Pendiente |
| Privacy assessment | 🔄 Pendiente |

---

## 7. PLAN DE EJECUCIÓN

| Fase | Certificación | Acciones | Timeline |
|------|--------------|---------|----------|
| **Q3 2026** | OIDC Provider | Ejecutar Conformance Suite → corregir → submit | Jul-Sep 2026 |
| **Q4 2026** | ISO 27001 | Contratar auditor IBNORCA → preparar SoA → auditoría Fase 1 | Oct-Dic 2026 |
| **Q1 2027** | FIDO2 | Completar attestation → contratar lab → functional test | Ene-Mar 2027 |
| **Q2 2027** | ISO 27001 | Auditoría Fase 2 → corregir hallazgos → certificación | Abr-Jun 2027 |
| **2028** | Kantara NIST | Trust Mark assessment | 2028 |

---

## 8. ESTADO FINAL DE GAPS

| Gap | Estado | Nota |
|-----|:---:|------|
| ~~G1~~ Compliance tests | ✅ | 23/23 pasan, 100% score |
| ~~G2~~ bnotify + integración | ✅ | Daemon v1.0.0 operativo |
| ~~G3~~ WebAuthn frontend JS | ✅ | `webauthn.js` 195 líneas |
| ~~G4~~ SAML firma XML | ✅ | XML-DSig con ring |
| ~~G5~~ B11 UserTemplate | ✅ | 6 handlers CRUD |
| ~~G6~~ Vault PKI | ✅ | Emisión certificados X.509 |
| ~~G7~~ Catálogo auth_method | ✅ | 28/28 métodos |
| **G8** Certificación externa | 🟡 | **Este documento. Depende de presupuesto y timing.** |

---

*BAUTH-CERTIFICATION-READINESS v1.0 · 2026-06-29 · SKULL*
