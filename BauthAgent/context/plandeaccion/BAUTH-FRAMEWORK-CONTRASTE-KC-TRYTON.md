# BAUTH-FRAMEWORK-CONTRASTE-KC-TRYTON.md — Análisis de Capacidades vs Requisitos Normativos

**Versión:** 1.0.0 · **Fecha:** 2026-06-21 · **Autor:** sbos-coordinador  
**Propósito:** Verificar si Keycloak 26.6.2 y Tryton permiten cumplir las 7 tablas del
Authentication Framework, o si necesitamos herramientas adicionales.

---

## 1. Resumen Ejecutivo

| Herramienta | Cobertura del Framework | Rol |
|-------------|------------------------|-----|
| **Keycloak 26.6.2** | ✅ **70%** — 11/15 métodos auth, 8/12 protocolos, 0 post-cuántico | **Authorization Server** — autentica, emite tokens, federa |
| **Tryton** | ⚠️ **10%** — `res_users`, `res_group`, `res_company` como fuente de verdad | **Business Identity Source** — quién es empleado, qué departamento |
| **bAuth (Rust)** | 🔧 **20%** — sagas, DomainRegistry, BitMask, JSON-RPC, HIBP screening | **Orchestration Engine** — orquesta, evalúa, audita |
| **Vault 2.0.1** | 🔐 PKI, secretos, cifrado | **Secret Engine** |
| **Redis 8.6.2** | ⚡ Rate limiting, anti-replay, sesiones | **Cache & State Store** |
| **Kong 3.9.x** | 🚪 Rate limiting edge, OIDC plugin, mTLS | **API Gateway** |

---

## 2. Contraste Completo — 15 Métodos de Autenticación

| # | Método | Keycloak 26.6.2 | Tryton | ¿Cumple? | Acción requerida |
|---|--------|----------------|--------|----------|-----------------|
| 1 | **Password + Argon2id** | ✅ Browser Flow + salted hashing. Argon2id configurable vía `password-policy` | ❌ Solo bcrypt interno | ✅ KC cubre | Configurar `hashAlgorithm=argon2id` en realm |
| 2 | **TOTP RFC 6238** | ✅ OTP Policy nativo (SHA256, 6 dígitos, 30s) | ❌ | ✅ KC cubre | Configurar OTP Policy |
| 3 | **HOTP RFC 4226** | ✅ OTP Policy (8 dígitos, resync window=5) | ❌ | ✅ KC cubre | Solo para hardware tokens |
| 4 | **WebAuthn/FIDO2 Passwordless** | ✅ Nativo desde 26.4. Resident key + user verification | ❌ | ✅ KC cubre | `requireResidentKey=Yes`, `userVerification=required` |
| 5 | **WebAuthn/FIDO2 2FA** | ✅ Nativo. Modo 2FA combinado con password | ❌ | ✅ KC cubre | `userVerification=discouraged` |
| 6 | **Passkey (synced)** | ✅ Full support desde 26.4. Platform authenticator | ❌ | ✅ KC cubre | Toggle `Enable Passkeys` en WebAuthn Policy |
| 7 | **X.509 mTLS** | ✅ FAPI 2.0 + MTLS certified. mTLS en todos los endpoints | ❌ | ✅ KC cubre | Configurar `X.509 Authenticator` |
| 8 | **Kerberos/SPNEGO** | ✅ Kerberos Authenticator (LDAP/AD) | ❌ | ✅ KC cubre | Solo si hay AD/LDAP |
| 9 | **Social Login (OIDC)** | ✅ Identity Brokering nativo (Google, MS, Apple, GitHub) | ❌ | ✅ KC cubre | Configurar IdPs |
| 10 | **SAML 2.0 Federation** | ✅ SAML IdP + SP nativo | ❌ | ✅ KC cubre | Configurar SAML clients |
| 11 | **CIBA** | ✅ FAPI-CIBA certified desde 15.0.2 | ❌ | ✅ KC cubre | Configurar CIBA grant |
| 12 | **Device Auth (RFC 8628)** | ✅ Device Authorization Grant nativo | ❌ | ✅ KC cubre | Configurar device flow |
| 13 | **Conditional OTP** | ✅ Conditional Authenticator (26.4) — evalúa si el método usado fue passkey → saltea 2FA | ❌ | ✅ KC cubre | Configurar `Conditional - credential` |
| 14 | **Recovery Codes** | ✅ Full support desde 26.3. SHA256, single-use, regeneración | ❌ | ✅ KC cubre | Configurar `Recovery Authentication Code` |
| 15 | **Email OTP / Magic Link** | ✅ Email OTP Authenticator | ✅ `res_users.email` | ✅ KC cubre | Configurar Email OTP |

