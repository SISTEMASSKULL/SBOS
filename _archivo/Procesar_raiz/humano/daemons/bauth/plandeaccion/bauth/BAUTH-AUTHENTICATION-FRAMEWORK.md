# BAUTH-AUTHENTICATION-FRAMEWORK.md — Framework de Autenticación del SBOS

**Versión:** 1.0.0 · **Fecha:** 2026-06-21 · **Autor:** sbos-coordinador + bauth  
**Clasificación:** CONFIDENCIAL · **Alcance:** SBOS Identity Core v3.0

---

## 1. Propósito

El **bAuth Authentication Framework** es el modelo declarativo completo que gobierna
la autenticación, federación, criptografía y cumplimiento normativo del SBOS.

Define **qué métodos de autenticación existen, qué políticas los gobiernan,
qué algoritmos criptográficos los respaldan, qué protocolos de federación
los interconectan, qué sagas los orquestan, y qué estándares internacionales
los auditan.**

No es código — es **conocimiento declarativo persistido en base de datos**
que el motor Rust de bAuth carga y ejecuta en runtime.

---

## 2. Objetivo

Proveer una **fuente única de verdad (SSOT)** para toda la configuración de
autenticación del ecosistema SBOS, garantizando:

| # | Objetivo | Cómo se cumple |
|---|---------|---------------|
| O1 | **Trazabilidad normativa** | Cada entidad referencia su estándar internacional (ISO, NIST, PCI, OWASP) |
| O2 | **Idempotencia operativa** | Seeds SQL con `ON CONFLICT DO NOTHING` — 100% repetibles sin daño |
| O3 | **Separación de concerns** | 7 tablas independientes con responsabilidades acotadas |
| O4 | **Auditabilidad** | `saga_execution` + `compliance_map` permiten evidenciar cumplimiento |
| O5 | **Extensibilidad sin recompilar** | Agregar un método/política/algoritmo = INSERT en BD, sin tocar Rust |
| O6 | **Multi-tenant ready** | `tier` en cada entidad permite políticas diferenciadas por nivel |

---

## 3. Arquitectura — 7 Tablas Declarativas

```
┌──────────────────────────────────────────────────────────────────┐
│              BAUTH AUTHENTICATION FRAMEWORK v1.0.0                │
│                  7 Tablas · 110+ Registros                        │
├────────────┬──────────┬──────────────────────────────────────────┤
│   Tabla    │ Registros│  Rol en el framework                      │
├────────────┼──────────┼──────────────────────────────────────────┤
│ 1.auth_method      │ 15 │ Catálogo de métodos de autenticación    │
│ 2.auth_policy      │ 22 │ Políticas por tier (NIST 800-63B Rev.4) │
│ 3.auth_config      │ 13 │ Configuraciones operativas              │
│ 4.crypto_algorithm │ 12 │ Algoritmos criptográficos (FIPS 140-3)  │
│ 5.federation_protocol│12│ Protocolos de federación (OAuth 2.1)    │
│ 6.saga_catalog     │ 12 │ Sagas de autenticación (orquestación)   │
│ 7.compliance_map   │ 24 │ Mapeo a estándares internacionales      │
└────────────┴──────────┴──────────────────────────────────────────┘
```

### 3.1 `auth_method` — 15 Métodos de Autenticación

Cada método se alinea con un **NIST Authentication Assurance Level (AAL)**:

| AAL | Métodos | Propósito |
|-----|---------|-----------|
| **AAL1** | Password, Passkey, Email OTP, Kerberos | Single-factor — consumidores (EXT_N0) |
| **AAL2** | TOTP, HOTP, WebAuthn 2FA, Conditional OTP | Multi-factor — negocio (BIZ) |
| **AAL3** | WebAuthn Passwordless, X.509 mTLS | Phishing-resistant — superusuarios (SU) |

**Campos clave:**
- `method_id` — identificador único (ej: `KC_WEBAUTHN_PASSWORDLESS`)
- `method_type` — `single_factor | multi_factor | phishing_resistant | federated | machine | recovery | adaptive | device`
- `aal_level` — `AAL1 | AAL2 | AAL3 | AAL1-AAL2 | AAL2-AAL3 | n/a`
- `nist_status` — `preferred | permitted | discouraged | deprecated`
- `applies_to` — array de tiers (`{SU, SYS, BIZ_N3_N5, ...}`)
- `rfc_ref` — referencia RFC (ej: `RFC_6238`)

### 3.2 `auth_policy` — Políticas por Tier

Define **qué reglas aplican a cada nivel de usuario**:

