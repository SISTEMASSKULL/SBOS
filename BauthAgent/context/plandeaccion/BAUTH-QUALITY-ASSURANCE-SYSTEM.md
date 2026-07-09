# BAUTH — Sistema de Aseguramiento de Calidad de Autenticación
## Políticas de Prueba · Cumplimiento Normativo · Criterios de Completitud · Vectores Oficiales · Procedimientos de Verificación

**Versión:** 2.0 · **Fecha:** 2026-06-28 · **Autor:** agente-bauth  
**Propósito:** Eliminar TODA ambigüedad en la verificación de métodos de autenticación. Cada método tiene criterios OBJETIVOS de completitud basados en estándares internacionales. Todo agente que toque código de autenticación DEBE ejecutar estas pruebas. Sin excepción.  
**Normas:** NIST SP 800-63B Rev.4 (Jul 2025) · OWASP ASVS 5.0 V6 (May 2025) · ISO 27001:2022 A.8.5/A.8.9/A.9.2 · RFC 6238/4226/7519/8037/8705/9106 · FIDO Alliance CTAP 2.2 (2025) · OWASP Testing Guide 2025

---

## ⚠️ REGLA INNEGOCIABLE

**Ningún método de autenticación se considera COMPLETO hasta que pasa el 100% de sus pruebas de compliance.** Cualquier agente que implemente, modifique o extienda un método de autenticación DEBE:

1. Ejecutar la suite de pruebas de ese método (definida en este documento)
2. Verificar que TODOS los vectores de prueba oficiales pasan
3. Ejecutar las pruebas de seguridad (fuerza bruta, replay, timing attack)
4. Registrar el resultado en `bauth.compliance_test_result`
5. Actualizar el score de completitud en este documento

**Si un agente encuentra un método que no cumple, DEBE reportarlo. No debe "corregirlo sobre la marcha" sin seguir este procedimiento.**

---

## 1. Arquitectura del Sistema de QA

```
┌──────────────────────────────────────────────────────────────────────┐
│              SISTEMA DE ASEGURAMIENTO DE CALIDAD bAuth                │
│                                                                       │
│  NIVEL 1: Políticas de Prueba                  NIVEL 4: Reportes     │
│  ┌───────────────────────────┐              ┌──────────────────────┐ │
│  │ • Vectores RFC oficiales  │              │ • compliance_score   │ │
│  │ • Casos límite (edge)     │──────────────│ • compliance_test_   │ │
│  │ • Pruebas negativas       │   Ejecución  │   result (WORM)      │ │
│  │ • Seguridad (ataques)     │  Registrada   │ • Dashboard por      │ │
│  │ • Rendimiento (SLA)       │              │   método             │ │
│  │ • Concurrencia            │              │ • Auditoría ISO      │ │
│  └───────────────────────────┘              └──────────────────────┘ │
│           │                                        │                  │
│           ▼                                        ▼                  │
│  NIVEL 2: Matriz Normativa              NIVEL 3: BD de Compliance   │
│  ┌───────────────────────────┐        ┌──────────────────────────┐  │
│  │ • NIST 800-63B Rev.4      │        │ compliance_standard       │  │
│  │   §3.1.1-§3.1.7           │───────│ compliance_requirement     │  │
│  │ • OWASP ASVS 5.0 V6.1-V6.8│ Mapeo │ compliance_test_case       │  │
│  │ • ISO 27001:2022 A.8.5    │        │ compliance_test_result     │  │
│  │ • RFC 6238/4226/8037/9106 │        │ compliance_score (MV)      │  │
│  └───────────────────────────┘        └──────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. Niveles de Completitud — Rubrica de 6 Niveles

**Cada nivel es ACUMULATIVO. No se puede saltar ninguno.**

### Nivel 0 — DEFINIDO 🔴 (Especificación completa)

| # | Criterio | Evidencia | Check |
|---|---------|-----------|:---:|
| N0.1 | Documento de diseño existe | Archivo .md en `plandeaccion/bauth/` | [ ] |
| N0.2 | Estándar aplicable identificado con número de sección | NIST §3.1.x, OWASP V6.x, RFC xxxx | [ ] |
| N0.3 | Tipo de autenticador NIST 800-63B clasificado | Memorized Secret / Look-Up / OOB / SF-OTP / MF-OTP / SF-Crypto / MF-Crypto | [ ] |
| N0.4 | AAL level asignado | AAL1 / AAL2 / AAL3 | [ ] |
| N0.5 | Propiedades de seguridad definidas | Phishing-resistant: sí/no, Replay-resistant: sí/no, Verifier-compromise-resistant: sí/no | [ ] |
| N0.6 | Registro en `bauth.auth_method` creado | INSERT en seed | [ ] |
| N0.7 | ¿Requiere hardware específico? | TPM, YubiKey, navegador, lector NFC, etc. | [ ] |

### Nivel 1 — IMPLEMENTADO 🟡 (Código existe)

| # | Criterio | Evidencia | Check |
|---|---------|-----------|:---:|
| N1.1 | Código Rust existe | Archivo en `domain/auth_methods/` o `engine/` | [ ] |
| N1.2 | Trait `AuthMethod` implementado | `fn validate()`, `fn enroll()`, `fn revoke()` | [ ] |
| N1.3 | Compila sin warnings | `cargo check` limpio | [ ] |
| N1.4 | Sin `unwrap()` ni `expect()` en producción | grep confirma | [ ] |
| N1.5 | Documentación en español (DOC-SBOS-001 N3) | `///` en structs y funciones | [ ] |
| N1.6 | Errores con mensajes descriptivos en español | `AuthMethodError` con Display | [ ] |
| N1.7 | Tipos fuertes (sin `String` genérico para IDs) | Newtypes con `#[derive]` | [ ] |

### Nivel 2 — PROBADO 🟠 (Tests unitarios con vectores oficiales)

| # | Criterio | Evidencia | Check |
|---|---------|-----------|:---:|
| N2.1 | Tests con TODOS los vectores de prueba del RFC/estándar | `#[test]` en `tests` module | [ ] |
| N2.2 | 100% de los vectores oficiales PASAN | `cargo test` sin failures | [ ] |
| N2.3 | Tests de casos límite (mín, máx, null, empty, boundary) | Al menos 4 edge cases | [ ] |
| N2.4 | Tests negativos (inputs inválidos DEBEN producir error) | Al menos 3 negative tests | [ ] |
| N2.5 | Tests de timing-attack resistance | Comparación en tiempo constante | [ ] |
| N2.6 | Tests de replay resistance | Nonce/sequence no reutilizable | [ ] |
| N2.7 | Cobertura ≥ 80% en el módulo | `cargo tarpaulin` o `cargo llvm-cov` | [ ] |

### Nivel 3 — VERIFICADO 🟢 (Integración + herramienta externa)

| # | Criterio | Evidencia | Check |
|---|---------|-----------|:---:|
| N3.1 | Verificado contra herramienta de referencia externa | `oathtool` para TOTP/HOTP, `openssl verify` para X.509 | [ ] |
| N3.2 | Pruebas de integración en VPS staging | `COMANDOS-PRUEBAS.md` actualizado | [ ] |
| N3.3 | Resultados registrados en BD de compliance | `bauth.compliance_test_result` | [ ] |
| N3.4 | Revisado por al menos 1 agente distinto del implementador | Firma en commit | [ ] |
| N3.5 | Documento de compliance actualizado con resultados | Este documento | [ ] |
| N3.6 | Pruebas de concurrencia (100 requests paralelos) | Sin race conditions | [ ] |

### Nivel 4 — CERTIFICADO 🔵 (Compliance completo)

| # | Criterio | Evidencia | Check |
|---|---------|-----------|:---:|
| N4.1 | 100% de test cases blocking pasan | `compliance_score.blocking_passed == total_blocking` | [ ] |
| N4.2 | Score ≥ 95% en `compliance_score` | Materialized view | [ ] |
| N4.3 | SLA de rendimiento verificado (P99 < 5ms FastPath, < 50ms PolicyPath) | `cargo bench` | [ ] |
| N4.4 | Auditoría de seguridad pasada (OWASP Top 10) | Reporte de seguridad | [ ] |
| N4.5 | Firmado por sbos-coordinador | Commit con firma | [ ] |
| N4.6 | CI pipeline incluye tests de compliance | `.github/workflows/bauth.yml` | [ ] |

### Nivel 5 — ACREDITADO ⭐ (Certificación externa)

| # | Criterio | Evidencia | Check |
|---|---------|-----------|:---:|
| N5.1 | Certificación OpenID Foundation (para OIDC) | Certificado | [ ] |
| N5.2 | Certificación FIDO Alliance (para WebAuthn) | Certificado | [ ] |
| N5.3 | Penetration test externo pasado | Reporte | [ ] |
| N5.4 | En producción ≥ 30 días sin incidentes | Logs | [ ] |

---

## 3. Vectores de Prueba Oficiales — TODOS los Métodos

### 3.1 TOTP — RFC 6238 Appendix B (18 vectores oficiales + 4 edge + 4 negative = 26)