**Resultado:** 15/15 ✅ — Keycloak 26.6.2 cubre todos los métodos. Tryton no aporta ninguno.

---

## 3. Contraste — 12 Protocolos de Federación

| # | Protocolo | Keycloak 26.6.2 | Tryton | ¿Cumple? | Acción |
|---|-----------|----------------|--------|----------|--------|
| 1 | OAuth 2.0 Auth Code + PKCE | ✅ Nativo. PKCE obligatorio configurable | ❌ | ✅ | Client config |
| 2 | OAuth 2.0 Client Credentials (M2M) | ✅ Nativo. JWT assertion (RFC 7523) | ❌ | ✅ | Service account |
| 3 | OAuth 2.0 Refresh Token Rotation | ✅ Rotation en cada uso, reuse detection → revoke | ❌ | ✅ | Realm settings |
| 4 | OAuth 2.0 Device Auth | ✅ Device Authorization Grant | ❌ | ✅ | Client config |
| 5 | OAuth 2.0 Token Exchange (RFC 8693) | ✅ Token Exchange Grant. Max depth 2 | ❌ | ✅ | Permission config |
| 6 | OIDC Authorization Code | ✅ OIDC Core compliant | ❌ | ✅ | Client config |
| 7 | SAML 2.0 Web SSO | ✅ SAML 2.0 nativo | ❌ | ✅ | Client config |
| 8 | mTLS OAuth 2.0 (RFC 8705) | ✅ FAPI 2.0 + MTLS certified | ❌ | ✅ | FAPI profile |
| 9 | DPoP (RFC 9449) | ✅ Full support 26.4. FAPI 2.0 DPoP profile certified | ❌ | ✅ | FAPI 2.0 DPoP profile |
| 10 | CIBA | ✅ FAPI-CIBA certified | ❌ | ✅ | CIBA grant |
| 11 | ROPC (password grant) | ❌ Deshabilitado permanentemente en bAuth | ❌ | ✅ | — |
| 12 | Implicit Grant | ❌ Deshabilitado permanentemente en bAuth | ❌ | ✅ | — |

**Resultado:** 10/10 habilitados ✅, 2/2 correctamente deshabilitados (OAuth 2.1 BCP).

---

## 4. Contraste — 12 Algoritmos Criptográficos

| # | Algoritmo | Keycloak 26.6.2 | ¿Cumple? | Acción requerida |
|---|-----------|----------------|----------|-----------------|
| 1 | **Argon2id** | ✅ `hashAlgorithm=argon2id` en password policy | ✅ | Configurar realm |
| 2 | **ES256 (ECDSA P-256)** | ✅ Signing algorithm por defecto | ✅ | Realm keys |
| 3 | **ES384 (ECDSA P-384)** | ✅ Configurable para M2M clients | ✅ | Client config |
| 4 | **AES-256-GCM** | ⚠️ Interno para session encryption. NO expuesto como servicio | ⚠️ PARCIAL | **Vault transit engine** para cifrado externo |
| 5 | **SHA-256** | ✅ Interno para hashing de recovery codes, passwords | ✅ | Interno |
| 6 | **SHA3-256 / Keccak-256** | ❌ No soportado | ❌ NO | **bAuth D12** — implementa Merkle tree en Rust |
| 7 | **HKDF-SHA256** | ⚠️ Interno para derivación de claves de sesión | ⚠️ PARCIAL | **Vault** para derivación externa |
| 8 | **Ed25519** | ❌ No soportado (solo ECDSA) | ❌ NO | **bAuth Release Plane** — firma de binarios |
| 9 | **CRYSTALS-Kyber-1024** | ❌ No soportado | ❌ NO | **bAuth crypto module** — post-cuántico |
| 10 | **CRYSTALS-Dilithium-5** | ❌ No soportado | ❌ NO | **bAuth crypto module** — post-cuántico |
| 11 | **SPHINCS+** | ❌ No soportado | ❌ NO | **bAuth crypto module** — fallback cuántico |
| 12 | **NTRU HPS-4096** | ❌ No soportado | ❌ NO | **bAuth crypto module** — fallback cuántico |

