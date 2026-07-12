# Anexo A.15 — El Stack Rust de Autenticación: librerías, cobertura del código real y brechas
## Documento de respaldo: qué cubre el código HOY, qué está parcial, qué falta — y qué exigen las normas y la industria

**Tipo:** ANEXO — respaldo de sustentación del desarrollo (tipo D: decisión técnica + **verificación de código real**)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** MANUAL-AUTENTICACION (2.01 §3-§4) · MANUAL-METODOS (2.02) · MANUAL-TOKENS (2.03) · MANUAL-SEGURIDAD-DATOS (2.10 §reposo)
**Verificación de código:** `Cargo.toml` + `src/domain/auth_methods/` + `src/domain/{password,jwt_*,jwe_encrypt}` — leída 2026-07-11
**Normas base:** NIST SP 800-63B (métodos) · FIPS 140-3/180-4/186-5/197/202 · RFC 6238/4226/8032/7515/7516 · W3C WebAuthn L3

---

## 1. Propósito

Dar al desarrollador la **sustentación técnica sin fricciones**: qué librería usa (o debe usar)
cada método de autenticación, qué está implementado en el código real con evidencia, qué está
parcialmente resuelto (con la brecha ESPECÍFICA) y qué falta pero las normas y la industria del
sector exigen. **Cómo citarlo:** `A.15 §2` (el stack) · `A.15 §4` (las brechas).

**El principio arquitectónico que gobierna la selección (la independencia de bAuth):** bAuth es
**cuasi-totalmente independiente de herramientas externas** — implementa nativamente lo que es
CORE de identidad (WebAuthn, JWT/JWE, SAML, evaluación) y usa crates auditados solo para
PRIMITIVAS criptográficas (RustCrypto/ring). Un IdP no delega su corazón a frameworks de
terceros: los crates de conveniencia (`auth-framework`, `webauthn-rs` completo) traen
dependencias y decisiones ajenas; las primitivas auditadas traen solo matemática verificada.
Esta es la materialización en código de la soberanía (carta rectora 0.00 §5) y del ADR-010.

## 2. El stack REAL verificado (Cargo.toml, 2026-07-11)

| Capa | Crate (versión) | Para qué | Norma |
|---|---|---|---|
| Hashing de contraseñas | `argon2 0.5` (RustCrypto) | Argon2id — parámetros por tier en `auth_config` | 800-63B · OWASP |
| Hash | `sha1/sha2/sha3 0.10` | SHA-1 (solo handshake WS RFC 6455) · SHA-256/512 · Keccak-256 (Merkle D12) | FIPS 180-4/202 |
| Firma | `ed25519-dalek 2` | EdDSA Ed25519 — JWT propio, certificados, exports | FIPS 186-5 · RFC 8032 |
| Cifrado autenticado | `aes-gcm 0.10` | AES-256-GCM — JWE A256GCM | FIPS 197 · SP 800-38D |
| Derivación | `hkdf 0.12` | HKDF | SP 800-56C · RFC 5869 |
| Higiene de secretos | `zeroize 1` | Borrado seguro en memoria | SP 800-57 |
| CSPRNG | `rand 0.8` | Generación de claves/nonces/diceware | SP 800-90A |
| TLS/primitivas ct | `ring 0.17` | BoringSSL auditado — X25519, constant-time | — |
| TOTP base | `data-encoding 2.6` | Base32 del enrolamiento (RFC 6238) | RFC 6238 |
| BitMask | `bitvec 1` | Rol BitMask one-hot (ADR-009) | — |
| BD / HTTP / gRPC | `sqlx 0.8` (rustls) · `reqwest 0.12` (HIBP) · `tonic 0.12`+`prost` (CAEP a bNotify por Unix socket) | Persistencia · screening · señales | — |
| Runtime | `tokio 1.45` · `uuid 1` (v4+**v7**) · `tracing` | Async · IDs · observabilidad | RFC 9562 |

**Implementaciones PROPIAS (nativas, sin crate de terceros) — la independencia en acción:**
`webauthn.rs` (189 líneas) · `totp.rs` (293) · `hotp.rs` (78) · `email_otp.rs` (100) ·
`push.rs` (115) · `recovery.rs` (101) · `saml.rs`+`saml_signature.rs` (358) · `mtls.rs` (134) ·
`password/` · `jwt_builder.rs` (377) + `jwt_signer.rs` (177) · `jwe_encrypt.rs` (155).

## 3. Cobertura por método — verificado contra el código