| Policy Type | Ejemplo | Tiers afectados |
|-------------|---------|-----------------|
| `password` | Longitud mínima (SU:20, EXT:8) | SU, SYS, BIZ, EXT |
| `rate_limit` | Requests/segundo (SU:∞, EXT:10) | Todos |
| `mfa` | Métodos MFA requeridos (SU:AAL3, EXT:AAL1) | Todos |
| `session` | Duración máxima (SU:4h, BIZ:8h) | SU, SYS, BIZ |
| `lockout` | Bloqueo progresivo (5→10→20 intentos) | ALL |

**UNIQUE:** `(policy_name, tier)` — una misma política puede tener valores distintos por tier.

### 3.3 `auth_config` — Configuraciones Operativas

Parámetros que controlan el comportamiento del motor en runtime:

| Config | Ejemplo SU | Ejemplo EXT |
|--------|-----------|------------|
| `token.access_ttl_minutes` | 5 min | 24 horas |
| `hash.argon2id.params` | t=5 m=128MB p=2 | t=2 m=32MB p=1 |
| `key.rotation` | proactiva cada 4h | — |
| `mfa.enrollment` | grace 7d, codes=10 | grace 7d, codes=10 |

### 3.4 `crypto_algorithm` — 12 Algoritmos Criptográficos

| Categoría | Algoritmos | FIPS |
|-----------|-----------|------|
| **Hashing** | Argon2id, SHA-256, SHA3-256 | FIPS 140-3 / 202 |
| **Firma digital** | ES256 (ECDSA P-256), ES384, Ed25519 | FIPS 186-5 |
| **Cifrado** | AES-256-GCM | FIPS 197 |
| **Key derivation** | HKDF-SHA256 | NIST SP 800-56C |
| **Post-cuántico** | CRYSTALS-Kyber-1024 (FIPS 203), CRYSTALS-Dilithium-5 (FIPS 204), SPHINCS+ (FIPS 205), NTRU HPS-4096 | NIST PQC 2024 |

### 3.5 `federation_protocol` — 12 Protocolos de Federación

| Protocolo | RFC | Estado en bAuth |
|-----------|-----|----------------|
| OAuth 2.0 Auth Code + PKCE | RFC 7636 | **enabled** |
| OAuth 2.0 Client Credentials (M2M) | RFC 6749 §4.4 | **enabled** |
| OAuth 2.0 Refresh Token Rotation | RFC 6749 §6 | **enabled** |
| OAuth 2.0 Device Authorization | RFC 8628 | **enabled** |
| OAuth 2.0 Token Exchange | RFC 8693 | **enabled_controlled** |
| OpenID Connect Auth Code | OIDC Core | **enabled** |
| SAML 2.0 Web SSO | SAML 2.0 | **enabled** |
| mTLS OAuth 2.0 | RFC 8705 | **enabled** |
| DPoP | RFC 9449 | **planned** |
| CIBA | OIDC CIBA Core | **enabled** |
| ROPC (password grant) | RFC 6749 §4.3 | **disabled_permanently** |
| Implicit Grant | RFC 6749 §4.2 | **disabled_permanently** |

### 3.6 `saga_catalog` — 12 Sagas de Autenticación

Flujos orquestados con pasos secuenciales y compensaciones inversas.
Invocables vía JSON-RPC 2.0: `bauth.saga.execute`.

| # | Saga | Pasos | Timeout | Compensación |
|---|------|-------|---------|-------------|
| S1 | `auth.password.login` | 6 | 45s | full_rollback |
| S2 | `auth.mfa.totp` | 4 | 30s | full_rollback |
| S3 | `auth.mfa.webauthn` | 7 | 60s | full_rollback |
| S4 | `auth.step_up` | 7 | 120s | full_rollback |
| S5 | `auth.token.refresh` | 5 | 10s | full_rollback |
| S6 | `auth.federated.oidc` | 7 | 60s | checkpoint |
| S7 | `auth.emergency.break_glass` | 7 | 4h | manual (HITL) |
| S8 | `auth.offline.login` | 6 | 30s | best_effort |
| S9 | `auth.password.reset` | 8 | 15min | full_rollback |
| S10 | `auth.mfa.enroll` | 6 | 5min | full_rollback |
| S11 | `auth.session.validate` | 5 | 2s | best_effort |
| S12 | `auth.account.lockout` | 6 | 5s | checkpoint |

### 3.7 `compliance_map` — 24 Mapeos de Cumplimiento

Cada control de estándar internacional mapeado a su implementación en bAuth:

| Estándar | Controles | Ejemplo |
|----------|----------|---------|
| **ISO 27001:2022** | 7 | A.8.5 Secure Authentication → `auth_method` (KC_WEBAUTHN, KC_TOTP) |
| **NIST SP 800-53 Rev.5** | 3 | AC-6 Least Privilege → `auth_policy` (per-tier) |
| **NIST SP 800-63B Rev.4** | 4 | AAL1-3 → `auth_method` (catálogo completo) |
| **NIST SP 800-207 (ZTA)** | 2 | ZTA-1 Continuous Verification → `saga_catalog` (S11) |
| **PCI DSS 4.0.1** | 3 | Req 8.4.2 MFA for CDE → `auth_policy` (mfa.required) |
| **GDPR** | 2 | Art.32 Security of Processing → `crypto_algorithm` (AES-256-GCM) |
| **OWASP ASVS 4.0.3** | 3 | V2.2.1 Anti-Automation → `auth_policy` (rate_limit) |

---

## 4. Forma de Uso

### 4.1 Carga inicial (bootstrap)

```bash
# Desde el directorio del proyecto BauthAgent
cat db/seeds/019_auth_framework_complete.sql | \
  ssh root@VPS "kubectl exec -i -n sbos-data postgresql-0 -- psql -U postgres -d bauth_db"
```

### 4.2 Consulta desde Rust (runtime)

```rust
// Cargar todos los métodos de autenticación activos
let methods: Vec<AuthMethodRow> = sqlx::query_as(
    "SELECT * FROM bauth.auth_method WHERE active = TRUE ORDER BY method_id"
).fetch_all(&pg_pool).await?;

// Cargar políticas para un tier específico
let policies: Vec<AuthPolicyRow> = sqlx::query_as(
    "SELECT * FROM bauth.auth_policy WHERE tier = $1 OR tier = 'ALL' ORDER BY priority"
).bind("BIZ_N3_N5").fetch_all(&pg_pool).await?;

// Verificar compliance de un control
let compliance: ComplianceRow = sqlx::query_as(
    "SELECT * FROM bauth.compliance_map WHERE standard = $1 AND control_id = $2"
).bind("ISO_27001_2022").bind("A.8.5").fetch_one(&pg_pool).await?;
```

### 4.3 Invocación de sagas vía JSON-RPC

```bash
curl --unix-socket /run/bos/bauth.sock -H 'Content-Type: application/json' -d '{
  "jsonrpc": "2.0",
  "method": "bauth.saga.execute",
  "params": {
    "saga": "auth.password.login",
    "ctx_id": "tenant-001.emp-01.suc-001.pos-01.user-42.trace-abc",
    "params": {
      "username": "cajero@skull.bo",
      "password": "correct-horse-battery-staple",
      "client_ip": "10.0.0.50",
      "device_fingerprint": "fp-abc123"
    }
  },
  "id": 1
}'
```

### 4.4 Validación de idempotencia

```bash
# Ejecutar 3 veces — siempre INSERT 0 0
for i in 1 2 3; do
  echo "Vuelta $i:"
  cat db/seeds/019_auth_framework_complete.sql | \
    ssh root@VPS "kubectl exec -i -n sbos-data postgresql-0 -- psql -U postgres -d bauth_db" \
    2>&1 | grep -E 'INSERT|ERROR'
done
```

---

## 5. Forma de Actualización

### 5.1 Agregar un nuevo método de autenticación

```sql
-- Ejemplo: agregar soporte para Passkey con biometría avanzada
INSERT INTO bauth.auth_method (method_id, method_name, method_type, category, aal_level, nist_status, applies_to, rfc_ref, requires_https)
VALUES ('KC_PASSKEY_BIO', 'Passkey with Advanced Biometrics', 'phishing_resistant', 'cryptographic', 'AAL3', 'preferred', '{SU,SYS}', 'W3C_WebAuthn_L2', TRUE)
ON CONFLICT (method_id) DO UPDATE SET method_name = EXCLUDED.method_name;
```

### 5.2 Actualizar una política existente

```sql
-- Cambiar el mínimo de password para SU de 20 a 24 caracteres
UPDATE bauth.auth_policy
SET policy_data = '{"min_length":24,"recommended":32,"max_length":128}'::jsonb,
    updated_at = now()
WHERE policy_name = 'password.min_length' AND tier = 'SU';
```

### 5.3 Agregar una nueva saga