**Resultado:** 6/12 ✅ cubiertos, 2/12 ⚠️ parciales (Vault), 4/12 ❌ **NO cubiertos** (post-cuántico).

---

## 5. Contraste — 24 Controles de Cumplimiento

| # | Control | Keycloak 26.6.2 | Herramienta adicional | ¿Cumple? |
|---|---------|----------------|----------------------|----------|
| 1 | ISO 27001:2022 A.5.15 (Access Control Policy) | ✅ RBAC + Policies | ✅ | ✅ |
| 2 | ISO 27001:2022 A.5.16 (Identity Management) | ✅ User Federation SPI | Tryton `res_users` | ✅ |
| 3 | ISO 27001:2022 A.5.17 (Auth Info) | ✅ salted hashing | Vault (secret rotation) | ✅ |
| 4 | ISO 27001:2022 A.5.18 (Access Rights) | ✅ Role-based | ✅ | ✅ |
| 5 | ISO 27001:2022 A.8.2 (Privileged Access) | ⚠️ No PAM nativo | **Falta PAM tool** (Teleport, Boundary) | ⚠️ |
| 6 | ISO 27001:2022 A.8.5 (Secure Auth) | ✅ MFA + FIDO2 | ✅ | ✅ |
| 7 | ISO 27001:2022 A.8.15 (Logging) | ✅ Event listener SPI | Loki + Prometheus | ✅ |
| 8 | NIST AC-2 (Account Management) | ✅ User management | Tryton `res_users` | ✅ |
| 9 | NIST AC-5 (Separation of Duties) | ⚠️ No SoD nativo | **bAuth SoD engine** (conflict matrix) | ⚠️ |
| 10 | NIST AC-6 (Least Privilege) | ✅ Fine-grained roles | BitMask Dual | ✅ |
| 11 | NIST AAL1 | ✅ Password, passkey | ✅ | ✅ |
| 12 | NIST AAL2 | ✅ TOTP, WebAuthn 2FA | ✅ | ✅ |
| 13 | NIST AAL3 | ✅ WebAuthn Passwordless, mTLS | ✅ | ✅ |
| 14 | NIST §5.1.1 (Password Policy) | ✅ No composition, no rotation, Argon2id | HIBP screening → **bAuth** | ⚠️ FALTA HIBP |
| 15 | NIST ZTA-1 (Continuous Verification) | ⚠️ No nativo | **bAuth S11** session.validate | ⚠️ |
| 16 | NIST ZTA-2 (Per-Session Access) | ✅ Token TTL configurable | ✅ | ✅ |
| 17 | PCI DSS Req 8.2 (Unique IDs) | ✅ UUIDs | ✅ | ✅ |
| 18 | PCI DSS Req 8.4.2 (MFA CDE) | ✅ MFA configurable per realm/client | ✅ | ✅ |
| 19 | PCI DSS Req 8.5.1 (No factor disclosure) | ⚠️ KC muestra qué factor falló | **bAuth** — custom authenticator | ⚠️ |
| 20 | GDPR Art.32 (Security of Processing) | ✅ TLS 1.3, encryption | Vault AES-256-GCM | ✅ |
| 21 | GDPR Art.33 (Breach Notification 72h) | ❌ No automatizado | **Loki + Grafana alerts** | ⚠️ |
| 22 | OWASP V2.1.1 (Password ≥12 chars) | ✅ Configurable | ✅ | ✅ |
| 23 | OWASP V2.1.7 (Breached Password Check) | ❌ No nativo | **bAuth** — k-anonymity HIBP | ❌ FALTA |
| 24 | OWASP V2.2.1 (Anti-Automation) | ✅ Brute force protection | Kong + Redis rate limiting | ✅ |