| Método (2.01 §4) | Módulo real | Estado | Evidencia |
|---|---|:---:|---|
| Password (Argon2id + HIBP + historial) | `password/` + `argon2` + `reqwest` | ✅ cubierto | Cargo + módulo |
| TOTP (RFC 6238) | `totp.rs` (293 líneas — el más desarrollado) | ✅ cubierto | módulo |
| HOTP (RFC 4226) | `hotp.rs` | ✅ cubierto | módulo |
| WebAuthn/passkey | `webauthn.rs` | ⚠️ **parcial** — ver §4-B1 | 189 líneas; 1 sola mención attestation/AAGUID/user_verification |
| Email OTP | `email_otp.rs` | ✅ cubierto (envío vía bNotify) | módulo |
| Push (Ed25519) | `push.rs` | ✅ cubierto | módulo |
| Recovery codes | `recovery.rs` | ✅ cubierto | módulo |
| SAML 2.0 (federación entrante) | `saml.rs` + `saml_signature.rs` | ⚠️ parcial — ver §4-B2 | módulos |
| mTLS / X.509 | `mtls.rs` | ⚠️ **parcial** — ver §4-B3 | 134 líneas; **0 menciones de parsing X.509** |
| JWT propio (firma Ed25519) | `jwt_builder.rs` + `jwt_signer.rs` | ✅ cubierto | 554 líneas |
| JWE (A256GCM) | `jwe_encrypt.rs` + `aes-gcm` | ✅ cubierto | módulo |

## 4. Las brechas ESPECÍFICAS — lo que falta y lo que la norma/industria exige

| # | Brecha específica (verificada en código) | Qué exige la norma/industria | Resolución recomendada |
|---|---|---|---|
| **B1** | **WebAuthn sin attestation completa:** `webauthn.rs` valida la assertion pero no evidencia verificación de attestation por AAGUID contra metadata (FIDO MDS), ni políticas por tipo de autenticador | W3C WebAuthn L3 (attestation) · FIDO MDS — la industria lo resuelve con `webauthn-rs-core` (operaciones criptográficas WebAuthn, mantenido, actualización 2026) | Completar nativo con `webauthn-rs-core` SOLO como primitiva criptográfica (no el framework completo — preserva la independencia), o implementar attestation packed/none + verificación AAGUID contra el catálogo `auth_method` |
| **B2** | **SAML con superficie mínima:** firma propia (`saml_signature.rs`) — sin evidencia de canonicalización XML completa (C14N) ni protección XSW (XML Signature Wrapping) | SAML 2.0 core · los ataques XSW son el vector clásico — OWASP | Verificación profunda del módulo en la fase de federación entrante (brecha P1 de 0.00 §8 pilar I); test vectors de XSW obligatorios |
| **B3** | **mTLS sin parsing X.509 propio:** `mtls.rs` no parsea certificados (0 menciones) — la validación depende del terminador TLS | RFC 5280 (validación de cadena, KU/EKU, revocación) · la industria usa `x509-parser` (Rust puro) | Si el binding certificado→identidad exige campos del cert (SAN, serial → `ath_binding`), incorporar `x509-parser` como primitiva de lectura |
| **B4** | **Redis DESACTIVADO (H-019, comentado en Cargo.toml):** el cache del BitMask (TTL 30 s) y las sesiones ctx en Redis NO están operativos — hoy todo va a PostgreSQL | El propio diseño (1.04: BitmaskBundle en cache; 1.13 §9.3 paso 9: invalidación) | Activar `redis 0.28` (tokio-comp) cuando la infraestructura esté; **hasta entonces la invalidación post-cambio es un no-op documentado** — riesgo conocido |
| **B5** | **Sin crate JOSE de terceros** (decisión): JWT/JWE propios | RFC 7515/7516 — cumplidos por implementación propia; exige **test vectors oficiales** (7.02 Calidad: vectores RFC en `compliance_test_case`) | Mantener propio (independencia) + completar vectores oficiales en el subsistema de calidad |
| **B6** | **PQC no presente en el stack** (ni ML-KEM ni ML-DSA) | FIPS 203/204 — el corpus lo declara "pendiente activar" (7.03 §5.3) | Cuando se active: crates RustCrypto `ml-kem`/`ml-dsa` (en maduración) — decisión de fase, no deuda actual |

## 5. Verificación de completitud

18 métodos del catálogo (2.02) vs 9 nativos implementados (2.01 §4): los restantes (CIBA,
device auth, token exchange, client credentials, social brokering…) son **flujos** sobre las
mismas primitivas — su estado vive en 2.01/2.02 y el catálogo declarativo `auth_method`
(`nist_status`). Este anexo cubre las LIBRERÍAS; los flujos faltantes están enrutados como
brechas en sus manuales (0.00 §8 pilar I).

## 6. Referencias e historial

**Del código:** `Cargo.toml` · `src/domain/auth_methods/` · `src/domain/{jwt_builder,jwt_signer,jwe_encrypt}.rs`.
**Industria (2026-07-11):** [lib.rs/authentication](https://lib.rs/authentication) · [webauthn-rs](https://crates.io/crates/webauthn-rs) · [webauthn-rs-core](https://crates.io/crates/webauthn-rs-core) · [argon2 (RustCrypto)](https://lib.rs/crates/argon2) · [categoría authentication en crates.io](https://crates.io/categories/authentication)

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial del patrón de sustentación (tipo D): el stack real verificado en Cargo.toml (primitivas RustCrypto/ring + implementaciones nativas propias como materialización de la independencia de bAuth), cobertura por método con evidencia de módulos, y **6 brechas específicas** (B1 attestation WebAuthn, B2 XSW/C14N SAML, B3 parsing X.509, B4 Redis H-019 desactivado — invalidación de cache no operativa, B5 test vectors JOSE, B6 PQC de fase) con la exigencia normativa y la resolución recomendada de cada una. |