```sql
-- 1. Insertar en el catálogo
INSERT INTO bauth.saga_catalog (saga_name, version, description, compensation, max_timeout_ms, tier_minimum, audit_level)
VALUES ('auth.passwordless.login', '1.0.0', 'Login sin password con FIDO2/WebAuthn + Passkey', 'full_rollback', 30000, 'EXT_N0', 'full')
ON CONFLICT DO NOTHING;

-- 2. Insertar sus pasos
INSERT INTO bauth.saga_step (saga_name, step_order, step_name, saga_op, action_ref, compensate_ref, timeout_ms, max_retries, depends_on)
VALUES
    ('auth.passwordless.login', 0, 'generar_challenge', 'execute', 'bauth.webauthn.generate_challenge', NULL, 1000, 0, '{}'),
    ('auth.passwordless.login', 1, 'verificar_assertion', 'execute', 'bauth.webauthn.verify_assertion', 'bauth.webauthn.revoke_challenge', 30000, 0, '{generar_challenge}'),
    ('auth.passwordless.login', 2, 'emitir_token', 'execute', 'bauth.token.emit_jwt', 'bauth.token.revoke_immediate', 2000, 0, '{verificar_assertion}')
ON CONFLICT (saga_name, step_name) DO NOTHING;
```

### 5.4 Actualizar un mapeo de cumplimiento

```sql
-- Marcar control como implementado
UPDATE bauth.compliance_map
SET implementation_status = 'implemented',
    evidence_ref = 'bauth.auth_method (KC_PASSKEY_BIO)',
    last_reviewed = now()
WHERE standard = 'NIST_800_63B_Rev4' AND control_id = 'AAL3';
```

### 5.5 Desplegar cambios

```bash
# Generar nuevo seed idempotente con los cambios
pg_dump -t bauth.auth_method -t bauth.auth_policy -t bauth.auth_config \
        -t bauth.crypto_algorithm -t bauth.federation_protocol \
        -t bauth.saga_catalog -t bauth.saga_step -t bauth.compliance_map \
        --inserts --on-conflict-do-nothing > db/seeds/020_framework_update.sql

# Ejecutar en staging
cat db/seeds/020_framework_update.sql | \
  ssh root@VPS "kubectl exec -i -n sbos-data postgresql-0 -- psql -U postgres -d bauth_db"
```

---

## 6. Requerimientos para el CRUD de Actualización

### 6.1 Reglas no negociables

| # | Regla | Sanción si se viola |
|---|-------|-------------------|
| R1 | **Todo INSERT debe usar `ON CONFLICT DO NOTHING` o `DO UPDATE`** | Seed no idempotente → rechazado por Bibliotecario |
| R2 | **Toda entidad debe referenciar al menos 1 estándar internacional** | Registro huérfano → no trazable en auditoría |
| R3 | **Nunca eliminar filas con `DELETE` — usar `active = FALSE`** | Borrado duro rompe auditoría ISO 27001 A.8.15 |
| R4 | **Todo cambio debe documentarse en `updated_at`** | Sin timestamp → imposible determinar cuándo se aplicó |
| R5 | **Nuevas sagas deben validarse con `validate_saga()` antes del INSERT** | Saga con ciclos → bAuth rechaza el catálogo al arrancar |
| R6 | **Métodos `deprecated` no deben asignarse a nuevos tiers** | Método obsoleto en producción → riesgo NIST |
| R7 | **Cada política `per-tier` debe tener su contraparte `ALL` o cubrir todos los tiers** | Tier sin política → comportamiento indefinido |

### 6.2 Permisos requeridos

| Operación | Rol requerido | Aprobación |
|-----------|-------------|-----------|
| `INSERT` en `auth_method` | ROL-SYS-ADMIN-SEGURIDAD | 1 aprobador |
| `INSERT`/`UPDATE` en `auth_policy` | ROL-SYS-ADMIN-SEGURIDAD | 1 aprobador |
| `INSERT` en `saga_catalog` | ROL-SYS-ADMIN-PROYECTO | 2 aprobadores |
| `UPDATE` en `compliance_map` | ROL-SYS-ADMIN-SEGURIDAD + Oficial de Cumplimiento | 2 aprobadores |
| `DELETE` (soft) | ROL-SYS-SUPERUSUARIO (break-glass) | 2-of-3 Shamir |

### 6.3 Flujo de aprobación para cambios

```
Desarrollador (bauth)
  │
  ├─→ Propone cambio en seed SQL
  │
  ├─→ sbos-coordinador revisa impacto arquitectónico
  │
  ├─→ Bibliotecario valida idempotencia + estándares
  │
  ├─→ Operador prueba en staging (nspawn blindado)
  │
  └─→ Coordinador aprueba deployment a producción
```

---

## 7. Rol e Impacto en el Proyecto

### 7.1 Rol del Framework