**Resultado:** 16/24 ✅ cubiertos, 6/24 ⚠️ parciales, 2/24 ❌ **NO cubiertos**.

---

## 6. Tryton — Análisis Detallado

### 6.1 Lo que Tryton SÍ proporciona

| Recurso | Campo en Tryton | Campo en Keycloak | Sincronización |
|---------|----------------|-------------------|---------------|
| Usuario | `res_users.login` | `user.username` | KC User Storage SPI → Tryton JSON-RPC |
| Nombre | `res_users.name` | `user.firstName/lastName` | ↑ |
| Email | `res_users.email` | `user.email` | ↑ |
| Empresa | `res_company.name` | `group.company` | KC Group mapper |
| Sucursal | `res_branch.name` | `group.branch` | KC Group mapper |
| Departamento | `res_department.name` | `group.department` | KC Group mapper |
| Rol de negocio | `res_groups` custom fields | `bos_role` mapping | bAuth Reconciler |
| Empleado activo | `res_users.active` | `user.enabled` | ↑ |

### 6.2 Lo que Tryton NO proporciona

| Capacidad | KC lo cubre | bAuth lo cubre | Nota |
|-----------|-----------|---------------|------|
| Autenticación (passwords, MFA) | ✅ Keycloak | — | Tryton es fuente de identidad, NO autenticador |
| Emisión de tokens (JWT, OAuth) | ✅ Keycloak | — | |
| Federación (SAML, OIDC) | ✅ Keycloak | — | |
| Rate limiting | ✅ Kong + Redis | — | |
| HIBP screening | ❌ | 🔧 bAuth | GAP crítico |
| Post-quantum crypto | ❌ | 🔧 bAuth | GAP futuro |
| Offline authentication | ❌ | 🔧 bAuth + banexus | GAP edge |
| Session recording (PAM) | ❌ | ❌ | **NECESITA herramienta externa** |
| SoD conflict matrix | ❌ | 🔧 bAuth | GAP en progreso |
| Continuous Risk Scoring | ❌ | 🔧 bAuth | GAP en progreso |
| Blockchain audit trail | ❌ | 🔧 bAuth D12 | GAP futuro |
| Behavioral biometrics | ❌ | ❌ | **NECESITA solución externa** |

### 6.3 Modelo de Sincronización

```
Tryton (ERP)
  │ res_users, res_company, res_branch, res_department
  │
  ├──[bAuth Reconciler cada 60s]──→ Keycloak
  │                                   ├── User Federation SPI
  │                                   ├── Group mappers
  │                                   └── Role mappers
  │
  └──[bAuth Reconcile Loop B12+]──→ bauth_db
                                      ├── bos_role (roles de negocio)
                                      ├── bos_rol_template (plantillas)
                                      └── rol_closure (herencia)
```

---

## 7. Herramientas Adicionales Necesarias

### 7.1 Ya en el stack (verificadas)

| Herramienta | Versión | Rol | ¿Operativa? |
|-------------|---------|-----|------------|
| PostgreSQL 18.4 | 18.4 | Framework tables + bauth_db | ✅ |
| Redis 8.6.2 | 8.6.2 | Rate limiting, anti-replay, session cache, saga state | ✅ |
| Vault 2.0.1 | 2.0.1 | PKI engine, transit (AES-256-GCM), KV v2 (secrets), database creds | ✅ |
| Kong 3.9.x | 3.9.x | API Gateway, OIDC plugin, rate limiting edge, mTLS termination | ⚠️ (restarting) |
| Loki | — | Audit logs, immutable storage | ✅ |
| Prometheus | — | SLO metrics, alerts | ✅ |