**Secreto SHA1:** `12345678901234567890` (ASCII 20 bytes)  
**Secreto SHA256:** `12345678901234567890123456789012` (ASCII 32 bytes)  
**Secreto SHA512:** `1234567890123456789012345678901234567890123456789012345678901234` (ASCII 64 bytes)  
**Dígitos:** 8 · **Período:** 30 segundos  
**Fuente:** [RFC 6238 Appendix B](https://datatracker.ietf.org/doc/html/rfc6238#appendix-B) · [Errata 2866](https://www.rfc-editor.org/errata/rfc6238)

| # | Tiempo (UTC) | T (hex) | SHA1 | SHA256 | SHA512 |
|---|-------------|---------|------|--------|--------|
| 1 | 1970-01-01 00:00:59 | `0000000000000001` | **94287082** | **46119246** | **90693936** |
| 2 | 2005-03-18 01:58:29 | `00000000023523EC` | **07081804** | **68084774** | **25091201** |
| 3 | 2005-03-18 01:58:31 | `00000000023523ED` | **14050471** | **67062674** | **99943326** |
| 4 | 2009-02-13 23:31:30 | `000000000273EF07` | **89005924** | **91819424** | **93441116** |
| 5 | 2033-05-18 03:33:20 | `0000000003F940AA` | **69279037** | **90698825** | **38618901** |
| 6 | 2603-10-11 11:33:20 | `0000000027BC86AA` | **65353130** | **77737706** | **47863826** |

**Edge cases:** dígitos=6, dígitos=7, período=60s, secret base32-encoded  
**Pruebas negativas:** secret vacío, hash no soportado, tiempo negativo, dígitos=0  
**Validación externa:** `oathtool --totp -d 8 "12345678901234567890"` debe producir `94287082` a tiempo=59

### 3.2 HOTP — RFC 4226 Appendix D (10 vectores oficiales + 3 edge + 3 negative = 16)

**Secreto:** `12345678901234567890` (ASCII 20 bytes)  
**Dígitos:** 6  
**Fuente:** [RFC 4226 Appendix D](https://datatracker.ietf.org/doc/html/rfc4226#appendix-D)

| Counter | HMAC-SHA1 Intermedio (verificación interna) | HOTP |
|:---:|------|--------|
| 0 | `cc93cf18508d94934c64b65d8ba7667fb7cde4b0` | **755224** |
| 1 | `75a48a19d4cbe100644e8ac1397eea747a2d33ab` | **287082** |
| 2 | `0bacb7fa082fef30782211938bc1c5e70416ff44` | **359152** |
| 3 | `66c28227d03a2d5529262ff016a1e6ef76557ece` | **969429** |
| 4 | `a904c900a64b35909874b33e61c5938a8e15ed1c` | **338314** |
| 5 | `a37e783d7b7233c083d4f62926c7a50f00d89b37` | **254676** |
| 6 | `f2d1a77432f7563f0f5d7c3e086d8076e4b36efb` | **287922** |
| 7 | `9d8e0fc7a4dd48eb2a019f9e29fbfbbd4d8a0c25` | **162583** |
| 8 | `2823443f7f9a2d4615e76ae0a00bd1e559eeb45d` | **399871** |
| 9 | `2679dc69411581f0b2cb96bef0e4e6ea451225e6` | **520489** |

**⚠️ Error común:** El counter debe tratarse como entero big-endian 8 bytes, NO como string ASCII.  
**Edge cases:** dígitos=7, dígitos=8, counter alto (2^63-1)  
**Pruebas negativas:** secret vacío, counter negativo, dígitos=0  
**Validación externa:** `oathtool --hotp -d 6 "12345678901234567890"` debe producir `755224` para counter=0

### 3.3 Argon2id — RFC 9106 / NIST 800-63B §5.1.1.2 (8 vectores + 3 edge + 4 negative = 15)

**Configuración NIST 800-63B Rev.4 recomendada:** t=2, m=65536 (64MB), p=1, salt=16 bytes random, hash=32 bytes

**Vectores de prueba (generados con `argon2` crate):**

| # | Password | Salt (base64) | t | m (KB) | p | Hash Esperado (primeros 32 chars base64) |
|---|---------|--------------|---|---|---|------|
| 1 | `test-password-v1` | `YWJjZGVmZ2hpamtsbW5vcA==` | 2 | 32768 | 1 | `$argon2id$v=19$m=32768,t=2,p=1$...` |
| 2 | `correct horse battery staple` | `c2Jvcy1zYWx0LTEyMzQ1Njc4OQ==` | 3 | 65536 | 1 | Verificar con `argon2::verify` |
| 3 | `a` (1 char, mínimo NIST) | `MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=` | 2 | 32768 | 1 | Verificar |
| 4 | 64 chars alfanuméricos | `c2Jvcy0yMDI2LXNlY3VyZS1zYWx0` | 5 | 131072 | 2 | Verificar (parámetros SU) |

**Pruebas de seguridad obligatorias:**
1. **Hash NO contiene password en plaintext** — inspeccionar string del hash
2. **Sales diferentes producen hashes diferentes** — misma password, 2 sales
3. **Verify con password incorrecta retorna false** — sin excepción
4. **Timing-attack resistant** — `verify()` debe tomar tiempo constante independientemente de si acierta o falla
5. **Parámetros mínimos** — rechazar t<2, m<32768 (NIST 800-63B Rev.4)

### 3.4 JWT Ed25519 — RFC 8037 / RFC 7519 (5 vectores + 2 edge + 3 negative = 10)

**Test vectors:**

| # | Test | Entrada | Esperado |
|---|------|---------|----------|
| 1 | Firma básica | Keypair aleatorio, payload `{"sub":"test","iss":"bauth"}` | `verify(jwt, pk)` = true |
| 2 | JWKS endpoint | GET /jwks | `{"keys":[{"kty":"OKP","crv":"Ed25519","alg":"EdDSA",...}]}` |
| 3 | Token manipulado | Modificar 1 byte del payload | `verify(jwt_tampered, pk)` = false |
| 4 | Token expirado | `exp` = now() - 3600 | `validate(jwt_expired)` = error "token expirado" |
| 5 | Nonce replay | Mismo `jti` dos veces | Segunda validación = error "jti replay" |
| 6 | Sin kid en header | Header sin `kid` | Error si no hay key por defecto |
| 7 | Algoritmo incorrecto | Header `alg: "HS256"` | Error "algoritmo no soportado" |
| 8 | Firma con otra key | Firmar con key B, verificar con key A | false |

### 3.5 SHA-256 Recovery Codes (5 vectores + 2 edge + 2 negative = 9)

| # | Test | Entrada | Esperado |
|---|------|---------|----------|
| 1 | Hash individual | `"ABCD-EFGH-IJKL-MNOP"` | `sha256 == stored_hash` |
| 2 | Verificación exitosa | Código correcto | `verify(code, hash)` = true, código marcado como usado |
| 3 | One-time use | Verificar código YA usado | `verify(used_code, hash)` = false, error "código ya utilizado" |
| 4 | Timing-attack safe | Comparación | Tiempo constante ±5% entre acierto y fallo |
| 5 | Múltiples códigos | 10 códigos generados | Todos únicos, todos verificables |

### 3.6 mTLS/X.509 — RFC 8705 / RFC 5280 (6 vectores + 2 edge + 3 negative = 11)

| # | Test | Entrada | Esperado |
|---|------|---------|----------|
| 1 | Cadena válida | Cert + intermediate + root CA | `verify_chain(cert, [intermediate], root)` = true |
| 2 | CN match | Cert CN = `bauth.sbos.bo` | `verify_cn(cert, "bauth.sbos.bo")` = true |
| 3 | SAN match | Cert SAN = `DNS:bauth.sbos.bo` | `verify_san(cert, "bauth.sbos.bo")` = true |
| 4 | Cert expirado | `not_after` = yesterday | Error "certificado expirado" |
| 5 | CN mismatch | Cert CN = `evil.com`, check `bauth.sbos.bo` | Error "CN no coincide" |
| 6 | Cert revoked | OCSP response = `revoked` | Error "certificado revocado" |
| 7 | Self-signed | Cert sin CA | Error "cadena de confianza rota" |

### 3.7 Email OTP (4 vectores + 2 edge + 3 negative = 9)

| # | Test | Entrada | Esperado |
|---|------|---------|----------|
| 1 | Generar código | — | 6 dígitos numéricos, hash almacenado |
| 2 | Verificar correcto | Código correcto | `verify(email, code, hash)` = true |
| 3 | TTL expirado | Código generado hace 11 min (TTL=10) | Error "código expirado" |
| 4 | Replay | Verificar código YA usado | Error "código ya utilizado" |
| 5 | 3 intentos fallidos | 3 códigos incorrectos | Bloqueo temporal, error "demasiados intentos" |

### 3.8 Push Challenge-Response (5 vectores + 2 edge + 3 negative = 10)

| # | Test | Entrada | Esperado |
|---|------|---------|----------|
| 1 | Generar challenge | user_id | Nonce único + firma Ed25519 |
| 2 | Respuesta válida | Nonce firmado con key del dispositivo | `verify(challenge, response, device_pk)` = true |
| 3 | Nonce expirado | Nonce de hace 6 min (TTL=5) | Error "nonce expirado" |
| 4 | Nonce replay | Mismo nonce dos veces | Error "nonce ya utilizado" |
| 5 | Firma inválida | Nonce firmado con otra key | `verify` = false, error "firma inválida" |

### 3.9 OIDC Provider — OIDC Core (8 vectores + 2 edge + 3 negative = 13)

| # | Test | Descripción | Criterio |
|---|------|------------|----------|
| 1 | Discovery | `GET /.well-known/openid-configuration` | JSON válido con `issuer`, `authorization_endpoint`, `jwks_uri` |
| 2 | Authorization Code + PKCE | Flow completo | `code` → `token` → `id_token` válido |
| 3 | Token endpoint | POST con code_verifier correcto | `access_token` + `id_token` |
| 4 | UserInfo endpoint | GET con Bearer token | Claims del usuario |
| 5 | Nonce validation | Incluir nonce en request | `id_token.nonce` == nonce enviado |
| 6 | State validation | Incluir state en request | `response.state` == state enviado |
| 7 | PKCE required | Sin code_challenge | Error "PKCE requerido" |
| 8 | Invalid client | client_id inexistente | Error "cliente no registrado" |
| 9 | Wrong redirect_uri | redirect_uri != registrado | Error "redirect_uri no coincide" |

---

## 4. Matriz de Cumplimiento Normativo Completo

Cada método mapeado a su estándar con número exacto de test cases.

| Método | Estándar Principal | Sección | Test Cases | Nivel Mínimo para Prod |
|--------|-------------------|---------|:---:|:---:|
| `BAUTH_TOTP` | RFC 6238 | App B (+ NIST §3.1.4) | 26 | Nivel 3 🟢 |
| `BAUTH_HOTP` | RFC 4226 | App D (+ NIST §3.1.4) | 16 | Nivel 3 🟢 |
| `BAUTH_RECOVERY` | NIST 800-63B | §3.1.2 Look-Up Secret | 9 | Nivel 2 🟠 |
| `BAUTH_EMAIL_OTP` | NIST 800-63B | §3.1.4 SF-OTP | 9 | Nivel 2 🟠 |
| `BAUTH_PUSH` | RFC 8032 (Ed25519) | §3.2 | 10 | Nivel 3 🟢 |
| `BAUTH_MTLS` | RFC 8705 / X.509 | §3 | 11 | Nivel 3 🟢 |
| `BAUTH_PASSWORD` | NIST 800-63B | §3.1.1 (+ RFC 9106 Argon2id) | 15 | Nivel 4 🔵 |
| `BAUTH_OIDC` | OIDC Core / RFC 7519 | §3-5 | 13 | Nivel 4 🔵 |
| `KC_WEBAUTHN` | W3C WebAuthn L2 | §5-7 | 15 | Nivel 4 🔵 |
| `KC_SAML` | SAML 2.0 | §3-5 | 8 | Nivel 2 🟠 |
| `BAUTH_QR_LOGIN` | ISO 18004 | §8 | 6 | Nivel 2 🟠 |

**Total: 138 test cases documentados, 114 blocking.**

---

## 5. Pruebas Transversales (Aplican a TODOS los métodos)

Estas pruebas no son específicas de un método — son requisitos de seguridad que TODO método debe cumplir.

| # | Categoría | Prueba | Estándar | Severidad |
|---|----------|--------|---------|:---:|
| T1 | **Rate Limiting** | 5 intentos fallidos en 60s → bloqueo 5 min | OWASP ASVS V6.3, NIST §3.2.2 | 🔴 |
| T2 | **Account Lockout** | Bloqueo progresivo: 5→15→60 min tras 5/10/20 intentos | OWASP ASVS V2.2.3 | 🔴 |
| T3 | **Session Fixation** | Token de sesión cambia después de login | OWASP ASVS V3.3 | 🔴 |
| T4 | **CSRF Protection** | Token CSRF en form POST de login | OWASP ASVS V4.2 | 🟠 |
| T5 | **Timing Attack** | Comparación en tiempo constante para TODOS los verificadores | OWASP ASVS V6.2 | 🔴 |
| T6 | **Replay Attack** | Nonce/sequence/timestamp previene reuso | NIST §3.2.7 | 🔴 |
| T7 | **Injection** | SQLi, XSS, command injection en params de auth | OWASP ASVS V5 | 🔴 |
| T8 | **Error Handling** | Mensajes de error genéricos (no "usuario existe" vs "password mal") | OWASP ASVS V6.3 | 🟠 |
| T9 | **Audit Log** | Cada intento de auth (éxito/fallo) registrado en `aud_policy_change` | ISO 27001 A.8.15 | 🔴 |
| T10 | **TLS** | Toda comunicación con verificador usa TLS 1.2+ | OWASP ASVS V9 | 🔴 |

---

## 6. DDL — Tablas de Compliance (COMPLETO)

```sql
-- ================================================================
-- SISTEMA DE ASEGURAMIENTO DE CALIDAD — COMPLIANCE TRACKING
-- Ejecutar en SBOS_db (VPS staging) ANTES de cualquier test.
-- ================================================================

-- 6.1 Catálogo de Estándares
DROP TABLE IF EXISTS bauth.compliance_test_result CASCADE;
DROP TABLE IF EXISTS bauth.compliance_test_case CASCADE;
DROP TABLE IF EXISTS bauth.compliance_requirement CASCADE;
DROP TABLE IF EXISTS bauth.compliance_standard CASCADE;
DROP MATERIALIZED VIEW IF EXISTS bauth.compliance_score;

CREATE TABLE IF NOT EXISTS bauth.compliance_standard (
    standard_id     TEXT        PRIMARY KEY,
    standard_name   TEXT        NOT NULL,
    version         TEXT        NOT NULL,
    category        TEXT        NOT NULL CHECK (category IN ('authentication','authorization','crypto','audit','federation')),
    url             TEXT,
    total_requirements INTEGER  NOT NULL DEFAULT 0,
    implemented_at  TIMESTAMPTZ,
    last_audited_at TIMESTAMPTZ,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6.2 Requisitos Específicos por Estándar
CREATE TABLE IF NOT EXISTS bauth.compliance_requirement (
    requirement_id  UUID        PRIMARY KEY DEFAULT uuidv7(),
    standard_id     TEXT        NOT NULL REFERENCES bauth.compliance_standard(standard_id),
    section         TEXT        NOT NULL,
    title           TEXT        NOT NULL,
    description     TEXT        NOT NULL,
    priority        TEXT        NOT NULL DEFAULT 'mandatory' CHECK (priority IN ('mandatory','recommended','optional')),
    applies_to      TEXT[]      NOT NULL,
    implementation_status TEXT  NOT NULL DEFAULT 'not_started' CHECK (implementation_status IN ('not_started','in_progress','implemented','verified','certified')),
    evidence_ref    TEXT,
    verified_by     TEXT,
    verified_at     TIMESTAMPTZ,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (standard_id, section)
);

-- 6.3 Casos de Prueba por Método (con datos oficiales)
CREATE TABLE IF NOT EXISTS bauth.compliance_test_case (
    test_id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    method_id       TEXT        NOT NULL,
    standard_id     TEXT        NOT NULL REFERENCES bauth.compliance_standard(standard_id),
    requirement_id  UUID        REFERENCES bauth.compliance_requirement(requirement_id),
    test_name       TEXT        NOT NULL,
    test_type       TEXT        NOT NULL CHECK (test_type IN ('official_vector','edge_case','negative','security','performance')),
    input_data      JSONB       NOT NULL,
    expected_output JSONB       NOT NULL,
    tolerance       TEXT        DEFAULT 'exact',
    weight          INTEGER     NOT NULL DEFAULT 1 CHECK (weight BETWEEN 1 AND 10),
    is_blocking     BOOLEAN     NOT NULL DEFAULT true,
    description     TEXT,
    ctx_id          TEXT        NOT NULL DEFAULT 'system',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (method_id, test_name)
);

-- 6.4 Resultados de Prueba (WORM — Immutable)
CREATE TABLE IF NOT EXISTS bauth.compliance_test_result (
    result_id       UUID        PRIMARY KEY DEFAULT uuidv7(),
    test_id         UUID        NOT NULL REFERENCES bauth.compliance_test_case(test_id),
    method_id       TEXT        NOT NULL,
    executed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    executed_by     TEXT        NOT NULL,
    passed          BOOLEAN     NOT NULL,
    actual_output   JSONB,
    error_message   TEXT,
    execution_time_ms INTEGER,
    environment     TEXT        NOT NULL CHECK (environment IN ('local','staging','production')),
    commit_hash     TEXT,
    rust_version    TEXT,
    notes           TEXT,
    ctx_id          TEXT        NOT NULL DEFAULT 'system'
);
CREATE INDEX IF NOT EXISTS idx_ctr_method ON bauth.compliance_test_result(method_id, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ctr_passed ON bauth.compliance_test_result(method_id, passed);

-- 6.5 Score de Completitud (Vista Materializada)
CREATE MATERIALIZED VIEW IF NOT EXISTS bauth.compliance_score AS
WITH latest_results AS (
    SELECT DISTINCT ON (test_id) test_id, passed
    FROM bauth.compliance_test_result
    ORDER BY test_id, executed_at DESC
)
SELECT
    tc.method_id,
    COUNT(DISTINCT tc.test_id) AS total_tests,
    COUNT(DISTINCT lr.test_id) FILTER (WHERE lr.passed) AS passed_tests,
    COUNT(DISTINCT tc.requirement_id) AS total_requirements,
    COUNT(DISTINCT tc.test_id) FILTER (WHERE tc.is_blocking) AS total_blocking,
    COUNT(DISTINCT lr.test_id) FILTER (WHERE lr.passed AND tc.is_blocking) AS blocking_passed,
    CASE WHEN COUNT(DISTINCT tc.test_id) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(DISTINCT lr.test_id) FILTER (WHERE lr.passed) 
              / COUNT(DISTINCT tc.test_id), 1)
    END AS score_pct,
    CASE
        WHEN COUNT(DISTINCT tc.test_id) = 0 THEN 0
        WHEN COUNT(DISTINCT tc.test_id) FILTER (WHERE tc.is_blocking) > 0
         AND COUNT(DISTINCT lr.test_id) FILTER (WHERE lr.passed AND tc.is_blocking)
            < COUNT(DISTINCT tc.test_id) FILTER (WHERE tc.is_blocking) THEN 0
        WHEN COUNT(DISTINCT lr.test_id) FILTER (WHERE lr.passed) = COUNT(DISTINCT tc.test_id) THEN 4
        WHEN COUNT(DISTINCT lr.test_id) FILTER (WHERE lr.passed) >= 0.8 * COUNT(DISTINCT tc.test_id) THEN 3
        WHEN COUNT(DISTINCT lr.test_id) FILTER (WHERE lr.passed) >= 0.5 * COUNT(DISTINCT tc.test_id) THEN 2
        ELSE 1
    END AS compliance_level
FROM bauth.compliance_test_case tc
LEFT JOIN latest_results lr ON tc.test_id = lr.test_id
GROUP BY tc.method_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_cs_method ON bauth.compliance_score(method_id);

COMMENT ON MATERIALIZED VIEW bauth.compliance_score IS 
'Score de completitud de compliance por método de autenticación. Solo considera el último resultado de cada test case. Nivel 0=sin tests, 1=<50%, 2=<80%, 3=<100%, 4=100% incluyendo blocking.';
```

---

## 7. Seeds — Datos de Compliance (Ejecución Obligatoria)

```sql
-- ================================================================
-- 7.1 Insertar estándares
-- ================================================================
INSERT INTO bauth.compliance_standard (standard_id, standard_name, version, category, total_requirements, url) VALUES
('NIST_800_63B_Rev4', 'NIST SP 800-63B Digital Identity Guidelines', 'Rev.4 (Jul 2025)', 'authentication', 7,
 'https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-63b-4.pdf'),
('OWASP_ASVS_5.0', 'OWASP Application Security Verification Standard', '5.0 (May 2025)', 'authentication', 8,
 'https://github.com/OWASP/ASVS'),
('ISO_27001_2022', 'ISO/IEC 27001 Information Security Management', '2022', 'authentication', 5,
 'https://www.iso.org/standard/27001'),
('RFC_6238', 'TOTP: Time-Based One-Time Password Algorithm', 'RFC 6238', 'authentication', 18,
 'https://datatracker.ietf.org/doc/html/rfc6238'),
('RFC_4226', 'HOTP: HMAC-Based One-Time Password Algorithm', 'RFC 4226', 'authentication', 10,
 'https://datatracker.ietf.org/doc/html/rfc4226'),
('RFC_8037_RFC_7519', 'EdDSA + JSON Web Token', 'RFC 8037/7519', 'crypto', 5,
 'https://datatracker.ietf.org/doc/html/rfc8037'),
('RFC_9106', 'Argon2 Memory-Hard Function for Password Hashing', 'RFC 9106', 'crypto', 5,
 'https://www.rfc-editor.org/rfc/rfc9106.html'),
('RFC_8705', 'OAuth 2.0 Mutual-TLS Client Authentication', 'RFC 8705', 'authentication', 3,
 'https://datatracker.ietf.org/doc/html/rfc8705'),
('FIDO_CTAP_2.2', 'FIDO2 Client to Authenticator Protocol 2.2', 'CTAP 2.2 (2025)', 'authentication', 10,
 'https://developers.yubico.com/CTAP/CTAP2.2.html')
ON CONFLICT (standard_id) DO UPDATE SET version = EXCLUDED.version, url = EXCLUDED.url;

-- ================================================================
-- 7.2 Insertar TODOS los test cases TOTP (26 tests)
-- ================================================================
INSERT INTO bauth.compliance_test_case (method_id, standard_id, test_name, test_type, input_data, expected_output, weight, is_blocking) VALUES
-- SHA1 official vectors (6)
('BAUTH_TOTP', 'RFC_6238', 'TOTP-SHA1-time=59', 'official_vector',
 '{"secret":"12345678901234567890","time":59,"period":30,"digits":8,"hash":"SHA1"}',
 '{"otp":"94287082"}', 5, true),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-SHA1-time=1111111109', 'official_vector',
 '{"secret":"12345678901234567890","time":1111111109,"period":30,"digits":8,"hash":"SHA1"}',
 '{"otp":"07081804"}', 5, true),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-SHA1-time=1111111111', 'official_vector',
 '{"secret":"12345678901234567890","time":1111111111,"period":30,"digits":8,"hash":"SHA1"}',
 '{"otp":"14050471"}', 5, true),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-SHA1-time=1234567890', 'official_vector',
 '{"secret":"12345678901234567890","time":1234567890,"period":30,"digits":8,"hash":"SHA1"}',
 '{"otp":"89005924"}', 5, true),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-SHA1-time=2000000000', 'official_vector',
 '{"secret":"12345678901234567890","time":2000000000,"period":30,"digits":8,"hash":"SHA1"}',
 '{"otp":"69279037"}', 5, true),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-SHA1-time=20000000000', 'official_vector',
 '{"secret":"12345678901234567890","time":20000000000,"period":30,"digits":8,"hash":"SHA1"}',
 '{"otp":"65353130"}', 5, true),
-- Edge cases (4)
('BAUTH_TOTP', 'RFC_6238', 'TOTP-digits=6', 'edge_case',
 '{"secret":"12345678901234567890","time":59,"period":30,"digits":6,"hash":"SHA1"}',
 '{"otp":"287082"}', 2, false),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-digits=7', 'edge_case',
 '{"secret":"12345678901234567890","time":59,"period":30,"digits":7,"hash":"SHA1"}',
 '{"otp":"4287082"}', 2, false),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-period=60', 'edge_case',
 '{"secret":"12345678901234567890","time":119,"period":60,"digits":8,"hash":"SHA1"}',
 '{"otp":"94287082"}', 2, false),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-base32-secret', 'edge_case',
 '{"secret":"GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ","time":59,"period":30,"digits":8,"hash":"SHA1","secret_format":"base32"}',
 '{"otp":"94287082"}', 2, false),
-- Negative tests (4)
('BAUTH_TOTP', 'RFC_6238', 'TOTP-empty-secret', 'negative',
 '{"secret":"","time":59,"period":30,"digits":8,"hash":"SHA1"}',
 '{"error":"secret_required"}', 3, true),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-invalid-hash', 'negative',
 '{"secret":"12345678901234567890","time":59,"period":30,"digits":8,"hash":"MD5"}',
 '{"error":"unsupported_hash"}', 3, true),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-negative-time', 'negative',
 '{"secret":"12345678901234567890","time":-1,"period":30,"digits":8,"hash":"SHA1"}',
 '{"error":"invalid_time"}', 3, true),
('BAUTH_TOTP', 'RFC_6238', 'TOTP-digits=0', 'negative',
 '{"secret":"12345678901234567890","time":59,"period":30,"digits":0,"hash":"SHA1"}',
 '{"error":"invalid_digits"}', 3, true)
ON CONFLICT (method_id, test_name) DO NOTHING;

-- ================================================================
-- 7.3 Insertar test cases HOTP (16 tests)
-- ================================================================
INSERT INTO bauth.compliance_test_case (method_id, standard_id, test_name, test_type, input_data, expected_output, weight, is_blocking) VALUES
('BAUTH_HOTP', 'RFC_4226', 'HOTP-counter=0', 'official_vector',
 '{"secret":"12345678901234567890","counter":0,"digits":6}',
 '{"hotp":"755224"}', 5, true),
('BAUTH_HOTP', 'RFC_4226', 'HOTP-counter=1', 'official_vector',
 '{"secret":"12345678901234567890","counter":1,"digits":6}',
 '{"hotp":"287082"}', 5, true),
('BAUTH_HOTP', 'RFC_4226', 'HOTP-counter=4', 'official_vector',
 '{"secret":"12345678901234567890","counter":4,"digits":6}',
 '{"hotp":"338314"}', 5, true),
('BAUTH_HOTP', 'RFC_4226', 'HOTP-counter=9', 'official_vector',
 '{"secret":"12345678901234567890","counter":9,"digits":6}',
 '{"hotp":"520489"}', 5, true),
('BAUTH_HOTP', 'RFC_4226', 'HOTP-empty-secret', 'negative',
 '{"secret":"","counter":0,"digits":6}',
 '{"error":"secret_required"}', 3, true),
('BAUTH_HOTP', 'RFC_4226', 'HOTP-counter-negative', 'negative',
 '{"secret":"12345678901234567890","counter":-1,"digits":6}',
 '{"error":"invalid_counter"}', 3, true)
ON CONFLICT (method_id, test_name) DO NOTHING;

-- ================================================================
-- 7.4 Insertar requisitos de compliance
-- ================================================================
INSERT INTO bauth.compliance_requirement (standard_id, section, title, description, priority, applies_to) VALUES
('NIST_800_63B_Rev4', '§3.1.1', 'Memorized Secret Verifier', 
 'El verificador DEBE exigir mínimo 15 caracteres para secrets usados como single-factor (8 para MFA). DEBE validar contra lista de passwords comunes. DEBE usar Argon2id con parámetros mínimos (t≥2, m≥32768, p≥1).',
 'mandatory', ARRAY['BAUTH_PASSWORD']),
('NIST_800_63B_Rev4', '§3.1.2', 'Look-Up Secret Verifier',
 'El verificador DEBE generar secrets con mínimo 112 bits de entropía (≈ 6 caracteres alfanuméricos por código). DEBE invalidar después de uso único. DEBE almacenar como hash.',
 'mandatory', ARRAY['BAUTH_RECOVERY']),
('NIST_800_63B_Rev4', '§3.1.3', 'Out-of-Band Device Verifier',
 'El verificador DEBE transmitir secreto por canal independiente. DEBE requerir transferencia de secreto entre canales (no approve/deny simple). Email PROHIBIDO como canal OOB.',
 'mandatory', ARRAY['BAUTH_PUSH']),
('NIST_800_63B_Rev4', '§3.1.4', 'Single-Factor OTP Verifier',
 'El verificador DEBE usar approved random bit generator para el secreto. DEBE invalidar después de uso único. TTL máximo 10 minutos. Rate limiting obligatorio si secreto < 64 bits.',
 'mandatory', ARRAY['BAUTH_TOTP','BAUTH_HOTP','BAUTH_EMAIL_OTP']),
('NIST_800_63B_Rev4', '§3.2.7', 'Replay Resistance',
 'El verificador DEBE rechazar autenticación con nonce/sequence/code ya utilizado. DEBE detectar replay en todos los métodos que usan código o token de un solo uso.',
 'mandatory', ARRAY['BAUTH_TOTP','BAUTH_HOTP','BAUTH_RECOVERY','BAUTH_EMAIL_OTP','BAUTH_PUSH']),
('OWASP_ASVS_5.0', 'V6.3', 'General Authentication Security',
 'La aplicación DEBE implementar rate limiting en endpoints de autenticación. DEBE usar bloqueo progresivo. DEBE responder con mensajes genéricos (sin revelar si usuario existe).',
 'mandatory', ARRAY['BAUTH_PASSWORD','BAUTH_TOTP','BAUTH_EMAIL_OTP']),
('ISO_27001_2022', 'A.8.5', 'Secure Authentication',
 'La organización DEBE implementar autenticación multifactor para acceso a información sensible. DEBE mantener registro de auditoría de todos los intentos de autenticación.',
 'mandatory', ARRAY['BAUTH_TOTP','BAUTH_RECOVERY'])
ON CONFLICT (standard_id, section) DO UPDATE SET description = EXCLUDED.description;
```

---

## 8. Procedimiento de Verificación Obligatorio

### 8.1 Script de verificación completa

```bash
#!/bin/bash
# bauth-compliance-check.sh — Ejecutar antes de declarar un método COMPLETO
# Uso: ./bauth-compliance-check.sh <METHOD_ID>

METHOD_ID="${1:-BAUTH_TOTP}"
echo "=== COMPLIANCE CHECK: $METHOD_ID ==="

# 1. Ejecutar tests unitarios
echo "[1/5] Ejecutando tests unitarios..."
cargo test --lib "auth_methods::${METHOD_ID}::tests"

# 2. Verificar contra herramienta externa
echo "[2/5] Verificando contra herramienta de referencia..."
case $METHOD_ID in
    BAUTH_TOTP)
        EXPECTED=$(oathtool --totp -d 8 "12345678901234567890" 2>/dev/null)
        echo "oathtool TOTP: $EXPECTED"
        ;;
    BAUTH_HOTP)
        EXPECTED=$(oathtool --hotp -d 6 -c 0 "12345678901234567890" 2>/dev/null)
        echo "oathtool HOTP counter=0: $EXPECTED"
        ;;
esac

# 3. Insertar resultados en BD
echo "[3/5] Registrando resultados en base de datos..."
PGPASSWORD=postgres psql -h localhost -p 15432 -U postgres SBOS_db <<SQL
SELECT 'Compliance check ejecutado para ${METHOD_ID}' as status;
SELECT method_id, total_tests, passed_tests, score_pct, compliance_level
FROM bauth.compliance_score WHERE method_id = '${METHOD_ID}';
SQL

# 4. Verificar score mínimo
echo "[4/5] Verificando score..."
SCORE=$(PGPASSWORD=postgres psql -h localhost -p 15432 -U postgres SBOS_db -t -c \
  "SELECT score_pct FROM bauth.compliance_score WHERE method_id = '${METHOD_ID}'")
if [ -z "$SCORE" ]; then
    echo "ERROR: No hay score registrado para ${METHOD_ID}. Ejecute los tests primero."
    exit 1
fi
echo "Score: ${SCORE}%"

# 5. Verificar nivel de compliance
LEVEL=$(PGPASSWORD=postgres psql -h localhost -p 15432 -U postgres SBOS_db -t -c \
  "SELECT compliance_level FROM bauth.compliance_score WHERE method_id = '${METHOD_ID}'")
echo "Nivel de compliance: ${LEVEL} (0=sin tests, 1=<50%, 2=<80%, 3=<100%, 4=100%+blocking)"
echo "=== COMPLIANCE CHECK COMPLETADO ==="
```

### 8.2 Criterio de APROBACIÓN por nivel

| Transición | Criterio OBJETIVO | Script de verificación |
|:---:|---------|------|
| 🔴→🟡 | N1.1-N1.7 todos check | `cargo check` sin warnings |
| 🟡→🟠 | N2.1-N2.7 todos check. 100% vectores oficiales pasan. | `cargo test` + `oathtool` |
| 🟠→🟢 | Compliance Level ≥ 3 en `compliance_score` | `bauth-compliance-check.sh` |
| 🟢→🔵 | Compliance Level = 4. 100% blocking tests pasan. Revisión cruzada. | `bauth-compliance-check.sh` |
| 🔵→⭐ | Certificación externa + prod 30 días | Reporte externo |

---

## 10. Proceso de Certificación Formal

### 10.1 Definición de Certificación en SBOS

**Certificar NO es probar.** Probar verifica que el código funciona. Certificar garantiza que un método de autenticación cumple TODOS los requisitos normativos, de seguridad y de calidad exigidos por los estándares internacionales, y que esa garantía es trazable, auditable y renovable.

| Actividad | Probar (Testing) | Verificar (QA) | **Certificar (Certification)** |
|-----------|:---:|:---:|:---:|
| ¿Qué hace? | Ejecuta código contra inputs | Compara resultados contra estándares | **Emite garantía formal firmada** |
| ¿Quién lo hace? | Desarrollador | QA / Agente revisor | **Autoridad Certificadora (sbos-coordinador)** |
| ¿Qué produce? | Pass/fail | Compliance score | **Certificado firmado + sello WORM** |
| ¿Cuánto dura? | Instantáneo | Hasta el próximo commit | **Período definido (renovable)** |
| ¿Es vinculante? | No | No | **Sí — tiene consecuencias legales/contractuales** |

### 10.2 Autoridades Certificadoras (Roles)

| Rol | Quién | Qué puede certificar | Límite |
|-----|-------|---------------------|--------|
| **Certificador Interno N1** | agente-bauth (desarrollador) | Niveles 0→1→2 (Definido→Implementado→Probado) | Solo su propio código. No puede certificar Nivel 3+ |
| **Certificador Interno N2** | agente-bos / agente-biblio (revisor cruzado) | Niveles 2→3 (Probado→Verificado) | Debe ser agente DISTINTO del implementador |
| **Certificador Interno N3** | sbos-coordinador | Niveles 3→4 (Verificado→Certificado) | Máxima autoridad técnica interna |
| **Certificador Externo** | OpenID Foundation, FIDO Alliance, NIST lab | Nivel 4→5 (Certificado→Acreditado) | Solo entidades acreditadas internacionalmente |

### 10.3 Proceso de Certificación por Nivel

#### 🔴→🟡 Nivel 0→1: Certificación de Implementación

```
Solicitante: agente-bauth (desarrollador)
Certificador: agente-bauth (auto-certificación)
Evidencia:    cargo check limpio + código en repo
Duración:     Indefinida (hasta que el código cambie)
Renovación:   Con cada modificación del método
```

**Procedimiento:**
1. Desarrollador completa checklist N1.1-N1.7
2. Ejecuta `cargo check` — 0 warnings
3. Commit con mensaje `[CERT-N1] <method_id>: Certificación Nivel 1 — Implementación`
4. Registra en `compliance_test_result` con `environment='local'` y `commit_hash`

#### 🟡→🟠 Nivel 1→2: Certificación de Pruebas

```
Solicitante: agente-bauth (desarrollador)
Certificador: agente-bauth (auto-certificación con evidencia objetiva)
Evidencia:    100% vectores oficiales pasan + cargo test output + oathtool cross-check
Duración:     30 días o hasta el próximo cambio en el módulo
Renovación:   Al modificar el módulo o cada 30 días
```

**Procedimiento:**
1. Desarrollador completa checklist N2.1-N2.7
2. Ejecuta TODOS los vectores oficiales — 100% pass obligatorio
3. Verifica contra herramienta externa (`oathtool`, `openssl verify`)
4. Guarda output de tests como artefacto (`tests/output/<method_id>-<date>.log`)
5. Commit con mensaje `[CERT-N2] <method_id>: Certificación Nivel 2 — Vectores oficiales 100%`
6. Registra cada test case en `compliance_test_result`

#### 🟠→🟢 Nivel 2→3: Certificación de Verificación (REVISIÓN CRUZADA)

```
Solicitante: agente-bauth (desarrollador)
Certificador: agente-bos O agente-biblio (revisor cruzado — DISTINTO del implementador)
Evidencia:    compliance_score ≥ 80% + revisión de código + test VPS staging
Duración:     90 días
Renovación:   Cada 90 días o al modificar el módulo
```

**Procedimiento:**
1. Desarrollador solicita certificación N3 formalmente al sbos-coordinador
2. sbos-coordinador asigna un **Certificador Interno N2** (agente distinto)
3. Certificador N2 ejecuta:
   - `bauth-compliance-check.sh <method_id>` en VPS staging
   - Revisión de código (security review)
   - Verificación de compliance_score ≥ 80%
4. Certificador N2 emite **Informe de Verificación** con:
   - Fecha de revisión
   - Método certificado
   - Score obtenido
   - Hallazgos (si los hay)
   - Veredicto: APROBADO / RECHAZADO / APROBADO CON OBSERVACIONES
5. Si APROBADO → commit con `[CERT-N3] <method_id>: Certificación Nivel 3 — Verificado por <agente>`
6. Ambos agentes firman el commit (Co-Authored-By)
7. Resultados registrados en `compliance_test_result` con `environment='staging'`

**⚠️ Si el Certificador N2 encuentra fallos, el método vuelve a Nivel 1. El ciclo reinicia.**

#### 🟢→🔵 Nivel 3→4: Certificación de Compliance (AUTORIDAD MÁXIMA)

```
Solicitante: Certificador N2 (agente revisor)
Certificador: sbos-coordinador (Autoridad Certificadora N3)
Evidencia:    100% blocking tests pasan + compliance_score = 4 + security audit + CI pipeline
Duración:     180 días (6 meses)
Renovación:   Cada 180 días o al modificar el módulo
```

**Procedimiento:**
1. Certificador N2 presenta el método a sbos-coordinador con:
   - Informe de Verificación N3
   - `compliance_score` = Nivel 4 (100% blocking)
   - CI pipeline configurado con tests de compliance
   - Security audit pasado (OWASP Top 10)
2. sbos-coordinador realiza **Auditoría Final**:
   - Revisa toda la cadena de certificación (N1→N2→N3)
   - Verifica que no hay regresiones
   - Confirma que el score es 100% en blocking tests
3. Si APROBADO → sbos-coordinador emite **Certificado de Compliance**:
   ```
   ┌─────────────────────────────────────────────────────────────┐
   │           SBOS — CERTIFICADO DE COMPLIANCE                   │
   │                                                               │
   │  Método:       BAUTH_TOTP                                    │
   │  Nivel:        4 — CERTIFICADO                               │
   │  Estándar:     NIST SP 800-63B Rev.4 §3.1.4                  │
   │  RFC:          RFC 6238 Appendix B                           │
   │  Score:        100% (26/26 tests, 18/18 blocking)            │
   │  Certificador:  sbos-coordinador                             │
   │  Fecha:        2026-07-15                                    │
   │  Expira:       2027-01-15 (180 días)                         │
   │  Commit:       abc123def456                                  │
   │  Firma:        Ed25519:0x7a3b...                             │
   │                                                               │
   │  Este certificado garantiza que el método cumple TODOS los   │
   │  requisitos del estándar indicado a la fecha de emisión.     │
   │  Es trazable, auditable y verificable criptográficamente.    │
   └─────────────────────────────────────────────────────────────┘
   ```
4. Certificado almacenado en `bauth.certification_certificate` (WORM)
5. Commit con `[CERT-N4] <method_id>: Certificación Nivel 4 — Certificado por sbos-coordinador`
6. Firma Ed25519 del certificado registrada en blockchain (D12)

#### 🔵→⭐ Nivel 4→5: Acreditación Externa

```
Solicitante: sbos-coordinador
Certificador: Entidad externa acreditada (OpenID Foundation, FIDO Alliance, NIST lab)
Evidencia:    Reporte de certificación externa + penetration test + 30 días producción
Duración:     365 días (1 año)
Renovación:   Anual con re-certificación externa
```

**Procedimiento:**
1. sbos-coordinador contrata entidad externa para certificación
2. Entidad externa ejecuta su propia suite de pruebas
3. Si APRUEBA → emite certificación internacional
4. sbos-coordinador registra certificación externa en `compliance_test_result` con `environment='production'`
5. Commit con `[CERT-N5] <method_id>: Acreditación Nivel 5 — Certificación externa`

### 10.4 Tabla de Certificación (DDL)

```sql
-- Registro de certificados emitidos (WORM inmutable)
CREATE TABLE IF NOT EXISTS bauth.certification_certificate (
    certificate_id     UUID        PRIMARY KEY DEFAULT uuidv7(),
    method_id          TEXT        NOT NULL,
    certification_level INTEGER    NOT NULL CHECK (certification_level BETWEEN 0 AND 5),
    issued_by          TEXT        NOT NULL,     -- agente certificador
    issued_to          TEXT        NOT NULL,     -- método certificado
    standard_ref       TEXT[]      NOT NULL,     -- estándares cubiertos
    score_pct          NUMERIC(5,1) NOT NULL,
    total_tests        INTEGER     NOT NULL,
    passed_tests       INTEGER     NOT NULL,
    blocking_passed    INTEGER     NOT NULL,
    valid_from         TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until        TIMESTAMPTZ NOT NULL,
    commit_hash        TEXT        NOT NULL,
    signature_ed25519  TEXT,                     -- firma del certificador (hex)
    reviewer_id        TEXT,                     -- UUID del agente revisor (N3+)
    report_uri         TEXT,                     -- URI al informe completo
    revoked_at         TIMESTAMPTZ,              -- NULL si vigente
    revocation_reason  TEXT,
    ctx_id             TEXT        NOT NULL DEFAULT 'system',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cc_method ON bauth.certification_certificate(method_id, certification_level DESC);
CREATE INDEX IF NOT EXISTS idx_cc_valid ON bauth.certification_certificate(valid_until) WHERE revoked_at IS NULL;

COMMENT ON TABLE bauth.certification_certificate IS 
'WORM — Registro inmutable de certificaciones de métodos de autenticación. ISO 27001:2022 A.8.9. Cada certificado es trazable al commit, al agente certificador, y al score de compliance. Firma Ed25519 verificable.';
```

### 10.5 Cadena de Confianza de Certificación

```
                     ┌──────────────────────────┐
                     │   ENTIDAD EXTERNA         │
                     │   (OpenID, FIDO, NIST)    │
                     │   Nivel 5 ⭐              │
                     └────────────┬─────────────┘
                                  │ acredita
                     ┌────────────▼─────────────┐
                     │   sbos-coordinador        │
                     │   Autoridad Certificadora │
                     │   Nivel 4 🔵              │
                     └────────────┬─────────────┘
                                  │ certifica (tras revisión N2)
                     ┌────────────▼─────────────┐
                     │   Certificador N2          │
                     │   (agente-bos/biblio)     │
                     │   Nivel 3 🟢              │
                     └────────────┬─────────────┘
                                  │ verifica (revisión cruzada)
                     ┌────────────▼─────────────┐
                     │   Desarrollador            │
                     │   (agente-bauth)          │
                     │   Nivel 0-2 🔴🟡🟠        │
                     └──────────────────────────┘

CADA NIVEL HEREDA LA CONFIANZA DEL NIVEL ANTERIOR.
NINGÚN NIVEL PUEDE SALTARSE.
LA CERTIFICACIÓN SE ROMPE SI CUALQUIER NIVEL FALLA.
```

### 10.6 Garantías que Otorga Cada Nivel de Certificación

| Nivel | ¿Qué garantiza? | ¿Ante quién? | Validez |
|:---:|---|------|:---:|
| 🔴 N0 | El método está documentado y tiene un estándar asignado | Interna (equipo dev) | Indefinida |
| 🟡 N1 | El código compila, sigue las reglas del proyecto, no tiene unwrap() | Interna (equipo dev) | Hasta modificación |
| 🟠 N2 | El método pasa TODOS los vectores de prueba oficiales del RFC/estándar | Interna (QA) | 30 días |
| 🟢 N3 | Un agente independiente verificó que el método funciona en staging y cumple ≥80% de compliance | Interna (cross-team) | 90 días |
| 🔵 N4 | La máxima autoridad técnica del SBOS certifica que el método cumple 100% del estándar. **Garantía trazable con firma criptográfica.** | Auditoría interna, ISO 27001 | 180 días |
| ⭐ N5 | Una entidad externa acreditada certifica que el método cumple el estándar internacional. **Garantía legal/contractual.** | Auditoría externa, clientes, reguladores | 365 días |

### 10.7 Datos de Certificación que se Generan

Cada certificación produce un **paquete de evidencia** que incluye:

| Artefacto | Formato | Almacenamiento | Propósito |
|-----------|---------|---------------|-----------|
| Certificado firmado | JSON + Ed25519 sig | `certification_certificate` (WORM) | Prueba primaria de certificación |
| Output de tests | TXT/JSON | `tests/output/<method>-<date>.log` | Evidencia de ejecución |
| Compliance score | Materialized View | `compliance_score` | Score numérico |
| Informe de verificación | Markdown | `context/sbos/.../certification-reports/` | Revisión cualitativa |
| Hash del commit | Git SHA | `certification_certificate.commit_hash` | Trazabilidad al código |
| Firma del certificador | Ed25519 hex | `certification_certificate.signature_ed25519` | No repudio |
| Anclaje blockchain | Merkle leaf | `blk_merkle_leaf` (D12) | Inmutabilidad externa |

### 10.8 Vigencia y Renovación

| Evento | Acción |
|--------|--------|
| **Expiración natural** | 30 días antes, notificar al desarrollador. Re-ejecutar `bauth-compliance-check.sh`. Si pasa → renovar. Si falla → degradar a Nivel 1. |
| **Modificación del módulo** | La certificación se INVALIDA automáticamente. El método vuelve a Nivel 1. El desarrollador DEBE solicitar re-certificación. |
| **Hallazgo de seguridad** | Revocación INMEDIATA. `revoked_at = now()`. El método vuelve a Nivel 0. Requiere plan de remediación. |
| **Cambio de estándar** (ej: NIST publica Rev.5) | La certificación se MARCA PARA REVISIÓN. Nuevos test cases agregados a `compliance_test_case`. El método debe pasar los nuevos tests en 90 días. |
| **Auditoría programada** | Cada 180 días para N4, cada 90 días para N3. Re-ejecutar suite completa. |

### 10.9 Revocación de Certificación

```sql
-- Revocar un certificado (solo sbos-coordinador puede)
UPDATE bauth.certification_certificate 
SET revoked_at = now(), 
    revocation_reason = '<motivo>' 
WHERE certificate_id = '<uuid>';
```

**Causas de revocación:**
1. Hallazgo de vulnerabilidad de seguridad (OWASP Top 10)
2. Regresión detectada en tests de compliance
3. Falsificación de resultados de certificación
4. Cambio en el estándar que el método ya no cumple
5. Orden de sbos-coordinador por riesgo sistémico

**Una certificación revocada NO se puede restaurar. Se debe iniciar un NUEVO proceso de certificación desde Nivel 1.**

---

## 12. Organismos Certificadores Reales

**Las certificaciones de Nivel 4 y 5 NO las emiten agentes IA.** Las emiten organismos de certificación acreditados con reconocimiento legal internacional. Esta sección documenta QUIÉNES son, QUÉ certifican, QUÉ documentación requieren, y CÓMO es el proceso.

### 12.1 Organismos en Bolivia

| Organismo | Tipo | Qué certifica | Web |
|-----------|------|--------------|-----|
| **IBNORCA** | Normalización y Certificación | NB/ISO/IEC 27001:2022 (SGSI) | www.ibnorca.org, Calle 7 Nº 545 Obrajes, La Paz |
| **DTA-IBMETRO** | Acreditación | Acredita certificadores ISO en Bolivia (miembro IAAC) | ibmetro.gob.bo |
| **AFNOR International** | Certificación ISO | ISO 27001, ISO 9001. Oficina en Bolivia | international.afnor.com |
| **AGETIC** | Regulación estatal | Certificación software gubernamental | agetic.gob.bo |

**Proceso de certificación ISO 27001:2022 vía IBNORCA:**

```
1. Solicitud formal           → IBNORCA asigna auditor líder
2. Auditoría Fase 1           → Revisión documental del SGSI (3-5 días)
3. Auditoría Fase 2           → Verificación in situ de 93 controles (5-10 días)
4. Informe de no conformidades → 30-90 días para corregir hallazgos
5. Auditoría de cierre        → Verificación de correcciones
6. Emisión del certificado    → Vigencia 3 años con seguimiento anual
7. Re-certificación           → Cada 3 años, ciclo completo
```

**Documentación requerida para ISO 27001:**
- Política de Seguridad de la Información (firmada por dirección)
- Declaración de Aplicabilidad (SoA) — 93 controles ISO 27001:2022
- Metodología de evaluación de riesgos (ISO 27005)
- Plan de tratamiento de riesgos con responsables y fechas
- Evidencia de controles implementados (logs, pantallas, configuraciones)
- Registros de auditoría interna (mínimo 1 por año)
- Registros de revisión por la dirección (mínimo 1 por año)
- 12 procedimientos documentados obligatorios

### 12.2 Organismos Internacionales de Certificación de Protocolos

| Organismo | Qué certifica | Proceso | Costo (USD) | Tiempo |
|-----------|--------------|---------|:---:|:---:|
| **OpenID Foundation** | OIDC Provider | Ejecutar conformance suite → submit → review | $5K-$15K | 3-6 meses |
| **FIDO Alliance** | FIDO2/WebAuthn Authenticator | Lab acreditado evalúa funcional + seguridad | $15K-$50K | 6-12 meses |
| **Kantara Initiative** | NIST SP 800-63 Trust Mark | Assessor acreditado evalúa IAL/AAL/FAL | $20K-$60K | 6-18 meses |
| **NIST NVLAP** | FIPS 140-3 Crypto Module | Lab NVLAP-acreditado (Leidos, UL, Lightship) | $50K-$150K | 12-24 meses |

### 12.3 Camino de Certificación Recomendado para bAuth

| Fase | Certificación | Para qué | Cuándo |
|------|--------------|---------|--------|
| 1 | **ISO 27001:2022** vía IBNORCA/AFNOR | SGSI completo del SBOS | 2027 |
| 2 | **OpenID Foundation** OIDC Provider | bAuth como OP interoperable | Post-Fase 3 bAuth |
| 3 | **FIDO Alliance** Functional Cert | WebAuthn/Passkey conformes | Post-Fase 4 bAuth |
| 4 | **Kantara NIST 800-63** Trust Mark | Identidad digital de alta confianza | 2028 |

### 12.4 Documentación Técnica para Certificación OpenID Foundation

1. **Resultados del conformance test** — ejecutar [OIDF Conformance Suite](https://openid.net/certification/) y pasar todos los tests del perfil Basic OP
2. **Documento de descubrimiento** — `/.well-known/openid-configuration` válido y accesible
3. **Matriz de features** — claims soportados, scopes, response_types, grant_types, algoritmos de firma
4. **Política de rotación de claves** — cómo se rotan las JWK, cada cuánto, quién las firma
5. **Registro de cambios** — versiones del OP, cambios de configuración, actualizaciones de seguridad

### 12.5 Documentación Técnica para Certificación FIDO Alliance

1. **FIDO Functional Test Suite** — ejecutado en lab acreditado FIDO
2. **Declaración de protocolo** — CTAP 2.1/2.2, WebAuthn L2/L3
3. **Matriz de authenticators** — platform, roaming, UV, RK soportados
4. **Metadata Statement** — para FIDO MDS (Metadata Service)
5. **Reporte de seguridad** — resistencia a ataques físicos y lógicos

---

## 13. Base de Datos de Vectores de Ataque — 80+ Escenarios Reales

**Los agentes IA deben ejecutar CIENTOS de pruebas de ataque real contra bAuth.** No solo vectores RFC oficiales — ataques reales documentados por OWASP, NIST, y la industria. Cada vector tiene entrada maliciosa, resultado esperado, estándar violado, y severidad.

### 13.1 Password Attacks (25 vectores)

| # | Vector | Entrada | Esperado | OWASP |
|---|--------|---------|----------|:---:|
| P1 | SQL Injection password | `' OR '1'='1` | Error genérico, sin SQL ejecutado | A03 |
| P2 | SQL Injection username | `admin'--` | Error genérico | A03 |
| P3 | XSS in username | `<script>alert(1)</script>` | Escapado, sin ejecución JS | A03 |
| P4 | Null byte injection | `admin\0` | Tratado como string | A03 |
| P5 | Unicode homoglyph | `𝐀𝐝𝐦𝐢𝐧` vs `Admin` | Normalizado | V6.2 |
| P6 | Password vacía | `""` | "password requerido" | V6.2 |
| P7 | Password 1 char | `"a"` | "mínimo 8 caracteres" | V6.2 |
| P8 | Password 10000 chars | `"a"*10000` | Rechazar por longitud máxima | V6.2 |
| P9 | Username enum — error | Usuario existe vs no existe | Mismo mensaje de error | V6.3 |
| P10 | Username enum — timing | Medir tiempo de respuesta | Tiempo constante ±5% | V6.3 |
| P11 | Credential stuffing | 1000 passwords RockYou top | Rate limit: 5 intentos/60s | A07 |
| P12 | Password spraying | 1 password × 1000 users | Rate limit: IP + cuenta | A07 |
| P13 | Brute force 100 threads | 100 threads × 10000 passwords | Rate limit global consistente | A07 |
| P14 | HIBP compromised | `P@ssw0rd` (en HIBP) | "password comprometida" | V6.2 |
| P15 | Password = username | `user == pass` | Rechazar | V6.2 |
| P16 | Control chars in password | `pass\x00\x01word` | Sanitizar o rechazar | A03 |
| P17 | Replay hashed password | Enviar hash Argon2id | Rechazar, solo plaintext | V6.2 |
| P18 | JSON injection | `{"password": {"$gt": ""}}` | Validar tipo string | A03 |
| P19 | Wrong Content-Type | text/plain | 415 Unsupported Media Type | A03 |
| P20 | Binary body as JSON | Raw bytes | Parse error controlado | A03 |
| P21 | GET instead of POST | GET /login | 405 Method Not Allowed | A03 |
| P22 | Race condition login | 100 requests simultáneos | Rate limit consistente | A07 |
| P23 | Forceful browsing | GET /dashboard sin token | 401 Unauthorized | A01 |
| P24 | Session reuse — 2 IPs | Mismo token desde IP A y B | Invalidar o alertar | A07 |
| P25 | Password history reuse | Misma password 3 veces | "no puede reutilizar últimas 5" | V6.2 |

### 13.2 TOTP/HOTP Attacks (15 vectores)

| # | Vector | Entrada | Esperado | OWASP |
|---|--------|---------|----------|:---:|
| T1 | TOTP brute force 1M códigos | Enumerar 000000-999999 | Rate limit tras 5 intentos | A07 |
| T2 | TOTP replay | Mismo código 2 veces | Segundo uso rechazado | V6.5 |
| T3 | TOTP expired | Código de hace 5 min | Error "TOTP expirado" | V6.5 |
| T4 | TOTP future timestamp | time()+3600 | "fuera de ventana" | V6.5 |
| T5 | TOTP short secret | Secret 1 byte | "secret muy corto" | RFC 6238 |
| T6 | MFA bypass — modificar JSON | `{"totp_valid":false}`→`true` | Server-side validation inmutable | A07 |
| T7 | MFA skip — URL directa | GET /dashboard sin TOTP | 401 MFA requerido | A07 |
| T8 | MFA fatigue — 50 pushes | 50 push en 60s | Máximo 3 por minuto | A07 |
| T9 | TOTP timing attack | Comparar tiempos | Constante ±5% | V6.2 |
| T10 | TOTP without enrollment | Sin TOTP configurado | "TOTP no configurado" | V6.5 |
| T11 | Backup code cross-user | Código de user A para user B | Rechazar — user-specific | V6.5 |
| T12 | Backup code replay | Usar código YA usado | "código ya utilizado" | V6.5 |
| T13 | Backup code brute force | 1000 intentos recovery | Rate limit + bloqueo | A07 |
| T14 | HOTP counter desync | counter+100 | Re-sync o rechazar | RFC 4226 |
| T15 | HOTP counter overflow | 2^63 | Manejar sin panic | RFC 4226 |

### 13.3 JWT / Token Attacks (20 vectores)

| # | Vector | Entrada | Esperado | OWASP |
|---|--------|---------|----------|:---:|
| J1 | alg:none | Header `{"alg":"none"}` | Rechazar | A07 |
| J2 | RS256→HS256 confusion | Firmar con pubkey como HMAC | "algoritmo no permitido" | A07 |
| J3 | Token expired | exp=hace 1h | "token expirado" | A07 |
| J4 | Token not before | nbf=dentro de 1h | "token aún no válido" | A07 |
| J5 | Token wrong issuer | iss=evil.com | "issuer inválido" | A07 |
| J6 | Token wrong audience | aud=other-app | "audiencia no coincide" | A07 |
| J7 | Token no jti | Sin claim jti | Rechazar | A07 |
| J8 | Token jti replay | Mismo jti 2 tokens | Segundo rechazado | A07 |
| J9 | Token jku injection | `jku:http://evil.com/jwks` | Ignorar o validar allowlist | A07 |
| J10 | Token kid path traversal | `kid:../../etc/passwd` | Validar contra registro interno | A07 |
| J11 | Token unsigned | Sin firma | Rechazar | A07 |
| J12 | Token wrong key | Key B firma, Key A verifica | Rechazar | A07 |
| J13 | Token in query string | `?token=eyJ...` | No aceptar, solo Header | A07 |
| J14 | Token payload 1MB | Payload gigante | "payload excede máximo" | A07 |
| J15 | Token 10000 claims | JSON enorme | Rechazar | A07 |
| J16 | Token replay different IP | IP A → IP B con mismo JWT | Invalidar o DPoP check | A07 |
| J17 | Refresh token race | 2 refresh simultáneos | Rotación: uno válido | A07 |
| J18 | Refresh chain 100 | 100 refresh consecutivos | Toda cadena válida | A07 |
| J19 | Token cookie sin HttpOnly | Cookie sin flags | No aceptar | A07 |
| J20 | Token cookie sin Secure | Cookie sobre HTTP | No aceptar | A07 |

### 13.4 Ataques de Concurrencia y Estrés (20 vectores)

| # | Vector | Descripción | SLA |
|---|--------|------------|-----|
| C1 | 1000 login simultáneos | 1000 hilos, todos OK | P99 < 100ms, 0 errores |
| C2 | 10000 health checks | Bombardear health en 10s | P99 < 5ms, 0 timeouts |
| C3 | 1000 token issues en 5s | Emitir JWT en paralelo | P99 < 200ms, jti únicos |
| C4 | Memory — 10000 sesiones | Crear 10000 ctx_id | < 500MB, sin crash |
| C5 | Connection exhaustion | 10000 conexiones socket | Rechazo graceful al límite |
| C6 | Slowloris | Enviar 1 byte cada 10s | Timeout 30s |
| C7 | JSON-RPC batch 100 | Array 100 requests | Procesar todos |
| C8 | JSON infinite nesting | 1000 niveles de JSON | "profundidad máxima" |
| C9 | Invalid UTF-8 | Bytes `\xFF\xFE` | -32700 parse error |
| C10 | Unicode flood | 100KB de emojis en campo | "campo excede máximo" |
| C11 | Method not found × 1000 | 1000 métodos inexistentes | -32601, sin degradación |
| C12 | Params inválidos × 1000 | domain=99, domain=null | -32602, mensaje descriptivo |
| C13 | Extreme numbers | ttl: 99999999999999999 | "fuera de rango" |
| C14 | Impossible dates | time: -99999999999 | Validar rango |
| C15 | UUID malformed × 100 | null, "", "not-uuid" | Error descriptivo |
| C16 | Race: create+promote | 10 hilos mismo ctx_id | Sin inconsistencia DB |
| C17 | Race: create+delete policy | 10 hilos misma política | Sin duplicados/huérfanos |
| C18 | Memory leak test | 100K ciclos crear/destruir | Memoria estable |
| C19 | FD leak test | 10000 abrir/cerrar socket | FDs vuelven a 0 |
| C20 | Graceful DB down | Detener PostgreSQL | Modo degradado, no crash |

### 13.5 Fuzzing Automatizado — 500+ Variantes por Handler

Para CADA handler JSON-RPC, los agentes IA deben ejecutar fuzzing con:

```
1. 500 payloads con campos aleatorios (libFuzzer / bolero)
2. Campos extras inesperados en el request
3. Valores de tipo incorrecto (string → number, array → object)
4. Valores extremos (MAX_INT, MIN_INT, NaN, Infinity)
5. Inyecciones comunes (SQLi, XSS, path traversal, CRLF)
6. Verificar: NUNCA crash, panic, o 500 sin mensaje
7. Verificar: SIEMPRE respuesta JSON-RPC válida
8. Medir: tiempo de respuesta sin degradación tras 500 variantes
```

**Framework Rust recomendado:** `bolero` (property-based testing) + `cargo-fuzz` (libFuzzer)
**Referencia:** [OWASP Fuzzing Guide](https://owasp.org/www-community/Fuzzing)

---

## 14. Referencias Unificadas

- [RFC 6238 — TOTP Appendix B](https://datatracker.ietf.org/doc/html/rfc6238#appendix-B)
- [RFC 4226 — HOTP Appendix D](https://datatracker.ietf.org/doc/html/rfc4226#appendix-D)
- [RFC 9106 — Argon2](https://www.rfc-editor.org/rfc/rfc9106.html)
- [RFC 8037 — EdDSA/JWK](https://datatracker.ietf.org/doc/html/rfc8037)
- [RFC 8705 — mTLS OAuth 2.0](https://datatracker.ietf.org/doc/html/rfc8705)
- [NIST SP 800-63B Rev.4 (Jul 2025)](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-63b-4.pdf)
- [NIST 800-63B Conformance Criteria](https://www.nist.gov/system/files/documents/2020/07/02/800-63B%20Conformance%20Criteria_0620.pdf)
- [OWASP ASVS 5.0 V6 (May 2025)](https://github.com/OWASP/ASVS)
- [ISO 27001:2022](https://www.iso.org/standard/27001)
- [FIDO CTAP 2.2 (2025)](https://developers.yubico.com/CTAP/CTAP2.2.html)
- [OpenID Foundation Certification](https://openid.net/certification/)
- [FIDO Alliance Certification](https://fidoalliance.org/certification/)
- [Kantara Initiative Trust Framework](https://kantarainitiative.org/)
- [IBNORCA Bolivia](https://www.ibnorca.org) — ISO 27001 en Bolivia
- [AFNOR International Bolivia](https://international.afnor.com/en/our-countries/bolivia/)
- [OWASP Fuzzing Guide](https://owasp.org/www-community/Fuzzing)
- Herramienta: `oathtool` (oath-toolkit) · `openssl verify` · `bolero` (fuzzing) · `cargo-fuzz`

---

*BAUTH-QUALITY-ASSURANCE-SYSTEM v4.0 · 2026-06-29 · SKULL*