El **bAuth Authentication Framework** es el **plano de control de identidad del SBOS**.
Sin él:

- ❌ Los daemons no saben qué métodos de autenticación están permitidos
- ❌ Las políticas de seguridad no tienen dónde declararse
- ❌ No hay trazabilidad entre controles ISO/NIST y su implementación real
- ❌ Cada cambio de configuración requiere recompilar Rust
- ❌ Los auditores no pueden verificar cumplimiento normativo

Con él:

- ✅ biedata puede consultar `auth_method` para decidir qué método usar según el tier
- ✅ bkernel puede consumir `saga_execution` para alimentar sus streams CDC
- ✅ Kong puede leer `federation_protocol` para configurar sus plugins OIDC
- ✅ Los auditores tienen `compliance_map` como evidencia directa
- ✅ Agregar un método nuevo es 1 INSERT, no 1 semana de desarrollo

### 7.2 Impacto en otros módulos

| Módulo | Cómo consume el Framework |
|--------|--------------------------|
| **biedata** | Invoca `bauth.saga.execute` para autenticar usuarios en sagas de negocio |
| **bkernel** | Consume eventos de `saga_execution` vía Redis Stream para CDC |
| **Kong** | Lee `federation_protocol` para configurar plugins OIDC/OAuth 2.0 |
| **Vault** | Lee `crypto_algorithm` para determinar algoritmos de PKI |
| **Keycloak** | Aplica `auth_policy` por realm (password policy, MFA requerida) |
| **Prometheus** | Monitorea `saga_execution` para SLOs de autenticación |
| **Loki** | Recibe logs de auditoría de cada ejecución de saga |
| **Auditores** | `compliance_map` como evidencia ISO 27001, PCI DSS, GDPR |

### 7.3 Cobertura normativa

| Estándar | % Cubierto | Controles |
|----------|-----------|-----------|
| ISO 27001:2022 | 70% (7/10 relevantes) | A.5.15-18, A.8.2, A.8.5, A.8.15 |
| NIST SP 800-53 Rev.5 | 60% (3/5 relevantes) | AC-2, AC-5 (planned), AC-6 |
| NIST SP 800-63B Rev.4 | 100% (4/4) | AAL1, AAL2, AAL3, §5.1.1 |
| PCI DSS 4.0.1 | 75% (3/4 relevantes) | Req 8.2, 8.4.2, 8.5.1 (planned) |
| GDPR | 50% (2/4 relevantes) | Art.32, Art.33 (planned) |
| OWASP ASVS 4.0.3 V2 | 75% (3/4 relevantes) | V2.1.1, V2.1.7, V2.2.1 |

---

## 8. Referencias

### 8.1 Documentos del proyecto

| Documento | Ubicación |
|-----------|----------|
| SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md | `context/sbos/Procesar/humano/daemons/bauth/` |
| Policies_Authentication_Framework_v4.json | `plandeaccion/bauth/` |
| 019_auth_framework_complete.sql | `BauthAgent/db/seeds/` |
| BitMask Dual v3.0 | `BauthAgent/src/bitmask/` |

### 8.2 Estándares internacionales

| Estándar | Versión | Año |
|----------|---------|-----|
| ISO/IEC 27001 | 2022 | 2022 |
| ISO/IEC 24760-1/2/3/4 | 2025 | 2025 |
| NIST SP 800-63B | Rev.4 | 2025 |
| NIST SP 800-207 (Zero Trust) | Final | 2020 |
| NIST SP 1800-35 (ZTA Implementation) | Final | 2024 |
| FIPS 140-3 | — | 2019 |
| FIPS 203 (CRYSTALS-Kyber) | — | 2024 |
| FIPS 204 (CRYSTALS-Dilithium) | — | 2024 |
| FIPS 205 (SPHINCS+) | — | 2024 |
| PCI DSS | 4.0.1 | 2025 |
| OWASP ASVS | 4.0.3 | 2024 |
| OAuth 2.1 BCP | — | 2025 |
| RFC 9470 (Step-Up) | — | 2023 |
| FIDO2/WebAuthn | Level 3 | 2024 |

---

## 9. Historial de cambios

| Versión | Fecha | Autor | Cambios |
|---------|-------|-------|---------|
| 1.0.0 | 2026-06-21 | sbos-coordinador + bauth | Framework inicial: 7 tablas, 110+ registros, 12 sagas, 24 compliance maps |

---

> **Principio rector:** La seguridad no se implementa — se declara. El código ejecuta lo que las tablas definen.
> Toda política, método, algoritmo y protocolo debe existir primero en BD antes de escribirse en Rust.