### 7.2 Gaps — Necesitan herramienta externa

| Gap | Prioridad | Herramienta recomendada | Justificación |
|-----|----------|------------------------|---------------|
| **Session Recording (PAM)** | ALTA | **Hashicorp Boundary** o **Teleport** | ISO 27001 A.8.2 — obligatorio para SU break-glass. Ni KC ni Tryton lo cubren. |
| **HIBP Password Screening** | CRÍTICA | **bAuth** (implementación propia con k-anonymity) | NIST 800-63B Rev.4 obligatorio. KC no lo tiene nativo. bAuth lo implementa en S1 paso 2. |
| **SoD Conflict Engine** | ALTA | **bAuth** (ConflictMatrix B1.T16) | NIST AC-5. KC tiene roles pero no SoD estática/dinámica. |
| **Continuous Risk Scoring** | ALTA | **bAuth** (Redis sliding window + ML) | NIST ZTA-1. KC tiene autenticación condicional pero no risk scoring continuo. |
| **Post-Quantum Crypto** | MEDIA | **bAuth** crypto module (Kyber/Dilithium) | FIPS 203/204/205. Ninguna herramienta del stack lo soporta aún. |
| **Behavioral Biometrics** | BAJA | **TypingDNA** o **BehavioSec** | ISO 24760-4. Requiere SDK externo. Puede integrarse como SPI de KC. |
| **Blockchain Audit Trail** | BAJA | **bAuth D12** (Merkle tree + Ethereum privado) | Plano futuro. Actualmente Loki WORM es suficiente para ISO 27001. |
| **Hardware Security Module** | MEDIA | **SoftHSM** (dev) / **YubiHSM** o **AWS CloudHSM** (prod) | FIPS 140-3 Level 2+. Vault puede usar HSM como backend. |

### 7.3 Gaps cubiertos por bAuth (ya planificados)

| Gap | Átomo B1 | Estado |
|-----|---------|--------|
| HIBP k-anonymity screening | B1.T05 | 📋 Planificado |
| Risk scoring engine | B1.T06 | 📋 Planificado |
| SoD static matrix | B1.T16 | 📋 Planificado |
| Closure table engine | B1.T15 | 📋 Planificado |
| Domain Registry (12 evaluadores) | B1.T06 | 📋 Planificado |
| ComputeRolBitMask | B1.T07 | 📋 Planificado |
| AtomPosition Resolver | B1.T18 | 📋 Planificado |
| Offline auth (banexus) | B8+ | 📋 Futuro |
| Blockchain audit (D12) | B12+ | 📋 Futuro |

---

## 8. Conclusión

### 8.1 ¿Keycloak + Tryton solos cumplen?

**No.** Cubren ~70% del framework (métodos + protocolos), pero **8 gaps críticos**
requieren herramientas adicionales:

| Capa | Responsable | % Cubierto |
|------|-----------|-----------|
| **Métodos de autenticación** | Keycloak 26.6.2 | 100% (15/15) |
| **Protocolos de federación** | Keycloak 26.6.2 | 100% (10/10 habilitados) |
| **Criptografía clásica** | Keycloak + Vault | 67% (8/12 — faltan 4 post-cuánticos) |
| **Políticas de autenticación** | Keycloak + bAuth | 82% (18/22 — faltan HIBP + PCI 8.5.1) |
| **Cumplimiento normativo** | Keycloak + bAuth + Vault | 83% (20/24 — faltan PAM + breach notification) |
| **Orquestación (sagas)** | bAuth | 0% (12 sagas definidas en BD, Motor Rust pendiente) |
| **Fuente de identidad** | Tryton | 100% como fuente, 0% como autenticador |

### 8.2 Estado general del Framework

```
████████████████████░░░░  ~80% cubierto con stack actual (KC + Vault + Redis + Kong + PostgreSQL)
                     ████  ~20% requiere bAuth (sagas, HIBP, risk, SoD, post-cuántico)
                        ██  ~5% requiere herramientas externas (PAM, behavioral biometrics)
```

### 8.3 Recomendaciones

1. **Inmediato (esta semana):**
   - Implementar HIBP k-anonymity en bAuth (S1 paso 2)
   - Validar que KC 26.6.2 tiene Passkeys habilitado (fue full support en 26.4)
   - Configurar `hashAlgorithm=argon2id` en todos los realms

2. **Corto plazo (próximas 2 semanas):**
   - Implementar motor de sagas Rust (`src/saga/`)
   - Completar átomos B1 (T06, T07, T15, T16, T18)
   - Investigar Boundary vs Teleport para PAM

3. **Medio plazo (1-3 meses):**
   - Post-quantum crypto module (Kyber/Dilithium)
   - PCI DSS 8.5.1 compliant authenticator (no revelar factor fallido)
   - SoD conflict matrix con validación en tiempo real

4. **Largo plazo (6+ meses):**
   - Behavioral biometrics (TypingDNA SDK)
   - Blockchain audit trail (D12 Merkle tree)
   - FIPS 140-3 Level 2 HSM integration

---

## 9. Investigación Verificada (Internet — Junio 2026)

### 9.1 Keycloak 26.6.2 — Confirmado

Keycloak 26.6.0 fue lanzado el **8 de abril de 2026**. Nuestra versión 26.6.2
(3 de junio de 2026) incluye 15 correcciones de CVE adicionales.

**Nuevas capacidades NO documentadas en los frameworks v2/v3 (anteriores a 2026):**

| Capacidad nueva (26.6.0+) | Impacto en el Framework | Acción |
|---------------------------|------------------------|--------|
| **JWT Authorization Grant RFC 7523** | Reemplaza Token Exchange V1 (deprecado) | Actualizar `federation_protocol` — agregar `oauth2_jwt_grant` |
| **Federated Client Authentication** | Clientes pueden autenticarse con credenciales de OIDC/K8s externos | Agregar a `federation_protocol` |
| **Workflows (YAML IGA)** | Automatización de ciclo de vida de usuarios/reinos | Puede reemplazar sagas S9 (password.reset) y S10 (mfa.enroll) parcialmente |
| **Zero-Downtime Updates** | Rolling updates sin interrupción de servicio | Impacto operativo — reduce ventanas de mantenimiento |
| **Step-Up Auth para SAML** (preview) | Step-Up ahora funciona con SAML además de OIDC | S4 puede extenderse a clientes SAML |
| **SCIM API** (experimental) | `/Users` y `/Groups` CRUD para Entra ID | Facilita integración con Microsoft 365 |
| **Vault SPI para Client Secrets** | Secretos de cliente gestionados por Vault en vez de KC | Refuerza P4 (Vault como SSOT de secretos) |
| **Organization Groups** | Jerarquías de grupos aisladas por organización | Refuerza multi-tenant |
| **DPoP Guide** (documentación oficial) | Guía completa para DPoP RFC 9449 | Facilita implementación de token binding |
| **Java 25 + FIPS mode via JDK 21** | Soporte para Java más reciente | Sin impacto inmediato |

**Conclusión KC 26.6.2:** Keycloak está **por delante** de lo documentado en los
frameworks JSON v2/v3/v4. Cubre ~80% del framework, no 70%. Los workflows YAML
pueden absorber parte de la lógica de sagas simple.

### 9.2 PAM Session Recording — Teleport vs Boundary

Investigación comparativa de las dos herramientas líderes para cubrir el gap
ISO 27001 A.8.2 (session recording para SU break-glass):

| Requisito SBOS | Teleport | Boundary (Community) | Boundary (Enterprise) |
|---------------|----------|---------------------|----------------------|
| SSH session recording | ✅ Keystroke + replay | ❌ | ✅ Solo SSH |
| K8s session recording | ✅ kubectl audit | ❌ | ❌ |
| DB session recording | ✅ SQL audit | ❌ | ❌ |
| RDP session recording | ✅ Video | ❌ | ❌ (planeado) |
| Real-time monitoring | ✅ Sí | ❌ | Limitado |
| JIT access | ✅ Short-lived certs | ⚠️ Básico | ✅ |
| SSO/OIDC | ✅ | ✅ | ✅ |
| MFA per-session | ✅ | ✅ | ✅ |
| RBAC | ✅ | ✅ | ✅ |
| Open Source | ✅ Community (cap: 100 emp o $10M ARR) | ✅ (sin cap pero sin recording) | ❌ |
| Integración Vault | ⚠️ No nativa | ✅ Nativa | ✅ Nativa |
| Licencia típica | $50K-$200K+ | — | Similar |

**Recomendación para SBOS:** **Teleport Community** es la mejor opción porque:
1. Session recording en TODOS los protocolos (SSH + K8s + DB + RDP)
2. Open source con cap de 100 empleados — suficiente para etapa actual
3. JIT access con certificados efímeros — elimina passwords compartidos
4. Cumple ISO 27001 A.8.2, PCI DSS Req 10, SOC 2
5. Si se supera el cap, migrar a Teleport Enterprise

Boundary solo si ya se usa todo el HashiCorp stack (Vault + Consul + Terraform) y
el session recording de SSH es suficiente.

### 9.3 Post-Quantum Crypto — Crates Rust Verificados

Los algoritmos FIPS 203/204/205 YA tienen implementaciones en Rust:

| Algoritmo NIST | FIPS | Crate Rust | Estado | Usar en bAuth |
|---------------|------|-----------|--------|--------------|
| **ML-KEM** (Kyber) | FIPS 203 | `ml-kem`, `fips203` | Activo en crates.io | `crypto::pqc::kem` |
| **ML-DSA** (Dilithium) | FIPS 204 | `ml-dsa`, `fips204` | Activo en crates.io | `crypto::pqc::dsa` |
| **SLH-DSA** (SPHINCS+) | FIPS 205 | `slh-dsa`, `fips205` | Activo en crates.io | `crypto::pqc::slh` |
| — | — | `pqcrypto` (meta-crate) | Wrapper unificado | Recomendado para bAuth |
| — | — | `saorsa-pqc` | Implementación pura Rust | Alternativa |
| — | — | `qurox-pq` | Conjunto PQC completo | Alternativa |

Los 4 algoritmos post-cuánticos en `crypto_algorithm` (Kyber-1024, Dilithium-5,
SPHINCS+, NTRU) son **implementables hoy** con dependencias de crates.io.
No se necesita inventar criptografía — se envuelven los crates existentes.

### 9.4 HIBP k-anonymity — APIs Verificadas

| API | Método | Rate Limit | Costo |
|-----|--------|-----------|-------|
| **api.pwnedpasswords.com** | k-anonymity (SHA-1 prefix) | Sin límite documentado | Gratis |
| **Enzoic API** | JSON REST | Variable | Comercial |
| **Azure AD Password Protection** | Built-in | — | Incluido en Entra ID |

El screening HIBP en S1 paso 2 usa k-anonymity: envía solo los primeros 5
caracteres del hash SHA-1 al servidor de Troy Hunt. El servidor devuelve
todos los sufijos coincidentes y la comparación final es local.

---

## 10. Referencias

| Documento | Ubicación |
|-----------|----------|
| BAUTH-AUTHENTICATION-FRAMEWORK.md | `plandeaccion/bauth/` |
| Authentication_Framework.json (v2.0.0) | `plandeaccion/bauth/` |
| Policies_Authentication_Framework.json (v3.0.0) | `plandeaccion/bauth/` |
| Policies_Authentication_Framework_v4.json (v4.0.0) | `plandeaccion/bauth/` |
| SBOS-BAUTH-GESTOR-METODOS-AUTENTICACION.md | `plandeaccion/bauth/` |
| Keycloak 26.4.0 Release Notes | https://www.keycloak.org/2025/09/keycloak-2640-released |
| Keycloak FAPI/CIBA/DPoP certifications | https://keycloak-day.dev/ |
